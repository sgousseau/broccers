import 'package:meta/meta.dart';

enum SgEmployeeRole {
  manager('Manager'),
  server('Serveur'),
  cook('Cuisinier'),
  bartender('Barman'),
  dishwasher('Plongeur'),
  host('Hôte');

  final String label;
  const SgEmployeeRole(this.label);
}

/// Employé de Broc. PINs hashés (bcrypt côté serveur) ne transitent jamais en clair.
@immutable
class SgEmployee {
  final String id;
  final String name;
  final SgEmployeeRole role;
  final double contractedHours;
  final String kioskName;
  final String? personalPinHash;
  final String? kioskPinHash;
  final bool active;

  const SgEmployee({
    required this.id,
    required this.name,
    required this.role,
    required this.contractedHours,
    required this.kioskName,
    this.personalPinHash,
    this.kioskPinHash,
    this.active = true,
  });

  SgEmployee copyWith({
    String? id,
    String? name,
    SgEmployeeRole? role,
    double? contractedHours,
    String? kioskName,
    String? personalPinHash,
    String? kioskPinHash,
    bool? active,
  }) =>
      SgEmployee(
        id: id ?? this.id,
        name: name ?? this.name,
        role: role ?? this.role,
        contractedHours: contractedHours ?? this.contractedHours,
        kioskName: kioskName ?? this.kioskName,
        personalPinHash: personalPinHash ?? this.personalPinHash,
        kioskPinHash: kioskPinHash ?? this.kioskPinHash,
        active: active ?? this.active,
      );

  Map<String, dynamic> toJson({bool includeHashes = false}) => {
        'id': id,
        'name': name,
        'role': role.name,
        'contracted_hours': contractedHours,
        'kiosk_name': kioskName,
        if (includeHashes && personalPinHash != null)
          'personal_pin_hash': personalPinHash,
        if (includeHashes && kioskPinHash != null)
          'kiosk_pin_hash': kioskPinHash,
        'active': active,
      };

  factory SgEmployee.fromJson(Map<String, dynamic> json) => SgEmployee(
        id: json['id'] as String,
        name: json['name'] as String,
        role: SgEmployeeRole.values
            .firstWhere((r) => r.name == json['role']),
        contractedHours: (json['contracted_hours'] as num).toDouble(),
        kioskName: json['kiosk_name'] as String,
        personalPinHash: json['personal_pin_hash'] as String?,
        kioskPinHash: json['kiosk_pin_hash'] as String?,
        active: json['active'] as bool? ?? true,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SgEmployee &&
          other.id == id &&
          other.name == name &&
          other.role == role &&
          other.active == active);

  @override
  int get hashCode => Object.hash(id, name, role, active);

  @override
  String toString() => 'SgEmployee($id, $name, ${role.name})';
}
