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
- Promotion `SgEventJournal` vers sg-packages (concept universel observability bienveillante).

### Phase B backlog (taux horaires + consommation staff)
- `SgHourlyRate` versionné par employé/rôle (changements tracés via journal).
- `SgStaffConsumption` (repas/boissons consommés par staff, lié optionnellement à un SgMenuItem).
- Reporting : « coût main d'œuvre du jour », « conso staff de la semaine ».

### Phase C backlog (caméras manager-only)
- `SgVisionCameraPort` (adapter futur RTSP / ESP32-S3 / SgWindowAgent).
- `SgFaceRecognitionPort` (probablement cluster Titan).
- `SgRoleObservation` (caméra observe X à position Y → comparé au rôle assigné, alerte douce au manager si écart).

### Phase D backlog (suggestions Claude — Seb 2026-05-31)
- **Briefing matinal** : Claude résume planning + tâches du jour au premier clock-in.
- **Pourboires** : champ tip sur SgShift + équilibrage pot/perso + reporting hebdo.
- **Heatmap occupation** : grille jour×heure colorée par rôle → repère pics / creux.
- **Anti-frustration** : alerte bienveillante manager si écart caméra↔rôle assigné.
- **Onboarding par rôle** : checklist auto par Claude pour nouveau staff.

## [0.2.0-alpha] — 2026-05-31 (en cours)

### Phase A — Multi-rôles dynamique + journal d'événements
- BREAKING : `SgEmployee.role` (single) → `SgEmployee.roles: Set<SgEmployeeRole>` + `defaultRole` + `weeklyDefault: Map<int, SgEmployeeRole>`.
- NEW : `SgShiftSegment` (un shift = N segments, chaque segment = rôle + startsAt + endsAt).
- NEW : `SgEventJournalEntry` (audit log universel — concept SG à promouvoir vers sg-packages).
- NEW UseCases : `ChangeRoleInShiftUseCase`, `SetWeeklyDefaultUseCase`, `SetEmployeeRolesUseCase`.
- UPDATED : `ClockInUseCase` résout le rôle (override → weekly[today] → defaultRole → failure) + crée premier segment + log event.
- UPDATED : `ClockOutUseCase` termine le segment actif + log.
- SQL migration : `employees.role` → `employees.roles_json` + `default_role` + `weekly_default_json`. Nouvelles tables `shift_segments` + `event_journal`.
- TestControlServer : `employee set-roles`, `employee set-weekly`, `shift change-role`, `shift segments`, `events list`.
- REST : `POST /api/employees/<id>/roles`, `POST /api/employees/<id>/weekly`, `POST /api/shifts/<id>/segments`, `GET /api/events`.
- UI : multi-Chips rôles + planning hebdo grid + journal manager.
- Philosophie : observability bienveillante (alertes manager only, formulation hypothétique).
