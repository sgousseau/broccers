# Spec analyst — RBAC Broccers

> 2 modes d'authentification + rôles SG-compliant via `sg_capability`.

## Modes d'auth

### 1. Personnel (JWT)
- Login PIN perso (4-6 chiffres bcrypt + rate-limit 5/15min)
- JWT HS256 TTL 24h, stocké LocalStorage côté browser
- Manager + chaque staff peuvent avoir un PIN perso

### 2. Kiosk (tablette commune cuisine/comptoir)
- Manager crée une session kiosk depuis son écran : `SgKioskSession` (deviceId, expiresAt = minuit)
- Tablette affiche grille noms staff (display `kioskName`)
- Employé tape son nom → modal PIN court (peut être plus court que personnel : 4 chiffres)
- Clock-in / break action immédiate sans JWT (la session kiosk fait foi)
- Aucune autre action accessible (pas de menu édition, pas de question, pas de courses)

## Rôles (`SgEmployeeRole`)

```dart
enum SgEmployeeRole {
  manager,    // tout
  server,     // shift, break, voir carte
  cook,       // shift, break, voir carte, courses
  bartender,  // shift, break, voir carte
  dishwasher, // shift, break uniquement
  host,       // shift, break, voir carte
}
```

## Capabilities (via `sg_capability`)

| Capability                  | manager | server | cook | bartender | dishwasher | host | kiosk |
|-----------------------------|:-------:|:------:|:----:|:---------:|:----------:|:----:|:-----:|
| `employee.clock_in_out`     |   ✓     |   ✓    |  ✓   |    ✓      |    ✓       |  ✓   |  ✓    |
| `employee.break`            |   ✓     |   ✓    |  ✓   |    ✓      |    ✓       |  ✓   |  ✓    |
| `employee.list`             |   ✓     |        |      |           |            |      |       |
| `employee.create`           |   ✓     |        |      |           |            |      |       |
| `employee.set_pin`          |   ✓     |        |      |           |            |      |       |
| `menu.read`                 |   ✓     |   ✓    |  ✓   |    ✓      |            |  ✓   |       |
| `menu.edit`                 |   ✓     |        |      |           |            |      |       |
| `menu.publish`              |   ✓     |        |      |           |            |      |       |
| `menu.export_pdf`           |   ✓     |        |      |           |            |      |       |
| `shopping.read`             |   ✓     |        |  ✓   |           |            |      |       |
| `shopping.add`              |   ✓     |        |  ✓   |           |            |      |       |
| `shopping.check`            |   ✓     |        |  ✓   |           |            |      |       |
| `question.ask`              |   ✓     |        |      |           |            |      |       |
| `kiosk.create_session`      |   ✓     |        |      |           |            |      |       |

## Endpoints REST + RBAC

| Endpoint                              | Cap requise                       | Auth                   |
|---------------------------------------|-----------------------------------|------------------------|
| `POST /api/auth/pin`                  | (open)                            | -                      |
| `POST /api/kiosk/sessions`            | `kiosk.create_session`            | JWT manager            |
| `POST /api/clock-in`                  | `employee.clock_in_out`           | JWT ou kiosk session   |
| `POST /api/clock-out`                 | `employee.clock_in_out`           | JWT ou kiosk session   |
| `POST /api/breaks`                    | `employee.break`                  | JWT ou kiosk session   |
| `POST /api/breaks/:id/end`            | `employee.break`                  | JWT ou kiosk session   |
| `GET /api/employees`                  | `employee.list`                   | JWT                    |
| `POST /api/employees`                 | `employee.create`                 | JWT                    |
| `GET /api/menu/cards/current`         | `menu.read`                       | JWT                    |
| `POST /api/menu/cards`                | `menu.edit`                       | JWT                    |
| `POST /api/menu/cards/:id/publish`    | `menu.publish`                    | JWT                    |
| `POST /api/menu/cards/:id/pdf`        | `menu.export_pdf`                 | JWT                    |
| `GET /api/shopping/lists`             | `shopping.read`                   | JWT                    |
| `POST /api/shopping/items`            | `shopping.add`                    | JWT                    |
| `POST /api/shopping/items/:id/check`  | `shopping.check`                  | JWT                    |
| `POST /api/questions`                 | `question.ask`                    | JWT                    |
| `POST /api/command`                   | (dev only, Tailscale-protected)   | -                      |

## v0.1 simplifié

Pour le MVP, on simplifie en gardant ces 4 niveaux :
- **manager** : tout
- **staff** : clock + break + menu read + shopping read
- **kiosk** : clock + break uniquement
- **public** : auth PIN

Les rôles fins (cook/server/etc.) sont stockés mais utilisés pour affichage et stats, pas pour bloquer des features en v0.1. Granularité réelle en v0.2.
