import 'package:meta/meta.dart';

@immutable
class SgSupplier {
  final String id;
  final String name;
  final String? contact;

  const SgSupplier({required this.id, required this.name, this.contact});

  SgSupplier copyWith({String? id, String? name, String? contact}) =>
      SgSupplier(
        id: id ?? this.id,
        name: name ?? this.name,
        contact: contact ?? this.contact,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (contact != null) 'contact': contact,
      };

  factory SgSupplier.fromJson(Map<String, dynamic> json) => SgSupplier(
        id: json['id'] as String,
        name: json['name'] as String,
        contact: json['contact'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SgSupplier && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'SgSupplier($id, "$name")';
}
