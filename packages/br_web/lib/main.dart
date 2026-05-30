// MIGRATE LATER : Material → sg_ui (SgApp, SgCard, SgButton, etc.).

import 'package:flutter/material.dart';

import 'src/api.dart';

const _apiBase = String.fromEnvironment(
  'BR_API_URL',
  defaultValue: 'http://127.0.0.1:8444',
);

void main() {
  runApp(const BroccersApp());
}

/// Identité visuelle Broc — Café Broc, 1 Rue du Canal, Villeurbanne (Puces du Canal).
/// Rouge brique enseigne + crème + jaune chaud (frites/lumière).
class BrocBrand {
  static const Color brocRed = Color(0xffc72226); // rouge enseigne CAFÉ
  static const Color brocRedDeep = Color(0xff8b1a1d); // bordeaux ombre
  static const Color brocCream = Color(0xfff5ebd6); // blanc cassé devanture
  static const Color brocYellow = Color(0xfff5c842); // doré frites/lumière
  static const Color brocGreen = Color(0xff7a8f4e); // vert salade
  static const Color brocBlack = Color(0xff14100f); // noir charbon
}

class BroccersApp extends StatelessWidget {
  const BroccersApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Broccers · Le Broc Café',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: BrocBrand.brocRed,
          brightness: Brightness.dark,
        ).copyWith(
          primary: BrocBrand.brocRed,
          secondary: BrocBrand.brocYellow,
          surface: const Color(0xff1f1818),
          surfaceContainerHighest: const Color(0xff2a1f1f),
        ),
        scaffoldBackgroundColor: BrocBrand.brocBlack,
        appBarTheme: const AppBarTheme(
          backgroundColor: BrocBrand.brocRed,
          foregroundColor: BrocBrand.brocCream,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: BrocBrand.brocYellow,
          foregroundColor: BrocBrand.brocBlack,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xff1f1818),
          indicatorColor: BrocBrand.brocRed.withValues(alpha: 0.4),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(color: BrocBrand.brocCream, fontSize: 11),
          ),
        ),
      ),
      home: const _Root(),
    );
  }
}

class _Root extends StatefulWidget {
  const _Root();
  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  late final BrWebApi _api;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _api = BrWebApi(baseUrl: Uri.parse(_apiBase));
    _api.loadCachedJwt().then((_) => setState(() => _loading = false));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _api.isAuthenticated
        ? HomeShell(api: _api)
        : LoginScreen(api: _api, onAuth: () => setState(() {}));
  }
}

class LoginScreen extends StatefulWidget {
  final BrWebApi api;
  final VoidCallback onAuth;
  const LoginScreen({super.key, required this.api, required this.onAuth});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _pinCtrl = TextEditingController();
  String? _error;
  bool _busy = false;

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final r = await widget.api.authenticate(_pinCtrl.text);
    r.when(
      success: (_) => widget.onAuth(),
      failure: (e) => setState(() => _error = e.message),
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: BrocBrand.brocRed,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: BrocBrand.brocRed.withValues(alpha: 0.5),
                        blurRadius: 30,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'CAFÉ',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: BrocBrand.brocCream,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Le Broc',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: BrocBrand.brocCream,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Puces du Canal — Villeurbanne',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: BrocBrand.brocYellow,
                    fontStyle: FontStyle.italic,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: _pinCtrl,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, letterSpacing: 8),
                  decoration: const InputDecoration(
                    labelText: 'PIN',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      style: const TextStyle(color: Colors.redAccent)),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48)),
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Entrer'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  final BrWebApi api;
  const HomeShell({super.key, required this.api});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      PersonnelScreen(api: widget.api),
      MenuScreen(api: widget.api),
      ShoppingScreen(api: widget.api),
      QuestionScreen(api: widget.api),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Broccers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await widget.api.logout();
              if (mounted) {
                Navigator.pushReplacement(context,
                    MaterialPageRoute(builder: (_) => const _Root()));
              }
            },
          ),
        ],
      ),
      body: screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.groups), label: 'Personnel'),
          NavigationDestination(icon: Icon(Icons.menu_book), label: 'Carte'),
          NavigationDestination(icon: Icon(Icons.shopping_cart), label: 'Courses'),
          NavigationDestination(icon: Icon(Icons.psychology), label: 'Question'),
        ],
      ),
    );
  }
}

