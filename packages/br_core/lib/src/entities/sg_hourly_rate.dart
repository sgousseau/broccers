import 'package:meta/meta.dart';

import 'sg_employee.dart';

/// Taux horaire versionné. Un employé peut avoir N entrées (changements de tarif dans le temps).
///
/// Si [role] est null : tarif global tout rôle confondu.
/// Si [role] est précisé : tarif spécifique à ce rôle (ex barman 14€/h, plonge 12€/h).
///
/// La résolution du tarif pour un segment de shift cherche, dans l'ordre :
/// 1. Tarif (employé + rôle spécifique) couvrant la période → utilise celui-là
/// 2. Tarif (employé + null) couvrant la période → fallback
/// 3. Pas trouvé → 0 (ou failure selon caller)
@immutable
class SgHourlyRate {
  final String id;
  final String employeeId;
  final SgEmployeeRole? role;
  final int rateCents;
  final DateTime validFrom;
  final DateTime? validTo;
  final String? source;

  const SgHourlyRate({
    required this.id,
    required this.employeeId,
    required this.rateCents,
    required this.validFrom,
    this.role,
    this.validTo,
    this.source,
  });

  /// True si le tarif est applicable à la date [at].
  bool isValidAt(DateTime at) =>
      !at.isBefore(validFrom) && (validTo == null || at.isBefore(validTo!));

  /// Tarif formaté en euros : `13,50 €/h`
  String formattedRate({String currency = '€/h'}) {
    final euros = rateCents ~/ 100;
    final cents = rateCents % 100;
    return cents == 0
        ? '$euros $currency'
        : '$euros,${cents.toString().padLeft(2, '0')} $currency';
  }

  SgHourlyRate copyWith({
    String? id,
    String? employeeId,
    SgEmployeeRole? role,
    int? rateCents,
    DateTime? validFrom,
    DateTime? validTo,
    String? source,
  }) =>
      SgHourlyRate(
        id: id ?? this.id,
        employeeId: employeeId ?? this.employeeId,
        role: role ?? this.role,
        rateCents: rateCents ?? this.rateCents,
        validFrom: validFrom ?? this.validFrom,
        validTo: validTo ?? this.validTo,
        source: source ?? this.source,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'employee_id': employeeId,
        if (role != null) 'role': role!.name,
        'rate_cents': rateCents,
        'valid_from': validFrom.toIso8601String(),
        if (validTo != null) 'valid_to': validTo!.toIso8601String(),
        if (source != null) 'source': source,
      };

  factory SgHourlyRate.fromJson(Map<String, dynamic> json) => SgHourlyRate(
        id: json['id'] as String,
        employeeId: json['employee_id'] as String,
        role: json['role'] != null
            ? SgEmployeeRole.fromName(json['role'] as String)
            : null,
        rateCents: json['rate_cents'] as int,
        validFrom: DateTime.parse(json['valid_from'] as String),
        validTo: json['valid_to'] != null
            ? DateTime.parse(json['valid_to'] as String)
            : null,
        source: json['source'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SgHourlyRate && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'SgHourlyRate($id, emp=$employeeId, ${role?.name ?? "all"}, ${formattedRate()})';
}
