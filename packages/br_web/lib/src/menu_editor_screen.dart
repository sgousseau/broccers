// Menu editor — CRUD complet items + catégories, multi-types cartes.
// Permet de construire/éditer une carte (brouillon ou publiée) en quelques clics.

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../main.dart' show BrocBrand, translateErrorFr;
import 'api.dart';

const _kinds = [
  ('food', 'Plats'),
  ('drinks', 'Boissons'),
  ('wine', 'Vins'),
  ('dessert', 'Desserts'),
  ('menu', 'Menus / Formules'),
  ('brunch', 'Brunch'),
  ('daily', 'Carte du jour'),
  ('other', 'Autre'),
];

// ===========================================================================
// MENU EDITOR SCREEN — édite une carte (catégories + items) avec ajout/suppr.
// ===========================================================================
class MenuEditorScreen extends StatefulWidget {
  final BrWebApi api;
  final String cardId;
  const MenuEditorScreen({super.key, required this.api, required this.cardId});

  @override
  State<MenuEditorScreen> createState() => _MenuEditorScreenState();
}

class _MenuEditorScreenState extends State<MenuEditorScreen> {
  Map<String, dynamic>? _card;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final r = await widget.api.get('/api/menu/cards/${widget.cardId}');
    if (!mounted) return;
    r.when(
      success: (data) => setState(() {
        _card = data;
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

  Future<void> _addCategory() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nouvelle catégorie'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'ex: Entrées, Plats, Vins rouges, Desserts',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            style: FilledButton.styleFrom(backgroundColor: BrocBrand.brocRed),
            child: const Text('Créer'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final cats = (_card!['categories'] as List?) ?? const [];
    final r = await widget.api.post(
      '/api/menu/cards/${widget.cardId}/categories',
      {'name': name, 'sort_order': cats.length},
    );
    if (!mounted) return;
    r.when(success: (_) => _load(), failure: (e) => _err(e.message));
  }

  Future<void> _addItem({String? categoryId}) async {
    final cats = ((_card!['categories'] as List?) ?? const []).cast<Map<String, dynamic>>();
    if (cats.isEmpty) {
      _err('Crée d\'abord une catégorie.');
      return;
    }
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _ItemDialog(
        title: 'Nouveau plat',
        categories: cats,
        initialCategoryId: categoryId ?? cats.first['id'],
      ),
    );
    if (result == null) return;
    final r = await widget.api.post(
      '/api/menu/cards/${widget.cardId}/items',
      result,
    );
    if (!mounted) return;
    r.when(success: (_) => _load(), failure: (e) => _err(e.message));
  }

  Future<void> _editItem(Map<String, dynamic> item) async {
    final cats = ((_card!['categories'] as List?) ?? const []).cast<Map<String, dynamic>>();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _ItemDialog(
        title: 'Éditer plat',
        categories: cats,
        initialCategoryId: item['category_id'] as String,
        initialName: item['name'] as String,
        initialDescription: item['description'] as String?,
        initialPriceCents: item['price_cents'] as int,
        initialAvailable: item['available'] as bool? ?? true,
        initialAllergens: ((item['allergens'] as List?) ?? const []).cast<String>().toSet(),
      ),
    );
    if (result == null) return;
    final r = await widget.api.put('/api/menu/items/${item['id']}', result);
    if (!mounted) return;
    r.when(success: (_) => _load(), failure: (e) => _err(e.message));
  }

  Future<void> _deleteItem(Map<String, dynamic> item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Supprimer "${item['name']}" ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Non')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: BrocBrand.brocRed),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final r = await widget.api.delete('/api/menu/items/${item['id']}');
    if (!mounted) return;
    r.when(success: (_) => _load(), failure: (e) => _err(e.message));
  }

  Future<void> _deleteCategory(Map<String, dynamic> cat) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Supprimer la catégorie "${cat['name']}" ?'),
        content: const Text('Tous les plats de cette catégorie seront supprimés aussi.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Non')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: BrocBrand.brocRed),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final r = await widget.api.delete('/api/menu/categories/${cat['id']}');
    if (!mounted) return;
    r.when(success: (_) => _load(), failure: (e) => _err(e.message));
  }

  Future<void> _editMeta() async {
    final nameCtrl = TextEditingController(text: _card!['name'] as String);
    String selectedKind = (_card!['kind'] as String?) ?? 'food';
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setLocal) {
        return AlertDialog(
          title: const Text('Éditer la carte'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nom de la carte',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedKind,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    border: OutlineInputBorder(),
                  ),
                  items: _kinds.map((k) => DropdownMenuItem(value: k.$1, child: Text(k.$2))).toList(),
                  onChanged: (v) => setLocal(() => selectedKind = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
            FilledButton(
              onPressed: () => Navigator.pop(context, {
                'name': nameCtrl.text.trim(),
                'kind': selectedKind,
              }),
              style: FilledButton.styleFrom(backgroundColor: BrocBrand.brocRed),
              child: const Text('Enregistrer'),
            ),
          ],
        );
      }),
    );
    if (result == null) return;
    final r = await widget.api.put('/api/menu/cards/${widget.cardId}', result);
    if (!mounted) return;
    r.when(success: (_) => _load(), failure: (e) => _err(e.message));
  }

  void _err(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(translateErrorFr(s)),
        backgroundColor: Colors.red.shade900,
      ));

  String _formatPrice(int cents) {
    final e = cents ~/ 100;
    final c = cents % 100;
    return c == 0 ? '$e €' : '$e,${c.toString().padLeft(2, '0')} €';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _card == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Éditeur carte')),
        body: const Center(child: CircularProgressIndicator(color: BrocBrand.brocRed)),
      );
    }
    final cats = ((_card!['categories'] as List?) ?? const []).cast<Map<String, dynamic>>();
    final items = ((_card!['items'] as List?) ?? const []).cast<Map<String, dynamic>>();
    final isPublished = _card!['published_at'] != null;

    final itemsByCat = <String, List<Map<String, dynamic>>>{};
    for (final it in items) {
      itemsByCat.putIfAbsent(it['category_id'] as String, () => []).add(it);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${_card!['name']} (v${_card!['version']})'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Éditer méta',
            onPressed: _editMeta,
          ),
          if (!isPublished)
            IconButton(
              icon: const Icon(Icons.publish, color: Colors.green),
              tooltip: 'Publier',
              onPressed: () async {
                final r = await widget.api.post('/api/menu/cards/${widget.cardId}/publish', null);
                if (!mounted) return;
                r.when(
                  success: (_) {
                    _load();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Carte publiée ✓'),
                      backgroundColor: BrocBrand.brocRed,
                    ));
                  },
                  failure: (e) => _err(e.message),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'PDF A4',
            onPressed: () {
              final url = '${widget.api.baseUrl}/api/menu/cards/${widget.cardId}/pdf';
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: SelectableText('PDF : $url'),
                duration: const Duration(seconds: 8),
              ));
            },
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'add-cat',
            onPressed: _addCategory,
            backgroundColor: BrocBrand.brocYellow,
            foregroundColor: BrocBrand.brocBlack,
            tooltip: 'Ajouter une catégorie',
            child: const Icon(Icons.folder_open),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'add-item',
            onPressed: cats.isEmpty ? null : () => _addItem(),
            backgroundColor: BrocBrand.brocRed,
            icon: const Icon(Icons.add),
            label: const Text('Ajouter un plat'),
          ),
        ],
      ),
      body: cats.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.menu_book, size: 64, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text('Aucune catégorie.\nCommence par en ajouter une.',
                      textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Ajouter une catégorie'),
                    onPressed: _addCategory,
                    style: FilledButton.styleFrom(backgroundColor: BrocBrand.brocRed),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 160),
              children: [
                for (final cat in cats) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: BrocBrand.brocRed.withValues(alpha: 0.15),
                    child: Row(
                      children: [
                        const Icon(Icons.folder, color: BrocBrand.brocYellow, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            (cat['name'] as String).toUpperCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                              color: BrocBrand.brocYellow,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, color: Colors.green, size: 20),
                          tooltip: 'Ajouter plat ici',
                          onPressed: () => _addItem(categoryId: cat['id'] as String),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
                          tooltip: 'Supprimer catégorie',
                          onPressed: () => _deleteCategory(cat),
                        ),
                      ],
                    ),
                  ),
                  if ((itemsByCat[cat['id']] ?? []).isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: TextButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Ajouter le 1er plat'),
                          onPressed: () => _addItem(categoryId: cat['id'] as String),
                        ),
                      ),
                    )
                  else
                    for (final it in itemsByCat[cat['id']]!) _itemTile(it),
                ],
              ],
            ),
    );
  }

  Widget _itemTile(Map<String, dynamic> it) {
    final available = it['available'] as bool? ?? true;
    final allergens = ((it['allergens'] as List?) ?? const []).cast<String>();
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      color: BrocBrand.brocBlack.withValues(alpha: 0.6),
      child: ListTile(
        title: Row(
          children: [
            Expanded(
              child: Text(
                it['name'] as String,
                style: TextStyle(
                  decoration: available ? null : TextDecoration.lineThrough,
                  color: available ? null : Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              _formatPrice(it['price_cents'] as int),
              style: const TextStyle(
                color: BrocBrand.brocYellow,
                fontWeight: FontWeight.bold,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (it['description'] != null && (it['description'] as String).isNotEmpty)
              Text(
                it['description'] as String,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            if (allergens.isNotEmpty)
              Wrap(
                spacing: 4,
                children: allergens.map((a) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade900.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(a, style: const TextStyle(fontSize: 9)),
                )).toList(),
              ),
            if (!available && it['unavailable_reason'] != null)
              Text('Rupture : ${it['unavailable_reason']}',
                  style: const TextStyle(color: BrocBrand.brocRed, fontSize: 11)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 18, color: Colors.grey),
              onPressed: () => _editItem(it),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
              onPressed: () => _deleteItem(it),
            ),
          ],
        ),
        onTap: () => _editItem(it),
      ),
    );
  }
}

class _ItemDialog extends StatefulWidget {
  final String title;
  final List<Map<String, dynamic>> categories;
  final String initialCategoryId;
  final String? initialName;
  final String? initialDescription;
  final int? initialPriceCents;
  final bool initialAvailable;
  final Set<String> initialAllergens;

  const _ItemDialog({
    required this.title,
    required this.categories,
    required this.initialCategoryId,
    this.initialName,
    this.initialDescription,
    this.initialPriceCents,
    this.initialAvailable = true,
    this.initialAllergens = const {},
  });

  @override
  State<_ItemDialog> createState() => _ItemDialogState();
}

class _ItemDialogState extends State<_ItemDialog> {
  late TextEditingController _name;
  late TextEditingController _desc;
  late TextEditingController _price;
  late String _categoryId;
  late bool _available;
  late Set<String> _allergens;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initialName ?? '');
    _desc = TextEditingController(text: widget.initialDescription ?? '');
    final priceEur = (widget.initialPriceCents ?? 0) / 100;
    _price = TextEditingController(
      text: widget.initialPriceCents == null ? '' : priceEur.toStringAsFixed(2),
    );
    _categoryId = widget.initialCategoryId;
    _available = widget.initialAvailable;
    _allergens = {...widget.initialAllergens};
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _name,
                autofocus: widget.initialName == null,
                decoration: const InputDecoration(
                  labelText: 'Nom du plat *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _categoryId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Catégorie *',
                        border: OutlineInputBorder(),
                      ),
                      items: widget.categories
                          .map((c) => DropdownMenuItem(
                                value: c['id'] as String,
                                child: Text(c['name'] as String),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _categoryId = v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _price,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Prix € *',
                        border: OutlineInputBorder(),
                        suffixText: '€',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _desc,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Description (optionnel)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Disponible'),
                subtitle: Text(_available ? 'Visible sur la carte' : 'EN RUPTURE'),
                value: _available,
                activeThumbColor: BrocBrand.brocYellow,
                onChanged: (v) => setState(() => _available = v),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 8, bottom: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Allergènes (INCO)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: _kAllergensFull
                    .map((a) => _allergenChip(a.$1, a.$2))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(
          onPressed: () {
            final name = _name.text.trim();
            final priceEur = double.tryParse(_price.text.trim().replaceAll(',', '.'));
            if (name.isEmpty || priceEur == null) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Nom et prix obligatoires'),
                backgroundColor: Colors.red,
              ));
              return;
            }
            Navigator.pop(context, {
              'name': name,
              if (_desc.text.trim().isNotEmpty) 'description': _desc.text.trim(),
              'price_cents': (priceEur * 100).round(),
              'category_id': _categoryId,
              'available': _available,
              'allergens': _allergens.toList(),
            });
          },
          style: FilledButton.styleFrom(backgroundColor: BrocBrand.brocRed),
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }

  Widget _allergenChip(String name, String label) {
    final selected = _allergens.contains(name);
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: selected,
      selectedColor: Colors.orange.shade900,
      checkmarkColor: BrocBrand.brocYellow,
      onSelected: (v) => setState(() {
        if (v) {
          _allergens.add(name);
        } else {
          _allergens.remove(name);
        }
      }),
    );
  }

  static const _kAllergensFull = <(String, String)>[
    ('gluten', 'Gluten'),
    ('dairy', 'Lait'),
    ('eggs', 'Œufs'),
    ('fish', 'Poisson'),
    ('crustaceans', 'Crustacés'),
    ('mollusks', 'Mollusques'),
    ('peanuts', 'Arachides'),
    ('treeNuts', 'Fruits à coque'),
    ('soy', 'Soja'),
    ('sesame', 'Sésame'),
    ('celery', 'Céleri'),
    ('mustard', 'Moutarde'),
    ('sulfites', 'Sulfites'),
    ('lupin', 'Lupin'),
  ];
}

