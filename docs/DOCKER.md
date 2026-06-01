# Broccers — Déploiement Docker

Guide pour déployer Broccers en autonomie réseau via Docker Compose (sans Tailscale).

## Prérequis

- Docker Engine ≥ 24
- Docker Compose v2 (`docker compose`, sans tiret)
- 1 Go de RAM minimum, 2 Go recommandés
- 500 Mo de disque pour l'image + la BD

## Démarrage rapide

```bash
# 1. Cloner le repo
git clone https://github.com/sgousseau/broccers.git
cd broccers

# 2. Générer le hash bcrypt du PIN (4 à 6 chiffres)
dart run scripts/setup-pin.dart 1234

# 3. Copier les valeurs dans .env
cp .env.example .env
# Éditer .env et coller BR_PIN_BCRYPT_HASH + BR_JWT_SECRET

# 4. Build du frontend Flutter Web
cd packages/br_web
flutter build web --release --output ../../dist/web
cd ../..

# 5. Build et démarrage des containers
docker compose build
docker compose up -d

# 6. Vérifier
docker compose ps
curl http://localhost:8444/api/health
# Ouvrir http://localhost:8766 dans le navigateur
```

## Structure

Deux services Docker :

- `br_server` — backend Dart shelf compilé (image personnalisée, ~80 Mo).
- `br_web` — nginx servant le build Flutter Web + proxy `/api/`.

Un volume nommé `broccers_data` persiste la base SQLite (`/app/data/broc.db`) et les exports PDF (`/app/data/pdf_exports/`).

## Variables d'environnement

Définies dans `.env` (voir `.env.example`) :

| Variable | Description | Défaut |
|----------|-------------|--------|
| `BR_PIN_BCRYPT_HASH` | Hash bcrypt du PIN super-admin (obligatoire) | — |
| `BR_JWT_SECRET` | Secret JWT HS256 24h (obligatoire pour la prod) | éphémère |
| `BR_CLAUDE_CLI_PATH` | Chemin vers le CLI Claude | `/usr/local/bin/claude` |
| `BR_WHISPER_URL` | URL Whisper STT (optionnel) | — |

## Commandes utiles

```bash
# Voir les logs
docker compose logs -f br_server

# Sauvegarder la BD
docker run --rm -v broccers_broccers_data:/data -v $(pwd)/backup:/backup alpine \
  tar czf /backup/broc-$(date +%F).tar.gz -C /data .

# Restaurer une BD
docker compose down
docker run --rm -v broccers_broccers_data:/data -v $(pwd)/backup:/backup alpine \
  tar xzf /backup/broc-2026-06-01.tar.gz -C /data
docker compose up -d

# Switcher de BD (par exemple démo client X)
docker compose down
# Renommer le volume ou modifier docker-compose.yml pour mapper un autre dossier
docker compose up -d

# Rebuild après changement de code
docker compose build br_server
docker compose up -d br_server

# Tout supprimer (ATTENTION : perte de données)
docker compose down -v
```

## Mise à jour Broccers

```bash
git pull
cd packages/br_web && flutter build web --release --output ../../dist/web && cd ../..
docker compose build
docker compose up -d
```

## Limites du mode Docker

- L'IA Claude (`claude -p`) doit être accessible depuis le container. Trois options :
  1. Monter le binaire en volume : `volumes: - /usr/local/bin/claude:/usr/local/bin/claude:ro`
  2. Installer claude CLI dans le Dockerfile (ajoute ~150 Mo à l'image)
  3. Pointer `BR_CLAUDE_CLI_PATH` vers un sidecar service via HTTP
- Pour Whisper, héberger ailleurs et pointer `BR_WHISPER_URL`.
- Pas de Tailscale dans cette config : exposer derrière nginx/Caddy + Let's Encrypt si accès distant nécessaire.

## Comparaison des modes

| Mode | Cas d'usage | Avantages | Limites |
|------|-------------|-----------|---------|
| Tailscale natif | Production maison (Le Broc) | Zéro install client, IA cluster | Nécessite tailnet enrôlé |
| Docker | Client tiers qui veut hoster lui-même | Autonomie, isolation | Configuration claude CLI |
| USB portable | Démos commerciales nomades | Aucune installation, offline | Pas adapté à la prod |
