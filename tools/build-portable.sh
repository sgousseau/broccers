#!/usr/bin/env bash
# Broccers — Build d'une distribution portable (USB / clé USB)
#
# Produit un dossier `dist/portable/` autonome contenant :
#   - br_server (binaire compilé pour la plateforme courante)
#   - web/ (build Flutter Web release)
#   - docs/ (HTML statique)
#   - data/broc.db (BD vierge ou seed)
#   - launch.sh (lance le serveur + ouvre le navigateur)
#   - launch.bat (équivalent Windows)
#   - README.md (mode d'emploi)
#
# Usage :
#   ./tools/build-portable.sh              # plateforme courante, BD vide
#   ./tools/build-portable.sh --with-seed  # avec BD de démo
#   ./tools/build-portable.sh --platform linux-x64

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST="$ROOT/dist/portable"
PLATFORM="$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m)"
WITH_SEED=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --with-seed) WITH_SEED=1; shift ;;
    --platform) PLATFORM="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,/^set -e/p' "$0" | sed 's/^# //'
      exit 0 ;;
    *) echo "Unknown option: $1"; exit 64 ;;
  esac
done

echo "→ Broccers portable build"
echo "  Platform     : $PLATFORM"
echo "  With seed    : $WITH_SEED"
echo "  Output       : $DIST"
echo ""

# --- 1. Clean output ---
rm -rf "$DIST"
mkdir -p "$DIST/web" "$DIST/docs" "$DIST/data" "$DIST/logs"

# --- 2. Compile br_server ---
echo "→ Compiling br_server for current platform..."
cd "$ROOT"
dart compile exe packages/br_server/bin/server.dart -o "$DIST/br_server"
echo "  → $(du -h "$DIST/br_server" | cut -f1)"

# --- 3. Build Flutter Web ---
echo "→ Building Flutter Web release..."
cd "$ROOT/packages/br_web"
flutter build web --release --output "$DIST/web" 2>&1 | tail -5
cd "$ROOT"
echo "  → $(du -sh "$DIST/web" | cut -f1)"

# --- 4. Copy docs ---
echo "→ Copying HTML docs..."
cp -r "$ROOT/docs/"*.html "$DIST/docs/" 2>/dev/null || true
echo "  → $(ls "$DIST/docs/" | wc -l | tr -d ' ') files"

# --- 5. Seed DB (optional) ---
if [[ $WITH_SEED -eq 1 ]]; then
  echo "→ Seeding demo database..."
  # Copy production DB as seed (snapshot)
  if [[ -f "$HOME/.broccers/broc.db" ]]; then
    cp "$HOME/.broccers/broc.db" "$DIST/data/broc.db"
    echo "  → seeded from ~/.broccers/broc.db ($(du -h "$DIST/data/broc.db" | cut -f1))"
  else
    echo "  ⚠ ~/.broccers/broc.db introuvable — démarrera avec une BD vide"
  fi
fi

# --- 6. Generate PIN + JWT for portable use ---
echo "→ Generating portable PIN (1234) + JWT secret..."
PIN_HASH=$(dart run scripts/setup-pin.dart 1234 2>/dev/null | grep "BR_PIN_BCRYPT_HASH" | sed "s/.*BR_PIN_BCRYPT_HASH='\(.*\)'/\1/")
JWT_SECRET=$(dart run scripts/setup-pin.dart 1234 2>/dev/null | grep "BR_JWT_SECRET" | sed "s/.*BR_JWT_SECRET='\(.*\)'/\1/")

# --- 7. Generate launchers ---
echo "→ Generating launchers (launch.sh + launch.bat)..."

cat > "$DIST/launch.sh" <<EOF
#!/usr/bin/env bash
# Broccers portable — lance le serveur et ouvre le navigateur
# PIN par défaut : 1234

DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
cd "\$DIR"

export BR_HOST="127.0.0.1"
export BR_PORT="8444"
export BR_DATA_DIR="\$DIR/data"
export BR_DB_PATH="\$DIR/data/broc.db"
export BR_PIN_BCRYPT_HASH='$PIN_HASH'
export BR_JWT_SECRET='$JWT_SECRET'
export BR_PORTABLE="1"

mkdir -p "\$DIR/logs"

echo "🍻 Broccers portable — démarrage..."
echo "   PIN : 1234"
echo "   BD  : \$BR_DB_PATH"
echo ""

# Lancer le serveur en arrière-plan
./br_server > logs/server.log 2>&1 &
SERVER_PID=\$!

# Lancer un serveur web simple (Python ou Ruby) pour servir le frontend
if command -v python3 &>/dev/null; then
  echo "→ Serveur web (Python) sur :8766..."
  (cd web && python3 -m http.server 8766 > "\$DIR/logs/web.log" 2>&1) &
  WEB_PID=\$!
elif command -v python &>/dev/null; then
  (cd web && python -m SimpleHTTPServer 8766 > "\$DIR/logs/web.log" 2>&1) &
  WEB_PID=\$!
elif command -v ruby &>/dev/null; then
  (cd web && ruby -run -e httpd . -p 8766 > "\$DIR/logs/web.log" 2>&1) &
  WEB_PID=\$!
