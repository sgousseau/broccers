# Architecture — Broccers v0.1

## Vue d'ensemble

```
┌───────────────────────────────────────────────────────────────────┐
│  Browser (Chrome / Safari / iPhone PWA / Tablette cuisine kiosk)  │
│  ┌──────────────────────────┐  ┌──────────────────────────┐       │
│  │ br_web Flutter           │  │ Auth : JWT (perso) ou    │       │
│  │ (sg_ui MIGRATE v0.2)     │  │ KioskPIN (tablette)      │       │
│  └─────────────┬────────────┘  └────────────┬─────────────┘       │
└────────────────┼─────────────────────────────┼────────────────────┘
                 │ HTTPS REST                  │
                 ▼                              ▼
┌────────────────────────────────────────────────────────────────────┐
│  Mac Studio — br_server (Dart shelf)                               │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌─────────────────────┐    │
│  │ REST API │ │ TestCtrl │ │ PIN auth │ │ SQLite WAL          │    │
│  │ + RBAC   │ │ /command │ │ + kiosk  │ │ ~/.broccers/broc.db │    │
│  └────┬─────┘ └────┬─────┘ └──────────┘ └─────────────────────┘    │
│       │            │                                                 │
│       │            │  + PDF exports: ~/.broccers/pdf_exports/Y/M/D/ │
└───────┼────────────┼─────────────────────────────────────────────────┘
        │            │
        │ HTTP       │ subprocess
        ▼            ▼
┌────────────────────┐  ┌──────────────────────┐
│ Claude Max         │  │ package:pdf Dart     │
│ (cluster Tailscale │  │ (server-side render  │
│  via `claude -p`)  │  │  PDF A4 imprimable)  │
└────────────────────┘  └──────────────────────┘
```

## Couches Clean Architecture

| Couche       | Package           | Contient                                                       |
|--------------|-------------------|----------------------------------------------------------------|
| Domain       | `br_core`         | Entities (Sg*), Ports, UseCases, Failures, Result<T,E>         |
| Adapter      | `br_server/lib/`  | SQLite repo, PIN auth, PDF renderer, Claude question           |
| Presentation | `br_web/lib/src/screens/` (sg_ui obligatoire en v0.2)                              |
| CLI          | `br_cli`          | `br auth|employee|shift|break|menu|shopping|ask|print`         |

## Dépendances

```
br_cli  ─┐
br_web  ─┼──→ br_core ──→ (meta only, pure Dart)
br_server┘                MIGRATE LATER → sg_core (when pure-Dart)

br_server ──→ shelf, shelf_router, sqlite3, bcrypt, dart_jsonwebtoken, http, pdf, uuid, logging
br_web    ──→ flutter, http, shared_preferences
br_cli    ──→ args, http
```

## Domaines métier

### 1. Personnel
- `SgEmployee` + `SgEmployeeRole` (manager/server/cook/bartender/dishwasher/host)
- `SgShift` (employeeId, startsAt, endsAt, position, status)
- `SgBreak` (employeeId, shiftId, type, startedAt, endedAt?, expectedDuration)
- UseCases : `ClockInUseCase`, `ClockOutUseCase`, `StartBreakUseCase`, `EndBreakUseCase`

### 2. Menu / Carte
- `SgMenuCard` (versionnée), `SgMenuItem`, `SgMenuCategory`, `SgAllergen`
- UseCases : `PublishMenuCardUseCase`, `ExportMenuCardPdfUseCase`
- Lineage : `SgPdfExport` pointe vers `SgMenuCard.version` (Source/Derivation)

### 3. Courses
- `SgShoppingList`, `SgShoppingItem`, `SgSupplier`
- UseCases : `AddShoppingItemUseCase`, `CheckShoppingItemUseCase`

### 4. Question (chat IA)
- `SgQuestion` (asked, context, answer, engine)
- UseCases : `AskQuestionUseCase` (compose contexte Broc → Claude → réponse)

## Source / Derivation lineage

```
carte v3  ─┬─→ PDF imprimé le 30/05 (chemin: pdf_exports/2026/05/30/menu_v3.pdf)
           │   dérivation: sourceCardId=v3, renderedAt=..., engine=pdf-dart-2.4
           │
question  ─┬─→ réponse Claude
           │   dérivation: questionId, contextSnapshot (carte+stock+rules)
```

## Flux principaux

### F1 — Clock-in employé (kiosk tablette)
1. Tablette affiche grille noms staff
2. Employé tape son nom → input PIN court
3. POST `/api/clock-in` `{employee_id, kiosk_pin}`
4. Serveur valide PIN + crée `SgShift` (startsAt = now)
5. UI affiche "Bonjour Sandra ✓ — en service depuis 09h45"

### F2 — Démarrer pause
1. Sur écran shift actif, employé tape "Pause"
2. POST `/api/breaks` `{shift_id, type: 'legal'}`
3. Serveur crée `SgBreak` (startedAt = now, expectedDuration = 20 min)
4. Timer affiché à l'écran (countdown)
5. Alert si dépassement non-conforme (voir `breaks_legal.md`)

### F3 — Édition carte + export PDF
1. Manager édite items dans `MenuScreen`
2. Bouton "Publier v3" → POST `/api/menu/cards` (version auto-incrément)
3. Bouton "Imprimer" → POST `/api/menu/cards/3/pdf`
4. Server : `SgPdfRendererPort.render(card)` → bytes Uint8List
5. Bytes stockés sur disque + servis en download (Content-Type: application/pdf)
6. Lineage : `pdf_exports/2026/05/30/menu_v3_<timestamp>.pdf`

### F4 — Pose question Claude
1. UI : zone de texte + bouton "Demander"
2. POST `/api/questions` `{question, scope: ['menu', 'shopping', 'rules']}`
3. Server : compose contexte (carte courante + courses ouvertes + règles statiques)
4. `claude -p <prompt>` → réponse texte
5. Persiste `SgQuestion` (question + answer + contextSnapshot + engine)
6. UI affiche réponse + bouton "Suivante"

## Stockage SQLite (`~/.broccers/broc.db`)

```sql
employees(id, name, role, contracted_hours, kiosk_name, kiosk_pin_hash, personal_pin_hash)
shifts(id, employee_id, starts_at, ends_at, position, status)
breaks(id, employee_id, shift_id, type, started_at, ended_at, expected_duration_ms)
menu_cards(id, name, version, published_at)
menu_items(id, card_id, category_id, name, description, price_cents, available, allergens_json, sort_order)
menu_categories(id, card_id, name, sort_order)
shopping_lists(id, name, created_at, status)
shopping_items(id, list_id, supplier_id, name, quantity, unit, urgent, done, created_at, checked_at)
suppliers(id, name, contact)
questions(id, asked_at, question, context_snapshot_json, answer, engine)
pdf_exports(id, card_id, card_version, rendered_at, file_path, byte_size, engine)
kiosk_sessions(id, device_id, started_at, expires_at)
auth_attempts(ip, attempted_at)
```

## Plateformes cibles

| Device       | Mode             | Notes                                                |
|--------------|------------------|------------------------------------------------------|
| Mac manager  | Chrome desktop   | Full UI (admin)                                      |
| iPhone perso | Safari → PWA     | Personnel + ask, planning rapide                     |
| iPad cuisine | Kiosk locked     | Clock-in/out + pause uniquement                      |
| iPad comptoir| Kiosk locked     | Idem + carte preview                                 |
