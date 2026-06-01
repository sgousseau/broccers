// Phase H — Onglet Super-admin : feature flags + config système + db info.
// Visible uniquement quand le rôle utilisateur est super_admin.

import 'package:flutter/material.dart';

import '../main.dart' show BrocBrand, translateErrorFr;
import 'api.dart';

class AdminScreen extends StatefulWidget {
  final BrWebApi api;
  const AdminScreen({super.key, required this.api});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: BrocBrand.brocBlack,
            child: TabBar(
              controller: _tab,
              labelColor: BrocBrand.brocYellow,
              unselectedLabelColor: Colors.grey,
              indicatorColor: BrocBrand.brocRed,
              tabs: const [
                Tab(icon: Icon(Icons.toggle_on), text: 'Feature flags'),
                Tab(icon: Icon(Icons.info_outline), text: 'Système'),
                Tab(icon: Icon(Icons.storage), text: 'Base de données'),
              ],
            ),
          ),
        ),
        body: TabBarView(
          controller: _tab,
          children: [
            _FeatureFlagsTab(api: widget.api),
            _SystemConfigTab(api: widget.api),
            _DbInfoTab(api: widget.api),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// FEATURE FLAGS TAB
// ===========================================================================
class _FeatureFlagsTab extends StatefulWidget {
  final BrWebApi api;
  const _FeatureFlagsTab({required this.api});
  @override
  State<_FeatureFlagsTab> createState() => _FeatureFlagsTabState();
}

class _FeatureFlagsTabState extends State<_FeatureFlagsTab> {
  List<Map<String, dynamic>> _flags = const [];
  bool _loading = true;
  String? _filter;

  static const _categories = [
    ('modules', 'Modules métier', Colors.blue),
    ('experimental', 'Expérimental (Phase H+)', Colors.orange),
    ('licensing', 'Licence & commercial', Colors.purple),
    ('security', 'Sécurité', Colors.red),
    ('ui', 'Interface', Colors.teal),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final r = await widget.api.get('/api/features');
    if (!mounted) return;
    r.when(
      success: (data) => setState(() {
        _flags = (data['features'] as List).cast<Map<String, dynamic>>();
        _loading = false;
      }),
      failure: (e) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(translateErrorFr(e.message)),
          backgroundColor: Colors.red.shade900,
        ));
      },
    );
  }

  Future<void> _toggle(Map<String, dynamic> f, bool newVal) async {
    if (newVal && f['phase'] != null) {
      // Warn before enabling experimental
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Activer ${f['label']} ?'),
          content: Text(
            'Cette feature est expérimentale (Phase ${f['phase']}).\n\n'
            '${f['description']}\n\n'
            'Elle peut nécessiter un redémarrage du serveur.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: BrocBrand.brocRed),
              child: const Text('Activer'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }
    final r = await widget.api.put(
      '/api/features/${f['key']}',
      {'enabled': newVal, 'actor': 'super_admin'},
    );
    if (!mounted) return;
    r.when(
      success: (data) {
        final restart = data['requires_restart'] as bool? ?? false;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            '${f['label']} → ${newVal ? "activé" : "désactivé"}'
            '${restart ? " (⚠ redémarrage requis)" : ""}',
          ),
          backgroundColor: newVal ? Colors.green.shade900 : BrocBrand.brocRed,
        ));
        _load();
      },
      failure: (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(translateErrorFr(e.message)),
          backgroundColor: Colors.red.shade900,
        ));
      },
    );
  }

  Color _catColor(String cat) {
    for (final c in _categories) {
      if (c.$1 == cat) return c.$3;
    }
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: BrocBrand.brocRed));
    }
    final visibleFlags = _filter == null
        ? _flags
        : _flags.where((f) => f['category'] == _filter).toList();
    final enabledCount = _flags.where((f) => f['enabled'] == true).length;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: BrocBrand.brocRed.withValues(alpha: 0.08),
          child: Row(
            children: [
              const Icon(Icons.toggle_on, color: BrocBrand.brocYellow, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Feature flags · super-admin uniquement',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Text(
                      '$enabledCount / ${_flags.length} activés · '
                      'Permet de moduler les fonctionnalités visibles pour démos et déploiements clients',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _load,
              ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              FilterChip(
                label: const Text('Toutes'),
                selected: _filter == null,
                selectedColor: BrocBrand.brocRed,
                checkmarkColor: BrocBrand.brocCream,
                onSelected: (_) => setState(() => _filter = null),
              ),
              const SizedBox(width: 4),
              for (final c in _categories) ...[
                FilterChip(
                  label: Text(c.$2),
                  selected: _filter == c.$1,
                  selectedColor: c.$3,
                  checkmarkColor: BrocBrand.brocCream,
                  onSelected: (_) => setState(() => _filter = c.$1),
                ),
                const SizedBox(width: 4),
              ],
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: BrocBrand.brocRed,
            onRefresh: _load,
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: visibleFlags.length,
              itemBuilder: (_, i) {
                final f = visibleFlags[i];
                final enabled = f['enabled'] as bool;
                final isDefault = f['is_default'] as bool? ?? true;
                final superAdminOnly = f['super_admin_only'] as bool? ?? false;
                final requiresRestart = f['requires_restart'] as bool? ?? false;
                final phase = f['phase'] as String?;
                final deps = ((f['depends_on'] as List?) ?? const []).cast<String>();
                return Card(
                  color: BrocBrand.brocBlack.withValues(alpha: 0.4),
                  child: ListTile(
                    leading: Container(
                      width: 6,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _catColor(f['category'] as String),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(child: Text(f['label'] as String,
                          style: const TextStyle(fontWeight: FontWeight.w600))),
                        if (phase != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade900,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text('PHASE $phase',
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                          ),
                        if (superAdminOnly)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade900,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: const Text('SUPER-ADMIN',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                          ),
                        if (requiresRestart)
                          const Icon(Icons.restart_alt, size: 16, color: Colors.orange),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(f['description'] as String,
                            style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Text(
                                f['key'] as String,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: BrocBrand.brocYellow,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              if (!isDefault && f['set_at'] != null) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: BrocBrand.brocRed.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  child: const Text('modifié',
                                    style: TextStyle(fontSize: 9, color: BrocBrand.brocYellow)),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (deps.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Wrap(
                              spacing: 4,
                              children: [
                                const Text('Dépend de:',
                                  style: TextStyle(fontSize: 10, color: Colors.grey)),
                                ...deps.map((d) => Text(d,
                                  style: const TextStyle(
                                    fontSize: 10, color: Colors.cyan, fontFamily: 'monospace'))),
                              ],
                            ),
                          ),
                      ],
                    ),
                    trailing: Switch(
                      value: enabled,
                      activeThumbColor: BrocBrand.brocYellow,
                      activeTrackColor: Colors.green.shade700,
                      onChanged: (v) => _toggle(f, v),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// SYSTEM CONFIG TAB
// ===========================================================================
class _SystemConfigTab extends StatefulWidget {
  final BrWebApi api;
  const _SystemConfigTab({required this.api});
  @override
  State<_SystemConfigTab> createState() => _SystemConfigTabState();
}

class _SystemConfigTabState extends State<_SystemConfigTab> {
  Map<String, dynamic>? _config;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final r = await widget.api.get('/api/system/config');
    if (!mounted) return;
    r.when(
      success: (d) => setState(() {
        _config = d;
        _loading = false;
      }),
      failure: (_) => setState(() => _loading = false),
    );
  }

  Color _modeColor(String mode) {
    return switch (mode) {
      'docker' => Colors.blue.shade700,
      'usb_portable' => Colors.orange.shade700,
      _ => Colors.green.shade700,
    };
  }

  String _modeLabel(String mode) {
    return switch (mode) {
      'docker' => 'Docker (autonomie réseau)',
      'usb_portable' => 'USB portable (démo nomade)',
      _ => 'Tailscale native (production maison)',
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _config == null) {
      return const Center(child: CircularProgressIndicator(color: BrocBrand.brocRed));
    }
    final mode = _config!['mode'] as String;
    final uptime = _config!['uptime_seconds'] as int;
    final uptimeStr = uptime < 60
        ? '${uptime}s'
        : uptime < 3600
            ? '${uptime ~/ 60}m ${uptime % 60}s'
            : '${uptime ~/ 3600}h ${(uptime % 3600) ~/ 60}m';
    return RefreshIndicator(
      color: BrocBrand.brocRed,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _modeColor(mode).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _modeColor(mode), width: 2),
            ),
            child: Row(
              children: [
                Icon(
                  mode == 'docker' ? Icons.dns : mode == 'usb_portable' ? Icons.usb : Icons.cloud_outlined,
                  color: _modeColor(mode),
                  size: 40,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('MODE DE DÉPLOIEMENT',
                        style: TextStyle(fontSize: 11, color: Colors.grey, letterSpacing: 1.5)),
                      const SizedBox(height: 4),
                      Text(
                        _modeLabel(mode),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: BrocBrand.brocYellow,
                        ),
                      ),
                      Text('Uptime · $uptimeStr',
                        style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: BrocBrand.brocBlack.withValues(alpha: 0.4),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('CONFIGURATION RUNTIME',
                    style: TextStyle(fontSize: 11, color: BrocBrand.brocYellow, letterSpacing: 1.5)),
                  const Divider(),
                  _row('Version', _config!['version']),
                  _row('Plateforme', _config!['platform']),
                  _row('Dart', (_config!['dart_version'] as String).split(' ').first),
                  _row('Démarré à', (_config!['started_at'] as String).substring(0, 19).replaceAll('T', ' ')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: BrocBrand.brocBlack.withValues(alpha: 0.4),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('CHEMINS & ENDPOINTS',
                    style: TextStyle(fontSize: 11, color: BrocBrand.brocYellow, letterSpacing: 1.5)),
                  const Divider(),
                  _row('Data dir', _config!['data_dir']),
                  _row('Base SQLite', _config!['db_path']),
                  _row('Host', _config!['host']),
                  _row('Port', _config!['port'].toString()),
                  _row('Claude CLI', _config!['claude_cli']),
                  _row('Whisper URL', _config!['whisper_url'] ?? '(désactivé)'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade900.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade900.withValues(alpha: 0.5)),
            ),
            child: const Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Colors.orange),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pour changer le chemin de la base de données, redémarrer le serveur avec une autre variable BR_DB_PATH.\n'
                    'Ex : BR_DB_PATH=/tmp/demo.db /Users/sgo/Code/broccers/bin/br_server',
                    style: TextStyle(fontSize: 11, color: Colors.orange),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label.toUpperCase(),
              style: const TextStyle(fontSize: 10, color: Colors.grey, letterSpacing: 1)),
          ),
          Expanded(
            child: SelectableText(
              value.toString(),
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: BrocBrand.brocCream,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// DB INFO TAB
// ===========================================================================
class _DbInfoTab extends StatefulWidget {
  final BrWebApi api;
  const _DbInfoTab({required this.api});
  @override
  State<_DbInfoTab> createState() => _DbInfoTabState();
}

class _DbInfoTabState extends State<_DbInfoTab> {
  Map<String, dynamic>? _info;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final r = await widget.api.get('/api/system/db-info');
    if (!mounted) return;
    r.when(
      success: (d) => setState(() {
        _info = d;
        _loading = false;
      }),
      failure: (_) => setState(() => _loading = false),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _info == null) {
      return const Center(child: CircularProgressIndicator(color: BrocBrand.brocRed));
    }
    final counts = (_info!['counts'] as Map<String, dynamic>?) ?? const {};
    return RefreshIndicator(
      color: BrocBrand.brocRed,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: BrocBrand.brocBlack.withValues(alpha: 0.4),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.storage, color: BrocBrand.brocYellow, size: 28),
                      SizedBox(width: 12),
                      Text('Base de données SQLite',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Divider(),
                  _row('Chemin', _info!['path']),
                  _row('Existe', _info!['exists'] == true ? '✓ oui' : '✗ non'),
                  if (_info!['exists'] == true) ...[
                    _row('Taille', '${_info!['size_mb']} Mo (${_info!['size_bytes']} octets)'),
                    _row('Modifiée le',
                        (_info!['modified_at'] as String?)?.substring(0, 19).replaceAll('T', ' ') ?? '-'),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: BrocBrand.brocBlack.withValues(alpha: 0.4),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('CONTENU',
                    style: TextStyle(fontSize: 11, color: BrocBrand.brocYellow, letterSpacing: 1.5)),
                  const Divider(),
                  _countRow('Employés', counts['employees'] as int? ?? 0, Icons.groups),
                  _countRow('Cartes', counts['menu_cards'] as int? ?? 0, Icons.menu_book),
                  _countRow('Tables', counts['tables'] as int? ?? 0, Icons.table_restaurant),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.purple.shade900.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SWITCHER D\'INSTANCE',
                  style: TextStyle(fontSize: 11, color: Colors.purpleAccent, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                SelectableText(
                  'Pour ouvrir une autre base (démo client X par exemple) :\n\n'
                  '1. Stopper le serveur en cours\n'
                  '2. Relancer avec BR_DB_PATH=/chemin/vers/autre.db\n'
                  '3. Recharger l\'app (F5)\n\n'
                  'Exemples de bases :\n'
                  '~/.broccers/broc.db          → production Le Broc\n'
                  '~/.broccers/demo-vide.db     → démo client (BD vierge)\n'
                  '~/.broccers/demo-restaurant-x.db → démo client X',
                  style: TextStyle(fontSize: 11, color: Colors.purpleAccent, fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label.toUpperCase(),
              style: const TextStyle(fontSize: 10, color: Colors.grey, letterSpacing: 1)),
          ),
          Expanded(
            child: SelectableText(
              value.toString(),
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: BrocBrand.brocCream,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _countRow(String label, int count, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: BrocBrand.brocYellow),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          Text(
            count.toString(),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: BrocBrand.brocYellow,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