// ===========================================================================
// Personnel
// ===========================================================================
class PersonnelScreen extends StatefulWidget {
  final BrWebApi api;
  const PersonnelScreen({super.key, required this.api});
  @override
  State<PersonnelScreen> createState() => _PersonnelScreenState();
}

/// Traduit les messages d'erreur SgFailure en FR user-friendly.
String translateErrorFr(String raw) {
  final m = raw.toLowerCase();
  if (m.contains('no active shift')) {
    return "Cet employé n'est pas en service. Démarre un shift d'abord (bouton ▶).";
  }
  if (m.contains('already has an active shift')) {
    return "Déjà en service. Termine le shift en cours avant d'en démarrer un nouveau.";
  }
  if (m.contains('already on break')) {
    return "Déjà en pause. Termine la pause en cours d'abord.";
  }
  if (m.contains('cannot hold role')) {
    return "Ce rôle n'est pas dans les capabilities de cet employé. Configure ses rôles d'abord.";
  }
  if (m.contains('cannot resolve role')) {
    return "Impossible de déterminer le rôle aujourd'hui. Configure le planning hebdo ou le rôle par défaut.";
  }
  if (m.contains('has no roles configured')) {
    return "Cet employé n'a pas de rôle configuré. Ajoute au moins un rôle d'abord.";
  }
  if (m.contains('cannot archive') && m.contains('active shift')) {
    return "Impossible d'archiver : un shift est actif. Termine-le d'abord.";
  }
  if (m.contains('not found')) return "Introuvable.";
  return raw;
}

