import 'dart:convert';
import 'dart:io';

import 'package:br_core/br_core.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/pin_auth_service.dart';
import 'command_handler.dart';

/// Routes REST + TestControlServer.
class BrApiRouter {
  final PinAuthService _auth;
  final SgBrocRepositoryPort _repo;
  final BrCommandRegistry _commands;
  final ClockInUseCase _clockIn;
  final ClockOutUseCase _clockOut;
  final StartBreakUseCase _startBreak;
  final EndBreakUseCase _endBreak;
  final PublishMenuCardUseCase _publishMenu;
  final ExportMenuCardPdfUseCase _exportPdf;
  final AddShoppingItemUseCase _addShoppingItem;
  final CheckShoppingItemUseCase _checkShoppingItem;
  final AskQuestionUseCase _askQuestion;
  final ChangeRoleInShiftUseCase _changeRole;
  final SetWeeklyDefaultUseCase _setWeekly;
  final SetEmployeeRolesUseCase _setRoles;
  final SetSettingUseCase _setSetting;
  final ComputeMenuItemCostUseCase _computeCost;
  final DeclareFoodWasteUseCase _declareWaste;
  final ToggleMenuItemAvailabilityUseCase _toggleAvail;
  final CreateTableUseCase _createTable;
  final String Function() _idGenerator;

  BrApiRouter({
    required PinAuthService auth,
    required SgBrocRepositoryPort repository,
    required BrCommandRegistry commandRegistry,
    required ClockInUseCase clockIn,
    required ClockOutUseCase clockOut,
    required StartBreakUseCase startBreak,
    required EndBreakUseCase endBreak,
    required PublishMenuCardUseCase publishMenu,
    required ExportMenuCardPdfUseCase exportPdf,
    required AddShoppingItemUseCase addShoppingItem,
    required CheckShoppingItemUseCase checkShoppingItem,
    required AskQuestionUseCase askQuestion,
    required ChangeRoleInShiftUseCase changeRole,
    required SetWeeklyDefaultUseCase setWeekly,
    required SetEmployeeRolesUseCase setRoles,
    required SetSettingUseCase setSetting,
    required ComputeMenuItemCostUseCase computeCost,
    required DeclareFoodWasteUseCase declareWaste,
    required ToggleMenuItemAvailabilityUseCase toggleAvail,
    required CreateTableUseCase createTable,
    required String Function() idGenerator,
  })  : _auth = auth,
        _repo = repository,
        _commands = commandRegistry,
        _clockIn = clockIn,
        _clockOut = clockOut,
        _startBreak = startBreak,
        _endBreak = endBreak,
        _publishMenu = publishMenu,
        _exportPdf = exportPdf,
        _addShoppingItem = addShoppingItem,
        _checkShoppingItem = checkShoppingItem,
        _askQuestion = askQuestion,
        _changeRole = changeRole,
        _setWeekly = setWeekly,
        _setRoles = setRoles,
        _setSetting = setSetting,
        _computeCost = computeCost,
        _declareWaste = declareWaste,
        _toggleAvail = toggleAvail,
        _createTable = createTable,
        _idGenerator = idGenerator;

