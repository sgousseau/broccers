import 'dart:convert';
import 'dart:io';

import 'package:br_core/br_core.dart';
import 'package:uuid/uuid.dart';

import '../config.dart';

/// SG TestControlServer — chaque feature testable via HTTP.
/// POST /api/command {"cmd": "..."} → {"type": "success"|"failure"|"invalid_args", ...}
class BrCommandRegistry {
  final BrServerConfig _config;
  final SgBrocRepositoryPort _repo;
  final SgQuestionPort _question;
  final SgPdfRendererPort _pdf;
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
  final Uuid _uuid;
  final DateTime Function() _now;

  BrCommandRegistry({
    required BrServerConfig config,
    required SgBrocRepositoryPort repository,
    required SgQuestionPort question,
    required SgPdfRendererPort pdf,
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
    required Uuid uuid,
    required DateTime Function() now,
  })  : _config = config,
        _repo = repository,
        _question = question,
        _pdf = pdf,
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
        _uuid = uuid,
        _now = now;

  Future<Map<String, dynamic>> dispatch(String cmd) async {
    final tokens = _tokenize(cmd);
    if (tokens.isEmpty) return _invalid('empty command');
    final group = tokens.first;
    final args = tokens.sublist(1);
    try {
      switch (group) {
        case 'health':
          return _success({
            'service': 'broccers',
            'version': '0.1.0',
            'now': _now().toIso8601String(),
          });
        case 'audit':
          return _success(await _audit());
        case 'help':
          return _success({'commands': _helpText});
        case 'employee':
          return _dispatchEmployee(args);
        case 'shift':
          return _dispatchShift(args);
        case 'break':
          return _dispatchBreak(args);
        case 'menu':
          return _dispatchMenu(args);
        case 'shopping':
          return _dispatchShopping(args);
        case 'question':
          return _dispatchQuestion(args);
        case 'supplier':
          return _dispatchSupplier(args);
        case 'events':
          return _dispatchEvents(args);
        default:
          return _invalid('unknown command: $group');
      }
    } catch (e, st) {
      return _failure('exception: $e\n$st');
    }
  }

