# Changelog — br_web

## [0.6.0] — 2026-06-01 — Phase F
### Added
- 3 nouveaux onglets dans la NavigationBar : 🗑️ Pertes, 📱 Tables, ⚙️ Paramètres (manager-only).
- `SettingsScreen` : édition typée par catégorie (margins, breaksLegal, costs, voice), badges « défaut » vs valeur modifiée, dialogs adaptés (int/double/enum/bool), toute modif audit-loggée.
- `WasteScreen` : récap 7j (total €, breakdown par raison + par jour), historique 50 dernières pertes, dialog `_DeclareWasteDialog` avec auto-estimation valeur.
- `TablesScreen` : CRUD tables avec QR code (via `api.qrserver.com` pour rendu, fallback texte si offline), bouton Régénérer (invalide ancien QR), Désactiver.
- Mode 86 inline dans onglet Carte : bouton `🚫 Rupture` sur cartes publiées → bottom sheet avec switch par item + dialog raison obligatoire si désactivation.
- API client : ajout `put()` et `delete()` HTTP methods.

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
