# Spec analyst — Règles pauses (droit du travail français)

> Tracker des pauses + alertes non-conformité. Pas un substitut au conseil juridique.

## Règle légale FR de référence (Code du Travail Art. L. 3121-16/17)

- **Pause minimum 20 min** dès que la durée quotidienne **atteint 6 h continues** de travail
- Pauses **incluses ou non** dans le temps de travail effectif selon la convention collective (CHR/HCR = pause généralement non rémunérée)
- Repos quotidien : **11 h consécutives minimum** entre 2 jours
- Repos hebdomadaire : **24 h consécutives minimum + 11 h** = 35 h consécutives

> Pour la restauration (convention HCR), des minima spécifiques s'ajoutent. v1 = règle générale ; affinement HCR en v0.2.

## Entités

```dart
enum SgBreakType {
  legal,    // pause obligatoire 20 min après 6h
  lunch,    // pause déjeuner
  quick,    // pause cigarette / micro
}

class SgBreak {
  String id;
  String employeeId;
  String shiftId;
  SgBreakType type;
  DateTime startedAt;
  DateTime? endedAt;
  Duration expectedDuration; // 20 min pour legal, 30-60 pour lunch, 5-10 pour quick
}
```

## Alertes

Calculées à chaque tick (cron 1 min côté server, ou polling UI 30 s) :

| Code                          | Condition                                                              | Niveau |
|-------------------------------|------------------------------------------------------------------------|--------|
| `BREAK_OVERDUE`               | shift > 6 h continues sans pause de type `legal`                       | warn   |
| `BREAK_TOO_SHORT`             | pause `legal` terminée avec durée < 20 min                             | warn   |
| `SHIFT_TOO_LONG`              | shift > 10 h sans interruption                                         | error  |
| `DAILY_REST_VIOLATED`         | < 11 h entre end shift J-1 et start shift J                            | error  |
| `WEEKLY_REST_VIOLATED`        | 0 jour off dans 7 jours consécutifs                                    | error  |

Retournées par `GET /api/alerts` (+ filtrable par employé).

## UseCases

### `StartBreakUseCase`
1. Charge shift actif de l'employé
2. Refuse si déjà une pause en cours (sauf manager override)
3. Crée `SgBreak` (startedAt = now, expectedDuration selon type)
4. Émet event `BreakStarted` (signal UI)

### `EndBreakUseCase`
1. Charge la pause active
2. Set `endedAt = now`
3. Si type=legal et durée < expectedDuration : émet alert `BREAK_TOO_SHORT`

### `CheckLegalComplianceUseCase` (called by cron)
1. Pour chaque shift actif :
   - durée continue = now - startedAt - somme(durées pauses)
   - si > 6 h ET pas de break de type=legal terminé → alert `BREAK_OVERDUE`
   - si > 10 h continues → alert `SHIFT_TOO_LONG`
2. Pour chaque employé :
   - dernier shift end vs prochain shift start → check 11 h gap

## UI

- Sur LiveScreen du shift actif : timer cumulé + bouton "Pause"
- Pause active : countdown grand format + bouton "Reprendre"
- Bandeau orange si `BREAK_OVERDUE` (manager + employé)
- Bandeau rouge si `SHIFT_TOO_LONG` ou `DAILY_REST_VIOLATED`

## Décisions v0.1

- Seules les règles **générales** (pas spécifiques HCR) sont implémentées
- Cron 1 min via Dart Timer.periodic dans le serveur
- Override manager possible via `force=true` query param (loggé)
- Convention par défaut : pauses **non rémunérées** (cohérent CHR/HCR)