  // employee
  Future<Map<String, dynamic>> _dispatchEmployee(List<String> args) async {
    if (args.isEmpty) return _invalid('employee <sub>');
    final sub = args.first;
    final rest = args.sublist(1);
    switch (sub) {
      case 'list':
        final r = await _repo.listEmployees();
        return r.when(
          success: (l) => _success({
            'count': l.length,
            'employees': l.map((e) => e.toJson()).toList(),
          }),
          failure: _failureOf,
        );
      case 'create':
        final name = _opt(rest, '--name');
        final rolesArg = _opt(rest, '--roles') ?? _opt(rest, '--role');
        final defaultRoleArg = _opt(rest, '--default-role');
        final hours = double.tryParse(_opt(rest, '--hours') ?? '35');
        if (name == null || rolesArg == null) {
          return _invalid('employee create --name "..." --roles role1,role2,... [--default-role X] [--hours N --kiosk-name "..."]');
        }
        final roles = <SgEmployeeRole>{};
        for (final r in rolesArg.split(',')) {
          final e = SgEmployeeRole.values.where((x) => x.name == r.trim()).firstOrNull;
          if (e == null) return _invalid('unknown role: ${r.trim()}');
          roles.add(e);
        }
        SgEmployeeRole? defaultRole;
        if (defaultRoleArg != null) {
          defaultRole = SgEmployeeRole.values
              .where((x) => x.name == defaultRoleArg)
              .firstOrNull;
          if (defaultRole == null) {
            return _invalid('unknown default role: $defaultRoleArg');
          }
        } else if (roles.length == 1) {
          defaultRole = roles.first;
        }
        final emp = SgEmployee(
          id: 'emp-${_uuid.v4()}',
          name: name,
          roles: roles,
          defaultRole: defaultRole,
          contractedHours: hours ?? 35,
          kioskName: _opt(rest, '--kiosk-name') ?? name,
        );
        final r = await _repo.createEmployee(emp);
        return r.when(success: (e) => _success(e.toJson()), failure: _failureOf);
      case 'get':
        if (rest.isEmpty) return _invalid('employee get <id>');
        final r = await _repo.getEmployee(rest.first);
        return r.when(
          success: (e) =>
              e == null ? _failure('not found') : _success(e.toJson()),
          failure: _failureOf,
        );
      case 'set-roles':
        final empId = _opt(rest, '--employee');
        final rolesArg = _opt(rest, '--roles');
        final defaultRoleArg = _opt(rest, '--default-role');
        final actor = _opt(rest, '--actor') ?? 'manager';
        final reason = _opt(rest, '--reason');
        if (empId == null || rolesArg == null) {
          return _invalid('employee set-roles --employee <id> --roles a,b,c [--default-role X --actor manager:<id> --reason "..."]');
        }
        final roles = <SgEmployeeRole>{};
        for (final r in rolesArg.split(',')) {
          final e = SgEmployeeRole.values.where((x) => x.name == r.trim()).firstOrNull;
          if (e == null) return _invalid('unknown role: ${r.trim()}');
          roles.add(e);
        }
        SgEmployeeRole? defaultRole;
        if (defaultRoleArg != null) {
          defaultRole = SgEmployeeRole.values
              .where((x) => x.name == defaultRoleArg)
              .firstOrNull;
        }
        final r = await _setRoles(
          employeeId: empId,
          roles: roles,
          defaultRole: defaultRole,
          actor: actor,
          reason: reason,
        );
        return r.when(success: (e) => _success(e.toJson()), failure: _failureOf);
      case 'set-weekly':
        final empId = _opt(rest, '--employee');
        final scheduleArg = _opt(rest, '--schedule');
        final actor = _opt(rest, '--actor') ?? 'manager';
        final reason = _opt(rest, '--reason');
        if (empId == null || scheduleArg == null) {
          return _invalid('employee set-weekly --employee <id> --schedule mon=runner,wed=bartender,thu=server [--actor manager:<id>]');
        }
        final weekly = <SgWeekday, SgEmployeeRole>{};
        for (final pair in scheduleArg.split(',')) {
          final parts = pair.split('=');
          if (parts.length != 2) {
            return _invalid('schedule entries must be day=role : got "$pair"');
          }
          final day = _parseWeekday(parts[0].trim());
          final role = SgEmployeeRole.values
              .where((x) => x.name == parts[1].trim())
              .firstOrNull;
          if (day == null) return _invalid('unknown day: ${parts[0]}');
          if (role == null) return _invalid('unknown role: ${parts[1]}');
          weekly[day] = role;
        }
        final r = await _setWeekly(
          employeeId: empId,
          weekly: weekly,
          actor: actor,
          reason: reason,
        );
        return r.when(success: (e) => _success(e.toJson()), failure: _failureOf);
      default:
        return _invalid('employee: unknown sub "$sub"');
    }
  }

  static SgWeekday? _parseWeekday(String s) {
    final low = s.toLowerCase();
    return switch (low) {
      'mon' || 'lun' || 'monday' || 'lundi' => SgWeekday.monday,
      'tue' || 'mar' || 'tuesday' || 'mardi' => SgWeekday.tuesday,
      'wed' || 'mer' || 'wednesday' || 'mercredi' => SgWeekday.wednesday,
      'thu' || 'jeu' || 'thursday' || 'jeudi' => SgWeekday.thursday,
      'fri' || 'ven' || 'friday' || 'vendredi' => SgWeekday.friday,
      'sat' || 'sam' || 'saturday' || 'samedi' => SgWeekday.saturday,
      'sun' || 'dim' || 'sunday' || 'dimanche' => SgWeekday.sunday,
      _ => int.tryParse(low) != null && int.parse(low) >= 1 && int.parse(low) <= 7
          ? SgWeekday.fromIso(int.parse(low))
          : null,
    };
  }

