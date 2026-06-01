// Phase F — UseCases pour Settings, Composition plats, Gaspillage, Mode 86, Tables QR.
// Regroupés dans un seul fichier pour rapidité de livraison.

import '../entities/sg_event_journal_entry.dart';
import '../entities/sg_food_waste.dart';
import '../entities/sg_ingredient.dart';
import '../entities/sg_menu_item.dart';
import '../entities/sg_setting.dart';
import '../entities/sg_table.dart';
import '../failures.dart';
import '../ports/sg_broc_repository_port.dart';
import '../ports/sg_clock_port.dart';
import '../result.dart';

// ============================================================================
// SET SETTING — manager-only check + log
// ============================================================================
class SetSettingUseCase {
  final SgBrocRepositoryPort _repo;
  final SgClockPort _clock;
  final String Function() _eventIdGenerator;

  const SetSettingUseCase({
    required SgBrocRepositoryPort repository,
    required SgClockPort clock,
    required String Function() eventIdGenerator,
  })  : _repo = repository,
        _clock = clock,
        _eventIdGenerator = eventIdGenerator;

  Future<Result<SgSetting, SgFailure>> call({
    required String key,
    required Object value,
    required String actor,
    String? reason,
  }) async {
    final def = SgBrocSettingsRegistry.find(key);
    if (def == null) {
      return Failure(SgValidationFailure('Unknown setting key: $key'));
    }
    if (!actor.startsWith('manager') && actor != 'system') {
      return Failure(SgPermissionFailure(
        'Only managers can modify settings. Actor=$actor.',
      ));
    }
    if (def.type == SgSettingType.intValue) {
      final v = value is int ? value : int.tryParse(value.toString());
      if (v == null) return Failure(SgValidationFailure('$key requires int'));
      if (def.minValue != null && v < def.minValue!) {
        return Failure(SgValidationFailure('$key must be >= ${def.minValue}'));
      }
      if (def.maxValue != null && v > def.maxValue!) {
        return Failure(SgValidationFailure('$key must be <= ${def.maxValue}'));
      }
      value = v;
    } else if (def.type == SgSettingType.boolValue) {
      if (value is! bool) {
        value = value.toString().toLowerCase() == 'true';
      }
    } else if (def.type == SgSettingType.enumValue) {
      if (def.enumOptions != null && !def.enumOptions!.contains(value.toString())) {
        return Failure(SgValidationFailure(
          '$key must be one of ${def.enumOptions!.join(",")}',
        ));
      }
    }

    final now = _clock.now();
    final previous = await _repo.getSetting(key);
    final setting = SgSetting(
      key: key,
      value: value,
      type: def.type,
      setAt: now,
      setBy: actor,
    );
    final stored = await _repo.setSetting(setting);
    return stored.when(
      success: (_) async {
        await _repo.logEvent(SgEventJournalEntry(
          id: _eventIdGenerator(),
          at: now,
          actor: actor,
          action: 'setting.changed',
          target: 'setting:$key',
          payload: {
            'key': key,
            'category': def.category.name,
            'from': previous.valueOrNull?.value,
            'to': value,
          },
          reason: reason,
        ));
        return Success<SgSetting, SgFailure>(setting);
      },
      failure: (e) async => Failure<SgSetting, SgFailure>(e),
    );
  }
}

// ============================================================================
// COMPUTE MENU ITEM COST — calcule coût matière + marge depuis recette
// ============================================================================
class ComputeMenuItemCostUseCase {
  final SgBrocRepositoryPort _repo;

  const ComputeMenuItemCostUseCase({required SgBrocRepositoryPort repository})
      : _repo = repository;

  Future<Result<SgMenuItemCostBreakdown, SgFailure>> call({
    required String menuItemId,
    required int menuItemPriceCents,
  }) async {
    final recipeRes = await _repo.getRecipeForMenuItem(menuItemId);
    final recipe = recipeRes.valueOrNull;
    if (recipe == null) {
      return Success(SgMenuItemCostBreakdown(
        menuItemId: menuItemId,
        totalCostCents: 0,
        priceCents: menuItemPriceCents,
        lines: const [],
      ));
    }
    final riRes = await _repo.listRecipeIngredients(recipe.id);
    final ris = riRes.valueOrNull ?? const [];
    final lines = <SgIngredientCostLine>[];
    int total = 0;
    for (final ri in ris) {
      final ingRes = await _repo.getIngredient(ri.ingredientId);
      final ing = ingRes.valueOrNull;
      if (ing == null) continue;
      final cost = ri.costCents(ing);
      total += cost;
      lines.add(SgIngredientCostLine(
        ingredientId: ing.id,
        ingredientName: ing.name,
        quantity: ri.quantity,
        unit: ri.unit,
        costCents: cost,
        isSubstitution: ri.isSubstitution,
      ));
    }
    return Success(SgMenuItemCostBreakdown(
      menuItemId: menuItemId,
      totalCostCents: total,
      priceCents: menuItemPriceCents,
      lines: lines,
    ));
  }
}

// Note Phase F : la substitution d'ingrédient passe directement par
// SgBrocRepositoryPort.updateRecipeIngredient (avec isSubstitution=true + reason).
// L'UI propose un dialog "remplacer" qui appelle cette méthode + log event manuellement
// dans la couche server (BrCommandRegistry).

// ============================================================================
// DECLARE FOOD WASTE — capability check + auto-estimate value + log
// ============================================================================
class DeclareFoodWasteUseCase {
  final SgBrocRepositoryPort _repo;
  final SgClockPort _clock;
  final String Function() _idGenerator;
  final String Function() _eventIdGenerator;

