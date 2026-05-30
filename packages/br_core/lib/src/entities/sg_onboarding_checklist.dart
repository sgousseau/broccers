import 'package:meta/meta.dart';

import 'sg_employee.dart';

/// Item de checklist onboarding (1 ligne « préparer plateau », « connaître allergènes », etc.).
@immutable
class SgOnboardingItem {
  final String label;
  final bool done;
  final DateTime? checkedAt;

  const SgOnboardingItem({
    required this.label,
    this.done = false,
    this.checkedAt,
  });

  SgOnboardingItem check({required DateTime at}) =>
      SgOnboardingItem(label: label, done: true, checkedAt: at);

  SgOnboardingItem uncheck() =>
      SgOnboardingItem(label: label, done: false, checkedAt: null);

  Map<String, dynamic> toJson() => {
        'label': label,
        'done': done,
        if (checkedAt != null) 'checked_at': checkedAt!.toIso8601String(),
      };

  factory SgOnboardingItem.fromJson(Map<String, dynamic> j) => SgOnboardingItem(
        label: j['label'] as String,
        done: j['done'] as bool? ?? false,
        checkedAt: j['checked_at'] != null
            ? DateTime.parse(j['checked_at'] as String)
            : null,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SgOnboardingItem && other.label == label && other.done == done);

  @override
  int get hashCode => Object.hash(label, done);
}

/// Checklist d'onboarding pour un employé / rôle, générée par Claude.
@immutable
class SgOnboardingChecklist {
  final String id;
  final String employeeId;
  final SgEmployeeRole role;
  final List<SgOnboardingItem> items;
  final DateTime createdAt;
  final String engine;

  const SgOnboardingChecklist({
    required this.id,
    required this.employeeId,
    required this.role,
    required this.items,
    required this.createdAt,
    required this.engine,
  });

  int get checkedCount => items.where((i) => i.done).length;
  int get totalCount => items.length;
  double get progress => totalCount == 0 ? 0 : checkedCount / totalCount;

  SgOnboardingChecklist withItems(List<SgOnboardingItem> newItems) =>
      copyWith(items: newItems);

  SgOnboardingChecklist copyWith({
    String? id,
    String? employeeId,
    SgEmployeeRole? role,
    List<SgOnboardingItem>? items,
    DateTime? createdAt,
    String? engine,
  }) =>
      SgOnboardingChecklist(
        id: id ?? this.id,
        employeeId: employeeId ?? this.employeeId,
        role: role ?? this.role,
        items: items ?? this.items,
        createdAt: createdAt ?? this.createdAt,
        engine: engine ?? this.engine,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'employee_id': employeeId,
        'role': role.name,
        'items': items.map((i) => i.toJson()).toList(),
        'created_at': createdAt.toIso8601String(),
        'engine': engine,
        'progress': progress,
        'checked_count': checkedCount,
        'total_count': totalCount,
      };

  factory SgOnboardingChecklist.fromJson(Map<String, dynamic> j) =>
      SgOnboardingChecklist(
        id: j['id'] as String,
        employeeId: j['employee_id'] as String,
        role: SgEmployeeRole.fromName(j['role'] as String),
        items: ((j['items'] as List<dynamic>?) ?? const [])
            .map((i) => SgOnboardingItem.fromJson(i as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.parse(j['created_at'] as String),
        engine: j['engine'] as String,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SgOnboardingChecklist && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'SgOnboardingChecklist($id, emp=$employeeId, ${role.name}, $checkedCount/$totalCount)';
}