  // shift
  Future<Map<String, dynamic>> _dispatchShift(List<String> args) async {
    if (args.isEmpty) return _invalid('shift <sub>');
    final sub = args.first;
    final rest = args.sublist(1);
    final emp = _opt(rest, '--employee');
    switch (sub) {
      case 'clock-in':
        if (emp == null) return _invalid('shift clock-in --employee <id> [--role X --actor employee:<id> --reason "..."]');
        SgEmployeeRole? override;
        final overrideArg = _opt(rest, '--role');
        if (overrideArg != null) {
          override = SgEmployeeRole.values
              .where((x) => x.name == overrideArg)
              .firstOrNull;
          if (override == null) return _invalid('unknown role: $overrideArg');
        }
        final actor = _opt(rest, '--actor') ?? 'employee:$emp';
        final reason = _opt(rest, '--reason');
        final r = await _clockIn(
          employeeId: emp,
          roleOverride: override,
          actor: actor,
          reason: reason,
        );
        return r.when(success: (o) => _success(o.toJson()), failure: _failureOf);
      case 'clock-out':
        if (emp == null) return _invalid('shift clock-out --employee <id>');
        final actor = _opt(rest, '--actor') ?? 'employee:$emp';
        final reason = _opt(rest, '--reason');
        final r = await _clockOut(employeeId: emp, actor: actor, reason: reason);
        return r.when(success: (o) => _success(o.toJson()), failure: _failureOf);
      case 'change-role':
        final newRoleArg = _opt(rest, '--role');
        if (emp == null || newRoleArg == null) {
          return _invalid('shift change-role --employee <id> --role X [--actor employee:<id>|manager:<id> --reason "..."]');
        }
        final newRole = SgEmployeeRole.values
            .where((x) => x.name == newRoleArg)
            .firstOrNull;
        if (newRole == null) return _invalid('unknown role: $newRoleArg');
        final actor = _opt(rest, '--actor') ?? 'employee:$emp';
        final reason = _opt(rest, '--reason');
        final r = await _changeRole(
          employeeId: emp,
          newRole: newRole,
          actor: actor,
          reason: reason,
        );
        return r.when(success: (o) => _success(o.toJson()), failure: _failureOf);
      case 'segments':
        final shiftId = _opt(rest, '--shift');
        if (shiftId == null) return _invalid('shift segments --shift <id>');
        final r = await _repo.listSegments(shiftId);
        return r.when(
          success: (l) => _success({
            'count': l.length,
            'segments': l.map((s) => s.toJson()).toList(),
          }),
          failure: _failureOf,
        );
      case 'active':
        if (emp == null) return _invalid('shift active --employee <id>');
        final r = await _repo.getActiveShiftForEmployee(emp);
        return r.when(
          success: (s) =>
              _success({'is_active': s != null, 'shift': s?.toJson()}),
          failure: _failureOf,
        );
      case 'list':
        final r = await _repo.listShifts(employeeId: emp);
        return r.when(
          success: (l) => _success({
            'count': l.length,
            'shifts': l.map((s) => s.toJson()).toList(),
          }),
          failure: _failureOf,
        );
      default:
        return _invalid('shift: unknown sub "$sub"');
    }
  }

