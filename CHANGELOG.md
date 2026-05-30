# Changelog — Broccers

## [0.1.0-alpha] — 2026-05-30

### Added — SG Compliant skeleton v1
- Workspace Dart 3.8+ avec 4 packages : `br_core`, `br_server`, `br_web`, `br_cli`.
- Symlink `sg-packages` pour framework SG.
- Specs analyst : `architecture.md`, `rbac.md`, `menu_card_pdf.md`, `breaks_legal.md`.
- Schéma HTML présentable single-file `docs/schema.html`.
- README, CLAUDE.md (règles SG strictes), .gitignore, LICENSE.
- `br_core` : entities Sg* (Employee, Role, Shift, Break, MenuCard, MenuItem, Category, Allergen, ShoppingList, ShoppingItem, Supplier, Question). Ports (Repo, Pdf, Question, Auth). UseCases (ClockIn/Out, StartBreak/EndBreak, PublishMenuCard, ExportMenuCardPdf, AskQuestion).
- `br_server` : shelf REST + SQLite WAL + PIN auth + JWT + kiosk mode + adapter Claude + adapter PDF (package:pdf) + TestControlServer `/api/command`.
- `br_web` : Flutter Web PWA, Login PIN, écrans Personnel / Carte / Courses / Question (Material + TODO sg_ui MIGRATE v0.2).
- `br_cli` : `br auth|employee|shift|break|menu|shopping|ask|print`.

### Decisions
- Tailscale only par défaut (zéro cloud public).
- Audit pause droit du travail FR (alerte si pause < 20 min toutes les 6h continues).
- Carte versionnée + PDF tracé via Source/Derivation lineage.
- Auth 2 modes : personnel (JWT) + kiosk (PIN court tablette).

### Réutilisations Nono Cook
- `PinAuthService`, `ClaudeCliSynthesis`, `NcCommandRegistry`, `SqliteKitchenRepository`, Login PIN UI, LaunchAgent template.

### TODO v0.2
- Migrer Material → sg_ui (SgApp, SgCard, SgButton, SgSplitView, SgPanelHeader, SgFormDialog).
- Migrer args → sg_cli framework.
- Auto-génération courses depuis carte (deduction stock).
- Photos plats (upload + storage).
- Notifications iPhone PWA (push web).
- Refactor PinAuth en `sg_pin_auth` partagé entre Broccers + Nono Cook.