class _PersonnelScreenState extends State<PersonnelScreen> {
  List<Map<String, dynamic>> _employees = [];
  /// Map employeeId → state {'shift': bool, 'role': String?, 'break': bool}
  Map<String, Map<String, dynamic>> _states = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final r = await widget.api.get('/api/employees');
    if (!mounted) return;
    await r.when(
      success: (data) async {
        _employees = (data['employees'] as List<dynamic>).cast<Map<String, dynamic>>();
        // Charge les états (shift actif + pause active) en parallèle
        await _loadStates();
        if (mounted) setState(() => _loading = false);
      },
      failure: (_) async {
        if (mounted) setState(() => _loading = false);
      },
    );
  }

  Future<void> _loadStates() async {
    final futures = _employees.map((e) async {
      final id = e['id'] as String;
      final shiftR = await widget.api.command('shift active --employee $id');
      final breakR = await widget.api.command('break active --employee $id');
      final shiftIsActive = shiftR.valueOrNull?['result']?['is_active'] as bool? ?? false;
      final shift = shiftR.valueOrNull?['result']?['shift'] as Map<String, dynamic>?;
      final breakIsActive = breakR.valueOrNull?['result']?['is_active'] as bool? ?? false;
      String? currentRole;
      if (shiftIsActive && shift != null) {
        // get current segment via shift segments
        final segR = await widget.api.command('shift segments --shift ${shift['id']}');
        final segs = (segR.valueOrNull?['result']?['segments'] as List<dynamic>?) ?? const [];
        final activeSeg = segs.cast<Map<String, dynamic>>()
            .where((s) => s['ended_at'] == null).firstOrNull;
        currentRole = activeSeg?['role'] as String?;
      }
      return MapEntry(id, {
        'shift': shiftIsActive,
        'shift_id': shift?['id'],
        'role': currentRole,
        'break': breakIsActive,
      });
    });
    final entries = await Future.wait(futures);
    _states = Map.fromEntries(entries);
  }

  void _snack(String raw, {bool isError = false}) {
    final msg = isError ? translateErrorFr(raw) : raw;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red.shade900 : null,
      duration: Duration(seconds: isError ? 5 : 2),
    ));
  }

  Future<void> _clockIn(String empId, {String? roleOverride}) async {
    final body = <String, dynamic>{'employee_id': empId};
    if (roleOverride != null) body['role'] = roleOverride;
    final r = await widget.api.post('/api/shifts/clock-in', body);
    if (!mounted) return;
    r.when(
      success: (data) {
        final segment = data['first_segment'] as Map<String, dynamic>?;
        final role = segment?['role'] as String? ?? '?';
        _snack('Clock-in ✓ ($role)');
        _refresh();
      },
      failure: (e) => _snack(e.message, isError: true),
    );
  }

  Future<void> _clockOut(String empId) async {
    final r = await widget.api.post('/api/shifts/clock-out', {'employee_id': empId});
    if (!mounted) return;
    r.when(
      success: (_) {
        _snack('Clock-out ✓');
        _refresh();
      },
      failure: (e) => _snack(e.message, isError: true),
    );
  }

  Future<void> _startBreak(String empId) async {
    final r = await widget.api.post('/api/breaks/start', {'employee_id': empId, 'type': 'legal'});
    if (!mounted) return;
    r.when(
      success: (_) {
        _snack('Pause démarrée ☕');
        _refresh();
      },
      failure: (e) => _snack(e.message, isError: true),
    );
  }

  Future<void> _changeRole(String empId) async {
    final emp = _employees.firstWhere((e) => e['id'] == empId);
    final roles = ((emp['roles'] as List<dynamic>?) ?? const []).cast<String>();
    final currentRole = _states[empId]?['role'] as String?;
    final choice = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: Text('Changer le rôle de ${emp['name']} (actuel : ${currentRole ?? "?"})'),
        children: roles.where((r) => r != currentRole).map((r) =>
          SimpleDialogOption(
            child: Text(r),
            onPressed: () => Navigator.pop(context, r),
          ),
        ).toList(),
      ),
    );
    if (choice == null) return;
    final r = await widget.api.command(
      'shift change-role --employee $empId --role $choice --actor employee:$empId --reason "rectif employé"',
    );
    if (!mounted) return;
    r.when(
      success: (data) {
        if (data['type'] == 'success') {
          _snack('Rôle changé en $choice ✓');
          _refresh();
        } else {
          _snack(data['message']?.toString() ?? 'erreur', isError: true);
        }
      },
      failure: (e) => _snack(e.message, isError: true),
    );
  }

  Future<void> _archiveEmployee(String empId) async {
    final emp = _employees.firstWhere((e) => e['id'] == empId);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Archiver ${emp['name']} ?'),
        content: const Text(
            'L\'employé sera marqué inactif (soft-delete, données conservées).\n'
            'Réactivable plus tard via CLI.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archiver'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final r = await widget.api.command(
      'employee archive $empId --actor manager:seb --reason "archivé via UI"',
    );
    if (!mounted) return;
    r.when(
      success: (data) {
        if (data['type'] == 'success') {
          _snack('Employé archivé ✓');
          _refresh();
        } else {
          _snack(data['message']?.toString() ?? 'erreur', isError: true);
        }
      },
      failure: (e) => _snack(e.message, isError: true),
    );
  }

  Future<void> _addEmployee() async {
    final nameCtrl = TextEditingController();
    final selectedRoles = <String>{'server'};
    String? defaultRole;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, set) {
        return AlertDialog(
          title: const Text('Nouvel employé'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nom'), autofocus: true),
                const SizedBox(height: 16),
                const Text('Rôles (capabilities) — coche tout ce qu\'il sait faire :',
                    style: TextStyle(fontSize: 12, color: BrocBrand.brocCream)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final r in const [
                      ('manager', 'Manager'),
                      ('server', 'Serveur'),
                      ('runner', 'Runner'),
                      ('cook', 'Cuisinier'),
                      ('bartender', 'Barman'),
                      ('dishwasher', 'Plongeur'),
                      ('host', 'Hôte'),
                    ])
                      FilterChip(
                        label: Text(r.$2),
                        selected: selectedRoles.contains(r.$1),
                        onSelected: (v) => set(() {
                          if (v) {
                            selectedRoles.add(r.$1);
                          } else {
                            selectedRoles.remove(r.$1);
                            if (defaultRole == r.$1) defaultRole = null;
                          }
                        }),
                        selectedColor: BrocBrand.brocRed,
                        checkmarkColor: BrocBrand.brocCream,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Rôle par défaut (si pas de planning pour le jour) :',
                    style: TextStyle(fontSize: 12, color: BrocBrand.brocCream)),
                const SizedBox(height: 6),
                DropdownButton<String>(
                  value: selectedRoles.contains(defaultRole) ? defaultRole : null,
                  hint: const Text('— auto —'),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem<String>(value: null, child: Text('Auto (premier rôle)')),
                    for (final r in selectedRoles)
                      DropdownMenuItem<String>(value: r, child: Text(r)),
                  ],
                  onChanged: (v) => set(() => defaultRole = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
            FilledButton(
              onPressed: selectedRoles.isEmpty || nameCtrl.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(context, true),
              child: const Text('Créer'),
            ),
          ],
        );
      }),
    );
    if (ok != true || selectedRoles.isEmpty) return;
    final rolesArg = selectedRoles.join(',');
    final defaultArg = defaultRole != null ? ' --default-role $defaultRole' : '';
    final r = await widget.api.command(
      'employee create --name "${nameCtrl.text}" --roles $rolesArg$defaultArg',
    );
    if (!mounted) return;
    r.when(
      success: (_) => _refresh(),
      failure: (e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addEmployee,
        icon: const Icon(Icons.person_add),
        label: const Text('Ajouter employé'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _employees.isEmpty
              ? const Center(child: Text('Aucun employé.\nAjoute-en un.', textAlign: TextAlign.center))
              : ListView.builder(
                  itemCount: _employees.length,
                  itemBuilder: (_, i) {
                    final e = _employees[i];
                    final id = e['id'] as String;
                    final roles = ((e['roles'] as List<dynamic>?) ?? const [])
                        .cast<String>();
                    final defaultRole = e['default_role'] as String?;
                    final rolesLabel = roles.isEmpty
                        ? 'aucun rôle'
                        : roles.join(' · ');
                    final state = _states[id];
                    final onShift = state?['shift'] as bool? ?? false;
                    final onBreak = state?['break'] as bool? ?? false;
                    final currentRole = state?['role'] as String?;
                    final canChangeRole = onShift && roles.length > 1;
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: onShift
                              ? (onBreak ? Colors.orange : Colors.green)
                              : BrocBrand.brocRed,
                          child: Text(
                            (e['name'] as String).isNotEmpty
                                ? (e['name'] as String)[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                color: BrocBrand.brocCream,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(e['name'] as String,
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 8),
                            if (onShift)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: onBreak ? Colors.orange : Colors.green,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  onBreak
                                      ? 'EN PAUSE'
                                      : 'EN SERVICE${currentRole != null ? " · $currentRole" : ""}',
                                  style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black),
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade800,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'OFF',
                                  style: TextStyle(fontSize: 10, color: Colors.grey),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rolesLabel + (defaultRole != null ? '  (default: $defaultRole)' : ''),
                              style: const TextStyle(
                                  color: BrocBrand.brocYellow, fontSize: 12),
                            ),
                            Text('${e['contracted_hours']}h/sem',
                                style: const TextStyle(fontSize: 11)),
                          ],
                        ),
                        trailing: Wrap(spacing: 0, children: [
                          IconButton(
                            tooltip: onShift
                                ? 'Déjà en service — termine le shift d\'abord'
                                : 'Démarrer le shift (clock-in)',
                            icon: Icon(Icons.play_circle_fill,
                                color: onShift ? Colors.grey : Colors.greenAccent),
                            onPressed: onShift ? null : () => _clockIn(id),
                          ),
                          if (canChangeRole)
                            IconButton(
                              tooltip: 'Changer de rôle en cours de shift',
                              icon: const Icon(Icons.swap_horiz, color: Colors.purpleAccent),
                              onPressed: () => _changeRole(id),
                            ),
                          IconButton(
                            tooltip: onShift && !onBreak
                                ? 'Démarrer une pause'
                                : (onBreak ? 'Déjà en pause' : 'Pas en service — clock-in d\'abord'),
                            icon: Icon(Icons.local_cafe,
                                color: (onShift && !onBreak) ? Colors.orange : Colors.grey),
                            onPressed: (onShift && !onBreak) ? () => _startBreak(id) : null,
                          ),
                          IconButton(
                            tooltip: onShift
                                ? 'Terminer le shift (clock-out)'
                                : 'Pas en service',
                            icon: Icon(Icons.stop_circle,
                                color: onShift ? Colors.redAccent : Colors.grey),
                            onPressed: onShift ? () => _clockOut(id) : null,
                          ),
                          PopupMenuButton<String>(
                            tooltip: 'Plus d\'actions',
                            icon: const Icon(Icons.more_vert),
                            itemBuilder: (_) => [
                              PopupMenuItem<String>(
                                value: 'archive',
                                enabled: !onShift,
                                child: Row(
                                  children: const [
                                    Icon(Icons.archive, size: 18, color: Colors.redAccent),
                                    SizedBox(width: 8),
                                    Text('Archiver employé'),
                                  ],
                                ),
                              ),
                            ],
                            onSelected: (v) {
                              if (v == 'archive') _archiveEmployee(id);
                            },
                          ),
                        ]),
                      ),
                    );
                  },
                ),
    );
  }
}

