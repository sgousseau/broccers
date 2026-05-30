import 'dart:convert';

import 'package:br_core/br_core.dart';
import 'package:test/test.dart';

void main() {
  group('SgEmployee', () {
    test('toJson/fromJson roundtrip (no hashes)', () {
      const original = SgEmployee(
        id: 'e-1',
        name: 'Sandra',
        role: SgEmployeeRole.server,
        contractedHours: 35,
        kioskName: 'Sandra',
      );
      final restored = SgEmployee.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
      );
      expect(restored, original);
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
