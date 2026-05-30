import 'package:meta/meta.dart';

/// Type d'événement journalisé. Liste extensible — l'enum donne les types canoniques,
/// mais on accepte n'importe quel `action` String dans le journal pour flexibilité.
class SgEventActions {
  static const String employeeCreated = 'employee.created';
  static const String employeeRolesChanged = 'employee.roles_changed';
  static const String employeeWeeklyChanged = 'employee.weekly_changed';
  static const String shiftStarted = 'shift.started';
  static const String shiftEnded = 'shift.ended';
  static const String segmentOpened = 'segment.opened';
  static const String segmentClosed = 'segment.closed';
  static const String segmentRoleChanged = 'segment.role_changed';
  static const String breakStarted = 'break.started';
  static const String breakEnded = 'break.ended';
  static const String menuCardPublished = 'menu_card.published';
  static const String menuCardPdfExported = 'menu_card.pdf_exported';
  static const String shoppingItemChecked = 'shopping_item.checked';
  static const String questionAsked = 'question.asked';
  static const String complianceAlert = 'compliance.alert';

  SgEventActions._();
}

/// Entrée de journal d'événements (concept SG universel — **TO BE PROMOTED** vers sg-packages).
///
/// Philosophie : observability **bienveillante**. Tout est tracé pour comprendre et
/// améliorer, jamais pour réprimander. Les alertes vont au manager, pas à l'employé.
///
/// Champs :
/// - [actor] : qui a déclenché (employee_id, "manager:<id>", "system")
/// - [action] : verbe / type (cf [SgEventActions])
/// - [target] : ce qui est touché — format `entity:id` (ex `employee:emp-123`, `shift:sh-456`)
/// - [payload] : détails libres (ancien/nouveau état, valeurs, etc.)
/// - [reason] : pourquoi (optionnelle, mais encouragée si modification manuelle)
@immutable
class SgEventJournalEntry {
  final String id;
  final DateTime at;
  final String actor;
  final String action;
  final String? target;
  final Map<String, dynamic> payload;
  final String? reason;

  const SgEventJournalEntry({
    required this.id,
    required this.at,
    required this.actor,
    required this.action,
    required this.payload,
    this.target,
    this.reason,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'at': at.toIso8601String(),
        'actor': actor,
        'action': action,
        if (target != null) 'target': target,
        'payload': payload,
        if (reason != null) 'reason': reason,
      };

  factory SgEventJournalEntry.fromJson(Map<String, dynamic> json) =>
      SgEventJournalEntry(
        id: json['id'] as String,
        at: DateTime.parse(json['at'] as String),
        actor: json['actor'] as String,
        action: json['action'] as String,
        target: json['target'] as String?,
        payload: (json['payload'] as Map<String, dynamic>?) ?? const {},
        reason: json['reason'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SgEventJournalEntry && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'SgEventJournalEntry($id, $actor → $action${target != null ? " on $target" : ""})';
}