  Handler build() {
    final r = Router();

    r.get('/api/health', (Request req) async => _json(200, {
          'status': 'ok',
          'service': 'broccers',
          'version': '0.1.0',
          'now': DateTime.now().toUtc().toIso8601String(),
        }));

    r.post('/api/auth/pin', _handleAuthPin);
    r.post('/api/command', _handleCommand);

    // Documentation HTML (publique — pas d'auth)
    r.get('/docs', _serveDocsProduct);
    r.get('/docs/', _serveDocsProduct);
    r.get('/docs/product', _serveDocsProduct);
    r.get('/docs/product.html', _serveDocsProduct);
    r.get('/docs/schema', _serveDocsSchema);
    r.get('/docs/schema.html', _serveDocsSchema);
    r.get('/', _serveDocsIndex);

    r.get('/api/employees', _withAuth(_listEmployees));
    r.post('/api/employees/<id>/roles', _withAuthId(_handleSetEmployeeRoles));
    r.post('/api/employees/<id>/weekly', _withAuthId(_handleSetWeekly));
    r.post('/api/shifts/change-role', _withAuth(_handleChangeRole));
    r.get('/api/events', _withAuth(_listEvents));
    r.post('/api/shifts/clock-in', _withAuth(_handleClockIn));
    r.post('/api/shifts/clock-out', _withAuth(_handleClockOut));
    r.post('/api/breaks/start', _withAuth(_handleStartBreak));
    r.post('/api/breaks/end', _withAuth(_handleEndBreak));
    r.get('/api/menu/cards', _withAuth(_listMenuCards));
    r.get('/api/menu/cards/current', _withAuth(_currentMenuCard));
    r.post('/api/menu/cards/<id>/publish', _withAuthId(_publishMenuCard));
    r.get('/api/menu/cards/<id>/pdf', _withAuthId(_downloadMenuCardPdf));
    r.get('/api/shopping/lists', _withAuth(_listShoppingLists));
    r.post('/api/shopping/items', _withAuth(_handleAddShoppingItem));
    r.post('/api/shopping/items/<id>/check', _withAuthId(_checkItem));
    r.post('/api/shopping/items/<id>/uncheck', _withAuthId(_uncheckItem));
    r.post('/api/questions', _withAuth(_handleAskQuestion));
    r.get('/api/questions', _withAuth(_listQuestions));

    // === Phase F — Settings (manager-only) ===
    r.get('/api/settings', _withAuth(_listSettings));
    r.get('/api/settings/<key>', _withAuthId(_getSetting));
    r.put('/api/settings/<key>', _withAuthId(_putSetting));

    // === Phase F — Ingredients ===
    r.get('/api/ingredients', _withAuth(_listIngredients));
    r.post('/api/ingredients', _withAuth(_createIngredient));
    r.put('/api/ingredients/<id>', _withAuthId(_updateIngredient));

    // === Phase F — Recipe ingredients ===
    r.get('/api/recipes/<id>/ingredients', _withAuthId(_listRecipeIngredients));
    r.post('/api/recipes/<id>/ingredients', _withAuthId(_addRecipeIngredient));
    r.put('/api/recipe-ingredients/<id>', _withAuthId(_updateRecipeIngredient));
    r.delete('/api/recipe-ingredients/<id>', _withAuthId(_deleteRecipeIngredient));

    // === Phase F — Compute menu item cost ===
    r.get('/api/menu/items/<id>/cost', _withAuthId(_computeMenuItemCost));

    // === Phase F — Food waste ===
    r.get('/api/waste', _withAuth(_listWaste));
    r.post('/api/waste', _withAuth(_declareWasteRoute));
    r.get('/api/waste/summary', _withAuth(_wasteSummary));

    // === Phase F — Mode 86 ===
    r.post('/api/menu/items/<id>/availability', _withAuthId(_toggleAvailability));

    // === Phase F — Tables QR ===
    r.get('/api/tables', _withAuth(_listTables));
    r.post('/api/tables', _withAuth(_createTableRoute));
    r.post('/api/tables/<id>/rotate-secret', _withAuthId(_rotateTableSecret));
    r.post('/api/tables/<id>/deactivate', _withAuthId(_deactivateTable));

    // === Phase F — Public consultation carte via QR (PAS d'auth) ===
    r.get('/menu/<id>/<secret>', _publicMenuByQr);
    r.get('/api/public/menu/<id>/<secret>', _publicMenuJsonByQr);

    return r.call;
  }

  // ============================================================================
  // Phase F handlers
  // ============================================================================

  Future<Response> _listSettings(Request req) async {
    final cat = req.url.queryParameters['category'];
    SgSettingCategory? filter;
    if (cat != null) {
      filter = SgSettingCategory.values
          .where((c) => c.name == cat)
          .firstOrNull;
    }
    final stored = await _repo.listSettings(category: filter);
    final defs = filter == null
        ? SgBrocSettingsRegistry.allDefinitions
        : SgBrocSettingsRegistry.allDefinitions.where((d) => d.category == filter).toList();
    return stored.when(
      success: (l) {
        // Merge defaults + stored values
        final byKey = {for (final s in l) s.key: s};
        final result = defs.map((d) {
          final s = byKey[d.key];
          return {
            'key': d.key,
            'label': d.label,
            'description': d.description,
            'category': d.category.name,
            'category_label': d.category.label,
            'type': d.type.name,
            'default_value': d.defaultValue,
            'value': s?.value ?? d.defaultValue,
            'min_value': d.minValue,
            'max_value': d.maxValue,
            'enum_options': d.enumOptions,
            'unit': d.unit,
            if (s != null) ...{
              'set_at': s.setAt.toIso8601String(),
              'set_by': s.setBy,
            },
          };
        }).toList();
        return _json(200, {'settings': result});
      },
      failure: _failureResponse,
    );
  }

  Future<Response> _getSetting(Request req, String key) async {
    final def = SgBrocSettingsRegistry.find(key);
    if (def == null) return _json(404, {'error': 'unknown setting: $key'});
    final r = await _repo.getSetting(key);
    return r.when(
      success: (s) => _json(200, {
        'key': key,
        'value': s?.value ?? def.defaultValue,
        'is_default': s == null,
      }),
      failure: _failureResponse,
    );
  }

  Future<Response> _putSetting(Request req, String key) async {
    final body = await _readJson(req);
    final value = body['value'];
    if (value == null) return _json(400, {'error': 'value required'});
    final actor = (body['actor'] as String?) ?? 'manager';
    final reason = body['reason'] as String?;
    final r = await _setSetting(
      key: key,
      value: value as Object,
      actor: actor,
      reason: reason,
    );
    return r.when(success: (s) => _json(200, s.toJson()), failure: _failureResponse);
  }

  Future<Response> _listIngredients(Request req) async {
    final r = await _repo.listIngredients();
    return r.when(
      success: (l) => _json(200, {'ingredients': l.map((i) => i.toJson()).toList()}),
      failure: _failureResponse,
    );
  }

