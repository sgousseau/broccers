# Broccers — Tools

Outils de test, capture, build et distribution pour Broccers v0.8+.

## Scripts disponibles

### `test-all.sh` — orchestrateur complet (recommandé)

Lance les serveurs si nécessaire, exécute la suite complète (API + probes + Playwright screenshots + génération JSON evidence) et met à jour `docs/test-assets/` avec les artefacts les plus récents.

```bash
./tools/test-all.sh                  # tests complets + rapport (~2 min)
./tools/test-all.sh --quick          # API tests seulement (skip Playwright)
./tools/test-all.sh --commit         # commit + push après tests
./tools/test-all.sh --no-server      # suppose les serveurs déjà UP
```

Le rapport est ensuite servi à `http://127.0.0.1:8444/docs/test-report` (ou `http://100.95.200.28:8444/docs/test-report` via Tailscale).

### `capture-flutter-screens.py` — Playwright Flutter Web

Capture screenshots de tous les écrans Flutter Broccers via Chromium headless avec authentification réelle via UI (PIN 1234). Produit 17 fichiers PNG dans `docs/test-assets/` :

- `flutter_login.png` — écran d'accueil avant auth
- `flutter_{personnel,kitchen,menu,shopping,question,journal,costs,waste,tables,settings,admin}.png` — 11 onglets principaux
- `flutter_admin_{system,db}.png` — 2 sous-onglets de Admin
- `flutter_dialog_{new_table,waste,qr}.png` — 3 dialogs interactifs

```bash
PY=/usr/local/Cellar/python@3.13/3.13.2/Frameworks/Python.framework/Versions/3.13/bin/python3.13
$PY tools/capture-flutter-screens.py
```

**Pré-requis :** Python 3.13 + Playwright + Chromium installés. Lecture du token depuis `/tmp/broccers-tests/token.txt` (généré par `test-all.sh`).

### `build-portable.sh` — distribution USB autonome

Compile un dossier `dist/portable/` complet à graver sur clé USB pour démos nomades. Contient binaire `br_server` + Flutter Web release + docs + launchers macOS/Linux/Windows + BD vierge ou seed.

```bash
./tools/build-portable.sh                  # plateforme courante, BD vide
./tools/build-portable.sh --with-seed      # avec snapshot BD prod
./tools/build-portable.sh --platform linux-x64
```

### `setup-pin.dart` — génération hash bcrypt + JWT

```bash
dart run scripts/setup-pin.dart 1234
# Affiche BR_PIN_BCRYPT_HASH et BR_JWT_SECRET à copier dans .env / launch
```

## Workflows utiles

### Rerun complet des tests et publication

```bash
./tools/test-all.sh --commit
```

### Build macOS pour distribution Tailscale

```bash
cd packages/br_web
flutter build macos --release \
  --dart-define=BR_API_URL=http://100.95.200.28:8444
# → build/macos/Build/Products/Release/br_web.app
```

### Création DMG distribuable depuis le .app

```bash
APP=packages/br_web/build/macos/Build/Products/Release/br_web.app
hdiutil create -srcfolder "$APP" -volname "Broccers" \
  -format UDZO -ov dist/Broccers-v0.8.1.dmg
# → dist/Broccers-v0.8.1.dmg (à envoyer par AirDrop ou copier)
```

### Restart serveurs proprement

```bash
pkill -f bin/br_server
pkill -f "flutter run"
./tools/test-all.sh --no-server  # relance via test-all (qui détecte le down)
```

## Variables d'environnement (br_server)

| Variable | Défaut | Description |
|----------|--------|-------------|
| `BR_HOST` | `127.0.0.1` | Bind address. `0.0.0.0` pour exposer sur tailnet. |
| `BR_PORT` | `8444` | Port HTTP. |
| `BR_DB_PATH` | `~/.broccers/broc.db` | Chemin SQLite. Permet le switch d'instance. |
| `BR_DATA_DIR` | `~/.broccers` | Racine des fichiers générés (PDF exports). |
| `BR_PIN_BCRYPT_HASH` | — | Hash bcrypt du PIN super-admin (obligatoire). |
| `BR_JWT_SECRET` | éphémère | Secret HS256 pour les JWT. Si vide, généré au démarrage (sessions perdues au restart). |
| `BR_CLAUDE_CLI_PATH` | `/usr/local/bin/claude` | Binaire Claude CLI pour subprocess IA. |
| `BR_WHISPER_URL` | — | URL Whisper STT (optionnel, Phase E). |
| `BR_CAMERA_SHARED_SECRET` | — | Secret partagé pour ingestion ESP32 caméras. |
| `BR_PORTABLE` | — | À `1` pour signaler mode USB portable dans /api/system/config. |
| `DOCKER_CONTAINER` | — | À `1` pour signaler mode Docker. Auto-détecté via /.dockerenv. |

## Architecture des tests

```
tools/test-all.sh
  ├── 1. ensure br_server + flutter web UP
  ├── 2. POST /api/auth/pin → JWT
  ├── 3. 15 GET routes (Phases A, F, G, H)
  ├── 4. 4 probes adversariaux (PIN bad, camera no secret, QR bad, flag dep)
  ├── 5. capture-flutter-screens.py (17 screenshots)
  │   ├── Chromium headless 1440×900
  │   ├── Auth via UI (champ PIN + Enter)
  │   ├── Navigation par clic coord (NavigationBar)
  │   └── Dialogs ouverts via FAB
  └── 6. génération pretty JSON dans docs/test-assets/json/
```

## Artefacts persistants

- `/tmp/broccers-tests/api/*.json` — réponses brutes des routes (non-commit)
- `/tmp/broccers-tests/logs/{br_server,br_web}.log` — logs serveurs (non-commit)
- `docs/test-assets/*.png` — screenshots commités dans Git (~7 Mo)
- `docs/test-assets/json/*.json` — JSON pretty-printed servis au rapport
- `docs/test-report.html` — rapport HTML autonome servi par br_server

## URLs documentation

| URL | Description |
|-----|-------------|
| `/` | Index racine avec tous les liens |
| `/docs/overview` | Vue d'ensemble visuelle (la belle présentation) |
| `/docs/presentation` | Présentation courte « pour les nuls » |
| `/docs/specifications` | Spec exhaustive avec TDM navigable |
| `/docs/features` | Table des 30 feature flags |
| `/docs/test-report` | **Rapport de tests E2E avec preuves** |
| `/docs/product` | Doc technique produit |
| `/docs/schema` | Schéma visuel |
