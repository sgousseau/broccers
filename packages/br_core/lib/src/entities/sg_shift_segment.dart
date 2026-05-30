import 'package:meta/meta.dart';

import 'sg_employee.dart';

/// Un segment d'un shift : un rôle tenu sur un intervalle.
///
/// Un shift contient N segments enchaînés. Le segment actif est celui dont
/// `endedAt == null`. Tout changement de rôle ferme le segment en cours et
/// ouvre un nouveau.
@immutable
class SgShiftSegment {
  final String id;
  final String shiftId;
  final SgEmployeeRole role;
  final DateTime startedAt;
  final DateTime? endedAt;

  /// `reason` optionnelle expliquant pourquoi ce segment a été ouvert (ex « manager assigned », « employee corrected », « clock-in initial », « shift end »).
  final String? reason;

  /// Qui a déclenché la création de ce segment. Peut être employé lui-même OU un manager.
  /// Valeur `"system"` pour les transitions automatiques (clock-out).
  final String createdBy;

  const SgShiftSegment({
    required this.id,
    required this.shiftId,
    required this.role,
    required this.startedAt,
    required this.createdBy,
    this.endedAt,
    this.reason,
  });

  bool get isActive => endedAt == null;
  Duration get duration => (endedAt ?? DateTime.now()).difference(startedAt);

  SgShiftSegment end({required DateTime at}) => copyWith(endedAt: at);

  SgShiftSegment copyWith({
    String? id,
    String? shiftId,
    SgEmployeeRole? role,
    DateTime? startedAt,
    DateTime? endedAt,
    String? reason,
    String? createdBy,
  }) =>
      SgShiftSegment(
        id: id ?? this.id,
        shiftId: shiftId ?? this.shiftId,
        role: role ?? this.role,
        startedAt: startedAt ?? this.startedAt,
        endedAt: endedAt ?? this.endedAt,
        reason: reason ?? this.reason,
        createdBy: createdBy ?? this.createdBy,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'shift_id': shiftId,
        'role': role.name,
        'started_at': startedAt.toIso8601String(),
        if (endedAt != null) 'ended_at': endedAt!.toIso8601String(),
        if (reason != null) 'reason': reason,
        'created_by': createdBy,
      };

  factory SgShiftSegment.fromJson(Map<String, dynamic> json) => SgShiftSegment(
        id: json['id'] as String,
        shiftId: json['shift_id'] as String,
        role: SgEmployeeRole.fromName(json['role'] as String),
        startedAt: DateTime.parse(json['started_at'] as String),
        endedAt: json['ended_at'] != null
            ? DateTime.parse(json['ended_at'] as String)
            : null,
        reason: json['reason'] as String?,
        createdBy: json['created_by'] as String,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SgShiftSegment && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'SgShiftSegment($id, ${role.name}, ${duration.inMinutes}min${isActive ? ", active" : ""})';
}