  Future<Response> _createIngredient(Request req) async {
    final body = await _readJson(req);
    final name = body['name'] as String?;
    final unitStr = body['unit'] as String?;
    final price = (body['current_price_cents'] as num?)?.toInt();
    if (name == null || unitStr == null || price == null) {
      return _json(400, {'error': 'name + unit + current_price_cents required'});
    }
    final unit = SgIngredientUnit.values.where((u) => u.name == unitStr).firstOrNull;
    if (unit == null) return _json(400, {'error': 'unknown unit: $unitStr'});
    final ing = SgIngredient(
      id: 'ing-${_idGenerator()}',
      name: name,
      unit: unit,
      currentPriceCents: price,
      supplierId: body['supplier_id'] as String?,
      notes: body['notes'] as String?,
      updatedAt: DateTime.now().toUtc(),
    );
    final r = await _repo.createIngredient(ing);
    return r.when(success: (i) => _json(201, i.toJson()), failure: _failureResponse);
  }

  Future<Response> _updateIngredient(Request req, String id) async {
    final body = await _readJson(req);
    final cur = await _repo.getIngredient(id);
    final ing = cur.valueOrNull;
    if (ing == null) return _json(404, {'error': 'ingredient not found'});
    final updated = ing.copyWith(
      name: body['name'] as String? ?? ing.name,
      currentPriceCents: (body['current_price_cents'] as num?)?.toInt() ?? ing.currentPriceCents,
      supplierId: body['supplier_id'] as String? ?? ing.supplierId,
      notes: body['notes'] as String? ?? ing.notes,
      updatedAt: DateTime.now().toUtc(),
    );
    final r = await _repo.updateIngredient(updated);
    return r.when(success: (i) => _json(200, i.toJson()), failure: _failureResponse);
  }

  Future<Response> _listRecipeIngredients(Request req, String recipeId) async {
    final r = await _repo.listRecipeIngredients(recipeId);
    return r.when(
      success: (l) => _json(200, {'items': l.map((ri) => ri.toJson()).toList()}),
      failure: _failureResponse,
    );
  }

  Future<Response> _addRecipeIngredient(Request req, String recipeId) async {
    final body = await _readJson(req);
    final ingredientId = body['ingredient_id'] as String?;
    final qty = (body['quantity'] as num?)?.toDouble();
    final unitStr = body['unit'] as String?;
    if (ingredientId == null || qty == null || unitStr == null) {
      return _json(400, {'error': 'ingredient_id + quantity + unit required'});
    }
    final unit = SgIngredientUnit.values.where((u) => u.name == unitStr).firstOrNull;
    if (unit == null) return _json(400, {'error': 'unknown unit: $unitStr'});
    final ri = SgRecipeIngredient(
      id: 'ri-${_idGenerator()}',
      recipeId: recipeId,
      ingredientId: ingredientId,
      quantity: qty,
      unit: unit,
      notes: body['notes'] as String?,
      isSubstitution: body['is_substitution'] as bool? ?? false,
      substitutionReason: body['substitution_reason'] as String?,
    );
    final r = await _repo.createRecipeIngredient(ri);
    return r.when(success: (x) => _json(201, x.toJson()), failure: _failureResponse);
  }

  Future<Response> _updateRecipeIngredient(Request req, String id) async {
    final body = await _readJson(req);
    final recipeId = body['recipe_id'] as String?;
    if (recipeId == null) return _json(400, {'error': 'recipe_id required'});
    final list = await _repo.listRecipeIngredients(recipeId);
    final cur = list.valueOrNull?.where((r) => r.id == id).firstOrNull;
    if (cur == null) return _json(404, {'error': 'recipe ingredient not found'});
    final unit = body['unit'] != null
        ? SgIngredientUnit.values.where((u) => u.name == body['unit']).firstOrNull
        : null;
    final updated = cur.copyWith(
      ingredientId: body['ingredient_id'] as String? ?? cur.ingredientId,
      quantity: (body['quantity'] as num?)?.toDouble() ?? cur.quantity,
      unit: unit ?? cur.unit,
      isSubstitution: body['is_substitution'] as bool? ?? cur.isSubstitution,
      substitutionReason: body['substitution_reason'] as String? ?? cur.substitutionReason,
      notes: body['notes'] as String? ?? cur.notes,
    );
    final r = await _repo.updateRecipeIngredient(updated);
    if (updated.isSubstitution && (cur.ingredientId != updated.ingredientId)) {
      await _repo.logEvent(SgEventJournalEntry(
        id: 'evt-${_idGenerator()}',
        at: DateTime.now().toUtc(),
        actor: (body['actor'] as String?) ?? 'manager',
        action: 'ingredient.substituted',
        target: 'recipe_ingredient:$id',
        payload: {
          'from': cur.ingredientId,
          'to': updated.ingredientId,
          'reason': updated.substitutionReason,
        },
        reason: updated.substitutionReason,
      ));
    }
    return r.when(success: (x) => _json(200, x.toJson()), failure: _failureResponse);
  }

  Future<Response> _deleteRecipeIngredient(Request req, String id) async {
    final r = await _repo.deleteRecipeIngredient(id);
    return r.when(
      success: (_) => _json(200, {'deleted': id}),
      failure: _failureResponse,
    );
  }

