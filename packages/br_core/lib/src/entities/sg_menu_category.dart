import 'package:meta/meta.dart';

@immutable
class SgMenuCategory {
  final String id;
  final String cardId;
  final String name;
  final int sortOrder;

  const SgMenuCategory({
    required this.id,
    required this.cardId,
    required this.name,
    required this.sortOrder,
  });

  SgMenuCategory copyWith({
    String? id,
    String? cardId,
    String? name,
    int? sortOrder,
  }) =>
      SgMenuCategory(
        id: id ?? this.id,
        cardId: cardId ?? this.cardId,
        name: name ?? this.name,
        sortOrder: sortOrder ?? this.sortOrder,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'card_id': cardId,
        'name': name,
        'sort_order': sortOrder,
      };

  factory SgMenuCategory.fromJson(Map<String, dynamic> json) => SgMenuCategory(
        id: json['id'] as String,
        cardId: json['card_id'] as String,
        name: json['name'] as String,
        sortOrder: json['sort_order'] as int,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SgMenuCategory && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'SgMenuCategory($id, "$name", #$sortOrder)';
}
