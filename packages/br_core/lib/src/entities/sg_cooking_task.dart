import 'package:meta/meta.dart';

/// État d'une tâche de cuisine (1 étape d'une recette pour un item de ticket précis).
enum SgCookingTaskStatus {
  pending,
  inProgress,
  done,
  skipped,
}

/// Tâche cuisine concrète : étape d'une recette en cours d'exécution pour un item de ticket.
///
/// Lifecycle : pending → inProgress (startedAt) → done (completedAt).
/// `assignedTo` = employé qui s'en occupe (optionnel).
@immutable
class SgCookingTask {
  final String id;
  final String ticketItemId;
  final String? recipeStepId;
  final String label;
  final SgCookingTaskStatus status;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final Duration expectedDuration;
  final String? assignedTo;
  final int sortOrder;

  const SgCookingTask({
    required this.id,
    required this.ticketItemId,
    required this.label,
    required this.status,
    required this.expectedDuration,
    required this.sortOrder,
    this.recipeStepId,
    this.startedAt,
    this.completedAt,
    this.assignedTo,
  });

  bool get isOverdue =>
      status == SgCookingTaskStatus.inProgress &&
      startedAt != null &&
      DateTime.now().difference(startedAt!) > expectedDuration;

  Duration? get elapsed =>
      startedAt == null ? null : (completedAt ?? DateTime.now()).difference(startedAt!);

  SgCookingTask start({required DateTime at, String? by}) => copyWith(
        status: SgCookingTaskStatus.inProgress,
        startedAt: at,
        assignedTo: by ?? assignedTo,
      );

  SgCookingTask complete({required DateTime at}) => copyWith(
        status: SgCookingTaskStatus.done,
        completedAt: at,
      );

  SgCookingTask skip() => copyWith(status: SgCookingTaskStatus.skipped);

  SgCookingTask copyWith({
    String? id,
    String? ticketItemId,
    String? recipeStepId,
    String? label,
    SgCookingTaskStatus? status,
    DateTime? startedAt,
    DateTime? completedAt,
    Duration? expectedDuration,
    String? assignedTo,
    int? sortOrder,
  }) =>
      SgCookingTask(
        id: id ?? this.id,
        ticketItemId: ticketItemId ?? this.ticketItemId,
        recipeStepId: recipeStepId ?? this.recipeStepId,
        label: label ?? this.label,
        status: status ?? this.status,
        startedAt: startedAt ?? this.startedAt,
        completedAt: completedAt ?? this.completedAt,
        expectedDuration: expectedDuration ?? this.expectedDuration,
        assignedTo: assignedTo ?? this.assignedTo,
        sortOrder: sortOrder ?? this.sortOrder,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'ticket_item_id': ticketItemId,
        if (recipeStepId != null) 'recipe_step_id': recipeStepId,
        'label': label,
        'status': status.name,
        if (startedAt != null) 'started_at': startedAt!.toIso8601String(),
        if (completedAt != null) 'completed_at': completedAt!.toIso8601String(),
        'expected_duration_ms': expectedDuration.inMilliseconds,
        if (assignedTo != null) 'assigned_to': assignedTo,
        'sort_order': sortOrder,
        'is_overdue': isOverdue,
        if (elapsed != null) 'elapsed_ms': elapsed!.inMilliseconds,
      };

  factory SgCookingTask.fromJson(Map<String, dynamic> j) => SgCookingTask(
        id: j['id'] as String,
        ticketItemId: j['ticket_item_id'] as String,
        recipeStepId: j['recipe_step_id'] as String?,
        label: j['label'] as String,
        status: SgCookingTaskStatus.values
            .firstWhere((s) => s.name == j['status']),
        startedAt: j['started_at'] != null
            ? DateTime.parse(j['started_at'] as String)
            : null,
        completedAt: j['completed_at'] != null
            ? DateTime.parse(j['completed_at'] as String)
            : null,
        expectedDuration: Duration(milliseconds: j['expected_duration_ms'] as int),
        assignedTo: j['assigned_to'] as String?,
        sortOrder: j['sort_order'] as int? ?? 0,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SgCookingTask && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'SgCookingTask($id, "$label", ${status.name}${isOverdue ? " ⚠OVERDUE" : ""})';
}