// ===========================================================================
// Menu / Carte
// ===========================================================================
class MenuScreen extends StatefulWidget {
  final BrWebApi api;
  const MenuScreen({super.key, required this.api});
  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  List<Map<String, dynamic>> _cards = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final r = await widget.api.get('/api/menu/cards');
    if (!mounted) return;
    r.when(
      success: (data) => setState(() {
        _cards = (data['cards'] as List<dynamic>).cast<Map<String, dynamic>>();
        _loading = false;
      }),
      failure: (_) => setState(() => _loading = false),
    );
  }

  Future<void> _createSample() async {
    final r = await widget.api.command('menu create-sample --name "Carte du jour"');
    if (!mounted) return;
    r.when(
      success: (_) => _refresh(),
      failure: (e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message))),
    );
  }

  Future<void> _publish(String id) async {
    final r = await widget.api.post('/api/menu/cards/$id/publish', null);
    if (!mounted) return;
    r.when(
      success: (_) {
        _refresh();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Publié ✓')));
      },
      failure: (e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message))),
    );
  }

  void _openPdf(String id) {
    final url = '${widget.api.baseUrl}/api/menu/cards/$id/pdf';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('PDF : $url'),
      action: SnackBarAction(label: 'Copier', onPressed: () {}),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createSample,
        icon: const Icon(Icons.add),
        label: const Text('Sample carte'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _cards.isEmpty
              ? const Center(child: Text('Aucune carte.\nCrée-en une.', textAlign: TextAlign.center))
              : ListView.builder(
                  itemCount: _cards.length,
                  itemBuilder: (_, i) {
                    final c = _cards[i];
                    final pub = c['published_at'] != null;
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: ListTile(
                        leading: Icon(pub ? Icons.check_circle : Icons.edit,
                            color: pub ? Colors.green : Colors.grey),
                        title: Text('${c['name']} (v${c['version']})'),
                        subtitle: Text(
                            '${c['items_count']} items · ${c['categories_count']} catégories${pub ? " · publiée" : " · brouillon"}'),
                        trailing: Wrap(spacing: 4, children: [
                          if (!pub)
                            IconButton(
                              tooltip: 'Publier',
                              icon: const Icon(Icons.publish, color: Colors.green),
                              onPressed: () => _publish(c['id'] as String),
                            ),
                          IconButton(
                            tooltip: 'PDF',
                            icon: const Icon(Icons.picture_as_pdf),
                            onPressed: () => _openPdf(c['id'] as String),
                          ),
                        ]),
                      ),
                    );
                  },
                ),
    );
  }
}

