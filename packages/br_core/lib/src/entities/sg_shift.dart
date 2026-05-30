import 'package:meta/meta.dart';

enum SgShiftStatus {
  planned, active, ended, cancelled;
}

enum SgShiftPosition {
  service, bar, kitchen, host, other;
}

/// Créneau de travail d'un employé. `endsAt` null tant que actif.
///
/// **Phase D** : [tipCents] = pourboires perçus durant ce shift (saisie manager ou employé en fin de shift).
@immutable
class SgShift {
  final String id;
  final String employeeId;
  final DateTime startsAt;
  final DateTime? endsAt;
  final DateTime? plannedEndsAt;
  final SgShiftPosition position;
  final SgShiftStatus status;
  final int tipCents;

  const SgShift({
    required this.id,
    required this.employeeId,
    required this.startsAt,
    required this.status,
    required this.position,
    this.endsAt,
    this.plannedEndsAt,
    this.tipCents = 0,
  });

  factory SgShift.clockIn({
    required String id,
    required String employeeId,
    required DateTime startsAt,
    SgShiftPosition position = SgShiftPosition.service,
    DateTime? plannedEndsAt,
  }) =>
      SgShift(
        id: id,
        employeeId: employeeId,
        startsAt: startsAt,
        status: SgShiftStatus.active,
        position: position,
        plannedEndsAt: plannedEndsAt,
      );

  SgShift end({required DateTime at}) => copyWith(
        endsAt: at,
        status: SgShiftStatus.ended,
      );

  SgShift cancel({required DateTime at}) => copyWith(
        endsAt: at,
        status: SgShiftStatus.cancelled,
      );

  SgShift withTip(int tipCents) => copyWith(tipCents: tipCents);

  bool get isActive => status == SgShiftStatus.active;
  Duration get duration =>
      (endsAt ?? DateTime.now()).difference(startsAt);

  SgShift copyWith({
    String? id,
    String? employeeId,
    DateTime? startsAt,
    DateTime? endsAt,
    DateTime? plannedEndsAt,
    SgShiftPosition? position,
    SgShiftStatus? status,
    int? tipCents,
  }) =>
      SgShift(
        id: id ?? this.id,
        employeeId: employeeId ?? this.employeeId,
        startsAt: startsAt ?? this.startsAt,
        endsAt: endsAt ?? this.endsAt,
        plannedEndsAt: plannedEndsAt ?? this.plannedEndsAt,
        position: position ?? this.position,
        status: status ?? this.status,
        tipCents: tipCents ?? this.tipCents,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'employee_id': employeeId,
        'starts_at': startsAt.toIso8601String(),
        if (endsAt != null) 'ends_at': endsAt!.toIso8601String(),
        if (plannedEndsAt != null) 'planned_ends_at': plannedEndsAt!.toIso8601String(),
        'position': position.name,
        'status': status.name,
        'tip_cents': tipCents,
      };

  factory SgShift.fromJson(Map<String, dynamic> json) => SgShift(
        id: json['id'] as String,
        employeeId: json['employee_id'] as String,
        startsAt: DateTime.parse(json['starts_at'] as String),
        endsAt: json['ends_at'] != null
            ? DateTime.parse(json['ends_at'] as String)
            : null,
        plannedEndsAt: json['planned_ends_at'] != null
            ? DateTime.parse(json['planned_ends_at'] as String)
            : null,
        position: SgShiftPosition.values
            .firstWhere((p) => p.name == json['position']),
        status: SgShiftStatus.values
            .firstWhere((s) => s.name == json['status']),
        tipCents: json['tip_cents'] as int? ?? 0,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SgShift && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'SgShift($id, emp=$employeeId, ${status.name}, ${duration.inMinutes}min${tipCents > 0 ? ", tip=${tipCents}c" : ""})';
}