  // break
  Future<Map<String, dynamic>> _dispatchBreak(List<String> args) async {
    if (args.isEmpty) return _invalid('break <sub>');
    final sub = args.first;
    final rest = args.sublist(1);
    final emp = _opt(rest, '--employee');
    switch (sub) {
      case 'start':
        if (emp == null) return _invalid('break start --employee <id> [--type legal|lunch|quick]');
        final type = SgBreakType.values
            .where((t) => t.name == (_opt(rest, '--type') ?? 'legal'))
            .firstOrNull ?? SgBreakType.legal;
        final r = await _startBreak(employeeId: emp, type: type);
        return r.when(success: (b) => _success(b.toJson()), failure: _failureOf);
      case 'end':
        if (emp == null) return _invalid('break end --employee <id>');
        final r = await _endBreak(employeeId: emp);
        return r.when(
          success: (out) => _success({
            'break': out.breakRecord.toJson(),
            if (out.warning != null) 'warning': out.warning,
          }),
          failure: _failureOf,
        );
      case 'active':
        if (emp == null) return _invalid('break active --employee <id>');
        final r = await _repo.getActiveBreakForEmployee(emp);
        return r.when(
          success: (b) =>
              _success({'is_active': b != null, 'break': b?.toJson()}),
          failure: _failureOf,
        );
      default:
        return _invalid('break: unknown sub "$sub"');
    }
  }

  // menu
  Future<Map<String, dynamic>> _dispatchMenu(List<String> args) async {
    if (args.isEmpty) return _invalid('menu <sub>');
    final sub = args.first;
    final rest = args.sublist(1);
    switch (sub) {
      case 'list':
        final r = await _repo.listMenuCards(includeDrafts: true);
        return r.when(
          success: (l) => _success({
            'count': l.length,
            'cards': l
                .map((c) => {
                      'id': c.id,
                      'name': c.name,
                      'version': c.version,
                      'published_at': c.publishedAt?.toIso8601String(),
                      'items_count': c.items.length,
                      'categories_count': c.categories.length,
                    })
                .toList(),
          }),
          failure: _failureOf,
        );
      case 'current':
        final r = await _repo.getCurrentPublishedMenuCard();
        return r.when(
          success: (c) =>
              c == null ? _failure('no published card') : _success(c.toJson()),
          failure: _failureOf,
        );
      case 'create-sample':
        return _createSampleMenu(_opt(rest, '--name') ?? 'Carte du jour');
      case 'publish':
        final id = _opt(rest, '--card');
        if (id == null) return _invalid('menu publish --card <id>');
        final r = await _publishMenu(cardId: id);
        return r.when(success: (c) => _success(c.toJson()), failure: _failureOf);
      case 'pdf':
        final id = _opt(rest, '--card');
        if (id == null) return _invalid('menu pdf --card <id>');
        final r = await _exportPdf(cardId: id);
        return r.when(
          success: (out) async {
            final dt = _now();
            final dir =
                '${_config.pdfExportsDir}/${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
            await Directory(dir).create(recursive: true);
            final path =
                '$dir/menu_v${out.export.cardVersion}_${dt.millisecondsSinceEpoch}.pdf';
            await File(path).writeAsBytes(out.bytes, flush: true);
            final finalExport = SgPdfExport(
              id: out.export.id,
              cardId: out.export.cardId,
              cardVersion: out.export.cardVersion,
              renderedAt: out.export.renderedAt,
              filePath: path,
              byteSize: out.export.byteSize,
              engine: out.export.engine,
            );
            await _repo.storePdfExport(finalExport);
            return _success(finalExport.toJson());
          },
          failure: _failureOf,
        );
      default:
        return _invalid('menu: unknown sub "$sub"');
    }
  }

