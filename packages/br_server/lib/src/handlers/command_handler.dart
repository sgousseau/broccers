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
  final SetHourlyRateUseCase _setHourlyRate;
  final RecordStaffConsumptionUseCase _recordConsumption;
  final ComputeShiftCostUseCase _computeShiftCost;
  final ArchiveEmployeeUseCase _archiveEmployee;
  final RecordShiftTipUseCase _recordShiftTip;
  final GenerateMorningBriefingUseCase _generateBriefing;
  final GenerateOnboardingChecklistUseCase _generateOnboarding;
  final CheckOnboardingItemUseCase _checkOnboardingItem;
  final ParseVoiceOrderUseCase _parseVoiceOrder;
  final SendTicketToKitchenUseCase _sendTicketToKitchen;
  final StartCookingTaskUseCase _startCookingTask;
  final CompleteCookingTaskUseCase _completeCookingTask;
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
    required SetHourlyRateUseCase setHourlyRate,
    required RecordStaffConsumptionUseCase recordConsumption,
    required ComputeShiftCostUseCase computeShiftCost,
    required ArchiveEmployeeUseCase archiveEmployee,
    required RecordShiftTipUseCase recordShiftTip,
    required GenerateMorningBriefingUseCase generateBriefing,
    required GenerateOnboardingChecklistUseCase generateOnboarding,
    required CheckOnboardingItemUseCase checkOnboardingItem,
    required ParseVoiceOrderUseCase parseVoiceOrder,
    required SendTicketToKitchenUseCase sendTicketToKitchen,
    required StartCookingTaskUseCase startCookingTask,
    required CompleteCookingTaskUseCase completeCookingTask,
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
        _setHourlyRate = setHourlyRate,
        _recordConsumption = recordConsumption,
        _computeShiftCost = computeShiftCost,
        _archiveEmployee = archiveEmployee,
        _recordShiftTip = recordShiftTip,
        _generateBriefing = generateBriefing,
        _generateOnboarding = generateOnboarding,
        _checkOnboardingItem = checkOnboardingItem,
        _parseVoiceOrder = parseVoiceOrder,
        _sendTicketToKitchen = sendTicketToKitchen,
        _startCookingTask = startCookingTask,
        _completeCookingTask = completeCookingTask,
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
        case 'rate':
          return _dispatchRate(args);
        case 'consumption':
          return _dispatchConsumption(args);
        case 'cost':
          return _dispatchCost(args);
        case 'tip':
          return _dispatchTip(args);
        case 'briefing':
          return _dispatchBriefing(args);
        case 'onboarding':
          return _dispatchOnboarding(args);
        case 'ticket':
          return _dispatchTicket(args);
        case 'recipe':
          return _dispatchRecipe(args);
        case 'cooking':
          return _dispatchCooking(args);
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
      case 'archive':
        if (rest.isEmpty) return _invalid('employee archive <id> [--actor manager --reason "..."]');
        final r = await _archiveEmployee(
          employeeId: rest.first,
          actor: _opt(rest, '--actor') ?? 'manager',
          reason: _opt(rest, '--reason'),
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

  // rate (Phase B)
  Future<Map<String, dynamic>> _dispatchRate(List<String> args) async {
    if (args.isEmpty) return _invalid('rate <set|list>');
    final sub = args.first;
    final rest = args.sublist(1);
    switch (sub) {
      case 'set':
        final emp = _opt(rest, '--employee');
        final cents = int.tryParse(_opt(rest, '--cents') ?? '');
        final roleArg = _opt(rest, '--role');
        if (emp == null || cents == null) {
          return _invalid('rate set --employee <id> --cents <N> [--role X --actor manager --reason "..."]');
        }
        SgEmployeeRole? role;
        if (roleArg != null) {
          role = SgEmployeeRole.values.where((r) => r.name == roleArg).firstOrNull;
          if (role == null) return _invalid('unknown role: $roleArg');
        }
        final r = await _setHourlyRate(
          employeeId: emp,
          role: role,
          rateCents: cents,
          actor: _opt(rest, '--actor') ?? 'manager',
          reason: _opt(rest, '--reason'),
        );
        return r.when(success: (h) => _success(h.toJson()), failure: _failureOf);
      case 'list':
        final emp = _opt(rest, '--employee');
        final r = await _repo.listHourlyRates(employeeId: emp);
        return r.when(
          success: (l) => _success({
            'count': l.length,
            'rates': l.map((h) => h.toJson()).toList(),
          }),
          failure: _failureOf,
        );
      default:
        return _invalid('rate: unknown sub "$sub"');
    }
  }

  // consumption (Phase B)
  Future<Map<String, dynamic>> _dispatchConsumption(List<String> args) async {
    if (args.isEmpty) return _invalid('consumption <record|list>');
    final sub = args.first;
    final rest = args.sublist(1);
    switch (sub) {
      case 'record':
        final emp = _opt(rest, '--employee');
        final label = _opt(rest, '--label');
        final cents = int.tryParse(_opt(rest, '--cents') ?? '');
        if (emp == null || label == null || cents == null) {
          return _invalid('consumption record --employee <id> --label "..." --cents <N> [--menu-item <id> --paid]');
        }
        final r = await _recordConsumption(
          employeeId: emp,
          label: label,
          amountCents: cents,
          menuItemId: _opt(rest, '--menu-item'),
          paid: rest.contains('--paid'),
          actor: _opt(rest, '--actor') ?? 'system',
        );
        return r.when(success: (c) => _success(c.toJson()), failure: _failureOf);
      case 'list':
        final emp = _opt(rest, '--employee');
        final r = await _repo.listStaffConsumptions(employeeId: emp);
        return r.when(
          success: (l) {
            final totalCents = l.fold<int>(0, (a, c) => a + c.amountCents);
            return _success({
              'count': l.length,
              'total_cents': totalCents,
              'items': l.map((c) => c.toJson()).toList(),
            });
          },
          failure: _failureOf,
        );
      default:
        return _invalid('consumption: unknown sub "$sub"');
    }
  }

  // cost (Phase B)
  Future<Map<String, dynamic>> _dispatchCost(List<String> args) async {
    if (args.isEmpty) return _invalid('cost <shift>');
    final sub = args.first;
    final rest = args.sublist(1);
    switch (sub) {
      case 'shift':
        final shiftId = _opt(rest, '--shift');
        if (shiftId == null) return _invalid('cost shift --shift <id>');
        final r = await _computeShiftCost(shiftId: shiftId);
        return r.when(success: (b) => _success(b.toJson()), failure: _failureOf);
      default:
        return _invalid('cost: unknown sub "$sub"');
    }
  }

  // ticket (Phase E1 — voice + kitchen tickets)
  Future<Map<String, dynamic>> _dispatchTicket(List<String> args) async {
    if (args.isEmpty) return _invalid('ticket <parse|list|get|send|item-status>');
    final sub = args.first;
    final rest = args.sublist(1);
    switch (sub) {
      case 'parse':
        final text = _opt(rest, '--text');
        final tableStr = _opt(rest, '--table');
        if (text == null) {
          return _invalid('ticket parse --text "table 5 deux ricards une entrecôte saignante" [--table N]');
        }
        final r = await _parseVoiceOrder(
          textFallback: text,
          tableNumber: tableStr != null ? int.tryParse(tableStr) : null,
          createdBy: _opt(rest, '--actor') ?? 'server',
        );
        return r.when(success: (t) => _success(t.toJson()), failure: _failureOf);
      case 'list':
        final statusStr = _opt(rest, '--status');
        final status = statusStr != null
            ? SgKitchenTicketStatus.values
                .where((s) => s.name == statusStr)
                .firstOrNull
            : null;
        final r = await _repo.listKitchenTickets(status: status);
        return r.when(
          success: (l) => _success({
            'count': l.length,
            'tickets': l.map((t) => t.toJson()).toList(),
          }),
          failure: _failureOf,
        );
      case 'get':
        if (rest.isEmpty) return _invalid('ticket get <id>');
        final r = await _repo.getKitchenTicket(rest.first);
        return r.when(
          success: (t) =>
              t == null ? _failure('not found') : _success(t.toJson()),
          failure: _failureOf,
        );
      case 'send':
        if (rest.isEmpty) return _invalid('ticket send <id>');
        final r = await _sendTicketToKitchen(
          ticketId: rest.first,
          actor: _opt(rest, '--actor') ?? 'server',
        );
        return r.when(success: (t) => _success(t.toJson()), failure: _failureOf);
      case 'item-status':
        final itemId = _opt(rest, '--item');
        final statusStr = _opt(rest, '--status');
        if (itemId == null || statusStr == null) {
          return _invalid('ticket item-status --item <id> --status pending|cooking|ready|served|cancelled');
        }
        final status = SgKitchenItemStatus.values
            .where((s) => s.name == statusStr)
            .firstOrNull;
        if (status == null) return _invalid('unknown status: $statusStr');
        // load item via ticket — quick path : list all tickets and find
        final allRes = await _repo.listKitchenTickets();
        SgKitchenTicketItem? found;
        for (final t in (allRes.valueOrNull ?? const <SgKitchenTicket>[])) {
          for (final it in t.items) {
            if (it.id == itemId) {
              found = it;
              break;
            }
          }
          if (found != null) break;
        }
        if (found == null) return _failure('item not found');
        final now = _now();
        final updated = found.copyWith(
          status: status,
          startedAt: status == SgKitchenItemStatus.cooking ? now : found.startedAt,
          readyAt: status == SgKitchenItemStatus.ready ? now : found.readyAt,
          servedAt: status == SgKitchenItemStatus.served ? now : found.servedAt,
        );
        final r = await _repo.updateKitchenTicketItem(updated);
        return r.when(success: (i) => _success(i.toJson()), failure: _failureOf);
      default:
        return _invalid('ticket: unknown sub "$sub"');
    }
  }

  // recipe (Phase E2)
  Future<Map<String, dynamic>> _dispatchRecipe(List<String> args) async {
    if (args.isEmpty) return _invalid('recipe <list|get|create|create-sample>');
    final sub = args.first;
    final rest = args.sublist(1);
    switch (sub) {
      case 'list':
        final r = await _repo.listRecipes();
        return r.when(
          success: (l) => _success({
            'count': l.length,
            'recipes': l.map((r) => r.toJson()).toList(),
          }),
          failure: _failureOf,
        );
      case 'get':
        if (rest.isEmpty) return _invalid('recipe get <id>');
        final r = await _repo.getRecipe(rest.first);
        return r.when(
          success: (rec) =>
              rec == null ? _failure('not found') : _success(rec.toJson()),
          failure: _failureOf,
        );
      case 'create-sample':
        final menuItemId = _opt(rest, '--item');
        if (menuItemId == null) {
          return _invalid('recipe create-sample --item <menu_item_id>');
        }
        return _createSampleRecipe(menuItemId);
      default:
        return _invalid('recipe: unknown sub "$sub"');
    }
  }

  Future<Map<String, dynamic>> _createSampleRecipe(String menuItemId) async {
    final recipeId = 'r-${_uuid.v4()}';
    final now = _now();
    final steps = <SgRecipeStep>[
      SgRecipeStep(
        id: 'rs-${_uuid.v4()}',
        recipeId: recipeId,
        sortOrder: 0,
        type: SgRecipeStepType.prep,
        label: 'Préparer ingrédients',
        expectedDuration: const Duration(minutes: 3),
      ),
      SgRecipeStep(
        id: 'rs-${_uuid.v4()}',
        recipeId: recipeId,
        sortOrder: 1,
        type: SgRecipeStepType.cooking,
        label: 'Cuisson',
        expectedDuration: const Duration(minutes: 8),
        instructions: 'Surveiller le timer — viser saignant par défaut',
      ),
      SgRecipeStep(
        id: 'rs-${_uuid.v4()}',
        recipeId: recipeId,
        sortOrder: 2,
        type: SgRecipeStepType.plating,
        label: 'Dressage',
        expectedDuration: const Duration(minutes: 2),
      ),
    ];
    final recipe = SgRecipe(
      id: recipeId,
      menuItemId: menuItemId,
      name: 'Recette standard',
      steps: steps,
      createdAt: now,
      createdBy: 'manager',
    );
    final r = await _repo.createRecipe(recipe);
    return r.when(success: (rec) => _success(rec.toJson()), failure: _failureOf);
  }

  // cooking (Phase E2)
  Future<Map<String, dynamic>> _dispatchCooking(List<String> args) async {
    if (args.isEmpty) return _invalid('cooking <list|start|complete>');
    final sub = args.first;
    final rest = args.sublist(1);
    switch (sub) {
      case 'list':
        final statusStr = _opt(rest, '--status');
        final status = statusStr != null
            ? SgCookingTaskStatus.values
                .where((s) => s.name == statusStr)
                .firstOrNull
            : null;
        final r = await _repo.listCookingTasks(status: status);
        return r.when(
          success: (l) => _success({
            'count': l.length,
            'tasks': l.map((t) => t.toJson()).toList(),
          }),
          failure: _failureOf,
        );
      case 'start':
        if (rest.isEmpty) return _invalid('cooking start <task_id> [--by employee]');
        final r = await _startCookingTask(
          taskId: rest.first,
          assignedTo: _opt(rest, '--by'),
          actor: _opt(rest, '--actor') ?? 'cook',
        );
        return r.when(success: (t) => _success(t.toJson()), failure: _failureOf);
      case 'complete':
        if (rest.isEmpty) return _invalid('cooking complete <task_id>');
        final r = await _completeCookingTask(
          taskId: rest.first,
          actor: _opt(rest, '--actor') ?? 'cook',
        );
        return r.when(success: (t) => _success(t.toJson()), failure: _failureOf);
      default:
        return _invalid('cooking: unknown sub "$sub"');
    }
  }

  // tip (Phase D)
  Future<Map<String, dynamic>> _dispatchTip(List<String> args) async {
    if (args.isEmpty) return _invalid('tip <set>');
    final sub = args.first;
    final rest = args.sublist(1);
    switch (sub) {
      case 'set':
        final shiftId = _opt(rest, '--shift');
        final cents = int.tryParse(_opt(rest, '--cents') ?? '');
        if (shiftId == null || cents == null) {
          return _invalid('tip set --shift <id> --cents <N> [--actor X --reason "..."]');
        }
        final r = await _recordShiftTip(
          shiftId: shiftId,
          tipCents: cents,
          actor: _opt(rest, '--actor') ?? 'manager',
          reason: _opt(rest, '--reason'),
        );
        return r.when(success: (s) => _success(s.toJson()), failure: _failureOf);
      default:
        return _invalid('tip: unknown sub "$sub"');
    }
  }

  // briefing (Phase D)
  Future<Map<String, dynamic>> _dispatchBriefing(List<String> args) async {
    if (args.isEmpty) return _invalid('briefing <today|generate>');
    final sub = args.first;
    switch (sub) {
      case 'today':
      case 'generate':
        final r = await _generateBriefing(actor: 'manager');
        return r.when(success: (q) => _success(q.toJson()), failure: _failureOf);
      default:
        return _invalid('briefing: unknown sub "$sub"');
    }
  }

  // onboarding (Phase D)
  Future<Map<String, dynamic>> _dispatchOnboarding(List<String> args) async {
    if (args.isEmpty) return _invalid('onboarding <generate|list|get|check|uncheck>');
    final sub = args.first;
    final rest = args.sublist(1);
    switch (sub) {
      case 'generate':
        final emp = _opt(rest, '--employee');
        final roleStr = _opt(rest, '--role');
        if (emp == null || roleStr == null) {
          return _invalid('onboarding generate --employee <id> --role X');
        }
        final role = SgEmployeeRole.values
            .where((r) => r.name == roleStr)
            .firstOrNull;
        if (role == null) return _invalid('unknown role: $roleStr');
        final r = await _generateOnboarding(
          employeeId: emp,
          role: role,
          actor: _opt(rest, '--actor') ?? 'manager',
        );
        return r.when(success: (c) => _success(c.toJson()), failure: _failureOf);
      case 'list':
        final emp = _opt(rest, '--employee');
        final r = await _repo.listOnboardingChecklists(employeeId: emp);
        return r.when(
          success: (l) => _success({
            'count': l.length,
            'checklists': l.map((c) => c.toJson()).toList(),
          }),
          failure: _failureOf,
        );
      case 'get':
        if (rest.isEmpty) return _invalid('onboarding get <checklist_id>');
        final r = await _repo.getOnboardingChecklist(rest.first);
        return r.when(
          success: (c) => c == null
              ? _failure('not found')
              : _success(c.toJson()),
          failure: _failureOf,
        );
      case 'check':
      case 'uncheck':
        final cid = _opt(rest, '--checklist');
        final idx = int.tryParse(_opt(rest, '--item') ?? '');
        if (cid == null || idx == null) {
          return _invalid('onboarding $sub --checklist <id> --item <index> [--actor X]');
        }
        final r = await _checkOnboardingItem(
          checklistId: cid,
          itemIndex: idx,
          done: sub == 'check',
          actor: _opt(rest, '--actor') ?? 'employee',
        );
        return r.when(success: (c) => _success(c.toJson()), failure: _failureOf);
      default:
        return _invalid('onboarding: unknown sub "$sub"');
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
