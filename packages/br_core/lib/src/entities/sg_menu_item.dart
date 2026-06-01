import 'package:meta/meta.dart';

import 'sg_allergen.dart';

@immutable
class SgMenuItem {
  final String id;
  final String cardId;
  final String categoryId;
  final String name;
  final String? description;
  final int priceCents;
  final bool available;
  final Set<SgAllergen> allergens;
  final int sortOrder;
  final String? unavailableReason;

  const SgMenuItem({
    required this.id,
    required this.cardId,
    required this.categoryId,
    required this.name,
    required this.priceCents,
    required this.available,
    required this.allergens,
    required this.sortOrder,
    this.description,
    this.unavailableReason,
  });

  /// Prix formaté en euros : `12,50 €` (locale FR).
  String formattedPrice({String currency = '€'}) {
    final euros = priceCents ~/ 100;
    final cents = priceCents % 100;
    return cents == 0
        ? '$euros $currency'
        : '$euros,${cents.toString().padLeft(2, '0')} $currency';
  }

  SgMenuItem copyWith({
    String? id,
    String? cardId,
    String? categoryId,
    String? name,
    String? description,
    int? priceCents,
    bool? available,
    Set<SgAllergen>? allergens,
    int? sortOrder,
    String? unavailableReason,
  }) =>
      SgMenuItem(
        id: id ?? this.id,
        cardId: cardId ?? this.cardId,
        categoryId: categoryId ?? this.categoryId,
        name: name ?? this.name,
        description: description ?? this.description,
        priceCents: priceCents ?? this.priceCents,
        available: available ?? this.available,
        allergens: allergens ?? this.allergens,
        sortOrder: sortOrder ?? this.sortOrder,
        unavailableReason: unavailableReason ?? this.unavailableReason,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'card_id': cardId,
        'category_id': categoryId,
        'name': name,
        if (description != null) 'description': description,
        'price_cents': priceCents,
        'available': available,
        if (unavailableReason != null) 'unavailable_reason': unavailableReason,
        'allergens': allergens.map((a) => a.name).toList(),
        'sort_order': sortOrder,
      };

  factory SgMenuItem.fromJson(Map<String, dynamic> json) => SgMenuItem(
        id: json['id'] as String,
        cardId: json['card_id'] as String,
        categoryId: json['category_id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        priceCents: json['price_cents'] as int,
        available: json['available'] as bool? ?? true,
        unavailableReason: json['unavailable_reason'] as String?,
        allergens: ((json['allergens'] as List<dynamic>?) ?? const [])
            .map((a) =>
                SgAllergen.values.firstWhere((al) => al.name == a as String))
            .toSet(),
        sortOrder: json['sort_order'] as int? ?? 0,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SgMenuItem && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'SgMenuItem($id, "$name", ${formattedPrice()}${available ? "" : ", UNAVAIL"})';
}
