import 'package:meta/meta.dart';

@immutable
class SgShoppingItem {
  final String id;
  final String listId;
  final String? supplierId;
  final String name;
  final double quantity;
  final String unit;
  final bool urgent;
  final bool done;
  final DateTime createdAt;
  final DateTime? checkedAt;

  const SgShoppingItem({
    required this.id,
    required this.listId,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.createdAt,
    this.supplierId,
    this.urgent = false,
    this.done = false,
    this.checkedAt,
  });

  SgShoppingItem check({required DateTime at}) =>
      copyWith(done: true, checkedAt: at);

  SgShoppingItem uncheck() => copyWith(done: false, checkedAt: null);

  SgShoppingItem copyWith({
    String? id,
    String? listId,
    String? supplierId,
    String? name,
    double? quantity,
    String? unit,
    bool? urgent,
    bool? done,
    DateTime? createdAt,
    DateTime? checkedAt,
  }) =>
      SgShoppingItem(
        id: id ?? this.id,
        listId: listId ?? this.listId,
        supplierId: supplierId ?? this.supplierId,
        name: name ?? this.name,
        quantity: quantity ?? this.quantity,
        unit: unit ?? this.unit,
        urgent: urgent ?? this.urgent,
        done: done ?? this.done,
        createdAt: createdAt ?? this.createdAt,
        checkedAt: checkedAt ?? this.checkedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'list_id': listId,
        if (supplierId != null) 'supplier_id': supplierId,
        'name': name,
        'quantity': quantity,
        'unit': unit,
        'urgent': urgent,
        'done': done,
        'created_at': createdAt.toIso8601String(),
        if (checkedAt != null) 'checked_at': checkedAt!.toIso8601String(),
      };

  factory SgShoppingItem.fromJson(Map<String, dynamic> json) => SgShoppingItem(
        id: json['id'] as String,
        listId: json['list_id'] as String,
        supplierId: json['supplier_id'] as String?,
        name: json['name'] as String,
        quantity: (json['quantity'] as num).toDouble(),
        unit: json['unit'] as String,
        urgent: json['urgent'] as bool? ?? false,
        done: json['done'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
        checkedAt: json['checked_at'] != null
            ? DateTime.parse(json['checked_at'] as String)
            : null,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SgShoppingItem && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'SgShoppingItem($id, "$name" $quantity $unit${done ? " ✓" : ""}${urgent ? " ⚠" : ""})';
}
