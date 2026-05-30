# CLAUDE.md — Broccers

## Identité
- **Projet** : Broccers — gestion brasserie Broc (Villeurbanne)
- **Owner** : Seb (CTO Stowy Agency)
- **Stack** : Dart 3.8+ / Flutter Web / shelf / SQLite / package:pdf / Claude / Tailscale
- **Cluster** : Mac Studio (server) + cluster Claude pour IA

## Règles inviolables

### SG Compliance 100% obligatoire
- **Clean Architecture 4 couches** (Domain / Adapter / Provider / UI)
- **Result<T, E>** partout. Jamais de `throw` cross-layer.
- **Port / Adapter** pour toute dépendance externe (PDF gen, Claude, SQLite, Tailscale, auth).
- **Sg prefix** sur toute classe/enum publique de `br_core` (et sg-packages a fortiori).
- **sg_ui obligatoire** dans `br_web` (Material avec TODO MIGRATE pour la v1).
- **Command-First** : chaque feature DOIT exister en CLI (`br_cli`) avant d'être en UI.
- **CHANGELOG.md** de chaque package mis à jour à chaque changement.
- **SDK** : `">=3.8.0 <4.0.0"` partout.

### Méthode Agency (sans dispatch externe ici)
Chaque feature passe par : analyst → dev → lead → qa.

### Tâches Agency
- Préfixe projet : `BR` (Broccers). Convention `[BR-12] feature: ...`.

### Auth & RBAC
- **2 modes** : personnel (JWT, manager + staff perso) + kiosk (tablette cuisine, sélection rapide nom + PIN court 4-6 pour clock-in/break).
- **PIN bcrypt** + rate-limit (5 essais / 15 min).
- **Tailscale only** par défaut.

### Légal / pauses
- Tracker temps de pause par employé pendant son shift.
- Alerter si non-conforme droit du travail FR (pause >= 20min toutes les 6h consécutives, etc.).
- Spec détaillée : `docs/specs/breaks_legal.md`.

### Dépendances SG packages (via symlink `sg-packages/`)
- `sg_core` — Result, SgFailure (INLINE pour l'instant car Flutter-bound — MIGRATE LATER)
- `sg_ui` — toute la UI br_web (MIGRATE v0.2)
- `sg_io` — HTTP/WS
- `sg_cli` + `sg_cli_flutter` — CLI framework (MIGRATE v0.2)
- `sg_capability` — RBAC (manager / staff / kiosk)
- `sg_inference` — adapter Claude (réutilise pattern nc)
- `sg_derivation` — Source/Derivation lineage (carte → PDF imprimé)
- `sg_repository` — pattern CRUD

### Réutilisations directes du repo `nono-cook`
Le code suivant est copié/adapté de `~/Code/nono-cook` :
- `PinAuthService` → `BrPinAuthService` (mêmes mécanismes bcrypt + JWT)
- `ClaudeCliSynthesis` → `BrQuestionAdapter` (prompt différent : contexte Broc)
- `NcCommandRegistry` (TestControlServer) → `BrCommandRegistry`
- `SqliteKitchenRepository` pattern → `SqliteBrocRepository`
- Login PIN UI + manifest PWA + LaunchAgent template

Quand le code se stabilisera, créer un package `sg_pin_auth` partagé (refactor v0.3).

### Audit & PDF
- Carte versionnée (`SgMenuCard.version`) — chaque PDF imprimé est dérivé d'une version précise (`sg_derivation`).
- Stocker les exports PDF dans `~/.broccers/pdf_exports/YYYY/MM/DD/menu_card_<version>.pdf`.

### Observability bienveillante (philosophie inviolable)
- Tout est tracé (`SgEventJournal`) pour **COMPRENDRE et AMÉLIORER**, jamais pour réprimander.
- Les alertes vont au **manager**, jamais à l'employé directement.
- Formulation hypothétique (« semble », « peut-être »), jamais accusatoire.
- Objectif : comprendre pourquoi on perd du temps, pas qui faute.
- Toute action manager/employé qui modifie un rôle/shift/segment → log avec `actor`, `action`, `target`, `reason?`.

### Multi-rôles (Phase A — 2026-05-31)
- `SgEmployee.roles: Set<SgEmployeeRole>` = capabilities (ce que l'employé sait faire)
- `SgEmployee.defaultRole` = rôle par défaut (fallback)
- `SgEmployee.weeklyDefault: Map<int weekday, SgEmployeeRole>` = planning hebdo (1=Lun..7=Dim)
- `SgShift` = présence globale (start/end clock-in/out)
- `SgShiftSegment` = un rôle tenu sur un intervalle dans un shift. N segments par shift.
- Au `ClockIn` : résolution `override OR weekly[today] OR defaultRole OR failure` puis crée segment.
- `ChangeRoleInShift` : end segment actuel + create nouveau + log event.
- Manager peut tout faire ; employé peut rectifier son propre shift.

## Workflow dev

```bash
cd /Users/sgo/Code/broccers
dart pub get
dart format .
dart analyze --fatal-infos .
dart test
dart run packages/br_server/bin/server.dart
flutter run -d chrome --target packages/br_web/lib/main.dart
```

## Anti-règles

- **Pas de quick fix** : tout problème récurrent = abstraction conceptuelle (Port/Adapter).
- **Pas de stub silencieux** : feature manquante = TODO + entrée CHANGELOG, jamais `return null;` orphelin.
- **Pas de rsync pour le code** : git push/pull uniquement.
- **Pas d'amend git** : NEW commits toujours.
- **Pas d'utilisation API Anthropic directe** : utiliser `claude -p` cluster Tailscale.
