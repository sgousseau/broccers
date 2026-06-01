// MIGRATE LATER : Material → sg_ui (SgApp, SgCard, SgButton, etc.).

import 'package:flutter/material.dart';

import 'src/admin_screen.dart';
import 'src/api.dart';
import 'src/br_sg.dart';
import 'src/menu_editor_screen.dart';
import 'src/phase_f_screens.dart';

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
                SgTextField(
                  controller: _pinCtrl,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  textStyle: const TextStyle(fontSize: 24, letterSpacing: 8),
                  label: 'PIN',
                  onSubmitted: (_) => _submit(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  SgCallout.error(_error!),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: SgButton(
                    label: 'Entrer',
                    icon: Icons.login,
                    onPressed: _busy ? null : _submit,
                    busy: _busy,
                  ),
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

  Future<void> _showMorningBriefing() async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        title: Row(children: [
          Icon(Icons.wb_sunny, color: BrocBrand.brocYellow),
          SizedBox(width: 8),
          Text('Briefing matinal'),
        ]),
        content: SizedBox(
          width: 300,
          height: 100,
          child: Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              CircularProgressIndicator(color: BrocBrand.brocRed),
              SizedBox(height: 12),
              Text('Claude prépare le briefing du jour...'),
            ]),
          ),
        ),
      ),
    );
    final r = await widget.api.command('briefing today');
    if (!mounted) return;
    Navigator.pop(context);
    r.when(
      success: (data) {
        if (data['type'] != 'success') {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(translateErrorFr(data['message']?.toString() ?? 'erreur')),
            backgroundColor: Colors.red.shade900,
          ));
          return;
        }
        final result = data['result'] as Map<String, dynamic>;
        final answer = result['answer'] as String? ?? '(pas de réponse)';
        final ctx = result['context_snapshot'] as Map<String, dynamic>? ?? const {};
        final shiftsToday = (ctx['shifts_today'] as List<dynamic>?) ?? const [];
        showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Row(children: [
              Icon(Icons.wb_sunny, color: BrocBrand.brocYellow),
              SizedBox(width: 8),
              Text('Briefing du jour'),
            ]),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (shiftsToday.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: BrocBrand.brocRed.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${shiftsToday.length} shift(s) aujourd\'hui',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: BrocBrand.brocYellow),
                        ),
                      ),
                    Text(answer, style: const TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fermer'),
              ),
            ],
          ),
        );
      },
      failure: (e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(translateErrorFr(e.message)),
        backgroundColor: Colors.red.shade900,
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      PersonnelScreen(api: widget.api),
      KitchenScreen(api: widget.api),
      MenuListScreen(api: widget.api),
      ShoppingScreen(api: widget.api),
      QuestionScreen(api: widget.api),
      JournalScreen(api: widget.api),
      CostsScreen(api: widget.api),
      WasteScreen(api: widget.api),
      TablesScreen(api: widget.api),
      SettingsScreen(api: widget.api),
      AdminScreen(api: widget.api),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Le Broc'),
        actions: [
          IconButton(
            icon: const Icon(Icons.wb_sunny),
            tooltip: 'Briefing matinal Claude',
            onPressed: _showMorningBriefing,
          ),
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
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.groups), label: 'Personnel'),
          NavigationDestination(icon: Icon(Icons.restaurant), label: 'Cuisine'),
          NavigationDestination(icon: Icon(Icons.menu_book), label: 'Carte'),
          NavigationDestination(icon: Icon(Icons.shopping_cart), label: 'Courses'),
          NavigationDestination(icon: Icon(Icons.psychology), label: 'Question'),
          NavigationDestination(icon: Icon(Icons.fact_check), label: 'Journal'),
          NavigationDestination(icon: Icon(Icons.euro), label: 'Coûts'),
          NavigationDestination(icon: Icon(Icons.delete_outline), label: 'Pertes'),
          NavigationDestination(icon: Icon(Icons.qr_code), label: 'Tables'),
          NavigationDestination(icon: Icon(Icons.admin_panel_settings), label: 'Paramètres'),
          NavigationDestination(icon: Icon(Icons.shield), label: 'Admin'),
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

  Future<void> _editWeekly(Map<String, dynamic> emp) async {
    final roles = ((emp['roles'] as List<dynamic>?) ?? const []).cast<String>();
    if (roles.isEmpty) {
      _snack('Pas de rôles configurés', isError: true);
      return;
    }
    final initialWeekly = (emp['weekly_default'] as Map<String, dynamic>?) ?? const {};
    final selection = <int, String?>{
      for (var d = 1; d <= 7; d++) d: initialWeekly[d.toString()] as String?,
    };
    final days = const [
      (1, 'Lundi'),
      (2, 'Mardi'),
      (3, 'Mercredi'),
      (4, 'Jeudi'),
      (5, 'Vendredi'),
      (6, 'Samedi'),
      (7, 'Dimanche'),
    ];
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, set) {
        return AlertDialog(
          title: Text('Planning hebdo — ${emp['name']}'),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Pour chaque jour, le rôle par défaut (vide = défaut employé / résolution auto)',
                    style: TextStyle(fontSize: 11, color: BrocBrand.brocCream),
                  ),
                  const SizedBox(height: 12),
                  for (final d in days)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 90,
                            child: Text(d.$2, style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          Expanded(
                            child: DropdownButton<String?>(
                              isExpanded: true,
                              value: selection[d.$1],
                              hint: const Text('— aucun —'),
                              items: [
                                const DropdownMenuItem<String?>(value: null, child: Text('— aucun —')),
                                for (final r in roles)
                                  DropdownMenuItem<String?>(value: r, child: Text(r)),
                              ],
                              onChanged: (v) => set(() => selection[d.$1] = v),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Enregistrer')),
          ],
        );
      }),
    );
    if (ok != true) return;
    final scheduleArg = selection.entries
        .where((e) => e.value != null)
        .map((e) => '${e.key}=${e.value}')
        .join(',');
    if (scheduleArg.isEmpty) {
      _snack('Aucun jour sélectionné — rien à enregistrer');
      return;
    }
    final r = await widget.api.command(
      'employee set-weekly --employee ${emp['id']} --schedule $scheduleArg --actor manager:seb',
    );
    if (!mounted) return;
    r.when(
      success: (data) {
        if (data['type'] == 'success') {
          _snack('Planning hebdo sauvegardé ✓');
          _refresh();
        } else {
          _snack(data['message']?.toString() ?? 'erreur', isError: true);
        }
      },
      failure: (e) => _snack(e.message, isError: true),
    );
  }

  Future<void> _editRoles(Map<String, dynamic> emp) async {
    final currentRoles = ((emp['roles'] as List<dynamic>?) ?? const [])
        .cast<String>()
        .toSet();
    String? defaultRole = emp['default_role'] as String?;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, set) {
        return AlertDialog(
          title: Text('Rôles — ${emp['name']}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Capabilities (cocher) :', style: TextStyle(fontSize: 11)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final r in const [
                      'manager', 'server', 'runner', 'cook', 'bartender', 'dishwasher', 'host',
                    ])
                      FilterChip(
                        label: Text(r),
                        selected: currentRoles.contains(r),
                        onSelected: (v) => set(() {
                          if (v) {
                            currentRoles.add(r);
                          } else {
                            currentRoles.remove(r);
                            if (defaultRole == r) defaultRole = null;
                          }
                        }),
                        selectedColor: BrocBrand.brocRed,
                        checkmarkColor: BrocBrand.brocCream,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Rôle par défaut :', style: TextStyle(fontSize: 11)),
                DropdownButton<String>(
                  value: currentRoles.contains(defaultRole) ? defaultRole : null,
                  hint: const Text('Auto'),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem<String>(value: null, child: Text('Auto')),
                    for (final r in currentRoles)
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
              onPressed: currentRoles.isEmpty ? null : () => Navigator.pop(context, true),
              child: const Text('Enregistrer'),
            ),
          ],
        );
      }),
    );
    if (ok != true || currentRoles.isEmpty) return;
    final rolesArg = currentRoles.join(',');
    final defaultArg = defaultRole != null ? ' --default-role $defaultRole' : '';
    final r = await widget.api.command(
      'employee set-roles --employee ${emp['id']} --roles $rolesArg$defaultArg --actor manager:seb',
    );
    if (!mounted) return;
    r.when(
      success: (data) {
        if (data['type'] == 'success') {
          _snack('Rôles mis à jour ✓');
          _refresh();
        } else {
          _snack(data['message']?.toString() ?? 'erreur', isError: true);
        }
      },
      failure: (e) => _snack(e.message, isError: true),
    );
  }

  Future<void> _generateOnboarding(Map<String, dynamic> emp) async {
    final roles = ((emp['roles'] as List<dynamic>?) ?? const []).cast<String>();
    if (roles.isEmpty) {
      _snack('Pas de rôles configurés', isError: true);
      return;
    }
    final role = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: Text('Onboarding pour ${emp['name']} — choisis le rôle'),
        children: roles.map((r) =>
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, r),
            child: Text(r),
          ),
        ).toList(),
      ),
    );
    if (role == null) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        title: Row(children: [
          Icon(Icons.school, color: Colors.lightBlueAccent),
          SizedBox(width: 8),
          Text('Onboarding'),
        ]),
        content: SizedBox(
          width: 300,
          height: 100,
          child: Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Claude génère la checklist...'),
            ]),
          ),
        ),
      ),
    );
    final r = await widget.api.command(
      'onboarding generate --employee ${emp['id']} --role $role --actor manager:seb',
    );
    if (!mounted) return;
    Navigator.pop(context);
    r.when(
      success: (data) {
        if (data['type'] != 'success') {
          _snack(data['message']?.toString() ?? 'erreur', isError: true);
          return;
        }
        final checklist = data['result'] as Map<String, dynamic>;
        _showOnboardingChecklist(checklist);
      },
      failure: (e) => _snack(e.message, isError: true),
    );
  }

  void _showOnboardingChecklist(Map<String, dynamic> checklist) {
    showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, set) {
        final items = ((checklist['items'] as List<dynamic>?) ?? const [])
            .cast<Map<String, dynamic>>();
        final checked = items.where((i) => i['done'] as bool? ?? false).length;
        return AlertDialog(
          title: Row(children: [
            const Icon(Icons.school, color: Colors.lightBlueAccent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Onboarding ${checklist['role']} ($checked/${items.length})',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: items.asMap().entries.map((entry) {
                  final i = entry.key;
                  final item = entry.value;
                  final done = item['done'] as bool? ?? false;
                  return CheckboxListTile(
                    value: done,
                    title: Text(
                      item['label'] as String,
                      style: TextStyle(
                        decoration: done ? TextDecoration.lineThrough : null,
                        color: done ? Colors.grey : null,
                      ),
                    ),
                    onChanged: (v) async {
                      final r = await widget.api.command(
                        'onboarding ${v == true ? "check" : "uncheck"} --checklist ${checklist['id']} --item $i --actor employee:${checklist['employee_id']}',
                      );
                      r.when(
                        success: (data) {
                          if (data['type'] == 'success') {
                            set(() {
                              items[i] = {...item, 'done': v ?? false};
                            });
                          }
                        },
                        failure: (_) {},
                      );
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fermer'),
            ),
          ],
        );
      }),
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
                              const PopupMenuItem<String>(
                                value: 'weekly',
                                child: Row(
                                  children: [
                                    Icon(Icons.calendar_month, size: 18, color: Colors.purpleAccent),
                                    SizedBox(width: 8),
                                    Text('Planning hebdo'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem<String>(
                                value: 'roles',
                                child: Row(
                                  children: [
                                    Icon(Icons.checklist, size: 18, color: BrocBrand.brocYellow),
                                    SizedBox(width: 8),
                                    Text('Modifier les rôles'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem<String>(
                                value: 'onboarding',
                                child: Row(
                                  children: [
                                    Icon(Icons.school, size: 18, color: Colors.lightBlueAccent),
                                    SizedBox(width: 8),
                                    Text('Onboarding par rôle'),
                                  ],
                                ),
                              ),
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
                              if (v == 'weekly') _editWeekly(e);
                              if (v == 'roles') _editRoles(e);
                              if (v == 'onboarding') _generateOnboarding(e);
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

  Future<void> _openCardItemsForAvailability(String cardId) async {
    final r = await widget.api.get('/api/menu/cards/current');
    if (!mounted) return;
    Map<String, dynamic>? card;
    r.when(success: (data) => card = data, failure: (_) {});
    if (card == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Aucune carte publiée pour gérer 86.'),
        backgroundColor: BrocBrand.brocRed,
      ));
      return;
    }
    final items = ((card!['items'] as List?) ?? const []).cast<Map<String, dynamic>>();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: BrocBrand.brocBlack,
      isScrollControlled: true,
      builder: (_) {
        return StatefulBuilder(builder: (ctx, setLocal) {
          return DraggableScrollableSheet(
            initialChildSize: 0.85,
            expand: false,
            builder: (_, ctrl) {
              return ListView(
                controller: ctrl,
                padding: const EdgeInsets.all(16),
                children: [
                  Row(children: [
                    const Icon(Icons.no_food, color: BrocBrand.brocRed),
                    const SizedBox(width: 8),
                    Text('Mode 86 / Rupture — carte v${card!['version']}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 4),
                  const Text(
                    'Désactive un plat quand un ingrédient manque. La carte publique se met à jour automatiquement.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const Divider(),
                  for (final item in items)
                    Card(
                      color: BrocBrand.brocBlack.withValues(alpha: 0.6),
                      child: SwitchListTile(
                        title: Text(
                          item['name'] as String,
                          style: TextStyle(
                            decoration: (item['available'] as bool? ?? true)
                                ? null
                                : TextDecoration.lineThrough,
                            color: (item['available'] as bool? ?? true)
                                ? null
                                : Colors.grey,
                          ),
                        ),
                        subtitle: item['unavailable_reason'] != null
                            ? Text('Rupture : ${item['unavailable_reason']}',
                                style: const TextStyle(color: BrocBrand.brocRed, fontSize: 11))
                            : Text('${((item['price_cents'] as int) / 100).toStringAsFixed(2)} €',
                                style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        value: item['available'] as bool? ?? true,
                        activeThumbColor: BrocBrand.brocYellow,
                        onChanged: (newVal) async {
                          String? reason;
                          if (!newVal) {
                            final ctrl = TextEditingController();
                            reason = await showDialog<String>(
                              context: ctx,
                              builder: (_) => AlertDialog(
                                title: const Text('Pourquoi le mettre en rupture ?'),
                                content: TextField(
                                  controller: ctrl,
                                  autofocus: true,
                                  decoration: const InputDecoration(
                                    hintText: 'ex: plus de saumon, livraison demain',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Annuler')),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(context, ctrl.text.trim()),
                                    style: FilledButton.styleFrom(backgroundColor: BrocBrand.brocRed),
                                    child: const Text('Confirmer'),
                                  ),
                                ],
                              ),
                            );
                            if (reason == null) return;
                          }
                          final r = await widget.api.post(
                            '/api/menu/items/${item['id']}/availability',
                            {
                              'available': newVal,
                              if (reason != null) 'reason': reason,
                              'actor': 'manager',
                            },
                          );
                          if (!ctx.mounted) return;
                          r.when(
                            success: (data) {
                              setLocal(() {
                                item['available'] = newVal;
                                item['unavailable_reason'] = reason;
                              });
                              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                                content: Text(newVal
                                    ? '${item['name']} disponible à nouveau'
                                    : '${item['name']} en rupture'),
                                backgroundColor: BrocBrand.brocRed,
                              ));
                            },
                            failure: (e) => ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                              content: Text(translateErrorFr(e.message)),
                              backgroundColor: Colors.red.shade900,
                            )),
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          );
        });
      },
    );
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
                          if (pub)
                            IconButton(
                              tooltip: 'Mode 86 / Rupture',
                              icon: const Icon(Icons.no_food, color: BrocBrand.brocYellow),
                              onPressed: () => _openCardItemsForAvailability(c['id'] as String),
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

// ===========================================================================
// Journal (observability bienveillante)
// ===========================================================================
class JournalScreen extends StatefulWidget {
  final BrWebApi api;
  const JournalScreen({super.key, required this.api});
  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  List<Map<String, dynamic>> _events = [];
  String? _filterActor;
  String? _filterAction;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final args = <String>['events list --limit 200'];
    if (_filterActor != null && _filterActor!.isNotEmpty) {
      args.add('--actor "$_filterActor"');
    }
    if (_filterAction != null && _filterAction!.isNotEmpty) {
      args.add('--action $_filterAction');
    }
    final r = await widget.api.command(args.join(' '));
    if (!mounted) return;
    r.when(
      success: (data) {
        if (data['type'] == 'success') {
          _events = ((data['result']['events'] as List<dynamic>?) ?? const [])
              .cast<Map<String, dynamic>>();
        }
        setState(() => _loading = false);
      },
      failure: (_) => setState(() => _loading = false),
    );
  }

  static IconData _iconFor(String action) {
    if (action.startsWith('shift.')) return Icons.access_time;
    if (action.startsWith('segment.')) return Icons.swap_horiz;
    if (action.startsWith('break.')) return Icons.local_cafe;
    if (action.startsWith('employee.')) return Icons.person;
    if (action.startsWith('hourly_rate')) return Icons.euro;
    if (action.startsWith('staff_consumption')) return Icons.fastfood;
    if (action.startsWith('menu_card.')) return Icons.menu_book;
    if (action.startsWith('shopping_item.')) return Icons.shopping_cart;
    if (action.startsWith('question.')) return Icons.psychology;
    return Icons.bolt;
  }

  static Color _colorFor(String action) {
    if (action.contains('compliance')) return Colors.orange;
    if (action.contains('archive')) return Colors.redAccent;
    if (action.contains('role_changed') || action.contains('weekly_changed')) {
      return Colors.purpleAccent;
    }
    if (action.contains('started')) return Colors.greenAccent;
    if (action.contains('ended') || action.contains('closed')) return Colors.redAccent;
    return BrocBrand.brocYellow;
  }

  static String _fmtTime(String iso) {
    try {
      final d = DateTime.parse(iso).toLocal();
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} '
          '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.small(
        onPressed: _refresh,
        tooltip: 'Rafraîchir',
        child: const Icon(Icons.refresh),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Acteur (ex: manager:seb)',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (v) {
                      _filterActor = v.trim().isEmpty ? null : v.trim();
                      _refresh();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Action (ex: shift.started)',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (v) {
                      _filterAction = v.trim().isEmpty ? null : v.trim();
                      _refresh();
                    },
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Text('${_events.length} événements',
                    style: const TextStyle(color: BrocBrand.brocYellow, fontSize: 12)),
                const Spacer(),
                if (_filterActor != null || _filterAction != null)
                  TextButton(
                    onPressed: () {
                      _filterActor = null;
                      _filterAction = null;
                      _refresh();
                    },
                    child: const Text('Effacer filtres'),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _events.isEmpty
                    ? const Center(child: Text('Aucun événement.'))
                    : ListView.builder(
                        itemCount: _events.length,
                        itemBuilder: (_, i) {
                          final e = _events[i];
                          final action = e['action'] as String;
                          final actor = e['actor'] as String;
                          final target = e['target'] as String?;
                          final reason = e['reason'] as String?;
                          final payload = e['payload'] as Map<String, dynamic>? ?? const {};
                          final summary = _summarizePayload(payload);
                          return ListTile(
                            dense: true,
                            leading: Icon(_iconFor(action), color: _colorFor(action)),
                            title: Text('$actor → $action',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_fmtTime(e['at'] as String)}  ${target ?? ""}',
                                  style: const TextStyle(fontSize: 11, color: Color(0xff9ca3af)),
                                ),
                                if (summary.isNotEmpty)
                                  Text(summary,
                                      style: const TextStyle(fontSize: 11)),
                                if (reason != null && reason.isNotEmpty)
                                  Text('« $reason »',
                                      style: const TextStyle(
                                          fontStyle: FontStyle.italic,
                                          fontSize: 11,
                                          color: BrocBrand.brocYellow)),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  static String _summarizePayload(Map<String, dynamic> p) {
    if (p.isEmpty) return '';
    final keys = ['from_role', 'to_role', 'role', 'rate_cents', 'amount_cents', 'label', 'duration_minutes'];
    final parts = <String>[];
    for (final k in keys) {
      if (p.containsKey(k) && p[k] != null) {
        parts.add('$k=${p[k]}');
      }
    }
    return parts.join(' · ');
  }
}

// ===========================================================================
// Coûts (taux horaires + conso staff + total jour)
// ===========================================================================
class CostsScreen extends StatefulWidget {
  final BrWebApi api;
  const CostsScreen({super.key, required this.api});
  @override
  State<CostsScreen> createState() => _CostsScreenState();
}

class _CostsScreenState extends State<CostsScreen> {
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _rates = [];
  List<Map<String, dynamic>> _consumptions = [];
  List<Map<String, dynamic>> _shifts = [];
  int _totalConsumptionCents = 0;
  int _totalTipsCents = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final empR = await widget.api.get('/api/employees');
    final ratesR = await widget.api.command('rate list');
    final consR = await widget.api.command('consumption list');
    final shiftsR = await widget.api.command('shift list');
    if (!mounted) return;
    setState(() {
      _employees = empR.valueOrNull == null
          ? []
          : (empR.valueOrNull!['employees'] as List<dynamic>).cast<Map<String, dynamic>>();
      if (ratesR.valueOrNull?['type'] == 'success') {
        _rates = ((ratesR.valueOrNull!['result']['rates'] as List<dynamic>?) ?? const [])
            .cast<Map<String, dynamic>>();
      }
      if (consR.valueOrNull?['type'] == 'success') {
        final result = consR.valueOrNull!['result'] as Map<String, dynamic>;
        _consumptions = ((result['items'] as List<dynamic>?) ?? const [])
            .cast<Map<String, dynamic>>();
        _totalConsumptionCents = result['total_cents'] as int? ?? 0;
      }
      if (shiftsR.valueOrNull?['type'] == 'success') {
        _shifts = ((shiftsR.valueOrNull!['result']['shifts'] as List<dynamic>?) ?? const [])
            .cast<Map<String, dynamic>>();
        _totalTipsCents = _shifts.fold<int>(
          0,
          (a, s) => a + ((s['tip_cents'] as int?) ?? 0),
        );
      }
      _loading = false;
    });
  }

  Future<void> _setTip(Map<String, dynamic> shift) async {
    final ctrl = TextEditingController(text: ((shift['tip_cents'] as int?) ?? 0).toString());
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Pourboire — shift ${(shift['id'] as String).substring(0, 8)}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Employé : ${_empName(shift['employee_id'] as String)}',
              style: const TextStyle(fontSize: 11),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Pourboire (cents, 1500 = 15 €)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Enregistrer')),
        ],
      ),
    );
    if (ok != true) return;
    final cents = int.tryParse(ctrl.text);
    if (cents == null || cents < 0) {
      _snack('Montant invalide', isError: true);
      return;
    }
    final r = await widget.api.command(
      'tip set --shift ${shift['id']} --cents $cents --actor manager:seb',
    );
    if (!mounted) return;
    r.when(
      success: (data) {
        if (data['type'] == 'success') {
          _snack('Pourboire enregistré ✓');
          _refresh();
        } else {
          _snack(data['message']?.toString() ?? 'erreur', isError: true);
        }
      },
      failure: (e) => _snack(e.message, isError: true),
    );
  }

  void _snack(String s, {bool isError = false}) {
    final m = isError ? translateErrorFr(s) : s;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(m),
      backgroundColor: isError ? Colors.red.shade900 : null,
    ));
  }

  String _empName(String id) {
    final e = _employees.where((x) => x['id'] == id).firstOrNull;
    return e?['name'] as String? ?? id;
  }

  static String _fmtCents(int c) {
    final euros = c ~/ 100;
    final cents = c % 100;
    return cents == 0
        ? '$euros €'
        : '$euros,${cents.toString().padLeft(2, '0')} €';
  }

  Future<void> _setRate() async {
    if (_employees.isEmpty) return;
    String? empId = _employees.first['id'] as String;
    String? role;
    final centsCtrl = TextEditingController(text: '1500');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, set) {
        final emp = _employees.firstWhere((x) => x['id'] == empId);
        final roles = ((emp['roles'] as List<dynamic>?) ?? const []).cast<String>();
        return AlertDialog(
          title: const Text('Définir un taux horaire'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Employé :', style: TextStyle(fontSize: 11)),
                DropdownButton<String>(
                  isExpanded: true,
                  value: empId,
                  items: _employees
                      .map((e) => DropdownMenuItem<String>(
                          value: e['id'] as String,
                          child: Text(e['name'] as String)))
                      .toList(),
                  onChanged: (v) => set(() {
                    empId = v;
                    role = null;
                  }),
                ),
                const SizedBox(height: 8),
                const Text('Rôle (vide = tous) :', style: TextStyle(fontSize: 11)),
                DropdownButton<String>(
                  isExpanded: true,
                  value: role,
                  hint: const Text('Tous rôles'),
                  items: [
                    const DropdownMenuItem<String>(value: null, child: Text('Tous rôles (global)')),
                    for (final r in roles)
                      DropdownMenuItem<String>(value: r, child: Text(r)),
                  ],
                  onChanged: (v) => set(() => role = v),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: centsCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Taux (en centimes — 1500 = 15 €/h)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Définir')),
          ],
        );
      }),
    );
    if (ok != true) return;
    final cents = int.tryParse(centsCtrl.text);
    if (cents == null || cents <= 0) {
      _snack('Montant invalide', isError: true);
      return;
    }
    final roleArg = role != null ? ' --role $role' : '';
    final r = await widget.api.command(
      'rate set --employee $empId --cents $cents$roleArg --actor manager:seb',
    );
    if (!mounted) return;
    r.when(
      success: (data) {
        if (data['type'] == 'success') {
          _snack('Taux défini ✓');
          _refresh();
        } else {
          _snack(data['message']?.toString() ?? 'erreur', isError: true);
        }
      },
      failure: (e) => _snack(e.message, isError: true),
    );
  }

  Future<void> _recordConsumption() async {
    if (_employees.isEmpty) return;
    String? empId = _employees.first['id'] as String;
    final labelCtrl = TextEditingController();
    final centsCtrl = TextEditingController(text: '300');
    bool paid = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, set) {
        return AlertDialog(
          title: const Text('Enregistrer une consommation staff'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Employé :', style: TextStyle(fontSize: 11)),
                DropdownButton<String>(
                  isExpanded: true,
                  value: empId,
                  items: _employees
                      .map((e) => DropdownMenuItem<String>(
                          value: e['id'] as String,
                          child: Text(e['name'] as String)))
                      .toList(),
                  onChanged: (v) => set(() => empId = v),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: labelCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Article (ex: café, demi, plat du jour)',
                  ),
                  autofocus: true,
                ),
                TextField(
                  controller: centsCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Montant (centimes — 300 = 3 €)',
                  ),
                ),
                CheckboxListTile(
                  value: paid,
                  onChanged: (v) => set(() => paid = v ?? false),
                  title: const Text('Déjà payé (sinon à débiter sur salaire)'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Enregistrer')),
          ],
        );
      }),
    );
    if (ok != true) return;
    final cents = int.tryParse(centsCtrl.text);
    if (cents == null || cents <= 0 || labelCtrl.text.trim().isEmpty) {
      _snack('Article et montant requis', isError: true);
      return;
    }
    final paidArg = paid ? ' --paid' : '';
    final r = await widget.api.command(
      'consumption record --employee $empId --label "${labelCtrl.text}" --cents $cents$paidArg --actor manager:seb',
    );
    if (!mounted) return;
    r.when(
      success: (data) {
        if (data['type'] == 'success') {
          _snack('Conso enregistrée ✓');
          _refresh();
        } else {
          _snack(data['message']?.toString() ?? 'erreur', isError: true);
        }
      },
      failure: (e) => _snack(e.message, isError: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'rate',
            onPressed: _setRate,
            tooltip: 'Définir un taux horaire',
            child: const Icon(Icons.euro),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: 'cons',
            onPressed: _recordConsumption,
            icon: const Icon(Icons.fastfood),
            label: const Text('Conso staff'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 200),
              children: [
                // Totals : 2 bandeaux side by side
                Row(children: [
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(12, 12, 6, 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: BrocBrand.brocRed.withValues(alpha: 0.15),
                        border: Border.all(color: BrocBrand.brocRed),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Conso staff',
                              style: TextStyle(color: BrocBrand.brocYellow, fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(_fmtCents(_totalConsumptionCents),
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                          Text('${_consumptions.length} entries',
                              style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(6, 12, 12, 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: BrocBrand.brocYellow.withValues(alpha: 0.15),
                        border: Border.all(color: BrocBrand.brocYellow),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('💰 Pourboires totaux',
                              style: TextStyle(color: BrocBrand.brocYellow, fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(_fmtCents(_totalTipsCents),
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                          Text('${_shifts.where((s) => (s['tip_cents'] as int? ?? 0) > 0).length} shifts',
                              style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ]),
                // Heatmap 7 jours
                _Heatmap7DaysCard(shifts: _shifts, employees: _employees),
                // Taux horaires
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text('TAUX HORAIRES',
                      style: TextStyle(
                          color: BrocBrand.brocYellow,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1)),
                ),
                if (_rates.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Aucun taux défini.\nClique 💶 pour en définir un.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey)),
                  )
                else
                  ..._rates.map((r) {
                    final endStr = r['valid_to'] as String?;
                    final isCurrent = endStr == null;
                    return ListTile(
                      dense: true,
                      leading: Icon(Icons.euro,
                          color: isCurrent ? BrocBrand.brocYellow : Colors.grey),
                      title: Text(
                        '${_empName(r['employee_id'] as String)}'
                        '${r['role'] != null ? " · ${r['role']}" : " · tous rôles"}',
                        style: TextStyle(
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                            color: isCurrent ? null : Colors.grey),
                      ),
                      subtitle: Text(
                        '${_fmtCents(r['rate_cents'] as int)}/h  ·  depuis ${_JournalScreenState._fmtTime(r['valid_from'] as String)}'
                        '${endStr != null ? "  ·  jusqu'au ${_JournalScreenState._fmtTime(endStr)}" : "  ·  actif"}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    );
                  }),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text('CONSOMMATIONS STAFF',
                      style: TextStyle(
                          color: BrocBrand.brocYellow,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1)),
                ),
                if (_consumptions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Aucune consommation.\nClique « Conso staff » pour enregistrer.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey)),
                  )
                else
                  ..._consumptions.map((c) {
                    final paid = c['paid'] as bool? ?? false;
                    return ListTile(
                      dense: true,
                      leading: Icon(Icons.fastfood,
                          color: paid ? Colors.green : Colors.orange),
                      title: Text(
                        '${c['label']}  ·  ${_fmtCents(c['amount_cents'] as int)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${_empName(c['employee_id'] as String)}  ·  ${_JournalScreenState._fmtTime(c['consumed_at'] as String)}  ·  ${paid ? "payé" : "à débiter"}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    );
                  }),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text('POURBOIRES PAR SHIFT',
                      style: TextStyle(
                          color: BrocBrand.brocYellow,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1)),
                ),
                if (_shifts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Aucun shift enregistré.\nLes shifts terminés apparaîtront ici pour renseigner les pourboires.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                else
                  ..._shifts.take(15).map((s) {
                    final tipCents = (s['tip_cents'] as int?) ?? 0;
                    final hasTip = tipCents > 0;
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        Icons.savings,
                        color: hasTip ? Colors.greenAccent : Colors.grey,
                      ),
                      title: Text(
                        '${_empName(s['employee_id'] as String)}  ·  ${_fmtCents(tipCents)}',
                        style: TextStyle(
                            fontWeight: hasTip ? FontWeight.bold : FontWeight.normal,
                            color: hasTip ? null : Colors.grey),
                      ),
                      subtitle: Text(
                        '${_JournalScreenState._fmtTime(s['starts_at'] as String)}  ·  ${s['status']}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: IconButton(
                        tooltip: 'Modifier le pourboire',
                        icon: const Icon(Icons.edit, size: 16),
                        onPressed: () => _setTip(s),
                      ),
                    );
                  }),
              ],
            ),
    );
  }
}

// ===========================================================================
// Heatmap 7 jours — somme heures travaillées par employé × jour
// ===========================================================================
class _Heatmap7DaysCard extends StatelessWidget {
  final List<Map<String, dynamic>> shifts;
  final List<Map<String, dynamic>> employees;
  const _Heatmap7DaysCard({required this.shifts, required this.employees});

  static const _dayLabels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    // last 7 days (oldest → today)
    final days = List.generate(
        7, (i) => DateTime(now.year, now.month, now.day - (6 - i)));

    // For each employee, sum hours per day
    final grid = <String, Map<int, double>>{};
    for (final emp in employees) {
      grid[emp['id'] as String] = {for (var i = 0; i < 7; i++) i: 0};
    }
    double maxHours = 0;
    for (final s in shifts) {
      final empId = s['employee_id'] as String;
      if (!grid.containsKey(empId)) continue;
      final start = DateTime.parse(s['starts_at'] as String).toLocal();
      final end = s['ends_at'] != null
          ? DateTime.parse(s['ends_at'] as String).toLocal()
          : DateTime.now();
      final duration = end.difference(start).inMinutes / 60.0;
      for (var i = 0; i < 7; i++) {
        if (start.year == days[i].year &&
            start.month == days[i].month &&
            start.day == days[i].day) {
          grid[empId]![i] = (grid[empId]![i] ?? 0) + duration;
          if (grid[empId]![i]! > maxHours) maxHours = grid[empId]![i]!;
          break;
        }
      }
    }

    Color cellColor(double hours) {
      if (hours <= 0) return Colors.grey.shade900;
      final intensity = (maxHours > 0 ? hours / maxHours : 0.0).clamp(0.15, 1.0).toDouble();
      return BrocBrand.brocRed.withValues(alpha: intensity);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xff1f1818),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BrocBrand.brocRed.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🔥 ACTIVITÉ 7 DERNIERS JOURS',
              style: TextStyle(
                  color: BrocBrand.brocYellow,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  fontSize: 12)),
          const SizedBox(height: 8),
          // Header (day labels)
          Row(children: [
            const SizedBox(width: 80),
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Center(
                  child: Column(children: [
                    Text(_dayLabels[days[i].weekday - 1],
                        style: const TextStyle(
                            fontSize: 10,
                            color: BrocBrand.brocCream,
                            fontWeight: FontWeight.bold)),
                    Text(days[i].day.toString().padLeft(2, '0'),
                        style: const TextStyle(fontSize: 8, color: Colors.grey)),
                  ]),
                ),
              ),
          ]),
          const SizedBox(height: 4),
          // Rows employees
          if (employees.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: Text('Aucun employé', style: TextStyle(color: Colors.grey))),
            )
          else
            ...employees.take(8).map((emp) {
              final empId = emp['id'] as String;
              final daysHours = grid[empId] ?? const <int, double>{};
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  SizedBox(
                    width: 80,
                    child: Text(
                      emp['name'] as String,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                  for (var i = 0; i < 7; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1),
                        child: Tooltip(
                          message:
                              '${emp['name']} · ${_dayLabels[days[i].weekday - 1]} ${days[i].day}/${days[i].month}: ${(daysHours[i] ?? 0).toStringAsFixed(1)}h',
                          child: Container(
                            height: 22,
                            decoration: BoxDecoration(
                              color: cellColor(daysHours[i] ?? 0),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: (daysHours[i] ?? 0) > 0
                                ? Center(
                                    child: Text(
                                      (daysHours[i] ?? 0).toStringAsFixed(1),
                                      style: TextStyle(
                                          fontSize: 9,
                                          color: (daysHours[i] ?? 0) > maxHours * 0.5
                                              ? Colors.white
                                              : BrocBrand.brocCream,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                ]),
              );
            }),
          if (maxHours > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const Text('Max:', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  const SizedBox(width: 4),
                  Container(width: 12, height: 12, color: BrocBrand.brocRed),
                  const SizedBox(width: 4),
                  Text('${maxHours.toStringAsFixed(1)}h',
                      style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Cuisine — kanban tickets + cooking tasks + commande vocale
// ===========================================================================
class KitchenScreen extends StatefulWidget {
  final BrWebApi api;
  const KitchenScreen({super.key, required this.api});
  @override
  State<KitchenScreen> createState() => _KitchenScreenState();
}

class _KitchenScreenState extends State<KitchenScreen> {
  List<Map<String, dynamic>> _tickets = [];
  List<Map<String, dynamic>> _tasks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final tR = await widget.api.command('ticket list');
    final cR = await widget.api.command('cooking list');
    if (!mounted) return;
    setState(() {
      if (tR.valueOrNull?['type'] == 'success') {
        _tickets = ((tR.valueOrNull!['result']['tickets'] as List<dynamic>?) ?? const [])
            .cast<Map<String, dynamic>>();
      }
      if (cR.valueOrNull?['type'] == 'success') {
        _tasks = ((cR.valueOrNull!['result']['tasks'] as List<dynamic>?) ?? const [])
            .cast<Map<String, dynamic>>();
      }
      _loading = false;
    });
  }

  void _snack(String s, {bool isError = false}) {
    final m = isError ? translateErrorFr(s) : s;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(m),
      backgroundColor: isError ? Colors.red.shade900 : null,
    ));
  }

  Future<void> _signalRupture() async {
    final cardRes = await widget.api.get('/api/menu/cards/current');
    if (!mounted) return;
    Map<String, dynamic>? card;
    cardRes.when(success: (d) => card = d, failure: (_) {});
    if (card == null) {
      _snack('Aucune carte publiée — ajoute des items via l\'onglet Carte d\'abord.', isError: true);
      return;
    }
    final items = ((card!['items'] as List?) ?? const []).cast<Map<String, dynamic>>();
    if (items.isEmpty) {
      _snack('La carte publiée est vide.', isError: true);
      return;
    }

    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: BrocBrand.brocBlack,
      isScrollControlled: true,
      builder: (sheetCtx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        expand: false,
        builder: (_, ctrl) => ListView(
          controller: ctrl,
          padding: const EdgeInsets.all(16),
          children: [
            const Row(children: [
              Icon(Icons.no_food, color: BrocBrand.brocYellow),
              SizedBox(width: 8),
              Text('Quel plat est en rupture ?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 12),
            for (final it in items.where((i) => i['available'] as bool? ?? true))
              ListTile(
                title: Text(it['name'] as String),
                subtitle: Text(
                  '${((it['price_cents'] as int) / 100).toStringAsFixed(2)} €',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                trailing: const Icon(Icons.chevron_right, color: BrocBrand.brocRed),
                onTap: () => Navigator.pop(sheetCtx, it),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('${picked['name']} — pourquoi en rupture ?'),
        content: TextField(
          controller: reasonCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'ex: plus de saumon, livraison demain',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(context, reasonCtrl.text.trim()),
            style: FilledButton.styleFrom(backgroundColor: BrocBrand.brocRed),
            child: const Text('Signaler'),
          ),
        ],
      ),
    );
    if (reason == null) return;
    final r = await widget.api.post(
      '/api/menu/items/${picked['id']}/availability',
      {'available': false, 'reason': reason, 'actor': 'cook'},
    );
    if (!mounted) return;
    r.when(
      success: (_) => _snack('${picked['name']} en rupture. Carte client mise à jour.'),
      failure: (e) => _snack(e.message, isError: true),
    );
  }

  Future<void> _newVoiceOrder() async {
    final textCtrl = TextEditingController();
    final tableCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.mic, color: BrocBrand.brocRed),
          SizedBox(width: 8),
          Text('Nouvelle commande'),
        ]),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Dicte la commande à voix haute (utilise la dictée iOS/macOS) ou tape-la.\n'
                'Claude va la parser en items structurés + table.',
                style: TextStyle(fontSize: 11, color: Color(0xff9ca3af)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: tableCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Table (optionnel — Claude détecte sinon)',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: textCtrl,
                autofocus: true,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Commande',
                  hintText: 'ex: « table 5 deux ricards une entrecôte saignante frites un magret rosé »',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Parser via Claude'),
          ),
        ],
      ),
    );
    if (ok != true || textCtrl.text.trim().isEmpty) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: SizedBox(
          width: 280,
          height: 80,
          child: Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              CircularProgressIndicator(color: BrocBrand.brocRed),
              SizedBox(height: 8),
              Text('Claude parse la commande...'),
            ]),
          ),
        ),
      ),
    );
    final escapedText = textCtrl.text.replaceAll('"', '\\"');
    final tableArg =
        tableCtrl.text.isNotEmpty ? ' --table ${tableCtrl.text}' : '';
    final r = await widget.api.command(
      'ticket parse --text "$escapedText"$tableArg --actor server',
    );
    if (!mounted) return;
    Navigator.pop(context);
    r.when(
      success: (data) {
        if (data['type'] != 'success') {
          _snack(data['message']?.toString() ?? 'erreur', isError: true);
          return;
        }
        final ticket = data['result'] as Map<String, dynamic>;
        _showDraftPreview(ticket);
      },
      failure: (e) => _snack(e.message, isError: true),
    );
  }

  void _showDraftPreview(Map<String, dynamic> ticket) {
    final items = ((ticket['items'] as List<dynamic>?) ?? const [])
        .cast<Map<String, dynamic>>();
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.check_circle, color: Colors.greenAccent),
          const SizedBox(width: 8),
          Text('Draft · table ${ticket['table_number'] ?? "?"}'),
        ]),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (ticket['voice_transcript'] != null)
                  Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xff1f1818),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('« ${ticket['voice_transcript']} »',
                        style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 11)),
                  ),
                ...items.map((i) {
                  final mods = ((i['modifiers'] as List<dynamic>?) ?? const []).cast<String>();
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 12,
                      backgroundColor: BrocBrand.brocRed,
                      child: Text('${i['quantity']}',
                          style: const TextStyle(fontSize: 11, color: Colors.white)),
                    ),
                    title: Text(i['label'] as String,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (mods.isNotEmpty)
                          Text(mods.join(' · '),
                              style: const TextStyle(color: BrocBrand.brocYellow, fontSize: 11)),
                        if (i['notes'] != null)
                          Text('Notes: ${i['notes']}',
                              style: const TextStyle(fontSize: 11, color: Colors.orange)),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              Navigator.pop(context);
              final r = await widget.api.command('ticket send ${ticket['id']}');
              if (!mounted) return;
              r.when(
                success: (data) {
                  if (data['type'] == 'success') {
                    _snack('Ticket envoyé en cuisine ✓');
                    _refresh();
                  } else {
                    _snack(data['message']?.toString() ?? 'erreur', isError: true);
                  }
                },
                failure: (e) => _snack(e.message, isError: true),
              );
            },
            icon: const Icon(Icons.send),
            label: const Text('Envoyer en cuisine'),
          ),
        ],
      ),
    );
  }

  Future<void> _changeItemStatus(String itemId, String status) async {
    final r = await widget.api.command(
      'ticket item-status --item $itemId --status $status',
    );
    if (!mounted) return;
    r.when(
      success: (data) {
        if (data['type'] == 'success') {
          _refresh();
        } else {
          _snack(data['message']?.toString() ?? 'erreur', isError: true);
        }
      },
      failure: (e) => _snack(e.message, isError: true),
    );
  }

  Future<void> _toggleTask(Map<String, dynamic> task) async {
    final status = task['status'] as String;
    final id = task['id'] as String;
    String action;
    if (status == 'pending') {
      action = 'cooking start $id';
    } else if (status == 'inProgress') {
      action = 'cooking complete $id';
    } else {
      return;
    }
    final r = await widget.api.command(action);
    if (!mounted) return;
    r.when(
      success: (data) {
        if (data['type'] == 'success') {
          _refresh();
        } else {
          _snack(data['message']?.toString() ?? 'erreur', isError: true);
        }
      },
      failure: (e) => _snack(e.message, isError: true),
    );
  }

  Color _statusColor(String s) => switch (s) {
        'voiceDraft' => Colors.purpleAccent,
        'pendingKitchen' => Colors.orange,
        'inProgress' => Colors.blueAccent,
        'ready' => Colors.greenAccent,
        'served' => Colors.grey,
        'cancelled' => Colors.redAccent,
        _ => Colors.white,
      };

  @override
  Widget build(BuildContext context) {
    final drafts = _tickets.where((t) => t['status'] == 'voiceDraft').toList();
    final pending = _tickets.where((t) => t['status'] == 'pendingKitchen').toList();
    final inProgress = _tickets.where((t) => t['status'] == 'inProgress').toList();
    final ready = _tickets.where((t) => t['status'] == 'ready').toList();
    final pendingTasks = _tasks.where((t) => t['status'] == 'pending').toList();
    final activeTasks = _tasks.where((t) => t['status'] == 'inProgress').toList();

    return Scaffold(
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'kitchen-86',
            onPressed: _signalRupture,
            tooltip: 'Signaler une rupture (Mode 86)',
            backgroundColor: BrocBrand.brocYellow,
            foregroundColor: BrocBrand.brocBlack,
            child: const Icon(Icons.no_food),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'kitchen-voice',
            onPressed: _newVoiceOrder,
            icon: const Icon(Icons.mic),
            label: const Text('Nouvelle commande vocale'),
            backgroundColor: BrocBrand.brocRed,
            foregroundColor: BrocBrand.brocCream,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 200),
              children: [
                if (drafts.isNotEmpty)
                  _SectionHeader(
                      label: 'DRAFTS — à envoyer en cuisine',
                      count: drafts.length,
                      color: Colors.purpleAccent),
                ...drafts.map((t) => _TicketCard(
                      ticket: t,
                      statusColor: _statusColor(t['status'] as String),
                      tasksForTicket: const [],
                      onSend: () async {
                        final r = await widget.api.command('ticket send ${t['id']}');
                        r.when(
                          success: (data) {
                            if (data['type'] == 'success') {
                              _snack('Envoyé ✓');
                              _refresh();
                            } else {
                              _snack(data['message']?.toString() ?? 'erreur', isError: true);
                            }
                          },
                          failure: (e) => _snack(e.message, isError: true),
                        );
                      },
                    )),
                if (pending.isNotEmpty || inProgress.isNotEmpty)
                  _SectionHeader(
                      label: 'CUISINE EN COURS',
                      count: pending.length + inProgress.length,
                      color: Colors.orange),
                ...[...pending, ...inProgress].map((t) {
                  final tasksFor = _tasks.where((task) {
                    final items = (t['items'] as List<dynamic>).cast<Map<String, dynamic>>();
                    return items.any((i) => i['id'] == task['ticket_item_id']);
                  }).toList();
                  return _TicketCard(
                    ticket: t,
                    statusColor: _statusColor(t['status'] as String),
                    tasksForTicket: tasksFor,
                    onItemStatus: _changeItemStatus,
                    onTaskTap: _toggleTask,
                  );
                }),
                if (ready.isNotEmpty)
                  _SectionHeader(
                      label: 'PRÊT À SERVIR',
                      count: ready.length,
                      color: Colors.greenAccent),
                ...ready.map((t) => _TicketCard(
                      ticket: t,
                      statusColor: _statusColor(t['status'] as String),
                      tasksForTicket: const [],
                    )),
                const SizedBox(height: 16),
                _SectionHeader(
                    label: 'TÂCHES CUISINE',
                    count: pendingTasks.length + activeTasks.length,
                    color: BrocBrand.brocYellow),
                if (pendingTasks.isEmpty && activeTasks.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Aucune tâche en cours.\n'
                      'Les tâches apparaissent quand un ticket est envoyé en cuisine.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                else ...[
                  ...activeTasks.map((t) => _CookingTaskTile(task: t, onTap: () => _toggleTask(t))),
                  ...pendingTasks.map((t) => _CookingTaskTile(task: t, onTap: () => _toggleTask(t))),
                ],
              ],
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _SectionHeader({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(children: [
        Container(width: 8, height: 16, color: color),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, letterSpacing: 1)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
          child: Text('$count',
              style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }
}

class _TicketCard extends StatelessWidget {
  final Map<String, dynamic> ticket;
  final Color statusColor;
  final List<Map<String, dynamic>> tasksForTicket;
  final VoidCallback? onSend;
  final void Function(String itemId, String status)? onItemStatus;
  final void Function(Map<String, dynamic> task)? onTaskTap;

  const _TicketCard({
    required this.ticket,
    required this.statusColor,
    required this.tasksForTicket,
    this.onSend,
    this.onItemStatus,
    this.onTaskTap,
  });

  @override
  Widget build(BuildContext context) {
    final items = ((ticket['items'] as List<dynamic>?) ?? const [])
        .cast<Map<String, dynamic>>();
    final table = ticket['table_number'];
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.2),
                  border: Border.all(color: statusColor),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  table != null ? 'TABLE $table' : 'PAS DE TABLE',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                ),
              ),
              const Spacer(),
              Text(_JournalScreenState._fmtTime(ticket['created_at'] as String),
                  style: const TextStyle(fontSize: 10, color: Colors.grey)),
              if (onSend != null)
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.greenAccent, size: 18),
                  tooltip: 'Envoyer en cuisine',
                  onPressed: onSend,
                ),
            ]),
            const SizedBox(height: 4),
            ...items.map((i) {
              final mods = ((i['modifiers'] as List<dynamic>?) ?? const []).cast<String>();
              final iStatus = i['status'] as String;
              final iconColor = switch (iStatus) {
                'pending' => Colors.grey,
                'cooking' => Colors.orange,
                'ready' => Colors.greenAccent,
                'served' => Colors.green,
                _ => Colors.white,
              };
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Text('${i['quantity']}×',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: BrocBrand.brocYellow)),
                title: Text(i['label'] as String,
                    style: TextStyle(
                        fontSize: 13,
                        decoration: iStatus == 'served' ? TextDecoration.lineThrough : null,
                        color: iStatus == 'served' ? Colors.grey : null)),
                subtitle: mods.isNotEmpty
                    ? Text(mods.join(' · '),
                        style: const TextStyle(color: BrocBrand.brocYellow, fontSize: 10))
                    : null,
                trailing: onItemStatus == null
                    ? Icon(Icons.circle, size: 12, color: iconColor)
                    : PopupMenuButton<String>(
                        icon: Icon(Icons.circle, size: 14, color: iconColor),
                        tooltip: 'Statut item',
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'pending', child: Text('Pending')),
                          PopupMenuItem(value: 'cooking', child: Text('Cooking')),
                          PopupMenuItem(value: 'ready', child: Text('Ready')),
                          PopupMenuItem(value: 'served', child: Text('Served')),
                          PopupMenuItem(value: 'cancelled', child: Text('86 (annulé)')),
                        ],
                        onSelected: (v) => onItemStatus!(i['id'] as String, v),
                      ),
              );
            }),
            if (tasksForTicket.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: tasksForTicket.map((task) {
                    final s = task['status'] as String;
                    final isOverdue = task['is_overdue'] as bool? ?? false;
                    final c = s == 'done'
                        ? Colors.green
                        : s == 'inProgress'
                            ? (isOverdue ? Colors.red : Colors.orange)
                            : Colors.grey;
                    return GestureDetector(
                      onTap: onTaskTap == null ? null : () => onTaskTap!(task),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          border: Border.all(color: c),
                          borderRadius: BorderRadius.circular(4),
                          color: c.withValues(alpha: 0.1),
                        ),
                        child: Text(task['label'] as String,
                            style: TextStyle(fontSize: 10, color: c)),
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CookingTaskTile extends StatelessWidget {
  final Map<String, dynamic> task;
  final VoidCallback onTap;
  const _CookingTaskTile({required this.task, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = task['status'] as String;
    final isOverdue = task['is_overdue'] as bool? ?? false;
    final elapsedMs = task['elapsed_ms'] as int?;
    final expectedMs = task['expected_duration_ms'] as int;
    final color = status == 'done'
        ? Colors.green
        : status == 'inProgress'
            ? (isOverdue ? Colors.red : Colors.orange)
            : Colors.grey;
    return ListTile(
      dense: true,
      leading: Icon(
        status == 'done'
            ? Icons.check_circle
            : status == 'inProgress'
                ? Icons.timer
                : Icons.radio_button_unchecked,
        color: color,
      ),
      title: Text(task['label'] as String,
          style: TextStyle(
              decoration: status == 'done' ? TextDecoration.lineThrough : null,
              color: status == 'done' ? Colors.grey : null)),
      subtitle: Text(
        elapsedMs != null
            ? '${(elapsedMs / 60000).toStringAsFixed(1)}min écoulées · ${(expectedMs / 60000).toStringAsFixed(0)}min prévues${isOverdue ? "  ⚠ DÉPASSÉ" : ""}'
            : '${(expectedMs / 60000).toStringAsFixed(0)}min prévues',
        style: TextStyle(fontSize: 11, color: isOverdue ? Colors.red : null),
      ),
      trailing: status == 'done'
          ? null
          : TextButton(
              onPressed: onTap,
              child: Text(status == 'pending' ? 'Démarrer' : 'Terminer',
                  style: TextStyle(color: color)),
            ),
    );
  }
}
