import 'package:meta/meta.dart';

/// Consommation au bar par un membre du staff (repas, boissons).
///
/// Peut être liée à un `SgMenuItem` (auto-deduit le prix) ou en saisie libre (`label` + `amountCents`).
/// `paid` indique si déjà payé (cash, virement) ou à débiter sur salaire.
@immutable
class SgStaffConsumption {
  final String id;
  final String employeeId;
  final String? shiftId;
  final String? menuItemId;
  final String label;
  final int amountCents;
  final DateTime consumedAt;
  final bool paid;
  final String? note;

  const SgStaffConsumption({
    required this.id,
    required this.employeeId,
    required this.label,
    required this.amountCents,
    required this.consumedAt,
    this.shiftId,
    this.menuItemId,
    this.paid = false,
    this.note,
  });

  String formattedAmount({String currency = '€'}) {
    final euros = amountCents ~/ 100;
    final cents = amountCents % 100;
    return cents == 0
        ? '$euros $currency'
        : '$euros,${cents.toString().padLeft(2, '0')} $currency';
  }

  SgStaffConsumption markPaid({required DateTime at}) => copyWith(paid: true);

  SgStaffConsumption copyWith({
    String? id,
    String? employeeId,
    String? shiftId,
    String? menuItemId,
    String? label,
    int? amountCents,
    DateTime? consumedAt,
    bool? paid,
    String? note,
  }) =>
      SgStaffConsumption(
        id: id ?? this.id,
        employeeId: employeeId ?? this.employeeId,
        shiftId: shiftId ?? this.shiftId,
        menuItemId: menuItemId ?? this.menuItemId,
        label: label ?? this.label,
        amountCents: amountCents ?? this.amountCents,
        consumedAt: consumedAt ?? this.consumedAt,
        paid: paid ?? this.paid,
        note: note ?? this.note,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'employee_id': employeeId,
        if (shiftId != null) 'shift_id': shiftId,
        if (menuItemId != null) 'menu_item_id': menuItemId,
        'label': label,
        'amount_cents': amountCents,
        'consumed_at': consumedAt.toIso8601String(),
        'paid': paid,
        if (note != null) 'note': note,
      };

  factory SgStaffConsumption.fromJson(Map<String, dynamic> json) =>
      SgStaffConsumption(
        id: json['id'] as String,
        employeeId: json['employee_id'] as String,
        shiftId: json['shift_id'] as String?,
        menuItemId: json['menu_item_id'] as String?,
        label: json['label'] as String,
        amountCents: json['amount_cents'] as int,
        consumedAt: DateTime.parse(json['consumed_at'] as String),
        paid: json['paid'] as bool? ?? false,
        note: json['note'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SgStaffConsumption && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'SgStaffConsumption($id, emp=$employeeId, "$label" ${formattedAmount()}${paid ? " PAID" : ""})';
}
