import 'package:meta/meta.dart';

enum SgEmployeeRole {
  manager('Manager'),
  server('Serveur'),
  runner('Runner'),
  cook('Cuisinier'),
  bartender('Barman'),
  dishwasher('Plongeur'),
  host('Hôte');

  final String label;
  const SgEmployeeRole(this.label);

  static SgEmployeeRole fromName(String n) =>
      SgEmployeeRole.values.firstWhere((r) => r.name == n);
}

/// Jours de la semaine ISO (1=Lundi, 7=Dimanche). Aligné `DateTime.weekday`.
enum SgWeekday {
  monday(1, 'Lundi'),
  tuesday(2, 'Mardi'),
  wednesday(3, 'Mercredi'),
  thursday(4, 'Jeudi'),
  friday(5, 'Vendredi'),
  saturday(6, 'Samedi'),
  sunday(7, 'Dimanche');

  final int isoDay;
  final String label;
  const SgWeekday(this.isoDay, this.label);

  static SgWeekday fromIso(int d) =>
      SgWeekday.values.firstWhere((w) => w.isoDay == d);

  static SgWeekday ofDate(DateTime d) => fromIso(d.weekday);
}

/// Employé de Broc.
///
/// **Phase A (2026-05-31) — multi-rôles** :
/// - [roles] = capabilities (toutes les casquettes possibles : Eros sait barman + runner + plonge)
/// - [defaultRole] = fallback rôle si pas dans [weeklyDefault]
/// - [weeklyDefault] = planning hebdo type (mercredi=barman, jeudi=serveur)
///
/// PINs hashés (bcrypt côté serveur) ne transitent jamais en clair.
@immutable
class SgEmployee {
  final String id;
  final String name;
  final Set<SgEmployeeRole> roles;
  final SgEmployeeRole? defaultRole;
  final Map<SgWeekday, SgEmployeeRole> weeklyDefault;
  final double contractedHours;
  final String kioskName;
  final String? personalPinHash;
  final String? kioskPinHash;
  final bool active;

  const SgEmployee({
    required this.id,
    required this.name,
    required this.roles,
    required this.contractedHours,
    required this.kioskName,
    this.defaultRole,
    this.weeklyDefault = const {},
    this.personalPinHash,
    this.kioskPinHash,
    this.active = true,
  });

  /// Résout le rôle effectif pour une date donnée.
  /// Ordre : override → weeklyDefault[weekday] → defaultRole → seule capability → null
  SgEmployeeRole? resolveRoleFor(DateTime date, {SgEmployeeRole? override}) {
    if (override != null && roles.contains(override)) return override;
    final wd = SgWeekday.ofDate(date);
    final scheduled = weeklyDefault[wd];
    if (scheduled != null && roles.contains(scheduled)) return scheduled;
    if (defaultRole != null && roles.contains(defaultRole)) return defaultRole;
    if (roles.length == 1) return roles.first;
    return null;
  }

  bool canHold(SgEmployeeRole role) => roles.contains(role);

  SgEmployee copyWith({
    String? id,
    String? name,
    Set<SgEmployeeRole>? roles,
    SgEmployeeRole? defaultRole,
    Map<SgWeekday, SgEmployeeRole>? weeklyDefault,
    double? contractedHours,
    String? kioskName,
    String? personalPinHash,
    String? kioskPinHash,
    bool? active,
  }) =>
      SgEmployee(
        id: id ?? this.id,
        name: name ?? this.name,
        roles: roles ?? this.roles,
        defaultRole: defaultRole ?? this.defaultRole,
        weeklyDefault: weeklyDefault ?? this.weeklyDefault,
        contractedHours: contractedHours ?? this.contractedHours,
        kioskName: kioskName ?? this.kioskName,
        personalPinHash: personalPinHash ?? this.personalPinHash,
        kioskPinHash: kioskPinHash ?? this.kioskPinHash,
        active: active ?? this.active,
      );

  Map<String, dynamic> toJson({bool includeHashes = false}) => {
        'id': id,
        'name': name,
        'roles': roles.map((r) => r.name).toList(),
        if (defaultRole != null) 'default_role': defaultRole!.name,
        'weekly_default': {
          for (final e in weeklyDefault.entries)
            e.key.isoDay.toString(): e.value.name,
        },
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
        roles: ((json['roles'] as List<dynamic>?) ?? const <dynamic>[])
            .map((r) => SgEmployeeRole.fromName(r as String))
            .toSet(),
        defaultRole: json['default_role'] != null
            ? SgEmployeeRole.fromName(json['default_role'] as String)
            : null,
        weeklyDefault:
            ((json['weekly_default'] as Map<String, dynamic>?) ?? const {})
                .map((k, v) => MapEntry(
                      SgWeekday.fromIso(int.parse(k)),
                      SgEmployeeRole.fromName(v as String),
                    )),
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
          other.active == active);

  @override
  int get hashCode => Object.hash(id, name, active);

  @override
  String toString() =>
      'SgEmployee($id, $name, roles={${roles.map((r) => r.name).join(",")}})';
}