  Future<Map<String, dynamic>> _createSampleMenu(String name) async {
    final now = _now();
    final cardId = 'card-${_uuid.v4()}';
    final c1 = SgMenuCategory(id: 'cat-${_uuid.v4()}', cardId: cardId, name: 'Entrées', sortOrder: 0);
    final c2 = SgMenuCategory(id: 'cat-${_uuid.v4()}', cardId: cardId, name: 'Plats', sortOrder: 1);
    final c3 = SgMenuCategory(id: 'cat-${_uuid.v4()}', cardId: cardId, name: 'Desserts', sortOrder: 2);
    final items = [
      SgMenuItem(id: 'i-${_uuid.v4()}', cardId: cardId, categoryId: c1.id, name: 'Œuf mayo', description: 'Comme à la maison', priceCents: 600, available: true, allergens: {SgAllergen.eggs, SgAllergen.mustard}, sortOrder: 0),
      SgMenuItem(id: 'i-${_uuid.v4()}', cardId: cardId, categoryId: c1.id, name: 'Soupe à l\'oignon gratinée', description: 'Bouillon maison, croûtons, comté affiné', priceCents: 950, available: true, allergens: {SgAllergen.gluten, SgAllergen.dairy}, sortOrder: 1),
      SgMenuItem(id: 'i-${_uuid.v4()}', cardId: cardId, categoryId: c2.id, name: 'Tartare de bœuf', description: 'Bœuf coupé au couteau, condiments, frites', priceCents: 1800, available: true, allergens: {SgAllergen.mustard, SgAllergen.eggs}, sortOrder: 0),
      SgMenuItem(id: 'i-${_uuid.v4()}', cardId: cardId, categoryId: c2.id, name: 'Magret de canard', description: 'Sauce vierge au piment d\'Espelette, gratin dauphinois', priceCents: 2200, available: true, allergens: {SgAllergen.dairy}, sortOrder: 1),
      SgMenuItem(id: 'i-${_uuid.v4()}', cardId: cardId, categoryId: c2.id, name: 'Cabillaud rôti', description: 'Légumes de saison glacés', priceCents: 2400, available: true, allergens: {SgAllergen.fish}, sortOrder: 2),
      SgMenuItem(id: 'i-${_uuid.v4()}', cardId: cardId, categoryId: c3.id, name: 'Crumble pommes Golden', description: 'Crème pâtissière maison, sablé breton', priceCents: 850, available: true, allergens: {SgAllergen.gluten, SgAllergen.dairy, SgAllergen.eggs}, sortOrder: 0),
    ];
    final card = SgMenuCard(
      id: cardId,
      name: name,
      version: 0,
      createdAt: now,
      categories: [c1, c2, c3],
      items: items,
    );
    final r = await _repo.createMenuCard(card);
    return r.when(success: (c) => _success(c.toJson()), failure: _failureOf);
  }

  // shopping
  Future<Map<String, dynamic>> _dispatchShopping(List<String> args) async {
    if (args.isEmpty) return _invalid('shopping <sub>');
    final sub = args.first;
    final rest = args.sublist(1);
    switch (sub) {
      case 'lists':
        final r = await _repo.listShoppingLists();
        return r.when(
          success: (l) => _success({
            'count': l.length,
            'lists': l.map((s) => s.toJson()).toList(),
          }),
          failure: _failureOf,
        );
      case 'create-list':
        final name = _opt(rest, '--name') ?? 'Courses ${_friendlyDate(_now())}';
        final list = SgShoppingList.open(
          id: 'sl-${_uuid.v4()}',
          name: name,
          createdAt: _now(),
        );
        final r = await _repo.createShoppingList(list);
        return r.when(success: (l) => _success(l.toJson()), failure: _failureOf);
      case 'add':
        final list = _opt(rest, '--list');
        final name = _opt(rest, '--name');
        final qty = double.tryParse(_opt(rest, '--qty') ?? '1');
        final unit = _opt(rest, '--unit') ?? 'pcs';
        final urgent = rest.contains('--urgent');
        if (list == null || name == null) {
          return _invalid('shopping add --list <id> --name "..." [--qty N --unit X --urgent]');
        }
        final r = await _addShoppingItem(
          listId: list,
          name: name,
          quantity: qty ?? 1,
          unit: unit,
          urgent: urgent,
        );
        return r.when(success: (i) => _success(i.toJson()), failure: _failureOf);
      case 'items':
        final list = _opt(rest, '--list');
        final r = await _repo.listShoppingItems(listId: list);
        return r.when(
          success: (l) => _success({
            'count': l.length,
            'items': l.map((i) => i.toJson()).toList(),
          }),
          failure: _failureOf,
        );
      case 'check':
        if (rest.isEmpty) return _invalid('shopping check <item_id>');
        final r = await _checkShoppingItem(itemId: rest.first, done: true);
        return r.when(success: (i) => _success(i.toJson()), failure: _failureOf);
      case 'uncheck':
        if (rest.isEmpty) return _invalid('shopping uncheck <item_id>');
        final r = await _checkShoppingItem(itemId: rest.first, done: false);
        return r.when(success: (i) => _success(i.toJson()), failure: _failureOf);
      default:
        return _invalid('shopping: unknown sub "$sub"');
    }
  }

