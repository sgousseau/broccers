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
        _setRoles = setRoles;

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

    return r.call;
  }

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
