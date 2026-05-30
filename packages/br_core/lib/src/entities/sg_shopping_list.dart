import 'package:meta/meta.dart';

enum SgShoppingListStatus {
  open, closed;
}

@immutable
class SgShoppingList {
  final String id;
  final String name;
  final DateTime createdAt;
  final SgShoppingListStatus status;

  const SgShoppingList({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.status,
  });

  factory SgShoppingList.open({
    required String id,
    required String name,
    required DateTime createdAt,
  }) =>
      SgShoppingList(
        id: id,
        name: name,
        createdAt: createdAt,
        status: SgShoppingListStatus.open,
      );

  SgShoppingList close() => copyWith(status: SgShoppingListStatus.closed);

  SgShoppingList copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    SgShoppingListStatus? status,
  }) =>
      SgShoppingList(
        id: id ?? this.id,
        name: name ?? this.name,
        createdAt: createdAt ?? this.createdAt,
        status: status ?? this.status,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'created_at': createdAt.toIso8601String(),
        'status': status.name,
      };

  factory SgShoppingList.fromJson(Map<String, dynamic> json) => SgShoppingList(
        id: json['id'] as String,
        name: json['name'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        status: SgShoppingListStatus.values
            .firstWhere((s) => s.name == json['status']),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SgShoppingList && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'SgShoppingList($id, "$name", ${status.name})';
}