  Future<Response> _computeMenuItemCost(Request req, String id) async {
    final cardRes = await _repo.getCurrentPublishedMenuCard();
    final card = cardRes.valueOrNull;
    final item = card?.items.where((i) => i.id == id).firstOrNull;
    if (item == null) return _json(404, {'error': 'menu item not found'});
    final r = await _computeCost(menuItemId: id, menuItemPriceCents: item.priceCents);
    return r.when(
      success: (b) async {
        final red = await _settingInt('margin.threshold_red_pct', 60);
        final yellow = await _settingInt('margin.threshold_yellow_pct', 70);
        return _json(200, b.toJson(redThreshold: red, yellowThreshold: yellow));
      },
      failure: _failureResponse,
    );
  }

  Future<int> _settingInt(String key, int fallback) async {
    final r = await _repo.getSetting(key);
    final v = r.valueOrNull?.value;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  Future<Response> _listWaste(Request req) async {
    final q = req.url.queryParameters;
    DateTime? from;
    DateTime? to;
    if (q['from'] != null) from = DateTime.tryParse(q['from']!);
    if (q['to'] != null) to = DateTime.tryParse(q['to']!);
    SgWasteReason? reason;
    if (q['reason'] != null) {
      reason = SgWasteReason.values.where((r) => r.name == q['reason']).firstOrNull;
    }
    final r = await _repo.listFoodWaste(from: from, to: to, reason: reason);
    return r.when(
      success: (l) => _json(200, {
        'count': l.length,
        'total_cents': l.fold<int>(0, (a, w) => a + w.estimatedValueCents),
        'items': l.map((w) => w.toJson()).toList(),
      }),
      failure: _failureResponse,
    );
  }

  Future<Response> _declareWasteRoute(Request req) async {
    final body = await _readJson(req);
    final kindStr = body['kind'] as String?;
    final refId = body['ref_id'] as String?;
    final label = body['label'] as String?;
    final qty = (body['quantity'] as num?)?.toDouble();
    final reasonStr = body['reason'] as String?;
    final reportedBy = body['reported_by'] as String?;
    if (kindStr == null || refId == null || label == null || qty == null || reasonStr == null || reportedBy == null) {
      return _json(400, {'error': 'kind + ref_id + label + quantity + reason + reported_by required'});
    }
    final kind = SgWasteKind.values.where((k) => k.name == kindStr).firstOrNull;
    final reason = SgWasteReason.values.where((r) => r.name == reasonStr).firstOrNull;
    if (kind == null || reason == null) return _json(400, {'error': 'unknown kind or reason'});
    final unit = body['unit'] != null
        ? SgIngredientUnit.values.where((u) => u.name == body['unit']).firstOrNull
        : null;
    final r = await _declareWaste(
      kind: kind,
      refId: refId,
      label: label,
      quantity: qty,
      unit: unit,
      reason: reason,
      estimatedValueCents: (body['estimated_value_cents'] as num?)?.toInt(),
      notes: body['notes'] as String?,
      reportedBy: reportedBy,
    );
    return r.when(success: (w) => _json(201, w.toJson()), failure: _failureResponse);
  }

  Future<Response> _wasteSummary(Request req) async {
    final now = DateTime.now().toUtc();
    final weekAgo = now.subtract(const Duration(days: 7));
    final r = await _repo.listFoodWaste(from: weekAgo, to: now);
    return r.when(
      success: (l) {
        final byReason = <String, int>{};
        final byDay = <String, int>{};
        int total = 0;
        for (final w in l) {
          byReason[w.reason.name] = (byReason[w.reason.name] ?? 0) + w.estimatedValueCents;
          final day = w.reportedAt.toIso8601String().substring(0, 10);
          byDay[day] = (byDay[day] ?? 0) + w.estimatedValueCents;
          total += w.estimatedValueCents;
        }
        return _json(200, {
          'period': {'from': weekAgo.toIso8601String(), 'to': now.toIso8601String()},
          'count': l.length,
          'total_cents': total,
          'by_reason_cents': byReason,
          'by_day_cents': byDay,
        });
      },
      failure: _failureResponse,
    );
  }

  Future<Response> _toggleAvailability(Request req, String id) async {
    final body = await _readJson(req);
    final available = body['available'] as bool?;
    if (available == null) return _json(400, {'error': 'available (bool) required'});
    final actor = (body['actor'] as String?) ?? 'manager';
    final reason = body['reason'] as String?;
    final r = await _toggleAvail(
      menuItemId: id,
      available: available,
      reason: reason,
      actor: actor,
    );
    return r.when(success: (m) => _json(200, m.toJson()), failure: _failureResponse);
  }

  Future<Response> _listTables(Request req) async {
    final activeOnly = req.url.queryParameters['active_only'] != 'false';
    final r = await _repo.listTables(activeOnly: activeOnly);
    return r.when(
      success: (l) => _json(200, {'tables': l.map((t) => _tableJson(t, req)).toList()}),
      failure: _failureResponse,
    );
  }

  Map<String, dynamic> _tableJson(SgTable t, Request req) {
    final baseUrl = '${req.requestedUri.scheme}://${req.requestedUri.host}:${req.requestedUri.port}';
    return {
      ...t.toJson(),
      'public_menu_url': t.publicMenuUrl(baseUrl),
    };
  }

  Future<Response> _createTableRoute(Request req) async {
    final body = await _readJson(req);
    final label = body['label'] as String?;
    if (label == null) return _json(400, {'error': 'label required'});
    final r = await _createTable(
      label: label,
      capacity: (body['capacity'] as num?)?.toInt(),
      position: body['position'] as String?,
      actor: (body['actor'] as String?) ?? 'manager',
    );
    return r.when(success: (t) => _json(201, _tableJson(t, req)), failure: _failureResponse);
  }

  Future<Response> _rotateTableSecret(Request req, String id) async {
    final cur = await _repo.getTable(id);
    final t = cur.valueOrNull;
    if (t == null) return _json(404, {'error': 'table not found'});
    final newSecret = _idGenerator().replaceAll('-', '').substring(0, 16);
    final rotated = t.rotateSecret(newSecret: newSecret, at: DateTime.now().toUtc());
    final r = await _repo.updateTable(rotated);
    return r.when(success: (x) => _json(200, _tableJson(x, req)), failure: _failureResponse);
  }

  Future<Response> _deactivateTable(Request req, String id) async {
    final cur = await _repo.getTable(id);
    final t = cur.valueOrNull;
    if (t == null) return _json(404, {'error': 'table not found'});
    final r = await _repo.updateTable(t.copyWith(active: false));
    return r.when(success: (x) => _json(200, _tableJson(x, req)), failure: _failureResponse);
  }

  Future<Response> _publicMenuByQr(Request req, String id, String secret) async {
    final t = await _repo.getTableByIdAndSecret(id, secret);
    if (t.valueOrNull == null) {
      return Response.notFound('Table introuvable ou QR code invalide.');
    }
    final cardRes = await _repo.getCurrentPublishedMenuCard();
    final card = cardRes.valueOrNull;
    if (card == null) {
      return Response.notFound('Aucune carte publiée.');
    }
    final html = _renderPublicMenuHtml(card, t.valueOrNull!);
    return Response.ok(html, headers: {'content-type': 'text/html; charset=utf-8'});
  }

  Future<Response> _publicMenuJsonByQr(Request req, String id, String secret) async {
    final t = await _repo.getTableByIdAndSecret(id, secret);
    if (t.valueOrNull == null) return _json(404, {'error': 'invalid QR'});
    final cardRes = await _repo.getCurrentPublishedMenuCard();
    final card = cardRes.valueOrNull;
    if (card == null) return _json(404, {'error': 'no published card'});
    return _json(200, {
      'table': {'id': t.valueOrNull!.id, 'label': t.valueOrNull!.label},
      'card': card.toJson(),
    });
  }

  String _renderPublicMenuHtml(SgMenuCard card, SgTable table) {
    final buf = StringBuffer();
    buf.write('''<!DOCTYPE html><html lang="fr"><head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Le Broc — Table ${table.label}</title>
<style>
  body{margin:0;background:#14100f;color:#f5ebd6;font-family:-apple-system,'Helvetica Neue',sans-serif;padding:18px;line-height:1.5}
  .b{background:#c72226;color:#f5ebd6;padding:6px 12px;border-radius:6px;font-weight:900;letter-spacing:2px;font-size:11px;display:inline-block}
  h1{font-size:2.2rem;margin:12px 0 4px;font-weight:900;background:linear-gradient(135deg,#f5c842,#c72226);-webkit-background-clip:text;-webkit-text-fill-color:transparent;background-clip:text}
  .table-info{color:#b5a89a;font-style:italic;margin-bottom:24px}
  h2{color:#f5c842;border-bottom:2px solid #c72226;padding-bottom:6px;margin-top:32px;font-size:1.3rem}
  .item{padding:12px 0;border-bottom:1px solid #2a221e;display:flex;justify-content:space-between;gap:12px;align-items:baseline}
  .item.unavailable{opacity:0.45}
  .item-name{font-weight:600}
  .item-desc{color:#b5a89a;font-size:0.85rem;margin-top:2px}
  .item-price{font-weight:700;color:#f5c842;font-variant-numeric:tabular-nums;white-space:nowrap}
  .item-tag{font-size:0.7rem;background:#c72226;color:#f5ebd6;padding:2px 6px;border-radius:3px;margin-left:6px;display:inline-block}
  .footer{margin-top:40px;text-align:center;color:#7a6f63;font-size:0.75rem;font-family:monospace;padding:20px}
  .footer a{color:#7a6f63;text-decoration:none}
</style></head><body>
<div class="b">CAFÉ</div>
<h1>Le Broc</h1>
<div class="table-info">Table ${table.label} · Carte v${card.version} · Puces du Canal, Villeurbanne</div>
''');
    final byCat = <String, List<SgMenuItem>>{};
    for (final i in card.items) {
      byCat.putIfAbsent(i.categoryId, () => []).add(i);
    }
    for (final cat in card.categories) {
      final items = byCat[cat.id] ?? [];
      if (items.isEmpty) continue;
      buf.write('<h2>${_escape(cat.name)}</h2>');
      for (final i in items) {
        final cls = i.available ? 'item' : 'item unavailable';
        final tag = i.available ? '' : '<span class="item-tag">EN RUPTURE</span>';
        final desc = i.description != null && i.description!.isNotEmpty
            ? '<div class="item-desc">${_escape(i.description!)}</div>'
            : '';
        buf.write('''<div class="$cls">
  <div><div class="item-name">${_escape(i.name)}$tag</div>$desc</div>
  <div class="item-price">${_formatPrice(i.priceCents)}</div>
</div>''');
      }
    }
    buf.write('''
<div class="footer">
  Carte susceptible d'évoluer selon la disponibilité des produits frais.<br>
  Pour commander, demandez votre serveur. ${card.publishedAt != null ? "Publiée le ${card.publishedAt!.toIso8601String().substring(0, 10)}" : ""}.
</div>
</body></html>''');
    return buf.toString();
  }

  String _formatPrice(int cents) {
    final e = cents ~/ 100;
    final c = cents % 100;
    return c == 0 ? '$e €' : '$e,${c.toString().padLeft(2, '0')} €';
  }

  String _escape(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  Future<Response> _handleAuthPin(Request req) async {
    final body = await _readJson(req);
    final pin = body['pin'] as String?;
    if (pin == null || pin.isEmpty) return _json(400, {'error': 'pin required'});
    final ip = _clientIp(req);
    final result = await _auth.authenticate(pin: pin, clientIp: ip);
    return result.when(
      success: (jwt) => _json(200, {'token': jwt}),
      failure: _failureResponse,
    );
  }

  Future<Response> _handleCommand(Request req) async {
    final raw = await req.readAsString();
    final result = await handleCommandJson(_commands, raw);
    final type = result['type'];
    final status = type == 'success' ? 200 : (type == 'invalid_args' ? 400 : 500);
    return _json(status, result);
  }

  // ==== Doc HTML statiques (servies depuis docs/) ====
  Future<Response> _serveDocsProduct(Request req) => _serveDocFile('docs/product.html');
  Future<Response> _serveDocsSchema(Request req) => _serveDocFile('docs/schema.html');

  Future<Response> _serveDocsIndex(Request req) async {
    return Response.ok(
      '''<!DOCTYPE html><html><head><meta charset="UTF-8"><title>Le Broc Café · API</title>
<style>body{background:#14100f;color:#f5ebd6;font-family:-apple-system,sans-serif;padding:40px;text-align:center}
.b{background:#c72226;color:#f5ebd6;padding:8px 14px;border-radius:6px;font-weight:900;letter-spacing:2px;display:inline-block}
a{color:#f5c842;text-decoration:none;display:block;padding:8px;font-size:1.2rem}
a:hover{text-decoration:underline}
h1{font-size:3rem;margin:20px 0;font-weight:900;background:linear-gradient(135deg,#f5c842,#c72226);-webkit-background-clip:text;-webkit-text-fill-color:transparent}
.lead{color:#b5a89a;margin-bottom:30px;font-style:italic}</style></head>
<body>
<div class="b">CAFÉ</div>
<h1>Le Broc</h1>
<p class="lead">Serveur Broccers — Puces du Canal, Villeurbanne</p>
<p><strong style="color:#f5c842">App PWA :</strong> <a href="http://127.0.0.1:8766">http://127.0.0.1:8766</a> (Flutter Web)</p>
<p><strong style="color:#f5c842">Documentation produit :</strong> <a href="/docs/product">/docs/product</a></p>
<p><strong style="color:#f5c842">Schéma visuel :</strong> <a href="/docs/schema">/docs/schema</a></p>
<p><strong style="color:#f5c842">API Health :</strong> <a href="/api/health">/api/health</a></p>
<p style="margin-top:40px;font-size:11px;color:#7a6f63;font-family:monospace">v0.3.0-alpha · SG Framework · Tailscale only · zero cloud public</p>
</body></html>''',
      headers: {'content-type': 'text/html; charset=utf-8'},
    );
  }

  Future<Response> _serveDocFile(String relativePath) async {
    final candidates = [
      relativePath,
      '../../$relativePath',
      '../../../$relativePath',
      '/Users/sgo/Code/broccers/$relativePath',
    ];
    for (final p in candidates) {
      final f = File(p);
      if (await f.exists()) {
        return Response.ok(
          await f.readAsString(),
          headers: {'content-type': 'text/html; charset=utf-8'},
        );
      }
    }
    return Response.notFound('Doc not found: $relativePath');
  }

  Future<Response> _listEmployees(Request req) async {
    final r = await _repo.listEmployees();
    return r.when(
      success: (l) => _json(200, {'employees': l.map((e) => e.toJson()).toList()}),
      failure: _failureResponse,
    );
  }

  Future<Response> _handleClockIn(Request req) async {
    final body = await _readJson(req);
    final id = body['employee_id'] as String?;
    if (id == null) return _json(400, {'error': 'employee_id required'});
    SgEmployeeRole? override;
    if (body['role'] != null) {
      override = SgEmployeeRole.values
          .where((r) => r.name == body['role'])
          .firstOrNull;
    }
    final actor = (body['actor'] as String?) ?? 'employee:$id';
    final reason = body['reason'] as String?;
    final r = await _clockIn(
      employeeId: id,
      roleOverride: override,
      actor: actor,
      reason: reason,
    );
    return r.when(success: (o) => _json(201, o.toJson()), failure: _failureResponse);
  }

  Future<Response> _handleClockOut(Request req) async {
    final body = await _readJson(req);
    final id = body['employee_id'] as String?;
    if (id == null) return _json(400, {'error': 'employee_id required'});
    final actor = (body['actor'] as String?) ?? 'employee:$id';
    final reason = body['reason'] as String?;
    final r = await _clockOut(employeeId: id, actor: actor, reason: reason);
    return r.when(success: (o) => _json(200, o.toJson()), failure: _failureResponse);
  }

  Future<Response> _handleChangeRole(Request req) async {
    final body = await _readJson(req);
    final id = body['employee_id'] as String?;
    final roleStr = body['role'] as String?;
    if (id == null || roleStr == null) {
      return _json(400, {'error': 'employee_id + role required'});
    }
    final newRole = SgEmployeeRole.values.where((r) => r.name == roleStr).firstOrNull;
    if (newRole == null) return _json(400, {'error': 'unknown role: $roleStr'});
    final actor = (body['actor'] as String?) ?? 'employee:$id';
    final reason = body['reason'] as String?;
    final r = await _changeRole(
      employeeId: id,
      newRole: newRole,
      actor: actor,
      reason: reason,
    );
    return r.when(success: (o) => _json(200, o.toJson()), failure: _failureResponse);
  }

  Future<Response> _handleSetEmployeeRoles(Request req, String id) async {
    final body = await _readJson(req);
    final rolesArg = body['roles'] as List<dynamic>?;
    if (rolesArg == null) return _json(400, {'error': 'roles required'});
    final roles = <SgEmployeeRole>{};
    for (final r in rolesArg) {
      final e = SgEmployeeRole.values.where((x) => x.name == r as String).firstOrNull;
      if (e == null) return _json(400, {'error': 'unknown role: $r'});
      roles.add(e);
    }
    SgEmployeeRole? defaultRole;
    if (body['default_role'] != null) {
      defaultRole = SgEmployeeRole.values
          .where((x) => x.name == body['default_role'])
          .firstOrNull;
    }
    final actor = (body['actor'] as String?) ?? 'manager';
    final reason = body['reason'] as String?;
    final r = await _setRoles(
      employeeId: id,
      roles: roles,
      defaultRole: defaultRole,
      actor: actor,
      reason: reason,
    );
    return r.when(success: (e) => _json(200, e.toJson()), failure: _failureResponse);
  }

  Future<Response> _handleSetWeekly(Request req, String id) async {
    final body = await _readJson(req);
    final weeklyArg = body['weekly'] as Map<String, dynamic>?;
    if (weeklyArg == null) return _json(400, {'error': 'weekly required'});
    final weekly = <SgWeekday, SgEmployeeRole>{};
    for (final entry in weeklyArg.entries) {
      final day = int.tryParse(entry.key);
      if (day == null || day < 1 || day > 7) {
        return _json(400, {'error': 'weekday must be 1..7: ${entry.key}'});
      }
      final role = SgEmployeeRole.values
          .where((x) => x.name == entry.value as String)
          .firstOrNull;
      if (role == null) return _json(400, {'error': 'unknown role: ${entry.value}'});
      weekly[SgWeekday.fromIso(day)] = role;
    }
    final actor = (body['actor'] as String?) ?? 'manager';
    final reason = body['reason'] as String?;
    final r = await _setWeekly(
      employeeId: id,
      weekly: weekly,
      actor: actor,
      reason: reason,
    );
    return r.when(success: (e) => _json(200, e.toJson()), failure: _failureResponse);
  }

  Future<Response> _listEvents(Request req) async {
    final q = req.url.queryParameters;
    final r = await _repo.listEvents(
      actor: q['actor'],
      action: q['action'],
      targetPrefix: q['target_prefix'],
      limit: int.tryParse(q['limit'] ?? '200'),
    );
    return r.when(
      success: (l) => _json(200, {
        'count': l.length,
        'events': l.map((e) => e.toJson()).toList(),
      }),
      failure: _failureResponse,
    );
  }

  Future<Response> _handleStartBreak(Request req) async {
    final body = await _readJson(req);
    final id = body['employee_id'] as String?;
    if (id == null) return _json(400, {'error': 'employee_id required'});
    final type = SgBreakType.values
        .where((t) => t.name == (body['type'] ?? 'legal'))
        .firstOrNull ??
        SgBreakType.legal;
    final r = await _startBreak(employeeId: id, type: type);
    return r.when(success: (b) => _json(201, b.toJson()), failure: _failureResponse);
  }

  Future<Response> _handleEndBreak(Request req) async {
    final body = await _readJson(req);
    final id = body['employee_id'] as String?;
    if (id == null) return _json(400, {'error': 'employee_id required'});
    final r = await _endBreak(employeeId: id);
    return r.when(
      success: (out) => _json(200, {
        'break': out.breakRecord.toJson(),
        if (out.warning != null) 'warning': out.warning,
      }),
      failure: _failureResponse,
    );
  }

  Future<Response> _listMenuCards(Request req) async {
    final r = await _repo.listMenuCards(includeDrafts: true);
    return r.when(
      success: (l) => _json(200, {'cards': l.map((c) => c.toJson()).toList()}),
      failure: _failureResponse,
    );
  }

  Future<Response> _currentMenuCard(Request req) async {
    final r = await _repo.getCurrentPublishedMenuCard();
    return r.when(
      success: (c) =>
          c == null ? _json(404, {'error': 'no published card'}) : _json(200, c.toJson()),
      failure: _failureResponse,
    );
  }

  Future<Response> _publishMenuCard(Request req, String id) async {
    final r = await _publishMenu(cardId: id);
    return r.when(success: (c) => _json(200, c.toJson()), failure: _failureResponse);
  }

  Future<Response> _downloadMenuCardPdf(Request req, String id) async {
    final r = await _exportPdf(cardId: id);
    return r.when(
      success: (out) => Response.ok(
        out.bytes,
        headers: {
          'content-type': 'application/pdf',
          'content-disposition':
              'inline; filename="menu_v${out.export.cardVersion}.pdf"',
        },
      ),
      failure: _failureResponse,
    );
  }

  Future<Response> _listShoppingLists(Request req) async {
    final r = await _repo.listShoppingLists();
    return r.when(
      success: (l) => _json(200, {'lists': l.map((s) => s.toJson()).toList()}),
      failure: _failureResponse,
    );
  }

  Future<Response> _handleAddShoppingItem(Request req) async {
    final body = await _readJson(req);
    final list = body['list_id'] as String?;
    final name = body['name'] as String?;
    if (list == null || name == null) {
      return _json(400, {'error': 'list_id and name required'});
    }
    final r = await _addShoppingItem(
      listId: list,
      name: name,
      quantity: (body['quantity'] as num?)?.toDouble() ?? 1,
      unit: body['unit'] as String? ?? 'pcs',
      urgent: body['urgent'] as bool? ?? false,
      supplierId: body['supplier_id'] as String?,
    );
    return r.when(success: (i) => _json(201, i.toJson()), failure: _failureResponse);
  }

  Future<Response> _checkItem(Request req, String id) async {
    final r = await _checkShoppingItem(itemId: id, done: true);
    return r.when(success: (i) => _json(200, i.toJson()), failure: _failureResponse);
  }

  Future<Response> _uncheckItem(Request req, String id) async {
    final r = await _checkShoppingItem(itemId: id, done: false);
    return r.when(success: (i) => _json(200, i.toJson()), failure: _failureResponse);
  }

  Future<Response> _handleAskQuestion(Request req) async {
    final body = await _readJson(req);
    final text = body['question'] as String?;
    if (text == null) return _json(400, {'error': 'question required'});
    final scope = ((body['scope'] as List<dynamic>?) ?? const ['menu', 'shopping'])
        .map((e) => e as String)
        .toSet();
    final r = await _askQuestion(question: text, scope: scope);
    return r.when(success: (q) => _json(200, q.toJson()), failure: _failureResponse);
  }

  Future<Response> _listQuestions(Request req) async {
    final r = await _repo.listQuestions();
    return r.when(
      success: (l) => _json(200, {'questions': l.map((q) => q.toJson()).toList()}),
      failure: _failureResponse,
    );
  }

  // ===== Auth wrappers =====
  Handler _withAuth(Future<Response> Function(Request) handler) {
    return (Request req) async {
      final auth = req.headers['authorization'];
      if (auth == null || !auth.startsWith('Bearer ')) {
        return _json(401, {'error': 'Bearer token required'});
      }
      final token = auth.substring('Bearer '.length);
      final v = _auth.verifyJwt(token);
      return v.when(success: (_) => handler(req), failure: (e) async => _failureResponse(e));
    };
  }

  Future<Response> Function(Request, String) _withAuthId(
    Future<Response> Function(Request, String) handler,
  ) {
    return (Request req, String id) async {
      final auth = req.headers['authorization'];
      if (auth == null || !auth.startsWith('Bearer ')) {
        return _json(401, {'error': 'Bearer token required'});
      }
      final token = auth.substring('Bearer '.length);
      final v = _auth.verifyJwt(token);
      return v.when(success: (_) => handler(req, id), failure: (e) async => _failureResponse(e));
    };
  }

  // ===== helpers =====
  Future<Map<String, dynamic>> _readJson(Request req) async {
    final body = await req.readAsString();
    if (body.isEmpty) return const {};
    return jsonDecode(body) as Map<String, dynamic>;
  }

  Response _json(int status, Object body) => Response(
        status,
        body: jsonEncode(body),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  Response _failureResponse(SgFailure e) {
    final status = switch (e) {
      SgValidationFailure() => 400,
      SgBrocAuthFailure() => 401,
      SgPermissionFailure() => 403,
      SgNotFoundFailure() => 404,
      SgBrocStateFailure() => 409,
      SgDatabaseFailure() => 500,
      SgNetworkFailure() => 502,
      SgBrocPdfFailure() => 500,
      SgBrocQuestionFailure() => 502,
      _ => 500,
    };
    return _json(status, {
      'error': e.runtimeType.toString(),
      'message': e.message,
    });
  }

  String _clientIp(Request req) {
    final forwarded = req.headers['x-forwarded-for'];
    if (forwarded != null && forwarded.isNotEmpty) {
      return forwarded.split(',').first.trim();
    }
    final conn = req.context['shelf.io.connection_info'];
    if (conn is HttpConnectionInfo) return conn.remoteAddress.address;
    return 'unknown';
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
