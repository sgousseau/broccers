import 'package:meta/meta.dart';

enum SgBreakType {
  legal('Pause légale', Duration(minutes: 20)),
  lunch('Déjeuner', Duration(minutes: 45)),
  quick('Pause rapide', Duration(minutes: 10));

  final String label;
  final Duration defaultDuration;
  const SgBreakType(this.label, this.defaultDuration);
}

/// Pause durant un shift. `endedAt` null tant que en cours.
@immutable
class SgBreak {
  final String id;
  final String employeeId;
  final String shiftId;
  final SgBreakType type;
  final DateTime startedAt;
  final DateTime? endedAt;
  final Duration expectedDuration;

  const SgBreak({
    required this.id,
    required this.employeeId,
    required this.shiftId,
    required this.type,
    required this.startedAt,
    required this.expectedDuration,
    this.endedAt,
  });

  factory SgBreak.start({
    required String id,
    required String employeeId,
    required String shiftId,
    required SgBreakType type,
    required DateTime startedAt,
    Duration? expectedDuration,
  }) =>
      SgBreak(
        id: id,
        employeeId: employeeId,
        shiftId: shiftId,
        type: type,
        startedAt: startedAt,
        expectedDuration: expectedDuration ?? type.defaultDuration,
      );

  SgBreak end({required DateTime at}) => copyWith(endedAt: at);

  bool get isActive => endedAt == null;
  Duration get duration =>
      (endedAt ?? DateTime.now()).difference(startedAt);

  /// True si la pause est terminée mais trop courte vs expectedDuration.
  bool get isShorterThanExpected =>
      !isActive && duration < expectedDuration;

  SgBreak copyWith({
    String? id,
    String? employeeId,
    String? shiftId,
    SgBreakType? type,
    DateTime? startedAt,
    DateTime? endedAt,
    Duration? expectedDuration,
  }) =>
      SgBreak(
        id: id ?? this.id,
        employeeId: employeeId ?? this.employeeId,
        shiftId: shiftId ?? this.shiftId,
        type: type ?? this.type,
        startedAt: startedAt ?? this.startedAt,
        endedAt: endedAt ?? this.endedAt,
        expectedDuration: expectedDuration ?? this.expectedDuration,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'employee_id': employeeId,
        'shift_id': shiftId,
        'type': type.name,
        'started_at': startedAt.toIso8601String(),
        if (endedAt != null) 'ended_at': endedAt!.toIso8601String(),
        'expected_duration_ms': expectedDuration.inMilliseconds,
      };

  factory SgBreak.fromJson(Map<String, dynamic> json) => SgBreak(
        id: json['id'] as String,
        employeeId: json['employee_id'] as String,
        shiftId: json['shift_id'] as String,
        type: SgBreakType.values.firstWhere((t) => t.name == json['type']),
        startedAt: DateTime.parse(json['started_at'] as String),
        endedAt: json['ended_at'] != null
            ? DateTime.parse(json['ended_at'] as String)
            : null,
        expectedDuration:
            Duration(milliseconds: json['expected_duration_ms'] as int),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is SgBreak && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'SgBreak($id, ${type.name}, ${duration.inMinutes}min/${expectedDuration.inMinutes}min)';
}
