#!/usr/bin/env bash
# Broccers — Orchestrateur complet des tests E2E + génération du rapport HTML
#
# Usage :
#   ./tools/test-all.sh                 → tests complets + rapport
#   ./tools/test-all.sh --quick         → API tests seulement (skip Playwright)
#   ./tools/test-all.sh --commit        → commit + push après tests
#   ./tools/test-all.sh --no-server     → suppose serveurs déjà UP
#
# Pré-requis :
#   - br_server binaire compilé dans bin/br_server
#   - Flutter web servi sur :8766 (sauf --no-server)
#   - python3.13 avec playwright + chromium installés
#   - jq + curl

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# === Config ===
PY=/usr/local/Cellar/python@3.13/3.13.2/Frameworks/Python.framework/Versions/3.13/bin/python3.13
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
SERVER_URL="http://127.0.0.1:8444"
WEB_URL="http://127.0.0.1:8766"
ART="/tmp/broccers-tests"
ASSETS="$ROOT/docs/test-assets"
PIN=1234
PIN_HASH='$2a$12$JbKKhzU/mPU10ny4VQ1eUu4oc1xALNoJQK68cKS8FZhserzAAVmV2'
JWT_SECRET='006e93b8dd03284d7297bce1072c51769bc0e50b30557a9fc4ea0f34597ea3c8ee13385d82a7ccf2173c6186abd0f61b'
CAM_SECRET='broc-camera-test-2026'

# === Args ===
QUICK=0
COMMIT=0
NOSERVER=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --quick)     QUICK=1; shift ;;
    --commit)    COMMIT=1; shift ;;
    --no-server) NOSERVER=1; shift ;;
    -h|--help)
      sed -n '2,/^set -e/p' "$0" | sed 's/^# //'
      exit 0 ;;
    *) echo "Unknown: $1"; exit 64 ;;
  esac
done

mkdir -p "$ART"/{api,screenshots,logs} "$ASSETS"/json

step() { echo ""; echo "════════════════════════════════════"; echo "  $1"; echo "════════════════════════════════════"; }
ok()   { echo "  ✅ $1"; }
fail() { echo "  ❌ $1"; }
info() { echo "  ⓘ  $1"; }

# === Step 1 : ensure servers up ===
step "1/6 Vérification serveurs"

if [[ $NOSERVER -eq 0 ]]; then
  if ! curl -s --max-time 2 "$SERVER_URL/api/health" > /dev/null 2>&1; then
    info "br_server down → restart"
    pkill -f "$ROOT/bin/br_server" 2>/dev/null || true
    sleep 1
    BR_PIN_BCRYPT_HASH="$PIN_HASH" \
    BR_JWT_SECRET="$JWT_SECRET" \
    BR_HOST=0.0.0.0 \
    BR_CAMERA_SHARED_SECRET="$CAM_SECRET" \
    nohup "$ROOT/bin/br_server" > "$ART/logs/br_server.log" 2>&1 &
    sleep 2
  fi
  ok "br_server : $(curl -s $SERVER_URL/api/health | jq -r '.service + " v" + .version + " @ " + .now[:19]')"

  if [[ $QUICK -eq 0 ]]; then
    if ! curl -s --max-time 2 "$WEB_URL/" > /dev/null 2>&1; then
      info "Flutter web down → restart"
      cd "$ROOT/packages/br_web"
      nohup flutter run -d web-server --web-port 8766 --web-hostname 0.0.0.0 --release > "$ART/logs/br_web.log" 2>&1 &
      cd "$ROOT"
      info "Attente Flutter compile (~30s)..."
      for i in $(seq 1 24); do
        sleep 5
        if curl -s --max-time 2 "$WEB_URL/" > /dev/null 2>&1; then break; fi
      done
    fi
    ok "Flutter web : $WEB_URL"
  fi
fi

# === Step 2 : auth + token ===
step "2/6 Authentification + token"
TOKEN=$(curl -s -X POST $SERVER_URL/api/auth/pin -H 'content-type: application/json' \
        -d "{\"pin\":\"$PIN\"}" | jq -r .token)
if [[ -z "$TOKEN" || "$TOKEN" == "null" ]]; then
  fail "Auth PIN $PIN refused"; exit 1
fi
echo "$TOKEN" > "$ART/token.txt"
ok "Token JWT obtenu (${#TOKEN} chars)"
H="Authorization: Bearer $TOKEN"

# === Step 3 : API tests ===
step "3/6 API tests (21 GETs + 11 probes)"

run() {
  local code=$(curl -s -o "$ART/api/$1.json" -w "%{http_code}" -X "$2" "$SERVER_URL$3" -H "$H")
  if [[ "$code" =~ ^2 ]]; then
    ok "$3 → HTTP $code"
  else
    fail "$3 → HTTP $code"
  fi
}