  // events
  Future<Map<String, dynamic>> _dispatchEvents(List<String> args) async {
    if (args.isEmpty) return _invalid('events <sub>');
    final sub = args.first;
    final rest = args.sublist(1);
    switch (sub) {
      case 'list':
        final actor = _opt(rest, '--actor');
        final action = _opt(rest, '--action');
        final target = _opt(rest, '--target-prefix');
        final limit = int.tryParse(_opt(rest, '--limit') ?? '50');
        final r = await _repo.listEvents(
          actor: actor,
          action: action,
          targetPrefix: target,
          limit: limit,
        );
        return r.when(
          success: (l) => _success({
            'count': l.length,
            'events': l.map((e) => e.toJson()).toList(),
          }),
          failure: _failureOf,
        );
      default:
        return _invalid('events: unknown sub "$sub"');
    }
  }

  // supplier
  Future<Map<String, dynamic>> _dispatchSupplier(List<String> args) async {
    if (args.isEmpty) return _invalid('supplier <sub>');
    final sub = args.first;
    final rest = args.sublist(1);
    switch (sub) {
      case 'list':
        final r = await _repo.listSuppliers();
        return r.when(
          success: (l) => _success({
            'count': l.length,
            'suppliers': l.map((s) => s.toJson()).toList(),
          }),
          failure: _failureOf,
        );
      case 'create':
        final name = _opt(rest, '--name');
        if (name == null) return _invalid('supplier create --name "..."');
        final s = SgSupplier(
          id: 'sup-${_uuid.v4()}',
          name: name,
          contact: _opt(rest, '--contact'),
        );
        final r = await _repo.createSupplier(s);
        return r.when(success: (s) => _success(s.toJson()), failure: _failureOf);
      default:
        return _invalid('supplier: unknown sub "$sub"');
    }
  }

  // question
  Future<Map<String, dynamic>> _dispatchQuestion(List<String> args) async {
    if (args.isEmpty) return _invalid('question <sub>');
    final sub = args.first;
    final rest = args.sublist(1);
    switch (sub) {
      case 'ask':
        final text = _opt(rest, '--text');
        if (text == null) return _invalid('question ask --text "..." [--scope menu,shopping]');
        final scopeStr = _opt(rest, '--scope') ?? 'menu,shopping';
        final scope = scopeStr.split(',').map((s) => s.trim()).toSet();
        final r = await _askQuestion(question: text, scope: scope);
        return r.when(success: (q) => _success(q.toJson()), failure: _failureOf);
      case 'list':
        final r = await _repo.listQuestions();
        return r.when(
          success: (l) => _success({
            'count': l.length,
            'questions': l.map((q) => q.toJson()).toList(),
          }),
          failure: _failureOf,
        );
      default:
        return _invalid('question: unknown sub "$sub"');
    }
  }