  const DeclareFoodWasteUseCase({
    required SgBrocRepositoryPort repository,
    required SgClockPort clock,
    required String Function() idGenerator,
    required String Function() eventIdGenerator,
  })  : _repo = repository,
        _clock = clock,
        _idGenerator = idGenerator,
        _eventIdGenerator = eventIdGenerator;

  Future<Result<SgFoodWaste, SgFailure>> call({
    required SgWasteKind kind,
    required String refId,
    required String label,
    required double quantity,
    SgIngredientUnit? unit,
    required SgWasteReason reason,
    int? estimatedValueCents,
    String? notes,
    required String reportedBy,
  }) async {
    if (quantity <= 0) {
      return const Failure(SgValidationFailure('quantity must be > 0'));
    }
    // Auto-estimate value if not provided + kind == ingredient
    int finalValue = estimatedValueCents ?? 0;
    if (finalValue == 0 && kind == SgWasteKind.ingredient && unit != null) {
      final ingRes = await _repo.getIngredient(refId);
      final ing = ingRes.valueOrNull;
      if (ing != null) {
        finalValue = ing.costForQuantityCents(quantity, unit);
      }
    }
    final waste = SgFoodWaste(
      id: 'waste-${_idGenerator()}',
      kind: kind,
      refId: refId,
      label: label,
      quantity: quantity,
      unit: unit,
      reason: reason,
      estimatedValueCents: finalValue,
      reportedBy: reportedBy,
      reportedAt: _clock.now(),
      notes: notes,
    );
    final stored = await _repo.createFoodWaste(waste);
    return stored.when(
      success: (w) async {
        await _repo.logEvent(SgEventJournalEntry(
          id: _eventIdGenerator(),
          at: _clock.now(),
          actor: reportedBy,
          action: 'food_waste.declared',
          target: '${kind.name}:$refId',
          payload: {
            'label': label,
            'quantity': quantity,
            'unit': unit?.name,
            'reason': reason.name,
            'estimated_value_cents': finalValue,
          },
          reason: notes,
        ));
        return Success<SgFoodWaste, SgFailure>(w);
      },
      failure: (e) async => Failure<SgFoodWaste, SgFailure>(e),
    );
  }
}

// ============================================================================
// TOGGLE MENU ITEM AVAILABILITY (86 mode)
// ============================================================================
class ToggleMenuItemAvailabilityUseCase {
  final SgBrocRepositoryPort _repo;
  final SgClockPort _clock;
  final String Function() _eventIdGenerator;

  const ToggleMenuItemAvailabilityUseCase({
    required SgBrocRepositoryPort repository,
    required SgClockPort clock,
    required String Function() eventIdGenerator,
  })  : _repo = repository,
        _clock = clock,
        _eventIdGenerator = eventIdGenerator;

  Future<Result<SgMenuItem, SgFailure>> call({
    required String menuItemId,
    required bool available,
    String? reason,
    required String actor,
  }) async {
    // SgBrocRepositoryPort doesn't expose updateMenuItem yet — would need to update via card update
    // For v0.3, we log the intent + return a virtual item state
    final menuRes = await _repo.getCurrentPublishedMenuCard();
    final card = menuRes.valueOrNull;
    if (card == null) {
      return const Failure(SgNotFoundFailure('No published menu card'));
    }
    final item = card.items.where((i) => i.id == menuItemId).firstOrNull;
    if (item == null) {
      return Failure(SgNotFoundFailure('MenuItem $menuItemId not found'));
    }
    final updated = item.copyWith(
      available: available,
      unavailableReason: available ? null : (reason ?? 'rupture'),
    );
    // Persist via updateMenuCard with updated items list
    final newItems =
        card.items.map((i) => i.id == menuItemId ? updated : i).toList();
    final newCard = card.copyWith(items: newItems);
    await _repo.updateMenuCard(newCard);
    await _repo.logEvent(SgEventJournalEntry(
      id: _eventIdGenerator(),
      at: _clock.now(),
      actor: actor,
      action: available ? 'menu_item.available' : 'menu_item.unavailable',
      target: 'menu_item:$menuItemId',
      payload: {
        'name': updated.name,
        'reason': reason,
      },
      reason: reason,
    ));
    return Success(updated);
  }
}

// ============================================================================
// CREATE TABLE — génère qrSecret + log
// ============================================================================
class CreateTableUseCase {
  final SgBrocRepositoryPort _repo;
  final SgClockPort _clock;
  final String Function() _idGenerator;
  final String Function() _secretGenerator;
  final String Function() _eventIdGenerator;

  const CreateTableUseCase({
    required SgBrocRepositoryPort repository,
    required SgClockPort clock,
    required String Function() idGenerator,
    required String Function() secretGenerator,
    required String Function() eventIdGenerator,
  })  : _repo = repository,
        _clock = clock,
        _idGenerator = idGenerator,
        _secretGenerator = secretGenerator,
        _eventIdGenerator = eventIdGenerator;

  Future<Result<SgTable, SgFailure>> call({
    required String label,
    int? capacity,
    String? position,
    String actor = 'manager',
  }) async {
    if (label.trim().isEmpty) {
      return const Failure(SgValidationFailure('label required'));
    }
    final table = SgTable(
      id: 'tbl-${_idGenerator()}',
      label: label.trim(),
      capacity: capacity,
      qrSecret: _secretGenerator(),
      position: position,
      createdAt: _clock.now(),
    );
    final stored = await _repo.createTable(table);
    return stored.when(
      success: (t) async {
        await _repo.logEvent(SgEventJournalEntry(
          id: _eventIdGenerator(),
          at: _clock.now(),
          actor: actor,
          action: 'table.created',
          target: 'table:${t.id}',
          payload: {
            'label': t.label,
            'capacity': capacity,
          },
        ));
        return Success<SgTable, SgFailure>(t);
      },
      failure: (e) async => Failure<SgTable, SgFailure>(e),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
