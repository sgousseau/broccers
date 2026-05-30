# Changelog — br_server

## [0.1.0] — 2026-05-30
### Added
- Dart shelf server `bin/server.dart` (port 8444 par défaut, distinct de Nono Cook 8443).
- SQLite WAL adapter `SqliteBrocRepository` (impl complète de `SgBrocRepositoryPort`).
- PIN auth service (bcrypt + rate-limit + JWT HS256 24h) — copié/adapté de nono-cook.
- PDF renderer `PdfDartMenuRenderer` via package `pdf` (layout A4 imprimable).
- Claude question adapter `ClaudeCliQuestion` via subprocess `claude -p`.
- REST API : auth/pin, employees, shifts (clock-in/out), breaks (start/end), menu/cards (CRUD + publish + PDF download), shopping (lists/items + check), questions (ask + list).
- TestControlServer `/api/command` (réutilise pattern nc).
- CORS Tailscale whitelist.

### TODO v0.2
- Splitter SgBrocRepositoryPort en Query/Command (ISP).
- Refactor PinAuth en package `sg_pin_auth` partagé.
- Cron checkLegalCompliance (alertes pauses droit du travail).
- Sink Apple Reminders / Notion pour push tâches manager.
