// Phase F UI screens : Paramètres (manager-only), Gaspillage, Tables/QR.
// Tous utilisent BrocBrand + Material widgets (transition path : br_sg.dart wrappers à v0.4).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../main.dart' show BrocBrand, translateErrorFr;
import 'api.dart';

// ===========================================================================
// SETTINGS SCREEN — manager-only — édite seuils marges, pauses, charges, etc.
// ===========================================================================
class SettingsScreen extends StatefulWidget {
  final BrWebApi api;
  const SettingsScreen({super.key, required this.api});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<Map<String, dynamic>> _settings = const [];
  bool _loading = true;
  String? _activeCategory;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final r = await widget.api.get(
      _activeCategory == null
          ? '/api/settings'
          : '/api/settings?category=$_activeCategory',
    );
    r.when(
      success: (data) {
        final items = (data['settings'] as List).cast<Map<String, dynamic>>();
        setState(() {
          _settings = items;
          _loading = false;
        });
      },
      failure: (e) {
        if (!mounted) return;
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(translateErrorFr(e.message)),
          backgroundColor: Colors.red.shade900,
        ));
      },
    );
  }

  Future<void> _editSetting(Map<String, dynamic> s) async {
    final controller = TextEditingController(text: s['value'].toString());
    final newVal = await showDialog<Object>(
      context: context,
      builder: (_) {
        final type = s['type'] as String;
        if (type == 'enumValue' && s['enum_options'] != null) {
          final opts = (s['enum_options'] as List).cast<String>();
          String selected = s['value'].toString();
          return StatefulBuilder(builder: (ctx, setLocal) {
            return AlertDialog(
              title: Text(s['label'] as String),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (s['description'] != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        s['description'] as String,
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ),
                  ...opts.map((o) => RadioListTile<String>(
                        title: Text(o),
                        value: o,
                        groupValue: selected,
                        onChanged: (v) => setLocal(() => selected = v!),
                      )),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, selected),
                  style: FilledButton.styleFrom(backgroundColor: BrocBrand.brocRed),
                  child: const Text('Enregistrer'),
                ),
              ],
            );
          });
        }
        if (type == 'boolValue') {
          bool selected = s['value'] == true || s['value'].toString() == 'true';
          return StatefulBuilder(builder: (ctx, setLocal) {
            return AlertDialog(
              title: Text(s['label'] as String),
              content: SwitchListTile(
                title: Text(selected ? 'Activé' : 'Désactivé'),
                value: selected,
                activeThumbColor: BrocBrand.brocYellow,
                onChanged: (v) => setLocal(() => selected = v),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, selected),
                  style: FilledButton.styleFrom(backgroundColor: BrocBrand.brocRed),
                  child: const Text('Enregistrer'),
                ),
              ],
            );
          });
        }
        // intValue, doubleValue, stringValue
        final unit = s['unit'];
        return AlertDialog(
          title: Text(s['label'] as String),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (s['description'] != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    s['description'] as String,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
              TextField(
                controller: controller,
                keyboardType: type == 'intValue' || type == 'doubleValue'
                    ? const TextInputType.numberWithOptions(decimal: true)
                    : TextInputType.text,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  suffix: unit != null ? Text(' $unit') : null,
                  helperText: (s['min_value'] != null || s['max_value'] != null)
                      ? 'Range: [${s['min_value'] ?? '−∞'}, ${s['max_value'] ?? '+∞'}]'
                      : null,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
            FilledButton(
              onPressed: () {
                final raw = controller.text.trim();
                Object parsed;
                if (type == 'intValue') {
                  parsed = int.tryParse(raw) ?? 0;
                } else if (type == 'doubleValue') {
                  parsed = double.tryParse(raw) ?? 0.0;
                } else {
                  parsed = raw;
                }
                Navigator.pop(context, parsed);
              },
              style: FilledButton.styleFrom(backgroundColor: BrocBrand.brocRed),
              child: const Text('Enregistrer'),
            ),
          ],
        );
      },
    );
    if (newVal == null) return;
    final r = await widget.api.put('/api/settings/${s['key']}', {
      'value': newVal,
      'actor': 'manager',
      'reason': 'manual edit via UI',
    });
    if (!mounted) return;
    r.when(
      success: (_) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Paramètre ${s['key']} mis à jour'),
          backgroundColor: BrocBrand.brocRed,
        ));
        _load();
      },
      failure: (e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(translateErrorFr(e.message)),
        backgroundColor: Colors.red.shade900,
      )),
    );
  }

  Color _categoryColor(String cat) {
    switch (cat) {
      case 'margins':
        return Colors.amber.shade700;
      case 'breaksLegal':
        return Colors.blue.shade700;
      case 'costs':
        return Colors.green.shade700;
      case 'voice':
        return Colors.purple.shade700;
      default:
        return BrocBrand.brocRed;
    }
  }

  IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'margins':
        return Icons.percent;
      case 'breaksLegal':
        return Icons.gavel;
      case 'costs':
        return Icons.euro;
      case 'voice':
        return Icons.mic;
      case 'kiosk':
        return Icons.tablet;
      case 'notifications':
        return Icons.notifications;
      case 'ui':
        return Icons.palette;
      default:
        return Icons.settings;
    }
  }

  @override
  Widget build(BuildContext context) {
    final byCat = <String, List<Map<String, dynamic>>>{};
    for (final s in _settings) {
      final c = s['category'] as String;
      byCat.putIfAbsent(c, () => []).add(s);
    }
    return RefreshIndicator(
      color: BrocBrand.brocRed,
      onRefresh: _load,
      child: _loading
          ? const Center(child: CircularProgressIndicator(color: BrocBrand.brocRed))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: BrocBrand.brocRed.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: BrocBrand.brocRed.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.admin_panel_settings, color: BrocBrand.brocYellow, size: 28),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Paramètres globaux — Manager / Super-admin uniquement.\n'
                          'Toute modification est tracée dans le journal (audit).',
                          style: TextStyle(fontSize: 12, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                for (final entry in byCat.entries) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    child: Row(
                      children: [
                        Icon(_categoryIcon(entry.key),
                            color: _categoryColor(entry.key), size: 22),
                        const SizedBox(width: 8),
                        Text(
                          entry.value.first['category_label'] as String,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: _categoryColor(entry.key),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Card(
                    color: BrocBrand.brocBlack.withValues(alpha: 0.4),
                    child: Column(
                      children: entry.value.map((s) {
                        final value = s['value'];
                        final unit = s['unit'] != null ? ' ${s['unit']}' : '';
                        final defaulted = s['set_at'] == null;
                        return ListTile(
                          title: Text(s['label'] as String),
                          subtitle: s['description'] != null
                              ? Text(
                                  s['description'] as String,
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                )
                              : null,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (defaulted)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade800,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: const Text('défaut',
                                      style: TextStyle(fontSize: 10, color: Colors.grey)),
                                ),
                              const SizedBox(width: 8),
                              Text(
                                '$value$unit',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: BrocBrand.brocYellow,
                                  fontSize: 16,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.edit, size: 16, color: Colors.grey),
                            ],
                          ),
                          onTap: () => _editSetting(s),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
    );
  }
}

// ===========================================================================
// WASTE SCREEN — déclarer gaspillage + voir total semaine + breakdown
// ===========================================================================
class WasteScreen extends StatefulWidget {
  final BrWebApi api;
  const WasteScreen({super.key, required this.api});

  @override
  State<WasteScreen> createState() => _WasteScreenState();
}

class _WasteScreenState extends State<WasteScreen> {
  Map<String, dynamic>? _summary;
  List<dynamic> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final summary = await widget.api.get('/api/waste/summary');
    final items = await widget.api.get('/api/waste');
    if (!mounted) return;
    summary.when(success: (d) => _summary = d, failure: (_) {});
    items.when(success: (d) => _items = (d['items'] as List), failure: (_) {});
    setState(() => _loading = false);
  }

  Future<void> _declareWaste() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _DeclareWasteDialog(),
    );
    if (result == null) return;
    final r = await widget.api.post('/api/waste', result);
    if (!mounted) return;
    r.when(
      success: (_) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Gaspillage déclaré. Merci pour la transparence.'),
          backgroundColor: BrocBrand.brocRed,
        ));
        _load();
      },
      failure: (e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(translateErrorFr(e.message)),
        backgroundColor: Colors.red.shade900,
      )),
    );
  }

  String _formatEuros(int cents) {
    final e = cents ~/ 100;
    final c = cents % 100;
    return c == 0 ? '$e €' : '$e,${c.toString().padLeft(2, '0')} €';
  }

  String _reasonLabel(String name) => switch (name) {
        'prepLoss' => 'Perte préparation',
        'servingLoss' => 'Perte service',
        'expiry' => 'Date dépassée',
        'unusedProduction' => 'Production non écoulée',
        'staffMeal' => 'Repas staff',
        'customerReturn' => 'Retour client',
        'burnt' => 'Brûlé / raté',
        'contamination' => 'Contamination',
        _ => name,
      };

  @override
  Widget build(BuildContext context) {
    final totalCents = (_summary?['total_cents'] as int?) ?? 0;
    final byReason = (_summary?['by_reason_cents'] as Map<String, dynamic>?) ?? const {};
    final byDay = (_summary?['by_day_cents'] as Map<String, dynamic>?) ?? const {};
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: BrocBrand.brocRed,
        icon: const Icon(Icons.add),
        label: const Text('Déclarer une perte'),
        onPressed: _declareWaste,
      ),
      body: RefreshIndicator(
        color: BrocBrand.brocRed,
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: BrocBrand.brocRed))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    color: BrocBrand.brocRed.withValues(alpha: 0.12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PERTES (7 derniers jours)',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _formatEuros(totalCents),
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              color: BrocBrand.brocYellow,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_summary?['count'] ?? 0} déclarations enregistrées',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (byReason.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('Par raison',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                    Card(
                      color: BrocBrand.brocBlack.withValues(alpha: 0.4),
                      child: Column(
                        children: byReason.entries.map((e) {
                          return ListTile(
                            dense: true,
                            title: Text(_reasonLabel(e.key)),
                            trailing: Text(
                              _formatEuros(e.value as int),
                              style: const TextStyle(
                                color: BrocBrand.brocYellow,
                                fontWeight: FontWeight.bold,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (byDay.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('Par jour',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                    Card(
                      color: BrocBrand.brocBlack.withValues(alpha: 0.4),
                      child: Column(
                        children: byDay.entries.map((e) {
                          return ListTile(
                            dense: true,
                            title: Text(e.key),
                            trailing: Text(
                              _formatEuros(e.value as int),
                              style: const TextStyle(
                                color: BrocBrand.brocYellow,
                                fontWeight: FontWeight.bold,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Historique récent',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                  if (_items.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Aucune perte enregistrée pour l\'instant.',
                            style: TextStyle(color: Colors.grey)),
                      ),
                    )
                  else
                    Card(
                      color: BrocBrand.brocBlack.withValues(alpha: 0.4),
                      child: Column(
                        children: _items.take(50).map<Widget>((wRaw) {
                          final w = wRaw as Map<String, dynamic>;
                          return ListTile(
                            dense: true,
                            title: Text('${w['label']} · ${w['quantity']} ${w['unit'] ?? ''}'),
                            subtitle: Text(
                              '${_reasonLabel(w['reason'] as String)} · '
                              '${(w['reported_at'] as String).substring(0, 16).replaceAll('T', ' ')}',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                            trailing: Text(
                              _formatEuros(w['estimated_value_cents'] as int),
                              style: const TextStyle(
                                color: BrocBrand.brocYellow,
                                fontWeight: FontWeight.bold,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  const SizedBox(height: 80),
                ],
              ),
      ),
    );
  }
}

class _DeclareWasteDialog extends StatefulWidget {
  const _DeclareWasteDialog();
  @override
  State<_DeclareWasteDialog> createState() => _DeclareWasteDialogState();
}

class _DeclareWasteDialogState extends State<_DeclareWasteDialog> {
  final _labelCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _valueCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _reason = 'prepLoss';
  String _unit = 'piece';

  static const _reasons = [
    ('prepLoss', 'Perte préparation'),
    ('servingLoss', 'Perte service'),
    ('expiry', 'Date dépassée'),
    ('unusedProduction', 'Production non écoulée'),
    ('staffMeal', 'Repas staff'),
    ('customerReturn', 'Retour client'),
    ('burnt', 'Brûlé / raté'),
    ('contamination', 'Contamination'),
    ('other', 'Autre'),
  ];

  static const _units = [
    ('piece', 'pcs'),
    ('gram', 'g'),
    ('kilogram', 'kg'),
    ('milliliter', 'ml'),
    ('liter', 'L'),
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(children: [
        Icon(Icons.delete_outline, color: BrocBrand.brocRed),
        SizedBox(width: 8),
        Text('Déclarer une perte'),
      ]),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _labelCtrl,
                decoration: const InputDecoration(
                  labelText: 'Quoi ? (ex: brochettes poulet)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _qtyCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Quantité',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: DropdownButtonFormField<String>(
                      initialValue: _unit,
                      isExpanded: true,
                      items: _units
                          .map((u) => DropdownMenuItem(value: u.$1, child: Text(u.$2)))
                          .toList(),
                      onChanged: (v) => setState(() => _unit = v!),
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _reason,
                isExpanded: true,
                items: _reasons
                    .map((r) => DropdownMenuItem(value: r.$1, child: Text(r.$2)))
                    .toList(),
                onChanged: (v) => setState(() => _reason = v!),
                decoration: const InputDecoration(
                  labelText: 'Raison',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _valueCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Valeur estimée € (optionnel)',
                  border: OutlineInputBorder(),
                  helperText: 'Auto-estimée si ingrédient connu',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes (optionnel)',
                  border: OutlineInputBorder(),
                  helperText: 'Bienveillance : on cherche à comprendre, pas réprimander',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(
          onPressed: () {
            final label = _labelCtrl.text.trim();
            final qty = double.tryParse(_qtyCtrl.text.trim());
            if (label.isEmpty || qty == null || qty <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Label + quantité requis'),
                backgroundColor: Colors.red,
              ));
              return;
            }
            final euros = double.tryParse(_valueCtrl.text.trim());
            Navigator.pop(context, {
              'kind': 'ingredient',
              'ref_id': 'unknown',
              'label': label,
              'quantity': qty,
              'unit': _unit,
              'reason': _reason,
              if (euros != null) 'estimated_value_cents': (euros * 100).round(),
              if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
              'reported_by': 'manager',
            });
          },
          style: FilledButton.styleFrom(backgroundColor: BrocBrand.brocRed),
          child: const Text('Déclarer'),
        ),
      ],
    );
  }
}

// ===========================================================================
// TABLES SCREEN — gérer tables + générer QR pour consultation carte
// ===========================================================================
class TablesScreen extends StatefulWidget {
  final BrWebApi api;
  const TablesScreen({super.key, required this.api});

  @override
  State<TablesScreen> createState() => _TablesScreenState();
}

class _TablesScreenState extends State<TablesScreen> {
  List<Map<String, dynamic>> _tables = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final r = await widget.api.get('/api/tables');
    r.when(
      success: (data) {
        final items = (data['tables'] as List).cast<Map<String, dynamic>>();
        setState(() {
          _tables = items;
          _loading = false;
        });
      },
      failure: (e) {
        if (!mounted) return;
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(translateErrorFr(e.message)),
          backgroundColor: Colors.red.shade900,
        ));
      },
    );
  }

  Future<void> _createTable() async {
    final labelCtrl = TextEditingController();
    final capCtrl = TextEditingController();
    final positionCtrl = TextEditingController();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nouvelle table'),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelCtrl,
                decoration: const InputDecoration(
                  labelText: 'Label (ex: T1, Terrasse 3)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: capCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Capacité (couverts)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: positionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Position (intérieur/terrasse/comptoir)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              final label = labelCtrl.text.trim();
              if (label.isEmpty) return;
              Navigator.pop(context, {
                'label': label,
                if (capCtrl.text.trim().isNotEmpty)
                  'capacity': int.tryParse(capCtrl.text.trim()),
                if (positionCtrl.text.trim().isNotEmpty) 'position': positionCtrl.text.trim(),
              });
            },
            style: FilledButton.styleFrom(backgroundColor: BrocBrand.brocRed),
            child: const Text('Créer'),
          ),
        ],
      ),
    );
    if (result == null) return;
    final r = await widget.api.post('/api/tables', result);
    if (!mounted) return;
    r.when(
      success: (_) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Table créée avec QR code unique'),
          backgroundColor: BrocBrand.brocRed,
        ));
        _load();
      },
      failure: (e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(translateErrorFr(e.message)),
        backgroundColor: Colors.red.shade900,
      )),
    );
  }

  Future<void> _showQrFor(Map<String, dynamic> t) async {
    final url = t['public_menu_url'] as String;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.qr_code, color: BrocBrand.brocYellow),
          const SizedBox(width: 8),
          Text('Table ${t['label']}'),
        ]),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.white,
                child: QrImageView(
                  data: url,
                  version: QrVersions.auto,
                  size: 280,
                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: BrocBrand.brocRed,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SelectableText(
                url,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  color: BrocBrand.brocYellow,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copier URL'),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: url));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('URL copiée'),
                        duration: Duration(seconds: 1),
                      ));
                    },
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Régénérer'),
                    onPressed: () async {
                      Navigator.pop(context);
                      await _rotateSecret(t);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Clients scannent → carte affichée en ligne (consultation seule).',
                style: TextStyle(fontSize: 11, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
        ],
      ),
    );
  }

  Future<void> _rotateSecret(Map<String, dynamic> t) async {
    final r = await widget.api.post('/api/tables/${t['id']}/rotate-secret', {});
    if (!mounted) return;
    r.when(
      success: (data) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Nouveau QR généré. Ancien invalidé.'),
          backgroundColor: BrocBrand.brocRed,
        ));
        _load();
      },
      failure: (e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(translateErrorFr(e.message)),
        backgroundColor: Colors.red.shade900,
      )),
    );
  }

  Future<void> _deactivate(Map<String, dynamic> t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Désactiver ${t['label']} ?'),
        content: const Text('Le QR code ne fonctionnera plus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Non')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: BrocBrand.brocRed),
            child: const Text('Désactiver'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final r = await widget.api.post('/api/tables/${t['id']}/deactivate', {});
    if (!mounted) return;
    r.when(success: (_) => _load(), failure: (e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message))));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: BrocBrand.brocRed,
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle table'),
        onPressed: _createTable,
      ),
      body: RefreshIndicator(
        color: BrocBrand.brocRed,
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: BrocBrand.brocRed))
            : _tables.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.table_restaurant, size: 64, color: Colors.grey),
                          SizedBox(height: 12),
                          Text('Aucune table. Crée la première (T1, T2...) avec le bouton + ci-dessous.',
                              textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _tables.length + 1,
                    itemBuilder: (_, i) {
                      if (i == _tables.length) {
                        return const SizedBox(height: 80);
                      }
                      final t = _tables[i];
                      return Card(
                        color: BrocBrand.brocBlack.withValues(alpha: 0.4),
                        child: ListTile(
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: BrocBrand.brocRed,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                t['label'] as String,
                                style: const TextStyle(
                                  color: BrocBrand.brocYellow,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          title: Text(t['label'] as String),
                          subtitle: Text(
                            [
                              if (t['capacity'] != null) '${t['capacity']} couverts',
                              if (t['position'] != null) t['position'].toString(),
                              if (t['secret_rotated_at'] != null) 'QR régénéré',
                            ].join(' · '),
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.qr_code, color: BrocBrand.brocYellow),
                                tooltip: 'Voir QR code',
                                onPressed: () => _showQrFor(t),
                              ),
                              IconButton(
                                icon: const Icon(Icons.visibility_off, color: Colors.grey),
                                tooltip: 'Désactiver',
                                onPressed: () => _deactivate(t),
                              ),
                            ],
                          ),
                          onTap: () => _showQrFor(t),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