// ===========================================================================
// Shopping / Courses
// ===========================================================================
class ShoppingScreen extends StatefulWidget {
  final BrWebApi api;
  const ShoppingScreen({super.key, required this.api});
  @override
  State<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends State<ShoppingScreen> {
  List<Map<String, dynamic>> _lists = [];
  List<Map<String, dynamic>> _items = [];
  String? _selectedList;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final r = await widget.api.get('/api/shopping/lists');
    if (!mounted) return;
    r.when(
      success: (data) async {
        _lists = (data['lists'] as List<dynamic>).cast<Map<String, dynamic>>();
        if (_lists.isNotEmpty && _selectedList == null) {
          _selectedList = _lists.first['id'] as String;
        }
        if (_selectedList != null) {
          await _loadItems(_selectedList!);
        }
        setState(() => _loading = false);
      },
      failure: (_) => setState(() => _loading = false),
    );
  }

  Future<void> _loadItems(String listId) async {
    final r = await widget.api.command('shopping items --list $listId');
    if (!mounted) return;
    r.when(
      success: (resp) {
        final result = resp['result'] as Map<String, dynamic>?;
        _items = ((result?['items'] as List<dynamic>?) ?? const [])
            .cast<Map<String, dynamic>>();
      },
      failure: (_) {},
    );
  }

