# Phase H — Plan de session (2026-06-01)

État : EN COURS · session autonome 1-2h · résilient à coupure internet.

## Lots (ordonnés par priorité)

### Lot 1 — Doc exhaustive HTML (PRIORITÉ ABSOLUE)
`docs/specifications.html` — single-page avec sidebar TDM sticky.

**Sections** :
1. Vision & philosophie produit
2. Identité opérationnelle (qui, où, pour qui)
3. Topologie des rôles (capabilities)
4. Architecture en 4 couches (concept)
5. Cycle d'une journée type
6. Modules fonctionnels (11) :
   - 6.1 Personnel & RH
   - 6.2 Cartes & menus
   - 6.3 Cuisine connectée
   - 6.4 Achats & fournisseurs
   - 6.5 Marges & coûts
   - 6.6 Gaspillage & pertes
   - 6.7 Tables & expérience client
   - 6.8 Paramètres & administration
   - 6.9 Journal & audit
   - 6.10 IA & assistance
   - 6.11 Caméras IA distribuées (ESP32-S3 Sense) [Phase H]
7. Catalogue exhaustif (~95 fonctionnalités numérotées)
8. Workflows transversaux (cook 86 → carte client, etc.)
9. Sécurité, confidentialité, conformité (RGPD, INCO, droit travail FR)
10. Portabilité & déploiement (Tailscale / Docker / USB / DB conf / Features)
11. Roadmap par phases (A à K+)
12. Architecture technique (résumé)
13. Glossaire

**Servie** : `GET /docs/specifications` (ajouter route br_server).

### Lot 2 — Feature flags
- `br_core/lib/src/entities/sg_feature_flag.dart` : entity + registry
- Persistance via settings (catégorie 'features')
- Routes `/api/features`, `/api/features/<key>`
- UI : Paramètres → section Features (super-admin only)
- Flags : kitchen.voice_orders, menu.import_image, camera.face_recognition,
  tips.tracking, briefing.morning, kiosk.mode, qr.public_menu, reports.heatmap

### Lot 3 — DB configurable (déjà OK via env)
- Valider BR_DB_PATH
- Documenter dans CLAUDE.md + specifications.html
- CLI : `config show` et `config set db-path <path>`

### Lot 4 — Docker
- `Dockerfile` multi-stage (Dart compile-exe → alpine final)
- `docker-compose.yml` avec br_server + nginx pour web + volume DB
- `.dockerignore`

### Lot 5 — USB portable
- `tools/build-portable.sh`
- Génère `dist/portable/` avec binaire + flutter web + launch.sh + seed.db

### Lot 6 — ESP32-S3 Sense (conceptuel)
- `br_core/lib/src/entities/sg_camera.dart`
- `br_core/lib/src/entities/sg_camera_event.dart`
- `br_core/lib/src/entities/sg_face_profile.dart`
- `br_core/lib/src/entities/sg_presence_event.dart`
- `br_core/lib/src/entities/sg_zone.dart`
- Endpoint `POST /api/camera-events` (HTTP simple, gated par feature flag)
- UI : section Caméras dans onglet Paramètres (super-admin) — affiche topologie

## Commit strategy (résilience coupure)

Après chaque lot complété :
```bash
git add docs packages tools Dockerfile docker-compose.yml
git commit -m "feat(v0.8.0-h<N>): <lot description>"
git push origin main
```

## État actuel

- Servers UP : br_server v0.7.0 sur 8444, Flutter web sur 8766
- Tailscale : 100.95.200.28
- Data seedée : 6 employés, 1 carte publiée 6 items, 6 tables avec QR, 3 ingrédients, 2 pertes (18,50€)
