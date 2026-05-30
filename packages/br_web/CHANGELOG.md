# Changelog — br_web

## [0.1.0] — 2026-05-30
### Added
- Flutter Web app entry `lib/main.dart`.
- Login PIN + écrans : Personnel (employés + shifts + clock-in/out + pauses), Carte (liste + sample + publish + PDF), Courses (lists + items + check), Question (chat Claude).
- API client HTTP + PDF download.
- PWA manifest + index.html iPhone home screen ready.

### MIGRATE LATER (v0.2)
- Migrer Material → `sg_ui` (SgApp, SgSplitView, SgPanelHeader, etc.).
- Mode kiosk (tablette cuisine) avec sélecteur staff + PIN court.
- Riverpod pour state management.
- Drag-drop édition carte.
