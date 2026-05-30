import 'dart:convert';

import 'package:br_core/br_core.dart';
import 'package:test/test.dart';

void main() {
  group('SgEmployee', () {
    test('toJson/fromJson roundtrip (multi-roles + weekly)', () {
      final original = SgEmployee(
        id: 'e-1',
        name: 'Eros',
        roles: const {SgEmployeeRole.runner, SgEmployeeRole.bartender, SgEmployeeRole.dishwasher},
        defaultRole: SgEmployeeRole.runner,
        weeklyDefault: const {
          SgWeekday.wednesday: SgEmployeeRole.bartender,
          SgWeekday.thursday: SgEmployeeRole.runner,
        },
        contractedHours: 35,
        kioskName: 'Eros',
      );
      final restored = SgEmployee.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
      );
      expect(restored, original);
      expect(restored.roles, original.roles);
      expect(restored.weeklyDefault[SgWeekday.wednesday], SgEmployeeRole.bartender);
    });

    test('resolveRoleFor — weekly wins over default', () {
      final emp = SgEmployee(
        id: 'e-1',
        name: 'Eros',
        roles: const {SgEmployeeRole.runner, SgEmployeeRole.bartender},
        defaultRole: SgEmployeeRole.runner,
        weeklyDefault: const {SgWeekday.wednesday: SgEmployeeRole.bartender},
        contractedHours: 35,
        kioskName: 'Eros',
      );
      final wed = DateTime(2026, 6, 3);
      expect(wed.weekday, 3);
      expect(emp.resolveRoleFor(wed), SgEmployeeRole.bartender);
      final tue = DateTime(2026, 6, 2);
      expect(emp.resolveRoleFor(tue), SgEmployeeRole.runner);
    });

    test('resolveRoleFor — override wins over all', () {
      final emp = SgEmployee(
        id: 'e-1',
        name: 'Eros',
        roles: const {SgEmployeeRole.runner, SgEmployeeRole.bartender},
        defaultRole: SgEmployeeRole.runner,
        weeklyDefault: const {SgWeekday.wednesday: SgEmployeeRole.bartender},
        contractedHours: 35,
        kioskName: 'Eros',
      );
      final wed = DateTime(2026, 6, 3);
      expect(
        emp.resolveRoleFor(wed, override: SgEmployeeRole.runner),
        SgEmployeeRole.runner,
      );
    });

    test('resolveRoleFor — override ignored if not in roles', () {
      const emp = SgEmployee(
        id: 'e-1',
        name: 'Eros',
        roles: {SgEmployeeRole.runner},
        defaultRole: SgEmployeeRole.runner,
        contractedHours: 35,
        kioskName: 'Eros',
      );
      expect(
        emp.resolveRoleFor(DateTime(2026, 6, 3), override: SgEmployeeRole.bartender),
        SgEmployeeRole.runner,
      );
    });
  });

  group('SgShiftSegment', () {
    test('isActive when endedAt null + duration', () {
      final seg = SgShiftSegment(
        id: 'seg-1',
        shiftId: 'sh-1',
        role: SgEmployeeRole.bartender,
        startedAt: DateTime(2026, 5, 30, 18),
        createdBy: 'system',
      );
      expect(seg.isActive, true);
      final closed = seg.end(at: DateTime(2026, 5, 30, 19, 30));
      expect(closed.isActive, false);
      expect(closed.duration, const Duration(minutes: 90));
    });
  });

  group('SgEventJournalEntry', () {
    test('toJson preserves all fields', () {
      final e = SgEventJournalEntry(
        id: 'evt-1',
        at: DateTime(2026, 5, 30, 12),
        actor: 'manager:m-1',
        action: SgEventActions.segmentRoleChanged,
        target: 'shift:sh-1',
        payload: const {'from_role': 'runner', 'to_role': 'bartender'},
        reason: 'manque de barman',
      );
      final restored = SgEventJournalEntry.fromJson(
        jsonDecode(jsonEncode(e.toJson())) as Map<String, dynamic>,
      );
      expect(restored, e);
      expect(restored.payload['to_role'], 'bartender');
      expect(restored.reason, 'manque de barman');
    });
  });

  group('SgShift', () {
    test('clockIn → active', () {
      final s = SgShift.clockIn(
        id: 's-1',
        employeeId: 'e-1',
        startsAt: DateTime(2026, 5, 30, 9),
      );
      expect(s.isActive, true);
    });

    test('end → ended', () {
      final s = SgShift.clockIn(
        id: 's-1',
        employeeId: 'e-1',
        startsAt: DateTime(2026, 5, 30, 9),
      ).end(at: DateTime(2026, 5, 30, 17));
      expect(s.status, SgShiftStatus.ended);
      expect(s.duration, const Duration(hours: 8));
    });
  });

  group('SgBreak', () {
    test('default duration matches type', () {
      final b = SgBreak.start(
        id: 'b-1',
        employeeId: 'e-1',
        shiftId: 's-1',
        type: SgBreakType.legal,
        startedAt: DateTime(2026, 5, 30, 12),
      );
      expect(b.expectedDuration, const Duration(minutes: 20));
    });

    test('isShorterThanExpected', () {
      final b = SgBreak.start(
        id: 'b-1',
        employeeId: 'e-1',
        shiftId: 's-1',
        type: SgBreakType.legal,
        startedAt: DateTime(2026, 5, 30, 12),
      ).end(at: DateTime(2026, 5, 30, 12, 10));
      expect(b.isShorterThanExpected, true);
      expect(b.duration, const Duration(minutes: 10));
    });
  });

  group('SgMenuItem', () {
    test('formattedPrice : entier sans cents', () {
      const item = SgMenuItem(
        id: 'i-1',
        cardId: 'c-1',
        categoryId: 'cat-1',
        name: 'Tartare',
        priceCents: 1200,
        available: true,
        allergens: {SgAllergen.gluten, SgAllergen.mustard},
        sortOrder: 0,
      );
      expect(item.formattedPrice(), '12 €');
    });

    test('formattedPrice : avec cents', () {
      const item = SgMenuItem(
        id: 'i-1',
        cardId: 'c-1',
        categoryId: 'cat-1',
        name: 'Soupe',
        priceCents: 950,
        available: true,
        allergens: {},
        sortOrder: 0,
      );
      expect(item.formattedPrice(), '9,50 €');
    });
  });

  group('SgMenuCard', () {
    test('groupedByCategory keeps sortOrder', () {
      final card = SgMenuCard(
        id: 'c-1',
        name: 'Test',
        version: 1,
        createdAt: DateTime(2026, 5, 30),
        categories: const [
          SgMenuCategory(id: 'cat-1', cardId: 'c-1', name: 'Entrées', sortOrder: 0),
          SgMenuCategory(id: 'cat-2', cardId: 'c-1', name: 'Plats', sortOrder: 1),
        ],
        items: const [
          SgMenuItem(id: 'i-1', cardId: 'c-1', categoryId: 'cat-2', name: 'A', priceCents: 1000, available: true, allergens: {}, sortOrder: 0),
          SgMenuItem(id: 'i-2', cardId: 'c-1', categoryId: 'cat-1', name: 'B', priceCents: 500, available: true, allergens: {}, sortOrder: 0),
        ],
      );
      final grouped = card.groupedByCategory();
      expect(grouped.keys.map((c) => c.name).toList(), ['Entrées', 'Plats']);
    });
  });

  group('SgShoppingItem', () {
    test('check sets done + checkedAt', () {
      final item = SgShoppingItem(
        id: 'si-1',
        listId: 'sl-1',
        name: 'Pommes',
        quantity: 4,
        unit: 'kg',
        createdAt: DateTime(2026, 5, 30, 9),
      ).check(at: DateTime(2026, 5, 30, 9, 30));
      expect(item.done, true);
      expect(item.checkedAt, DateTime(2026, 5, 30, 9, 30));
    });
  });
}