  Future<void> _newList() async {
    final ctrl = TextEditingController(text: 'Courses ${DateTime.now().day}/${DateTime.now().month}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nouvelle liste'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Créer')),
        ],
      ),
    );
    if (ok != true) return;
    final r = await widget.api.command('shopping create-list --name "${ctrl.text}"');
    if (!mounted) return;
    r.when(
      success: (_) => _refresh(),
      failure: (e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message))),
    );
  }

  Future<void> _addItem() async {
    if (_selectedList == null) return;
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    final unitCtrl = TextEditingController(text: 'kg');
    bool urgent = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, set) {
        return AlertDialog(
          title: const Text('Ajouter à la liste'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Article'), autofocus: true),
            Row(children: [
              Expanded(child: TextField(controller: qtyCtrl, decoration: const InputDecoration(labelText: 'Qté'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: unitCtrl, decoration: const InputDecoration(labelText: 'Unité'))),
            ]),
            CheckboxListTile(
              value: urgent,
              onChanged: (v) => set(() => urgent = v!),
              title: const Text('Urgent'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ajouter')),
          ],
        );
      }),
    );
    if (ok != true) return;
    final urgentFlag = urgent ? '--urgent' : '';
    final r = await widget.api.command(
      'shopping add --list $_selectedList --name "${nameCtrl.text}" --qty ${qtyCtrl.text} --unit ${unitCtrl.text} $urgentFlag',
    );
    if (!mounted) return;
    r.when(
      success: (_) async {
        await _loadItems(_selectedList!);
        setState(() {});
      },
      failure: (e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message))),
    );
  }

  Future<void> _toggleItem(String id, bool done) async {
    final r = await widget.api.post(
        '/api/shopping/items/$id/${done ? "check" : "uncheck"}', null);
    if (!mounted) return;
    r.when(
      success: (_) async {
        if (_selectedList != null) await _loadItems(_selectedList!);
        setState(() {});
      },
      failure: (e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
        FloatingActionButton.small(
          heroTag: 'newlist',
          onPressed: _newList,
          tooltip: 'Nouvelle liste',
          child: const Icon(Icons.list_alt),
        ),
        const SizedBox(height: 8),
        FloatingActionButton.extended(
          heroTag: 'additem',
          onPressed: _selectedList == null ? null : _addItem,
          icon: const Icon(Icons.add_shopping_cart),
          label: const Text('Ajouter article'),
        ),
      ]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _lists.isEmpty
              ? const Center(child: Text('Aucune liste.\nCrée-en une.', textAlign: TextAlign.center))
              : Column(children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedList,
                      decoration: const InputDecoration(labelText: 'Liste', border: OutlineInputBorder()),
                      items: _lists
                          .map((l) => DropdownMenuItem<String>(
                              value: l['id'] as String,
                              child: Text('${l['name']} (${l['status']})')))
                          .toList(),
                      onChanged: (v) async {
                        setState(() => _selectedList = v);
                        if (v != null) {
                          await _loadItems(v);
                          setState(() {});
                        }
                      },
                    ),
                  ),
                  Expanded(
                    child: _items.isEmpty
                        ? const Center(child: Text('Liste vide.'))
                        : ListView.builder(
                            itemCount: _items.length,
                            itemBuilder: (_, i) {
                              final it = _items[i];
                              final done = it['done'] as bool? ?? false;
                              final urgent = it['urgent'] as bool? ?? false;
                              return ListTile(
                                leading: Checkbox(
                                  value: done,
                                  onChanged: (v) => _toggleItem(it['id'] as String, v ?? false),
                                ),
                                title: Text(
                                  '${it['name']} — ${it['quantity']} ${it['unit']}',
                                  style: TextStyle(
                                    decoration: done ? TextDecoration.lineThrough : null,
                                    color: done ? Colors.grey : null,
                                  ),
                                ),
                                trailing: urgent
                                    ? const Icon(Icons.warning, color: Colors.orange)
                                    : null,
                              );
                            },
                          ),
                  ),
                ]),
    );
  }
}

