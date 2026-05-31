import 'dart:convert';

import 'package:br_core/br_core.dart';
import 'package:sqlite3/sqlite3.dart';

class SqliteBrocRepository implements SgBrocRepositoryPort {
  final Database _db;

  SqliteBrocRepository._(this._db);

  factory SqliteBrocRepository.open({required String dbPath}) {
    final db = sqlite3.open(dbPath);
    db.execute('PRAGMA journal_mode = WAL;');
    db.execute('PRAGMA foreign_keys = ON;');
    _migrate(db);
    return SqliteBrocRepository._(db);
  }

  Database get db => _db;

  static void _migrate(Database db) {
    // Fresh schema (Phase A — 2026-05-31)
    db.execute('''
      CREATE TABLE IF NOT EXISTS employees (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        roles_json TEXT NOT NULL DEFAULT '[]',
        default_role TEXT,
        weekly_default_json TEXT NOT NULL DEFAULT '{}',
        contracted_hours REAL NOT NULL,
        kiosk_name TEXT NOT NULL,
        personal_pin_hash TEXT,
        kiosk_pin_hash TEXT,
        active INTEGER NOT NULL DEFAULT 1
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS shifts (
        id TEXT PRIMARY KEY,
        employee_id TEXT NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
        starts_at TEXT NOT NULL,
        ends_at TEXT,
        planned_ends_at TEXT,
        status TEXT NOT NULL
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS shift_segments (
        id TEXT PRIMARY KEY,
        shift_id TEXT NOT NULL REFERENCES shifts(id) ON DELETE CASCADE,
        role TEXT NOT NULL,
        started_at TEXT NOT NULL,
        ended_at TEXT,
        reason TEXT,
        created_by TEXT NOT NULL
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS breaks (
        id TEXT PRIMARY KEY,
        employee_id TEXT NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
        shift_id TEXT NOT NULL REFERENCES shifts(id) ON DELETE CASCADE,
        type TEXT NOT NULL,
        started_at TEXT NOT NULL,
        ended_at TEXT,
        expected_duration_ms INTEGER NOT NULL
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS event_journal (
        id TEXT PRIMARY KEY,
        at TEXT NOT NULL,
        actor TEXT NOT NULL,
        action TEXT NOT NULL,
        target TEXT,
        payload_json TEXT NOT NULL DEFAULT '{}',
        reason TEXT
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS menu_cards (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        version INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        published_at TEXT
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS menu_categories (
        id TEXT PRIMARY KEY,
        card_id TEXT NOT NULL REFERENCES menu_cards(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        sort_order INTEGER NOT NULL
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS menu_items (
        id TEXT PRIMARY KEY,
        card_id TEXT NOT NULL REFERENCES menu_cards(id) ON DELETE CASCADE,
        category_id TEXT NOT NULL,
        name TEXT NOT NULL,
        description TEXT,
        price_cents INTEGER NOT NULL,
        available INTEGER NOT NULL DEFAULT 1,
        allergens_json TEXT NOT NULL DEFAULT '[]',
        sort_order INTEGER NOT NULL DEFAULT 0
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS pdf_exports (
        id TEXT PRIMARY KEY,
        card_id TEXT NOT NULL,
        card_version INTEGER NOT NULL,
        rendered_at TEXT NOT NULL,
        file_path TEXT NOT NULL,
        byte_size INTEGER NOT NULL,
        engine TEXT NOT NULL
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS suppliers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        contact TEXT
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS shopping_lists (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        created_at TEXT NOT NULL,
        status TEXT NOT NULL
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS shopping_items (
        id TEXT PRIMARY KEY,
        list_id TEXT NOT NULL REFERENCES shopping_lists(id) ON DELETE CASCADE,
        supplier_id TEXT REFERENCES suppliers(id) ON DELETE SET NULL,
        name TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit TEXT NOT NULL,
        urgent INTEGER NOT NULL DEFAULT 0,
        done INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        checked_at TEXT
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS questions (
        id TEXT PRIMARY KEY,
        asked_at TEXT NOT NULL,
        question TEXT NOT NULL,
        context_snapshot_json TEXT NOT NULL,
        answer TEXT,
        engine TEXT NOT NULL,
        answered_at TEXT
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS kiosk_sessions (
        id TEXT PRIMARY KEY,
        device_id TEXT NOT NULL,
        device_label TEXT,
        started_at TEXT NOT NULL,
        expires_at TEXT NOT NULL,
        created_by TEXT NOT NULL
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS hourly_rates (
        id TEXT PRIMARY KEY,
        employee_id TEXT NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
        role TEXT,
        rate_cents INTEGER NOT NULL,
        valid_from TEXT NOT NULL,
        valid_to TEXT,
        source TEXT
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS staff_consumptions (
        id TEXT PRIMARY KEY,
        employee_id TEXT NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
        shift_id TEXT,
        menu_item_id TEXT,
        label TEXT NOT NULL,
        amount_cents INTEGER NOT NULL,
        consumed_at TEXT NOT NULL,
        paid INTEGER NOT NULL DEFAULT 0,
        note TEXT
      );
    ''');
    db.execute('CREATE INDEX IF NOT EXISTS idx_rates_emp ON hourly_rates(employee_id, role, valid_from);');
    db.execute('CREATE INDEX IF NOT EXISTS idx_consumptions_emp ON staff_consumptions(employee_id, consumed_at);');

    db.execute('''
      CREATE TABLE IF NOT EXISTS onboarding_checklists (
        id TEXT PRIMARY KEY,
        employee_id TEXT NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
        role TEXT NOT NULL,
        items_json TEXT NOT NULL DEFAULT '[]',
        created_at TEXT NOT NULL,
        engine TEXT NOT NULL
      );
    ''');
    db.execute('CREATE INDEX IF NOT EXISTS idx_onboarding_emp ON onboarding_checklists(employee_id, created_at DESC);');

    // === Phase E1 — Kitchen tickets ===
    db.execute('''
      CREATE TABLE IF NOT EXISTS kitchen_tickets (
        id TEXT PRIMARY KEY,
        table_number INTEGER,
        table_label TEXT,
        status TEXT NOT NULL,
        created_by TEXT NOT NULL,
        created_at TEXT NOT NULL,
        sent_to_kitchen_at TEXT,
        completed_at TEXT,
        voice_transcript TEXT
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS kitchen_ticket_items (
        id TEXT PRIMARY KEY,
        ticket_id TEXT NOT NULL REFERENCES kitchen_tickets(id) ON DELETE CASCADE,
        menu_item_id TEXT,
        label TEXT NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 1,
        modifiers_json TEXT NOT NULL DEFAULT '[]',
        status TEXT NOT NULL,
        notes TEXT,
        started_at TEXT,
        ready_at TEXT,
        served_at TEXT
      );
    ''');
    db.execute('CREATE INDEX IF NOT EXISTS idx_tickets_status ON kitchen_tickets(status, created_at DESC);');
    db.execute('CREATE INDEX IF NOT EXISTS idx_ticket_items_ticket ON kitchen_ticket_items(ticket_id);');

    // === Phase E2 — Recipes + cooking tasks ===
    db.execute('''
      CREATE TABLE IF NOT EXISTS recipes (
        id TEXT PRIMARY KEY,
        menu_item_id TEXT NOT NULL,
        name TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        created_by TEXT
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS recipe_steps (
        id TEXT PRIMARY KEY,
        recipe_id TEXT NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
        sort_order INTEGER NOT NULL,
        type TEXT NOT NULL,
        label TEXT NOT NULL,
        expected_duration_ms INTEGER NOT NULL,
        instructions TEXT
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS cooking_tasks (
        id TEXT PRIMARY KEY,
        ticket_item_id TEXT NOT NULL REFERENCES kitchen_ticket_items(id) ON DELETE CASCADE,
        recipe_step_id TEXT,
        label TEXT NOT NULL,
        status TEXT NOT NULL,
        started_at TEXT,
        completed_at TEXT,
        expected_duration_ms INTEGER NOT NULL,
        assigned_to TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0
      );
    ''');
    db.execute('CREATE INDEX IF NOT EXISTS idx_recipes_menu ON recipes(menu_item_id);');
    db.execute('CREATE INDEX IF NOT EXISTS idx_recipe_steps_recipe ON recipe_steps(recipe_id, sort_order);');
    db.execute('CREATE INDEX IF NOT EXISTS idx_cooking_tasks_item ON cooking_tasks(ticket_item_id, sort_order);');
    db.execute('CREATE INDEX IF NOT EXISTS idx_cooking_tasks_status ON cooking_tasks(status, started_at);');

    // === Phase A migrations from v0.1 → v0.2 (idempotent) ===
    final empCols = db
        .select('PRAGMA table_info(employees)')
        .map((r) => r['name'] as String)
        .toSet();
    if (empCols.contains('role') && !empCols.contains('roles_json')) {
      // Backfill from old single `role` column
      db.execute(
          'ALTER TABLE employees ADD COLUMN roles_json TEXT NOT NULL DEFAULT \'[]\'');
      db.execute('ALTER TABLE employees ADD COLUMN default_role TEXT');
      db.execute(
          'ALTER TABLE employees ADD COLUMN weekly_default_json TEXT NOT NULL DEFAULT \'{}\'');
      db.execute(
          "UPDATE employees SET roles_json = json_array(role), default_role = role WHERE roles_json = '[]'");
      db.execute('ALTER TABLE employees DROP COLUMN role');
    }

    final shiftCols = db
        .select('PRAGMA table_info(shifts)')
        .map((r) => r['name'] as String)
        .toSet();
    if (shiftCols.contains('position')) {
      // Position dropped — segments now hold the role
      db.execute('ALTER TABLE shifts DROP COLUMN position');
    }
    // Phase D : add tip_cents to shifts
    if (!shiftCols.contains('tip_cents')) {
      db.execute('ALTER TABLE shifts ADD COLUMN tip_cents INTEGER NOT NULL DEFAULT 0');
    }

    db.execute('CREATE INDEX IF NOT EXISTS idx_shifts_employee ON shifts(employee_id, status);');
    db.execute('CREATE INDEX IF NOT EXISTS idx_segments_shift ON shift_segments(shift_id, ended_at);');
    db.execute('CREATE INDEX IF NOT EXISTS idx_breaks_employee ON breaks(employee_id, ended_at);');
    db.execute('CREATE INDEX IF NOT EXISTS idx_menu_items_card ON menu_items(card_id, category_id, sort_order);');
    db.execute('CREATE INDEX IF NOT EXISTS idx_shopping_items_list ON shopping_items(list_id, done);');
    db.execute('CREATE INDEX IF NOT EXISTS idx_kiosk_device ON kiosk_sessions(device_id, expires_at);');
    db.execute('CREATE INDEX IF NOT EXISTS idx_events_at ON event_journal(at);');
    db.execute('CREATE INDEX IF NOT EXISTS idx_events_actor ON event_journal(actor);');
    db.execute('CREATE INDEX IF NOT EXISTS idx_events_target ON event_journal(target);');
  }