  Future<Map<String, dynamic>> _audit() async {
    final emp = await _repo.listEmployees();
    final shifts = await _repo.listShifts();
    final lists = await _repo.listShoppingLists();
    final menus = await _repo.listMenuCards(includeDrafts: true);
    final questions = await _repo.listQuestions(limit: 10);
    return {
      'employees_count': emp.valueOrNull?.length ?? 0,
      'shifts_count': shifts.valueOrNull?.length ?? 0,
      'active_shifts':
          shifts.valueOrNull?.where((s) => s.isActive).length ?? 0,
      'shopping_lists_count': lists.valueOrNull?.length ?? 0,
      'menu_cards_count': menus.valueOrNull?.length ?? 0,
      'published_cards': menus.valueOrNull?.where((m) => m.isPublished).length ?? 0,
      'questions_count': questions.valueOrNull?.length ?? 0,
      'data_dir': _config.dataDir,
      'pdf_exports_dir': _config.pdfExportsDir,
      'pdf_engine': _pdf.engineId,
      'question_engine': _question.engineId,
    };
  }

  // helpers
  Map<String, dynamic> _success(Object result) =>
      {'type': 'success', 'result': result};
  Map<String, dynamic> _failure(String message) =>
      {'type': 'failure', 'message': message};
  Map<String, dynamic> _invalid(String message) =>
      {'type': 'invalid_args', 'message': message};
  Map<String, dynamic> _failureOf(SgFailure e) => {
        'type': 'failure',
        'code': e.runtimeType.toString(),
        'message': e.message,
      };

  String? _opt(List<String> args, String name) {
    final i = args.indexOf(name);
    if (i < 0 || i + 1 >= args.length) return null;
    return args[i + 1];
  }

  String _friendlyDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  List<String> _tokenize(String cmd) {
    final out = <String>[];
    final buf = StringBuffer();
    String? quote;
    for (var i = 0; i < cmd.length; i++) {
      final c = cmd[i];
      if (quote != null) {
        if (c == quote) {
          quote = null;
          continue;
        }
        if (c == r'\' && i + 1 < cmd.length) {
          buf.write(cmd[i + 1]);
          i++;
          continue;
        }
        buf.write(c);
      } else if (c == '"' || c == "'") {
        quote = c;
      } else if (c == ' ' || c == '\t') {
        if (buf.isNotEmpty) {
          out.add(buf.toString());
          buf.clear();
        }
      } else {
        buf.write(c);
      }
    }
    if (buf.isNotEmpty) out.add(buf.toString());
    return out;
  }

  static const _helpText = [
    'health',
    'audit',
    'employee list',
    'employee create --name "..." --role manager|server|cook|bartender|dishwasher|host [--hours N --kiosk-name "..."]',
    'employee get <id>',
    'shift clock-in --employee <id>',
    'shift clock-out --employee <id>',
    'shift active --employee <id>',
    'shift list [--employee <id>]',
    'break start --employee <id> [--type legal|lunch|quick]',
    'break end --employee <id>',
    'break active --employee <id>',
    'menu list',
    'menu current',
    'menu create-sample [--name "..."]',
    'menu publish --card <id>',
    'menu pdf --card <id>',
    'shopping lists',
    'shopping create-list [--name "..."]',
    'shopping add --list <id> --name "..." [--qty N --unit X --urgent]',
    'shopping items [--list <id>]',
    'shopping check <item_id>',
    'shopping uncheck <item_id>',
    'supplier list',
    'supplier create --name "..." [--contact "..."]',
    'question ask --text "..." [--scope menu,shopping]',
    'question list',
  ];
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

Future<Map<String, dynamic>> handleCommandJson(
  BrCommandRegistry registry,
  String jsonBody,
) async {
  Map<String, dynamic> body;
  try {
    body = jsonDecode(jsonBody) as Map<String, dynamic>;
  } catch (e) {
    return {'type': 'invalid_args', 'message': 'body must be JSON: $e'};
  }
  final cmd = body['cmd'] as String?;
  if (cmd == null || cmd.trim().isEmpty) {
    return {'type': 'invalid_args', 'message': '"cmd" field required'};
  }
  return registry.dispatch(cmd);
}