// ===========================================================================
// Question Claude
// ===========================================================================
class QuestionScreen extends StatefulWidget {
  final BrWebApi api;
  const QuestionScreen({super.key, required this.api});
  @override
  State<QuestionScreen> createState() => _QuestionScreenState();
}

class _QuestionScreenState extends State<QuestionScreen> {
  final _qCtrl = TextEditingController();
  List<Map<String, dynamic>> _history = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final r = await widget.api.get('/api/questions');
    if (!mounted) return;
    r.when(
      success: (data) => setState(() {
        _history = (data['questions'] as List<dynamic>).cast<Map<String, dynamic>>();
      }),
      failure: (_) {},
    );
  }

  Future<void> _ask() async {
    if (_qCtrl.text.trim().isEmpty) return;
    setState(() => _busy = true);
    final r = await widget.api.post('/api/questions', {
      'question': _qCtrl.text.trim(),
      'scope': ['menu', 'shopping'],
    });
    if (!mounted) return;
    r.when(
      success: (_) {
        _qCtrl.clear();
        _refresh();
        setState(() => _busy = false);
      },
      failure: (e) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _qCtrl,
              decoration: const InputDecoration(
                hintText: 'Pose ta question à Claude…',
                border: OutlineInputBorder(),
              ),
              minLines: 1,
              maxLines: 3,
              onSubmitted: (_) => _ask(),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _busy ? null : _ask,
            icon: _busy
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send),
            label: const Text('Demander'),
          ),
        ]),
      ),
      Expanded(
        child: _history.isEmpty
            ? const Center(child: Text('Aucune question.\nPose la première.', textAlign: TextAlign.center))
            : ListView.builder(
                reverse: true,
                itemCount: _history.length,
                itemBuilder: (_, i) {
                  final q = _history[i];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Icon(Icons.person, size: 16, color: Color(0xffd97706)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(q['question'] as String,
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ]),
                          if (q['answer'] != null) ...[
                            const SizedBox(height: 8),
                            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Icon(Icons.psychology, size: 16, color: Colors.greenAccent),
                              const SizedBox(width: 4),
                              Expanded(child: Text(q['answer'] as String)),
                            ]),
                          ],
                          const SizedBox(height: 4),
                          Text('${q['asked_at']} · ${q['engine']}',
                              style: const TextStyle(fontSize: 10, color: Color(0xff6b7280))),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    ]);
  }
}
