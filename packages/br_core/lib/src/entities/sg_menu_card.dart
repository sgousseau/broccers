import 'package:meta/meta.dart';

import 'sg_menu_category.dart';
import 'sg_menu_item.dart';

@immutable
class SgMenuCard {
  final String id;
  final String name;
  final int version;
  final DateTime createdAt;
  final DateTime? publishedAt;
  final List<SgMenuCategory> categories;
  final List<SgMenuItem> items;

  const SgMenuCard({
    required this.id,
    required this.name,
    required this.version,
    required this.createdAt,
    required this.categories,
    required this.items,
    this.publishedAt,
  });

  bool get isDraft => publishedAt == null;
  bool get isPublished => publishedAt != null;

  /// Items groupés par catégorie, dans l'ordre `sortOrder` de chaque.
  Map<SgMenuCategory, List<SgMenuItem>> groupedByCategory() {
    final sortedCats = [...categories]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return {
      for (final cat in sortedCats)
        cat: (items.where((i) => i.categoryId == cat.id).toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder))),
    };
  }

  SgMenuCard publish({required DateTime at}) =>
      copyWith(publishedAt: at);

  SgMenuCard copyWith({
    String? id,
    String? name,
    int? version,
    DateTime? createdAt,
    DateTime? publishedAt,
    List<SgMenuCategory>? categories,
    List<SgMenuItem>? items,
  }) =>
      SgMenuCard(
        id: id ?? this.id,
        name: name ?? this.name,
        version: version ?? this.version,
        createdAt: createdAt ?? this.createdAt,
        publishedAt: publishedAt ?? this.publishedAt,
        categories: categories ?? this.categories,
        items: items ?? this.items,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'version': version,
        'created_at': createdAt.toIso8601String(),
        if (publishedAt != null) 'published_at': publishedAt!.toIso8601String(),
        'categories': categories.map((c) => c.toJson()).toList(),
        'items': items.map((i) => i.toJson()).toList(),
      };

  factory SgMenuCard.fromJson(Map<String, dynamic> json) => SgMenuCard(
        id: json['id'] as String,
        name: json['name'] as String,
        version: json['version'] as int,
        createdAt: DateTime.parse(json['created_at'] as String),
        publishedAt: json['published_at'] != null
            ? DateTime.parse(json['published_at'] as String)
            : null,
        categories: ((json['categories'] as List<dynamic>?) ?? const [])
            .map((c) =>
                SgMenuCategory.fromJson(c as Map<String, dynamic>))
            .toList(),
        items: ((json['items'] as List<dynamic>?) ?? const [])
            .map((i) => SgMenuItem.fromJson(i as Map<String, dynamic>))
            .toList(),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SgMenuCard && other.id == id && other.version == version);

  @override
  int get hashCode => Object.hash(id, version);

  @override
  String toString() =>
      'SgMenuCard($id, "$name", v$version, ${items.length} items${isPublished ? ", published" : ""})';
}