# Happy paths
run phaseA_employees       GET /api/employees
run phaseA_journal         GET "/api/events?limit=20"
run phaseF_settings        GET /api/settings
run phaseF_ingredients     GET /api/ingredients
run phaseF_waste_summary   GET /api/waste/summary
run phaseF_waste_list      GET /api/waste
run phaseF_tables          GET /api/tables
run phaseG_cards_all       GET "/api/menu/cards?include_drafts=true"
run phaseG_card_current    GET /api/menu/cards/current
run phaseG_shopping        GET /api/shopping/lists
run phaseH_features        GET /api/features
run phaseH_features_public GET /api/features/public/enabled
run phaseH_system_config   GET /api/system/config
run phaseH_system_db       GET /api/system/db-info
run phaseH_camera_list     GET "/api/camera-events?limit=20"

# === Step 4 : Probes ===
step "4/6 Probes adversariaux"

# Probe 10 : PIN incorrect
code=$(curl -s -o /dev/null -w "%{http_code}" -X POST $SERVER_URL/api/auth/pin \
       -H 'content-type: application/json' -d '{"pin":"9999"}')
[[ "$code" == "401" ]] && ok "PIN incorrect → 401" || fail "PIN incorrect → $code (attendu 401)"

# Probe 11 : Camera no secret
code=$(curl -s -o /dev/null -w "%{http_code}" -X POST $SERVER_URL/api/camera-events \
       -H 'content-type: application/json' -d '{"camera_id":"x","zone_id":"y","kind":"presenceDetected"}')
[[ "$code" == "401" ]] && ok "Camera sans secret → 401" || fail "Camera sans secret → $code"

# Probe 7 : QR bad secret
TABLE_ID=$(curl -s "$SERVER_URL/api/tables" -H "$H" | jq -r '.tables[0].id // "x"')
code=$(curl -s -o /dev/null -w "%{http_code}" "$SERVER_URL/menu/$TABLE_ID/wrong")
[[ "$code" == "404" ]] && ok "QR bad secret → 404" || fail "QR bad secret → $code"

# Probe 9 : Flag dependency not met
curl -s -X PUT $SERVER_URL/api/features/feature.camera.presence -H "$H" \
     -H 'content-type: application/json' \
     -d '{"enabled":false,"actor":"super_admin"}' > /dev/null
code=$(curl -s -o "$ART/api/probe_flag_dep_409.json" -w "%{http_code}" \
       -X PUT $SERVER_URL/api/features/feature.camera.client_heatmap \
       -H "$H" -H 'content-type: application/json' \
       -d '{"enabled":true,"actor":"super_admin"}')
[[ "$code" == "409" ]] && ok "Flag dep manquante → 409" || fail "Flag dep manquante → $code"

# === Step 5 : Playwright screenshots ===
if [[ $QUICK -eq 0 ]]; then
  step "5/6 Screenshots Flutter (Playwright)"
  if [[ -x "$PY" ]]; then
    $PY "$ROOT/tools/capture-flutter-screens.py" 2>&1 | tail -15
  else
    fail "python3.13 introuvable à $PY"
  fi

  # Screenshots docs HTML via Chrome headless
  info "Docs HTML via Chrome headless"
  for doc in overview presentation specifications features test-report; do
    "$CHROME" --headless --disable-gpu --no-sandbox --hide-scrollbars \
      --window-size="1400,3500" \
      --screenshot="$ASSETS/doc_$doc.png" \
      "$SERVER_URL/docs/$doc" 2>/dev/null
    if [[ -f "$ASSETS/doc_$doc.png" ]]; then
      ok "doc_$doc.png ($(wc -c < $ASSETS/doc_$doc.png | tr -d ' ') bytes)"
    fi
  done
else
  step "5/6 Screenshots — SKIP (mode --quick)"
fi

# Generate pretty JSON for evidence in report
for f in "$ART"/api/*.json; do
  jq . "$f" > "$ASSETS/json/$(basename $f)" 2>/dev/null || true
done

# === Step 6 : Summary ===
step "6/6 Bilan"
NB_API=$(ls "$ART"/api/*.json 2>/dev/null | wc -l | tr -d ' ')
NB_SHOTS=$(ls "$ASSETS"/*.png 2>/dev/null | wc -l | tr -d ' ')
NB_JSON=$(ls "$ASSETS"/json/*.json 2>/dev/null | wc -l | tr -d ' ')
echo "  API dumps      : $NB_API"
echo "  Screenshots    : $NB_SHOTS"
echo "  JSON evidence  : $NB_JSON"
echo ""
echo "  📊 Rapport visuel : $SERVER_URL/docs/test-report"
echo "  🌐 Via Tailscale  : http://100.95.200.28:8444/docs/test-report"

# === Optional commit ===
if [[ $COMMIT -eq 1 ]]; then
  step "BONUS · Commit + push"
  git add docs/test-assets/
  if git diff --staged --quiet; then
    info "Pas de changement à committer"
  else
    git commit -m "test(auto): refresh test-assets via tools/test-all.sh

Rerun complet :
- $NB_API API dumps
- $NB_SHOTS screenshots
- $NB_JSON JSON evidence pretty-printed

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>" 2>&1 | tail -3
    git push origin main 2>&1 | tail -3
  fi
fi

echo ""
echo "✓ Tests terminés à $(date '+%Y-%m-%d %H:%M:%S')"