// ===========================================================================
// MENU LIST SCREEN — Liste des cartes (filtrable par kind) + bouton import image
// ===========================================================================
class MenuListScreen extends StatefulWidget {
  final BrWebApi api;
  const MenuListScreen({super.key, required this.api});
  @override
  State<MenuListScreen> createState() => _MenuListScreenState();
}

class _MenuListScreenState extends State<MenuListScreen> {
  List<Map<String, dynamic>> _cards = const [];
  bool _loading = true;
  String? _filter; // kind name or null

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final path = _filter == null
        ? '/api/menu/cards?include_drafts=true'
        : '/api/menu/cards?kind=$_filter';
    final r = await widget.api.get(path);
    if (!mounted) return;
    r.when(
      success: (data) => setState(() {
        _cards = (data['cards'] as List).cast<Map<String, dynamic>>();
        _loading = false;
      }),
      failure: (_) => setState(() => _loading = false),
    );
  }

  Future<void> _createCard() async {
    final nameCtrl = TextEditingController();
    String selectedKind = 'food';
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setLocal) {
        return AlertDialog(
          title: const Text('Nouvelle carte'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Nom de la carte',
                    hintText: 'ex: Carte des vins, Plats du jour',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedKind,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    border: OutlineInputBorder(),
                  ),
                  items: _kinds.map((k) => DropdownMenuItem(value: k.$1, child: Text(k.$2))).toList(),
                  onChanged: (v) => setLocal(() => selectedKind = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
            FilledButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.pop(context, {
                  'name': nameCtrl.text.trim(),
                  'kind': selectedKind,
                });
              },
              style: FilledButton.styleFrom(backgroundColor: BrocBrand.brocRed),
              child: const Text('Créer'),
            ),
          ],
        );
      }),
    );
    if (result == null) return;
    final r = await widget.api.post('/api/menu/cards', result);
    if (!mounted) return;
    r.when(
      success: (card) {
        _load();
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => MenuEditorScreen(api: widget.api, cardId: card['id'] as String),
        )).then((_) => _load());
      },
      failure: (e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(translateErrorFr(e.message)),
        backgroundColor: Colors.red.shade900,
      )),
    );
  }

  Future<void> _importImage() async {
    String selectedKind = 'food';
    final ok = await showDialog<String>(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setLocal) {
        return AlertDialog(
          title: const Row(children: [
            Icon(Icons.image, color: BrocBrand.brocYellow),
            SizedBox(width: 8),
            Text('Importer depuis photo'),
          ]),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Sélectionne une photo de carte. Claude va extraire les plats, prix et catégories. Tu pourras ensuite éditer manuellement.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedKind,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Type de carte',
                    border: OutlineInputBorder(),
                  ),
                  items: _kinds.map((k) => DropdownMenuItem(value: k.$1, child: Text(k.$2))).toList(),
                  onChanged: (v) => setLocal(() => selectedKind = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
            FilledButton.icon(
              icon: const Icon(Icons.upload_file),
              label: const Text('Choisir une photo'),
              onPressed: () => Navigator.pop(context, selectedKind),
              style: FilledButton.styleFrom(backgroundColor: BrocBrand.brocRed),
            ),
          ],
        );
      }),
    );
    if (ok == null) return;

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      _err('Image illisible');
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: SizedBox(
          width: 280,
          height: 140,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: BrocBrand.brocRed),
              SizedBox(height: 16),
              Text('Claude analyse l\'image…', textAlign: TextAlign.center),
              Text('(15-30 secondes)', style: TextStyle(color: Colors.grey, fontSize: 11)),
            ],
          ),
        ),
      ),
    );

    try {
      final r = await widget.api.postRaw(
        '/api/menu/cards/import-image?kind=$ok',
        bytes,
        contentType: 'image/${file.extension ?? 'jpeg'}',
      );
      if (!mounted) return;
      Navigator.pop(context); // close loading
      r.when(
        success: (card) {
          _load();
          final meta = (card['meta'] as Map<String, dynamic>?) ?? const {};
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
              'Import OK : ${meta['imported_items'] ?? 0} plats, '
              '${meta['imported_categories'] ?? 0} catégories. Édite avant publication.',
            ),
            backgroundColor: BrocBrand.brocRed,
            duration: const Duration(seconds: 4),
          ));
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => MenuEditorScreen(api: widget.api, cardId: card['id'] as String),
          )).then((_) => _load());
        },
        failure: (e) {
          _err('Import échoué : ${e.message}');
        },
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _err('Erreur import : $e');
    }
  }

  Future<void> _deleteCard(Map<String, dynamic> c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Supprimer "${c['name']}" ?'),
        content: const Text('Catégories et plats seront supprimés aussi.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Non')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: BrocBrand.brocRed),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final r = await widget.api.delete('/api/menu/cards/${c['id']}');
    if (!mounted) return;
    r.when(success: (_) => _load(), failure: (e) => _err(e.message));
  }

  void _err(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(translateErrorFr(s)),
        backgroundColor: Colors.red.shade900,
      ));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'menu-import',
            onPressed: kIsWeb ? _importImage : _importImage,
            backgroundColor: BrocBrand.brocYellow,
            foregroundColor: BrocBrand.brocBlack,
            tooltip: 'Importer depuis une photo',
            child: const Icon(Icons.image_search),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'menu-add',
            onPressed: _createCard,
            backgroundColor: BrocBrand.brocRed,
            icon: const Icon(Icons.add),
            label: const Text('Nouvelle carte'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Tous'),
                  selected: _filter == null,
                  selectedColor: BrocBrand.brocRed,
                  checkmarkColor: BrocBrand.brocCream,
                  onSelected: (_) {
                    setState(() => _filter = null);
                    _load();
                  },
                ),
                const SizedBox(width: 4),
                for (final k in _kinds) ...[
                  FilterChip(
                    label: Text(k.$2),
                    selected: _filter == k.$1,
                    selectedColor: BrocBrand.brocRed,
                    checkmarkColor: BrocBrand.brocCream,
                    onSelected: (_) {
                      setState(() => _filter = k.$1);
                      _load();
                    },
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
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: BrocBrand.brocRed))
                  : _cards.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.menu_book, size: 64, color: Colors.grey),
                                SizedBox(height: 12),
                                Text(
                                  'Aucune carte.\n+ Nouvelle carte ou import depuis photo.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          itemCount: _cards.length + 1,
                          itemBuilder: (_, i) {
                            if (i == _cards.length) return const SizedBox(height: 160);
                            final c = _cards[i];
                            final pub = c['published_at'] != null;
                            final itemsCount = ((c['items'] as List?) ?? const []).length;
                            final catsCount = ((c['categories'] as List?) ?? const []).length;
                            final kindLabel = (c['kind_label'] as String?) ?? c['kind'] ?? '';
                            return Card(
                              color: BrocBrand.brocBlack.withValues(alpha: 0.4),
                              child: ListTile(
                                leading: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: pub ? Colors.green.shade900 : Colors.grey.shade800,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    pub ? Icons.check_circle : Icons.edit,
                                    color: pub ? BrocBrand.brocYellow : Colors.grey,
                                  ),
                                ),
                                title: Text('${c['name']} (v${c['version']})'),
                                subtitle: Text(
                                  '$kindLabel · $itemsCount items · $catsCount catégories · '
                                  '${pub ? "PUBLIÉE" : "brouillon"}',
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: BrocBrand.brocYellow),
                                      tooltip: 'Éditer',
                                      onPressed: () {
                                        Navigator.push(context, MaterialPageRoute(
                                          builder: (_) => MenuEditorScreen(
                                              api: widget.api, cardId: c['id'] as String),
                                        )).then((_) => _load());
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.grey),
                                      onPressed: () => _deleteCard(c),
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  Navigator.push(context, MaterialPageRoute(
                                    builder: (_) => MenuEditorScreen(
                                        api: widget.api, cardId: c['id'] as String),
                                  )).then((_) => _load());
                                },
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