  Result<T, SgFailure> _wrap<T>(T Function() fn) {
    try {
      return Success(fn());
    } on SqliteException catch (e) {
      return Failure(SgDatabaseFailure('sqlite: ${e.message}', cause: e));
    }
  }

  // ============== Employees ==============
  @override
  Future<Result<SgEmployee, SgFailure>> createEmployee(SgEmployee e) async =>
      _wrap(() {
        _db.execute(
          'INSERT INTO employees(id, name, roles_json, default_role, weekly_default_json, contracted_hours, kiosk_name, personal_pin_hash, kiosk_pin_hash, active) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            e.id,
            e.name,
            jsonEncode(e.roles.map((r) => r.name).toList()),
            e.defaultRole?.name,
            jsonEncode({
              for (final entry in e.weeklyDefault.entries)
                entry.key.isoDay.toString(): entry.value.name,
            }),
            e.contractedHours,
            e.kioskName,
            e.personalPinHash,
            e.kioskPinHash,
            e.active ? 1 : 0,
          ],
        );
        return e;
      });

  @override
  Future<Result<SgEmployee, SgFailure>> updateEmployee(SgEmployee e) async =>
      _wrap(() {
        _db.execute(
          'UPDATE employees SET name = ?, roles_json = ?, default_role = ?, weekly_default_json = ?, contracted_hours = ?, kiosk_name = ?, personal_pin_hash = ?, kiosk_pin_hash = ?, active = ? WHERE id = ?',
          [
            e.name,
            jsonEncode(e.roles.map((r) => r.name).toList()),
            e.defaultRole?.name,
            jsonEncode({
              for (final entry in e.weeklyDefault.entries)
                entry.key.isoDay.toString(): entry.value.name,
            }),
            e.contractedHours,
            e.kioskName,
            e.personalPinHash,
            e.kioskPinHash,
            e.active ? 1 : 0,
            e.id,
          ],
        );
        return e;
      });

  @override
  Future<Result<SgEmployee?, SgFailure>> getEmployee(String id) async => _wrap(() {
        final rs = _db.select('SELECT * FROM employees WHERE id = ?', [id]);
        return rs.isEmpty ? null : _rowToEmployee(rs.first);
      });

  @override
  Future<Result<SgEmployee?, SgFailure>> getEmployeeByKioskName(String kioskName) async => _wrap(() {
        final rs = _db.select(
          'SELECT * FROM employees WHERE kiosk_name = ? AND active = 1',
          [kioskName],
        );
        return rs.isEmpty ? null : _rowToEmployee(rs.first);
      });

  @override
  Future<Result<List<SgEmployee>, SgFailure>> listEmployees({bool activeOnly = true}) async => _wrap(() {
        final rs = activeOnly
            ? _db.select('SELECT * FROM employees WHERE active = 1 ORDER BY name')
            : _db.select('SELECT * FROM employees ORDER BY name');
        return rs.map(_rowToEmployee).toList();
      });

  SgEmployee _rowToEmployee(Row r) {
    final rolesJson = jsonDecode(r['roles_json'] as String) as List<dynamic>;
    final weeklyJson =
        jsonDecode(r['weekly_default_json'] as String) as Map<String, dynamic>;
    return SgEmployee(
      id: r['id'] as String,
      name: r['name'] as String,
      roles: rolesJson
          .map((x) => SgEmployeeRole.fromName(x as String))
          .toSet(),
      defaultRole: r['default_role'] != null
          ? SgEmployeeRole.fromName(r['default_role'] as String)
          : null,
      weeklyDefault: weeklyJson.map((k, v) => MapEntry(
            SgWeekday.fromIso(int.parse(k)),
            SgEmployeeRole.fromName(v as String),
          )),
      contractedHours: (r['contracted_hours'] as num).toDouble(),
      kioskName: r['kiosk_name'] as String,
      personalPinHash: r['personal_pin_hash'] as String?,
      kioskPinHash: r['kiosk_pin_hash'] as String?,
      active: (r['active'] as int) == 1,
    );
  }

  // ============== Shifts ==============
  @override
  Future<Result<SgShift, SgFailure>> createShift(SgShift s) async => _wrap(() {
        _db.execute(
          'INSERT INTO shifts(id, employee_id, starts_at, ends_at, planned_ends_at, status, tip_cents) VALUES (?, ?, ?, ?, ?, ?, ?)',
          [
            s.id,
            s.employeeId,
            s.startsAt.toIso8601String(),
            s.endsAt?.toIso8601String(),
            s.plannedEndsAt?.toIso8601String(),
            s.status.name,
            s.tipCents,
          ],
        );
        return s;
      });

  @override
  Future<Result<SgShift, SgFailure>> updateShift(SgShift s) async => _wrap(() {
        _db.execute(
          'UPDATE shifts SET ends_at = ?, planned_ends_at = ?, status = ?, tip_cents = ? WHERE id = ?',
          [
            s.endsAt?.toIso8601String(),
            s.plannedEndsAt?.toIso8601String(),
            s.status.name,
            s.tipCents,
            s.id,
          ],
        );
        return s;
      });

  @override
  Future<Result<SgShift?, SgFailure>> getShift(String id) async => _wrap(() {
        final rs = _db.select('SELECT * FROM shifts WHERE id = ?', [id]);
        return rs.isEmpty ? null : _rowToShift(rs.first);
      });

  @override
  Future<Result<SgShift?, SgFailure>> getActiveShiftForEmployee(String employeeId) async => _wrap(() {
        final rs = _db.select(
          "SELECT * FROM shifts WHERE employee_id = ? AND status = 'active' ORDER BY starts_at DESC LIMIT 1",
          [employeeId],
        );
        return rs.isEmpty ? null : _rowToShift(rs.first);
      });

  @override
  Future<Result<List<SgShift>, SgFailure>> listShifts({String? employeeId, DateTime? from, DateTime? to}) async => _wrap(() {
        var sql = 'SELECT * FROM shifts WHERE 1=1';
        final params = <Object>[];
        if (employeeId != null) {
          sql += ' AND employee_id = ?';
          params.add(employeeId);
        }
        if (from != null) {
          sql += ' AND starts_at >= ?';
          params.add(from.toIso8601String());
        }
        if (to != null) {
          sql += ' AND starts_at <= ?';
          params.add(to.toIso8601String());
        }
        sql += ' ORDER BY starts_at DESC';
        return _db.select(sql, params).map(_rowToShift).toList();
      });

  SgShift _rowToShift(Row r) => SgShift(
        id: r['id'] as String,
        employeeId: r['employee_id'] as String,
        startsAt: DateTime.parse(r['starts_at'] as String),
        endsAt: r['ends_at'] != null ? DateTime.parse(r['ends_at'] as String) : null,
        plannedEndsAt: r['planned_ends_at'] != null
            ? DateTime.parse(r['planned_ends_at'] as String)
            : null,
        position: SgShiftPosition.service,
        status: SgShiftStatus.values.firstWhere((s) => s.name == r['status']),
        tipCents: (r['tip_cents'] as int?) ?? 0,
      );

  // ============== Shift segments (Phase A) ==============
  @override
  Future<Result<SgShiftSegment, SgFailure>> createSegment(SgShiftSegment seg) async => _wrap(() {
        _db.execute(
          'INSERT INTO shift_segments(id, shift_id, role, started_at, ended_at, reason, created_by) VALUES (?, ?, ?, ?, ?, ?, ?)',
          [
            seg.id,
            seg.shiftId,
            seg.role.name,
            seg.startedAt.toIso8601String(),
            seg.endedAt?.toIso8601String(),
            seg.reason,
            seg.createdBy,
          ],
        );
        return seg;
      });

  @override
  Future<Result<SgShiftSegment, SgFailure>> updateSegment(SgShiftSegment seg) async => _wrap(() {
        _db.execute(
          'UPDATE shift_segments SET ended_at = ?, reason = ? WHERE id = ?',
          [seg.endedAt?.toIso8601String(), seg.reason, seg.id],
        );
        return seg;
      });

  @override
  Future<Result<SgShiftSegment?, SgFailure>> getActiveSegmentForShift(String shiftId) async => _wrap(() {
        final rs = _db.select(
          'SELECT * FROM shift_segments WHERE shift_id = ? AND ended_at IS NULL ORDER BY started_at DESC LIMIT 1',
          [shiftId],
        );
        return rs.isEmpty ? null : _rowToSegment(rs.first);
      });

  @override
  Future<Result<List<SgShiftSegment>, SgFailure>> listSegments(String shiftId) async => _wrap(() {
        return _db.select(
          'SELECT * FROM shift_segments WHERE shift_id = ? ORDER BY started_at ASC',
          [shiftId],
        ).map(_rowToSegment).toList();
      });

  SgShiftSegment _rowToSegment(Row r) => SgShiftSegment(
        id: r['id'] as String,
        shiftId: r['shift_id'] as String,
        role: SgEmployeeRole.fromName(r['role'] as String),
        startedAt: DateTime.parse(r['started_at'] as String),
        endedAt: r['ended_at'] != null
            ? DateTime.parse(r['ended_at'] as String)
            : null,
        reason: r['reason'] as String?,
        createdBy: r['created_by'] as String,
      );

  // ============== Breaks ==============
  @override
  Future<Result<SgBreak, SgFailure>> createBreak(SgBreak b) async => _wrap(() {
        _db.execute(
          'INSERT INTO breaks(id, employee_id, shift_id, type, started_at, ended_at, expected_duration_ms) VALUES (?, ?, ?, ?, ?, ?, ?)',
          [b.id, b.employeeId, b.shiftId, b.type.name, b.startedAt.toIso8601String(), b.endedAt?.toIso8601String(), b.expectedDuration.inMilliseconds],
        );
        return b;
      });

  @override
  Future<Result<SgBreak, SgFailure>> updateBreak(SgBreak b) async => _wrap(() {
        _db.execute(
          'UPDATE breaks SET ended_at = ?, expected_duration_ms = ? WHERE id = ?',
          [b.endedAt?.toIso8601String(), b.expectedDuration.inMilliseconds, b.id],
        );
        return b;
      });

  @override
  Future<Result<SgBreak?, SgFailure>> getActiveBreakForEmployee(String employeeId) async => _wrap(() {
        final rs = _db.select(
          'SELECT * FROM breaks WHERE employee_id = ? AND ended_at IS NULL ORDER BY started_at DESC LIMIT 1',
          [employeeId],
        );
        return rs.isEmpty ? null : _rowToBreak(rs.first);
      });

  @override
  Future<Result<List<SgBreak>, SgFailure>> listBreaksForShift(String shiftId) async => _wrap(() {
        return _db.select(
          'SELECT * FROM breaks WHERE shift_id = ? ORDER BY started_at ASC',
          [shiftId],
        ).map(_rowToBreak).toList();
      });

  SgBreak _rowToBreak(Row r) => SgBreak(
        id: r['id'] as String,
        employeeId: r['employee_id'] as String,
        shiftId: r['shift_id'] as String,
        type: SgBreakType.values.firstWhere((t) => t.name == r['type']),
        startedAt: DateTime.parse(r['started_at'] as String),
        endedAt: r['ended_at'] != null ? DateTime.parse(r['ended_at'] as String) : null,
        expectedDuration: Duration(milliseconds: r['expected_duration_ms'] as int),
      );

  // ============== Menu cards ==============
  @override
  Future<Result<SgMenuCard, SgFailure>> createMenuCard(SgMenuCard card) async => _wrap(() {
        _db.execute('BEGIN TRANSACTION');
        try {
          _db.execute(
            'INSERT INTO menu_cards(id, name, version, created_at, published_at) VALUES (?, ?, ?, ?, ?)',
            [card.id, card.name, card.version, card.createdAt.toIso8601String(), card.publishedAt?.toIso8601String()],
          );
          for (final c in card.categories) {
            _db.execute(
              'INSERT INTO menu_categories(id, card_id, name, sort_order) VALUES (?, ?, ?, ?)',
              [c.id, c.cardId, c.name, c.sortOrder],
            );
          }
          for (final it in card.items) {
            _db.execute(
              'INSERT INTO menu_items(id, card_id, category_id, name, description, price_cents, available, allergens_json, sort_order) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
              [it.id, it.cardId, it.categoryId, it.name, it.description, it.priceCents, it.available ? 1 : 0, jsonEncode(it.allergens.map((a) => a.name).toList()), it.sortOrder],
            );
          }
          _db.execute('COMMIT');
          return card;
        } catch (e) {
          _db.execute('ROLLBACK');
          rethrow;
        }
      });

  @override
  Future<Result<SgMenuCard, SgFailure>> updateMenuCard(SgMenuCard card) async => _wrap(() {
        _db.execute(
          'UPDATE menu_cards SET name = ?, version = ?, published_at = ? WHERE id = ?',
          [card.name, card.version, card.publishedAt?.toIso8601String(), card.id],
        );
        return card;
      });

  @override
  Future<Result<SgMenuCard?, SgFailure>> getMenuCard(String id) async => _wrap(() {
        final rs = _db.select('SELECT * FROM menu_cards WHERE id = ?', [id]);
        if (rs.isEmpty) return null;
        return _hydrateMenuCard(rs.first);
      });

  @override
  Future<Result<SgMenuCard?, SgFailure>> getCurrentPublishedMenuCard() async => _wrap(() {
        final rs = _db.select(
          'SELECT * FROM menu_cards WHERE published_at IS NOT NULL ORDER BY version DESC LIMIT 1',
        );
        if (rs.isEmpty) return null;
        return _hydrateMenuCard(rs.first);
      });

  @override
  Future<Result<List<SgMenuCard>, SgFailure>> listMenuCards({bool includeDrafts = false}) async => _wrap(() {
        final rs = includeDrafts
            ? _db.select('SELECT * FROM menu_cards ORDER BY version DESC')
            : _db.select('SELECT * FROM menu_cards WHERE published_at IS NOT NULL ORDER BY version DESC');
        return rs.map(_hydrateMenuCard).toList();
      });

  @override
  Future<Result<int, SgFailure>> nextMenuCardVersion() async => _wrap(() {
        final rs = _db.select('SELECT COALESCE(MAX(version), 0) AS v FROM menu_cards');
        return ((rs.first['v'] as int?) ?? 0) + 1;
      });

  SgMenuCard _hydrateMenuCard(Row r) {
    final cardId = r['id'] as String;
    final cats = _db.select(
      'SELECT * FROM menu_categories WHERE card_id = ? ORDER BY sort_order',
      [cardId],
    ).map((c) => SgMenuCategory(
      id: c['id'] as String,
      cardId: c['card_id'] as String,
      name: c['name'] as String,
      sortOrder: c['sort_order'] as int,
    )).toList();
    final items = _db.select(
      'SELECT * FROM menu_items WHERE card_id = ? ORDER BY sort_order',
      [cardId],
    ).map((i) {
      final allergensList =
          (jsonDecode(i['allergens_json'] as String) as List<dynamic>)
              .map((a) => SgAllergen.values
                  .firstWhere((al) => al.name == a as String))
              .toSet();
      return SgMenuItem(
        id: i['id'] as String,
        cardId: i['card_id'] as String,
        categoryId: i['category_id'] as String,
        name: i['name'] as String,
        description: i['description'] as String?,
        priceCents: i['price_cents'] as int,
        available: (i['available'] as int) == 1,
        allergens: allergensList,
        sortOrder: i['sort_order'] as int,
      );
    }).toList();
    return SgMenuCard(
      id: cardId,
      name: r['name'] as String,
      version: r['version'] as int,
      createdAt: DateTime.parse(r['created_at'] as String),
      publishedAt: r['published_at'] != null
          ? DateTime.parse(r['published_at'] as String)
          : null,
      categories: cats,
      items: items,
    );
  }

  // ============== PDF exports ==============
  @override
  Future<Result<void, SgFailure>> storePdfExport(SgPdfExport export) async => _wrap(() {
        _db.execute(
          'INSERT INTO pdf_exports(id, card_id, card_version, rendered_at, file_path, byte_size, engine) VALUES (?, ?, ?, ?, ?, ?, ?)',
          [export.id, export.cardId, export.cardVersion, export.renderedAt.toIso8601String(), export.filePath, export.byteSize, export.engine],
        );
      });

  @override
  Future<Result<List<SgPdfExport>, SgFailure>> listPdfExports({String? cardId}) async => _wrap(() {
        final rs = cardId == null
            ? _db.select('SELECT * FROM pdf_exports ORDER BY rendered_at DESC')
            : _db.select(
                'SELECT * FROM pdf_exports WHERE card_id = ? ORDER BY rendered_at DESC',
                [cardId],
              );
        return rs.map((r) => SgPdfExport(
              id: r['id'] as String,
              cardId: r['card_id'] as String,
              cardVersion: r['card_version'] as int,
              renderedAt: DateTime.parse(r['rendered_at'] as String),
              filePath: r['file_path'] as String,
              byteSize: r['byte_size'] as int,
              engine: r['engine'] as String,
            )).toList();
      });

  // ============== Shopping ==============
  @override
  Future<Result<SgShoppingList, SgFailure>> createShoppingList(SgShoppingList l) async => _wrap(() {
        _db.execute(
          'INSERT INTO shopping_lists(id, name, created_at, status) VALUES (?, ?, ?, ?)',
          [l.id, l.name, l.createdAt.toIso8601String(), l.status.name],
        );
        return l;
      });

  @override
  Future<Result<SgShoppingList, SgFailure>> updateShoppingList(SgShoppingList l) async => _wrap(() {
        _db.execute(
          'UPDATE shopping_lists SET name = ?, status = ? WHERE id = ?',
          [l.name, l.status.name, l.id],
        );
        return l;
      });

  @override
  Future<Result<SgShoppingList?, SgFailure>> getShoppingList(String id) async => _wrap(() {
        final rs = _db.select('SELECT * FROM shopping_lists WHERE id = ?', [id]);
        if (rs.isEmpty) return null;
        return SgShoppingList(
          id: rs.first['id'] as String,
          name: rs.first['name'] as String,
          createdAt: DateTime.parse(rs.first['created_at'] as String),
          status: SgShoppingListStatus.values.firstWhere((s) => s.name == rs.first['status']),
        );
      });

  @override
  Future<Result<List<SgShoppingList>, SgFailure>> listShoppingLists({bool openOnly = false}) async => _wrap(() {
        final rs = openOnly
            ? _db.select("SELECT * FROM shopping_lists WHERE status = 'open' ORDER BY created_at DESC")
            : _db.select('SELECT * FROM shopping_lists ORDER BY created_at DESC');
        return rs.map((r) => SgShoppingList(
              id: r['id'] as String,
              name: r['name'] as String,
              createdAt: DateTime.parse(r['created_at'] as String),
              status: SgShoppingListStatus.values.firstWhere((s) => s.name == r['status']),
            )).toList();
      });

  @override
  Future<Result<SgShoppingItem, SgFailure>> createShoppingItem(SgShoppingItem item) async => _wrap(() {
        _db.execute(
          'INSERT INTO shopping_items(id, list_id, supplier_id, name, quantity, unit, urgent, done, created_at, checked_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [item.id, item.listId, item.supplierId, item.name, item.quantity, item.unit, item.urgent ? 1 : 0, item.done ? 1 : 0, item.createdAt.toIso8601String(), item.checkedAt?.toIso8601String()],
        );
        return item;
      });

  @override
  Future<Result<SgShoppingItem, SgFailure>> updateShoppingItem(SgShoppingItem item) async => _wrap(() {
        _db.execute(
          'UPDATE shopping_items SET supplier_id = ?, name = ?, quantity = ?, unit = ?, urgent = ?, done = ?, checked_at = ? WHERE id = ?',
          [item.supplierId, item.name, item.quantity, item.unit, item.urgent ? 1 : 0, item.done ? 1 : 0, item.checkedAt?.toIso8601String(), item.id],
        );
        return item;
      });

  @override
  Future<Result<SgShoppingItem?, SgFailure>> getShoppingItem(String id) async => _wrap(() {
        final rs = _db.select('SELECT * FROM shopping_items WHERE id = ?', [id]);
        return rs.isEmpty ? null : _rowToShoppingItem(rs.first);
      });

  @override
  Future<Result<List<SgShoppingItem>, SgFailure>> listShoppingItems({String? listId, bool? done}) async => _wrap(() {
        var sql = 'SELECT * FROM shopping_items WHERE 1=1';
        final params = <Object>[];
        if (listId != null) {
          sql += ' AND list_id = ?';
          params.add(listId);
        }
        if (done != null) {
          sql += ' AND done = ?';
          params.add(done ? 1 : 0);
        }
        sql += ' ORDER BY urgent DESC, done ASC, created_at ASC';
        return _db.select(sql, params).map(_rowToShoppingItem).toList();
      });

  SgShoppingItem _rowToShoppingItem(Row r) => SgShoppingItem(
        id: r['id'] as String,
        listId: r['list_id'] as String,
        supplierId: r['supplier_id'] as String?,
        name: r['name'] as String,
        quantity: (r['quantity'] as num).toDouble(),
        unit: r['unit'] as String,
        urgent: (r['urgent'] as int) == 1,
        done: (r['done'] as int) == 1,
        createdAt: DateTime.parse(r['created_at'] as String),
        checkedAt: r['checked_at'] != null ? DateTime.parse(r['checked_at'] as String) : null,
      );

  // ============== Suppliers ==============
  @override
  Future<Result<SgSupplier, SgFailure>> createSupplier(SgSupplier s) async => _wrap(() {
        _db.execute('INSERT INTO suppliers(id, name, contact) VALUES (?, ?, ?)', [s.id, s.name, s.contact]);
        return s;
      });

  @override
  Future<Result<List<SgSupplier>, SgFailure>> listSuppliers() async => _wrap(() {
        return _db.select('SELECT * FROM suppliers ORDER BY name').map((r) => SgSupplier(
              id: r['id'] as String,
              name: r['name'] as String,
              contact: r['contact'] as String?,
            )).toList();
      });

  // ============== Questions ==============
  @override
  Future<Result<void, SgFailure>> storeQuestion(SgQuestion q) async => _wrap(() {
        _db.execute(
          'INSERT OR REPLACE INTO questions(id, asked_at, question, context_snapshot_json, answer, engine, answered_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
          [q.id, q.askedAt.toIso8601String(), q.question, jsonEncode(q.contextSnapshot), q.answer, q.engine, q.answeredAt?.toIso8601String()],
        );
      });

  @override
  Future<Result<List<SgQuestion>, SgFailure>> listQuestions({int? limit}) async => _wrap(() {
        final lim = limit ?? 50;
        return _db.select('SELECT * FROM questions ORDER BY asked_at DESC LIMIT ?', [lim])
            .map((r) => SgQuestion(
                  id: r['id'] as String,
                  askedAt: DateTime.parse(r['asked_at'] as String),
                  question: r['question'] as String,
                  contextSnapshot: jsonDecode(r['context_snapshot_json'] as String)
                      as Map<String, dynamic>,
                  answer: r['answer'] as String?,
                  engine: r['engine'] as String,
                  answeredAt: r['answered_at'] != null
                      ? DateTime.parse(r['answered_at'] as String)
                      : null,
                ))
            .toList();
      });

  // ============== Kiosk sessions ==============
  @override
  Future<Result<SgKioskSession, SgFailure>> createKioskSession(SgKioskSession s) async => _wrap(() {
        _db.execute(
          'INSERT INTO kiosk_sessions(id, device_id, device_label, started_at, expires_at, created_by) VALUES (?, ?, ?, ?, ?, ?)',
          [s.id, s.deviceId, s.deviceLabel, s.startedAt.toIso8601String(), s.expiresAt.toIso8601String(), s.createdBy],
        );
        return s;
      });

  @override
  Future<Result<SgKioskSession?, SgFailure>> getActiveKioskSession(String deviceId) async => _wrap(() {
        final rs = _db.select(
          'SELECT * FROM kiosk_sessions WHERE device_id = ? AND expires_at > ? ORDER BY started_at DESC LIMIT 1',
          [deviceId, DateTime.now().toUtc().toIso8601String()],
        );
        if (rs.isEmpty) return null;
        return SgKioskSession(
          id: rs.first['id'] as String,
          deviceId: rs.first['device_id'] as String,
          deviceLabel: rs.first['device_label'] as String?,
          startedAt: DateTime.parse(rs.first['started_at'] as String),
          expiresAt: DateTime.parse(rs.first['expires_at'] as String),
          createdBy: rs.first['created_by'] as String,
        );
      });

  // ============== Event journal (Phase A) ==============
  @override
  Future<Result<void, SgFailure>> logEvent(SgEventJournalEntry e) async => _wrap(() {
        _db.execute(
          'INSERT INTO event_journal(id, at, actor, action, target, payload_json, reason) VALUES (?, ?, ?, ?, ?, ?, ?)',
          [
            e.id,
            e.at.toIso8601String(),
            e.actor,
            e.action,
            e.target,
            jsonEncode(e.payload),
            e.reason,
          ],
        );
      });

  @override
  Future<Result<List<SgEventJournalEntry>, SgFailure>> listEvents({
    String? actor,
    String? action,
    String? targetPrefix,
    DateTime? from,
    DateTime? to,
    int? limit,
  }) async =>
      _wrap(() {
        var sql = 'SELECT * FROM event_journal WHERE 1=1';
        final params = <Object>[];
        if (actor != null) {
          sql += ' AND actor = ?';
          params.add(actor);
        }
        if (action != null) {
          sql += ' AND action = ?';
          params.add(action);
        }
        if (targetPrefix != null) {
          sql += ' AND target LIKE ?';
          params.add('$targetPrefix%');
        }
        if (from != null) {
          sql += ' AND at >= ?';
          params.add(from.toIso8601String());
        }
        if (to != null) {
          sql += ' AND at <= ?';
          params.add(to.toIso8601String());
        }
        sql += ' ORDER BY at DESC LIMIT ?';
        params.add(limit ?? 200);
        return _db.select(sql, params).map((r) => SgEventJournalEntry(
              id: r['id'] as String,
              at: DateTime.parse(r['at'] as String),
              actor: r['actor'] as String,
              action: r['action'] as String,
              target: r['target'] as String?,
              payload: jsonDecode(r['payload_json'] as String)
                  as Map<String, dynamic>,
              reason: r['reason'] as String?,
            )).toList();
      });

  // ============== Hourly rates (Phase B) ==============
  @override
  Future<Result<SgHourlyRate, SgFailure>> createHourlyRate(SgHourlyRate r) async => _wrap(() {
        _db.execute(
          'INSERT INTO hourly_rates(id, employee_id, role, rate_cents, valid_from, valid_to, source) VALUES (?, ?, ?, ?, ?, ?, ?)',
          [
            r.id,
            r.employeeId,
            r.role?.name,
            r.rateCents,
            r.validFrom.toIso8601String(),
            r.validTo?.toIso8601String(),
            r.source,
          ],
        );
        return r;
      });

  @override
  Future<Result<SgHourlyRate, SgFailure>> updateHourlyRate(SgHourlyRate r) async => _wrap(() {
        _db.execute(
          'UPDATE hourly_rates SET role = ?, rate_cents = ?, valid_from = ?, valid_to = ?, source = ? WHERE id = ?',
          [
            r.role?.name,
            r.rateCents,
            r.validFrom.toIso8601String(),
            r.validTo?.toIso8601String(),
            r.source,
            r.id,
          ],
        );
        return r;
      });

  @override
  Future<Result<SgHourlyRate?, SgFailure>> getActiveHourlyRate({
    required String employeeId,
    SgEmployeeRole? role,
    required DateTime at,
  }) async =>
      _wrap(() {
        final atStr = at.toIso8601String();
        final rs = role == null
            ? _db.select(
                'SELECT * FROM hourly_rates WHERE employee_id = ? AND role IS NULL AND valid_from <= ? AND (valid_to IS NULL OR valid_to > ?) ORDER BY valid_from DESC LIMIT 1',
                [employeeId, atStr, atStr],
              )
            : _db.select(
                'SELECT * FROM hourly_rates WHERE employee_id = ? AND role = ? AND valid_from <= ? AND (valid_to IS NULL OR valid_to > ?) ORDER BY valid_from DESC LIMIT 1',
                [employeeId, role.name, atStr, atStr],
              );
        return rs.isEmpty ? null : _rowToRate(rs.first);
      });

  @override
  Future<Result<List<SgHourlyRate>, SgFailure>> listHourlyRates({String? employeeId}) async => _wrap(() {
        final rs = employeeId == null
            ? _db.select('SELECT * FROM hourly_rates ORDER BY employee_id, valid_from DESC')
            : _db.select(
                'SELECT * FROM hourly_rates WHERE employee_id = ? ORDER BY valid_from DESC',
                [employeeId],
              );
        return rs.map(_rowToRate).toList();
      });

  SgHourlyRate _rowToRate(Row r) => SgHourlyRate(
        id: r['id'] as String,
        employeeId: r['employee_id'] as String,
        role: r['role'] != null
            ? SgEmployeeRole.fromName(r['role'] as String)
            : null,
        rateCents: r['rate_cents'] as int,
        validFrom: DateTime.parse(r['valid_from'] as String),
        validTo: r['valid_to'] != null
            ? DateTime.parse(r['valid_to'] as String)
            : null,
        source: r['source'] as String?,
      );

  // ============== Staff consumption (Phase B) ==============
  @override
  Future<Result<SgStaffConsumption, SgFailure>> createStaffConsumption(SgStaffConsumption c) async => _wrap(() {
        _db.execute(
          'INSERT INTO staff_consumptions(id, employee_id, shift_id, menu_item_id, label, amount_cents, consumed_at, paid, note) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            c.id,
            c.employeeId,
            c.shiftId,
            c.menuItemId,
            c.label,
            c.amountCents,
            c.consumedAt.toIso8601String(),
            c.paid ? 1 : 0,
            c.note,
          ],
        );
        return c;
      });

  @override
  Future<Result<SgStaffConsumption, SgFailure>> updateStaffConsumption(SgStaffConsumption c) async => _wrap(() {
        _db.execute(
          'UPDATE staff_consumptions SET shift_id = ?, menu_item_id = ?, label = ?, amount_cents = ?, paid = ?, note = ? WHERE id = ?',
          [
            c.shiftId,
            c.menuItemId,
            c.label,
            c.amountCents,
            c.paid ? 1 : 0,
            c.note,
            c.id,
          ],
        );
        return c;
      });

  @override
  Future<Result<List<SgStaffConsumption>, SgFailure>> listStaffConsumptions({
    String? employeeId,
    String? shiftId,
    DateTime? from,
    DateTime? to,
    bool? paid,
  }) async =>
      _wrap(() {
        var sql = 'SELECT * FROM staff_consumptions WHERE 1=1';
        final params = <Object>[];
        if (employeeId != null) {
          sql += ' AND employee_id = ?';
          params.add(employeeId);
        }
        if (shiftId != null) {
          sql += ' AND shift_id = ?';
          params.add(shiftId);
        }
        if (from != null) {
          sql += ' AND consumed_at >= ?';
          params.add(from.toIso8601String());
        }
        if (to != null) {
          sql += ' AND consumed_at <= ?';
          params.add(to.toIso8601String());
        }
        if (paid != null) {
          sql += ' AND paid = ?';
          params.add(paid ? 1 : 0);
        }
        sql += ' ORDER BY consumed_at DESC';
        return _db.select(sql, params).map((r) => SgStaffConsumption(
              id: r['id'] as String,
              employeeId: r['employee_id'] as String,
              shiftId: r['shift_id'] as String?,
              menuItemId: r['menu_item_id'] as String?,
              label: r['label'] as String,
              amountCents: r['amount_cents'] as int,
              consumedAt: DateTime.parse(r['consumed_at'] as String),
              paid: (r['paid'] as int) == 1,
              note: r['note'] as String?,
            )).toList();
      });

  // ============== Onboarding checklists (Phase D) ==============
  @override
  Future<Result<SgOnboardingChecklist, SgFailure>> createOnboardingChecklist(SgOnboardingChecklist cl) async => _wrap(() {
        _db.execute(
          'INSERT INTO onboarding_checklists(id, employee_id, role, items_json, created_at, engine) VALUES (?, ?, ?, ?, ?, ?)',
          [
            cl.id,
            cl.employeeId,
            cl.role.name,
            jsonEncode(cl.items.map((i) => i.toJson()).toList()),
            cl.createdAt.toIso8601String(),
            cl.engine,
          ],
        );
        return cl;
      });

  @override
  Future<Result<SgOnboardingChecklist, SgFailure>> updateOnboardingChecklist(SgOnboardingChecklist cl) async => _wrap(() {
        _db.execute(
          'UPDATE onboarding_checklists SET role = ?, items_json = ? WHERE id = ?',
          [
            cl.role.name,
            jsonEncode(cl.items.map((i) => i.toJson()).toList()),
            cl.id,
          ],
        );
        return cl;
      });

  @override
  Future<Result<SgOnboardingChecklist?, SgFailure>> getOnboardingChecklist(String id) async => _wrap(() {
        final rs = _db.select('SELECT * FROM onboarding_checklists WHERE id = ?', [id]);
        if (rs.isEmpty) return null;
        return _rowToChecklist(rs.first);
      });

  @override
  Future<Result<List<SgOnboardingChecklist>, SgFailure>> listOnboardingChecklists({String? employeeId}) async => _wrap(() {
        final rs = employeeId == null
            ? _db.select('SELECT * FROM onboarding_checklists ORDER BY created_at DESC')
            : _db.select(
                'SELECT * FROM onboarding_checklists WHERE employee_id = ? ORDER BY created_at DESC',
                [employeeId],
              );
        return rs.map(_rowToChecklist).toList();
      });

  SgOnboardingChecklist _rowToChecklist(Row r) => SgOnboardingChecklist(
        id: r['id'] as String,
        employeeId: r['employee_id'] as String,
        role: SgEmployeeRole.fromName(r['role'] as String),
        items: ((jsonDecode(r['items_json'] as String) as List<dynamic>))
            .map((i) => SgOnboardingItem.fromJson(i as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.parse(r['created_at'] as String),
        engine: r['engine'] as String,
      );

  // ============== Kitchen tickets (Phase E1) ==============
  @override
  Future<Result<SgKitchenTicket, SgFailure>> createKitchenTicket(SgKitchenTicket t) async => _wrap(() {
        _db.execute('BEGIN TRANSACTION');
        try {
          _db.execute(
            'INSERT INTO kitchen_tickets(id, table_number, table_label, status, created_by, created_at, sent_to_kitchen_at, completed_at, voice_transcript) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
            [
              t.id,
              t.tableNumber,
              t.tableLabel,
              t.status.name,
              t.createdBy,
              t.createdAt.toIso8601String(),
              t.sentToKitchenAt?.toIso8601String(),
              t.completedAt?.toIso8601String(),
              t.voiceTranscript,
            ],
          );
          for (final it in t.items) {
            _db.execute(
              'INSERT INTO kitchen_ticket_items(id, ticket_id, menu_item_id, label, quantity, modifiers_json, status, notes, started_at, ready_at, served_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
              [
                it.id,
                it.ticketId,
                it.menuItemId,
                it.label,
                it.quantity,
                jsonEncode(it.modifiers),
                it.status.name,
                it.notes,
                it.startedAt?.toIso8601String(),
                it.readyAt?.toIso8601String(),
                it.servedAt?.toIso8601String(),
              ],
            );
          }
          _db.execute('COMMIT');
          return t;
        } catch (e) {
          _db.execute('ROLLBACK');
          rethrow;
        }
      });

  @override
  Future<Result<SgKitchenTicket, SgFailure>> updateKitchenTicket(SgKitchenTicket t) async => _wrap(() {
        _db.execute(
          'UPDATE kitchen_tickets SET table_number = ?, table_label = ?, status = ?, sent_to_kitchen_at = ?, completed_at = ?, voice_transcript = ? WHERE id = ?',
          [
            t.tableNumber,
            t.tableLabel,
            t.status.name,
            t.sentToKitchenAt?.toIso8601String(),
            t.completedAt?.toIso8601String(),
            t.voiceTranscript,
            t.id,
          ],
        );
        return t;
      });

  @override
  Future<Result<SgKitchenTicket?, SgFailure>> getKitchenTicket(String id) async => _wrap(() {
        final rs = _db.select('SELECT * FROM kitchen_tickets WHERE id = ?', [id]);
        if (rs.isEmpty) return null;
        return _hydrateTicket(rs.first);
      });

  @override
  Future<Result<List<SgKitchenTicket>, SgFailure>> listKitchenTickets({
    SgKitchenTicketStatus? status,
    DateTime? from,
    DateTime? to,
    int? limit,
  }) async =>
      _wrap(() {
        var sql = 'SELECT * FROM kitchen_tickets WHERE 1=1';
        final params = <Object>[];
        if (status != null) {
          sql += ' AND status = ?';
          params.add(status.name);
        }
        if (from != null) {
          sql += ' AND created_at >= ?';
          params.add(from.toIso8601String());
        }
        if (to != null) {
          sql += ' AND created_at <= ?';
          params.add(to.toIso8601String());
        }
        sql += ' ORDER BY created_at DESC LIMIT ?';
        params.add(limit ?? 200);
        return _db.select(sql, params).map(_hydrateTicket).toList();
      });

  @override
  Future<Result<SgKitchenTicketItem, SgFailure>> updateKitchenTicketItem(SgKitchenTicketItem item) async => _wrap(() {
        _db.execute(
          'UPDATE kitchen_ticket_items SET menu_item_id = ?, label = ?, quantity = ?, modifiers_json = ?, status = ?, notes = ?, started_at = ?, ready_at = ?, served_at = ? WHERE id = ?',
          [
            item.menuItemId,
            item.label,
            item.quantity,
            jsonEncode(item.modifiers),
            item.status.name,
            item.notes,
            item.startedAt?.toIso8601String(),
            item.readyAt?.toIso8601String(),
            item.servedAt?.toIso8601String(),
            item.id,
          ],
        );
        return item;
      });

  SgKitchenTicket _hydrateTicket(Row r) {
    final items = _db.select(
      'SELECT * FROM kitchen_ticket_items WHERE ticket_id = ? ORDER BY rowid',
      [r['id']],
    ).map((i) => SgKitchenTicketItem(
          id: i['id'] as String,
          ticketId: i['ticket_id'] as String,
          menuItemId: i['menu_item_id'] as String?,
          label: i['label'] as String,
          quantity: i['quantity'] as int,
          modifiers: ((jsonDecode(i['modifiers_json'] as String) as List<dynamic>))
              .cast<String>(),
          status: SgKitchenItemStatus.values
              .firstWhere((s) => s.name == i['status']),
          notes: i['notes'] as String?,
          startedAt: i['started_at'] != null
              ? DateTime.parse(i['started_at'] as String)
              : null,
          readyAt: i['ready_at'] != null
              ? DateTime.parse(i['ready_at'] as String)
              : null,
          servedAt: i['served_at'] != null
              ? DateTime.parse(i['served_at'] as String)
              : null,
        )).toList();
    return SgKitchenTicket(
      id: r['id'] as String,
      tableNumber: r['table_number'] as int?,
      tableLabel: r['table_label'] as String?,
      status: SgKitchenTicketStatus.values.firstWhere((s) => s.name == r['status']),
      items: items,
      createdBy: r['created_by'] as String,
      createdAt: DateTime.parse(r['created_at'] as String),
      sentToKitchenAt: r['sent_to_kitchen_at'] != null
          ? DateTime.parse(r['sent_to_kitchen_at'] as String)
          : null,
      completedAt: r['completed_at'] != null
          ? DateTime.parse(r['completed_at'] as String)
          : null,
      voiceTranscript: r['voice_transcript'] as String?,
    );
  }

  // ============== Recipes (Phase E2) ==============
  @override
  Future<Result<SgRecipe, SgFailure>> createRecipe(SgRecipe r) async => _wrap(() {
        _db.execute('BEGIN TRANSACTION');
        try {
          _db.execute(
            'INSERT INTO recipes(id, menu_item_id, name, created_at, updated_at, created_by) VALUES (?, ?, ?, ?, ?, ?)',
            [
              r.id,
              r.menuItemId,
              r.name,
              r.createdAt.toIso8601String(),
              r.updatedAt?.toIso8601String(),
              r.createdBy,
            ],
          );
          for (final s in r.steps) {
            _db.execute(
              'INSERT INTO recipe_steps(id, recipe_id, sort_order, type, label, expected_duration_ms, instructions) VALUES (?, ?, ?, ?, ?, ?, ?)',
              [
                s.id,
                s.recipeId,
                s.sortOrder,
                s.type.name,
                s.label,
                s.expectedDuration.inMilliseconds,
                s.instructions,
              ],
            );
          }
          _db.execute('COMMIT');
          return r;
        } catch (e) {
          _db.execute('ROLLBACK');
          rethrow;
        }
      });

  @override
  Future<Result<SgRecipe, SgFailure>> updateRecipe(SgRecipe r) async => _wrap(() {
        _db.execute('BEGIN TRANSACTION');
        try {
          _db.execute(
            'UPDATE recipes SET name = ?, updated_at = ? WHERE id = ?',
            [r.name, r.updatedAt?.toIso8601String(), r.id],
          );
          _db.execute('DELETE FROM recipe_steps WHERE recipe_id = ?', [r.id]);
          for (final s in r.steps) {
            _db.execute(
              'INSERT INTO recipe_steps(id, recipe_id, sort_order, type, label, expected_duration_ms, instructions) VALUES (?, ?, ?, ?, ?, ?, ?)',
              [
                s.id,
                s.recipeId,
                s.sortOrder,
                s.type.name,
                s.label,
                s.expectedDuration.inMilliseconds,
                s.instructions,
              ],
            );
          }
          _db.execute('COMMIT');
          return r;
        } catch (e) {
          _db.execute('ROLLBACK');
          rethrow;
        }
      });

  @override
  Future<Result<SgRecipe?, SgFailure>> getRecipe(String id) async => _wrap(() {
        final rs = _db.select('SELECT * FROM recipes WHERE id = ?', [id]);
        if (rs.isEmpty) return null;
        return _hydrateRecipe(rs.first);
      });

  @override
  Future<Result<SgRecipe?, SgFailure>> getRecipeForMenuItem(String menuItemId) async => _wrap(() {
        final rs = _db.select(
          'SELECT * FROM recipes WHERE menu_item_id = ? ORDER BY created_at DESC LIMIT 1',
          [menuItemId],
        );
        if (rs.isEmpty) return null;
        return _hydrateRecipe(rs.first);
      });

  @override
  Future<Result<List<SgRecipe>, SgFailure>> listRecipes() async => _wrap(() {
        return _db.select('SELECT * FROM recipes ORDER BY created_at DESC')
            .map(_hydrateRecipe).toList();
      });

  SgRecipe _hydrateRecipe(Row r) {
    final steps = _db.select(
      'SELECT * FROM recipe_steps WHERE recipe_id = ? ORDER BY sort_order',
      [r['id']],
    ).map((s) => SgRecipeStep(
          id: s['id'] as String,
          recipeId: s['recipe_id'] as String,
          sortOrder: s['sort_order'] as int,
          type: SgRecipeStepType.values.firstWhere((t) => t.name == s['type']),
          label: s['label'] as String,
          expectedDuration: Duration(milliseconds: s['expected_duration_ms'] as int),
          instructions: s['instructions'] as String?,
        )).toList();
    return SgRecipe(
      id: r['id'] as String,
      menuItemId: r['menu_item_id'] as String,
      name: r['name'] as String,
      steps: steps,
      createdAt: DateTime.parse(r['created_at'] as String),
      updatedAt: r['updated_at'] != null
          ? DateTime.parse(r['updated_at'] as String)
          : null,
      createdBy: r['created_by'] as String?,
    );
  }

  // ============== Cooking tasks (Phase E2) ==============
  @override
  Future<Result<SgCookingTask, SgFailure>> createCookingTask(SgCookingTask t) async => _wrap(() {
        _db.execute(
          'INSERT INTO cooking_tasks(id, ticket_item_id, recipe_step_id, label, status, started_at, completed_at, expected_duration_ms, assigned_to, sort_order) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            t.id,
            t.ticketItemId,
            t.recipeStepId,
            t.label,
            t.status.name,
            t.startedAt?.toIso8601String(),
            t.completedAt?.toIso8601String(),
            t.expectedDuration.inMilliseconds,
            t.assignedTo,
            t.sortOrder,
          ],
        );
        return t;
      });

  @override
  Future<Result<SgCookingTask, SgFailure>> updateCookingTask(SgCookingTask t) async => _wrap(() {
        _db.execute(
          'UPDATE cooking_tasks SET status = ?, started_at = ?, completed_at = ?, assigned_to = ?, label = ? WHERE id = ?',
          [
            t.status.name,
            t.startedAt?.toIso8601String(),
            t.completedAt?.toIso8601String(),
            t.assignedTo,
            t.label,
            t.id,
          ],
        );
        return t;
      });

  @override
  Future<Result<SgCookingTask?, SgFailure>> getCookingTask(String id) async => _wrap(() {
        final rs = _db.select('SELECT * FROM cooking_tasks WHERE id = ?', [id]);
        if (rs.isEmpty) return null;
        return _rowToCookingTask(rs.first);
      });

  @override
  Future<Result<List<SgCookingTask>, SgFailure>> listCookingTasks({
    String? ticketItemId,
    SgCookingTaskStatus? status,
    DateTime? from,
    DateTime? to,
  }) async =>
      _wrap(() {
        var sql = 'SELECT * FROM cooking_tasks WHERE 1=1';
        final params = <Object>[];
        if (ticketItemId != null) {
          sql += ' AND ticket_item_id = ?';
          params.add(ticketItemId);
        }
        if (status != null) {
          sql += ' AND status = ?';
          params.add(status.name);
        }
        if (from != null) {
          sql += ' AND COALESCE(started_at, "9999") >= ?';
          params.add(from.toIso8601String());
        }
        if (to != null) {
          sql += ' AND COALESCE(started_at, "0000") <= ?';
          params.add(to.toIso8601String());
        }
        sql += ' ORDER BY sort_order, started_at';
        return _db.select(sql, params).map(_rowToCookingTask).toList();
      });

  SgCookingTask _rowToCookingTask(Row r) => SgCookingTask(
        id: r['id'] as String,
        ticketItemId: r['ticket_item_id'] as String,
        recipeStepId: r['recipe_step_id'] as String?,
        label: r['label'] as String,
        status: SgCookingTaskStatus.values
            .firstWhere((s) => s.name == r['status']),
        startedAt: r['started_at'] != null
            ? DateTime.parse(r['started_at'] as String)
            : null,
        completedAt: r['completed_at'] != null
            ? DateTime.parse(r['completed_at'] as String)
            : null,
        expectedDuration: Duration(milliseconds: r['expected_duration_ms'] as int),
        assignedTo: r['assigned_to'] as String?,
        sortOrder: r['sort_order'] as int? ?? 0,
      );

  void close() => _db.dispose();
}