else
  echo "⚠ Pas de Python ni Ruby trouvé — frontend non démarré"
  WEB_PID=""
fi

sleep 2

# Ouvrir le navigateur
URL="http://127.0.0.1:8766"
echo "→ Ouverture de \$URL"
if [[ "\$OSTYPE" == "darwin"* ]]; then
  open "\$URL"
elif command -v xdg-open &>/dev/null; then
  xdg-open "\$URL"
fi

echo ""
echo "✓ Broccers est lancé."
echo "  Serveur : http://127.0.0.1:8444 (PID \$SERVER_PID)"
echo "  Web     : http://127.0.0.1:8766 (PID \${WEB_PID:-none})"
echo "  Docs    : http://127.0.0.1:8444/docs/presentation"
echo "  Logs    : \$DIR/logs/"
echo ""
echo "Pour arrêter : Ctrl-C ou kill \$SERVER_PID \$WEB_PID"
echo ""

# Wait pour que Ctrl-C arrête tout proprement
trap "echo 'Arrêt...'; kill \$SERVER_PID \$WEB_PID 2>/dev/null; exit" INT TERM
wait
EOF

chmod +x "$DIST/launch.sh"

cat > "$DIST/launch.bat" <<EOF
@echo off
REM Broccers portable Windows — lance le serveur et ouvre le navigateur
REM PIN par defaut : 1234

cd /d "%~dp0"

set BR_HOST=127.0.0.1
set BR_PORT=8444
set BR_DATA_DIR=%cd%\\data
set BR_DB_PATH=%cd%\\data\\broc.db
set BR_PIN_BCRYPT_HASH=$PIN_HASH
set BR_JWT_SECRET=$JWT_SECRET
set BR_PORTABLE=1

if not exist logs mkdir logs

echo Broccers portable - demarrage...
echo PIN : 1234
echo.

start /B br_server.exe > logs\\server.log 2>&1

REM Serveur web Python si dispo
where python >nul 2>&1
if %errorlevel% == 0 (
  start /B cmd /c "cd web && python -m http.server 8766 > ..\\logs\\web.log 2>&1"
) else (
  echo Avertissement : Python non trouve, frontend non demarre
)

timeout /t 2 /nobreak >nul

echo Ouverture du navigateur...
start http://127.0.0.1:8766

echo.
echo Broccers est lance.
echo Serveur : http://127.0.0.1:8444
echo Web     : http://127.0.0.1:8766
echo Docs    : http://127.0.0.1:8444/docs/presentation
echo.
echo Fermez cette fenetre ou pressez Ctrl-C pour arreter.

pause
EOF

# --- 8. README ---
cat > "$DIST/README.md" <<'EOF'
# Broccers Portable

Distribution autonome de Broccers à lancer depuis une clé USB ou un dossier local, sans installation préalable.

## Démarrage

### macOS / Linux

```bash
./launch.sh
```

### Windows

Double-cliquer sur `launch.bat`.

## Premier accès

- Ouvre automatiquement http://127.0.0.1:8766 dans le navigateur
- PIN super-admin par défaut : **1234**

## Contenu

| Élément | Description |
|---------|-------------|
| `br_server` | Backend Dart compilé natif pour la plateforme |
| `web/` | Application Flutter Web (build release) |
| `docs/` | Documentation HTML (présentation, spécifications) |
| `data/` | Base de données SQLite + exports PDF |
| `logs/` | Logs serveur et web |
| `launch.sh` / `launch.bat` | Lanceurs |

## Spécificités

- Pas de connexion Internet requise (sauf appels IA Claude)
- Aucune installation système nécessaire
- Données 100 % locales dans le dossier `data/`
- Pour utiliser sur une autre machine : copier le dossier complet

## Limites

- Les fonctionnalités IA (briefing Claude, vision photo carte, commande vocale) nécessitent que `claude` CLI soit installé sur la machine hôte et accessible dans le PATH.
- Le frontend nécessite Python (ou Ruby) installé sur la machine pour servir les fichiers statiques.

## Sauvegarder vos données

Copier le fichier `data/broc.db` quelque part en sécurité. C'est l'unique fichier nécessaire pour préserver la totalité du contenu (employés, cartes, tables, journal, paramètres).

## Documentation

- Présentation fonctionnelle : http://127.0.0.1:8444/docs/presentation
- Spécifications exhaustives : http://127.0.0.1:8444/docs/specifications
EOF

# --- 9. Final stats ---
TOTAL_SIZE=$(du -sh "$DIST" | cut -f1)
echo ""
echo "✓ Distribution portable prête : $DIST ($TOTAL_SIZE)"
echo ""
echo "Contenu :"
find "$DIST" -maxdepth 1 -mindepth 1 | while read f; do
  size=$(du -sh "$f" | cut -f1)
  printf "  %-15s %s\n" "$size" "$(basename $f)"
done
echo ""
echo "Pour lancer :"
echo "  cd $DIST && ./launch.sh"
echo ""
echo "Pour graver sur USB :"
echo "  cp -r $DIST/* /Volumes/MON_USB/Broccers/"
echo "  Sur Windows : copier $DIST sur la clé via Explorer."
