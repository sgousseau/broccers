# Broccers

> Gestion brasserie Broc (Villeurbanne — Puces du Canal). Personnel, pauses, carte dynamique imprimable, liste de courses, et chat IA.

Outil interne single-tenant pour la brasserie **Broc**. Tourne sur Mac Studio derrière Tailscale, accessible Chrome/Safari + iPhone PWA + tablette kiosk en cuisine.

## Features v1

- **Personnel** — staff, planning, clock-in/out, pauses avec tracker droit du travail
- **Carte dynamique** — édition + preview + export PDF imprimable A4
- **Liste de courses** — checklist par fournisseur, urgences
- **Pose question** — chat Claude Max (contexte carte + stock + règles légales)

## Architecture (SG Framework)

- **Frontend** : Flutter Web PWA (Chrome / Safari / iPhone home screen)
- **Backend** : Dart shelf sur Mac Studio (REST + TestControlServer)
- **Storage** : SQLite WAL local
- **PDF** : package `pdf` Dart natif (server-side render)
- **IA** : Claude Max via `claude -p` subprocess sur cluster Tailscale (jamais API Anthropic)
- **Réseau** : Tailscale mesh only
- **Auth** : 2 modes — JWT personnel (manager + staff) + kiosk PIN tablette cuisine

## Structure

```
packages/
├── br_core/    Domain pur — entities, ports, usecases, failures
├── br_server/  Backend Dart shelf — REST, SQLite, PIN auth, PDF, Claude
├── br_web/     Frontend Flutter Web — Login, Personnel, Carte, Courses, Question
└── br_cli/     CLI `br` — auth, employee, shift, break, menu, shopping, ask, print
```

Dépend de `sg-packages` (framework SG) via symlink `sg-packages/`.

## SG Compliance

Voir [`CLAUDE.md`](./CLAUDE.md) pour règles strictes (Clean Archi 4 couches, Result<T,E>, Port/Adapter, sg_ui obligatoire, Sg prefix, Command-First).

## Quickstart

```bash
dart pub get
dart run scripts/setup-pin.dart 1234     # génère hash + JWT secret
export NC_PIN_BCRYPT_HASH='...'           # à exporter
export NC_JWT_SECRET='...'
dart run packages/br_server/bin/server.dart
# autre terminal
flutter run -d chrome --target packages/br_web/lib/main.dart
```

## Statut

`v0.1.0-alpha` — Skeleton SG-compliant + 4 features MVP. Voir [`CHANGELOG.md`](./CHANGELOG.md).
