import 'package:meta/meta.dart';

import 'sg_ingredient.dart';

/// Raison du gaspillage.
enum SgWasteReason {
  prepLoss('Erreur de préparation'),
  servingLoss('Retour desserte (assiette pas finie)'),
  expiry('Date dépassée'),
  unusedProduction('Surproduction non vendue'),
  staffMeal('Repas staff (à valoriser)'),
  customerReturn('Retour client (insatisfaction)'),
  burnt('Brûlé / loupé'),
  contamination('Contamination / chute'),
  other('Autre');

  final String label;
  const SgWasteReason(this.label);

  static SgWasteReason fromName(String n) =>
      SgWasteReason.values.firstWhere((r) => r.name == n);
}

/// Type d'élément gâché : un ingrédient brut OU un menu item produit.
enum SgWasteKind {
  ingredient,
  menuItem,
}

/// Déclaration de gaspillage. Capability `waste.report` (manager + cook + dishwasher).
@immutable
class SgFoodWaste {
  final String id;
  final SgWasteKind kind;
  final String refId;
  final String label;
  final double quantity;
  final SgIngredientUnit? unit;
  final SgWasteReason reason;
  final int estimatedValueCents;
  final String reportedBy;
  final DateTime reportedAt;
  final String? notes;

  const SgFoodWaste({
    required this.id,
    required this.kind,
    required this.refId,
    required this.label,
    required this.quantity,
    required this.reason,
    required this.estimatedValueCents,
    required this.reportedBy,
    required this.reportedAt,
    this.unit,
    this.notes,
  });

  String formattedValue() {
    final euros = estimatedValueCents ~/ 100;
    final cents = estimatedValueCents % 100;
    return cents == 0
        ? '$euros €'
        : '$euros,${cents.toString().padLeft(2, '0')} €';
  }

  SgFoodWaste copyWith({
    String? id,
    SgWasteKind? kind,
    String? refId,
    String? label,
    double? quantity,
    SgIngredientUnit? unit,
    SgWasteReason? reason,
    int? estimatedValueCents,
    String? reportedBy,
    DateTime? reportedAt,
    String? notes,
  }) =>
      SgFoodWaste(
        id: id ?? this.id,
        kind: kind ?? this.kind,
        refId: refId ?? this.refId,
        label: label ?? this.label,
        quantity: quantity ?? this.quantity,
        unit: unit ?? this.unit,
        reason: reason ?? this.reason,
        estimatedValueCents: estimatedValueCents ?? this.estimatedValueCents,
        reportedBy: reportedBy ?? this.reportedBy,
        reportedAt: reportedAt ?? this.reportedAt,
        notes: notes ?? this.notes,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'ref_id': refId,
        'label': label,
        'quantity': quantity,
        if (unit != null) 'unit': unit!.name,
        'reason': reason.name,
        'reason_label': reason.label,
        'estimated_value_cents': estimatedValueCents,
        'formatted_value': formattedValue(),
        'reported_by': reportedBy,
        'reported_at': reportedAt.toIso8601String(),
        if (notes != null) 'notes': notes,
      };

  factory SgFoodWaste.fromJson(Map<String, dynamic> j) => SgFoodWaste(
        id: j['id'] as String,
        kind: SgWasteKind.values.firstWhere((k) => k.name == j['kind']),
        refId: j['ref_id'] as String,
        label: j['label'] as String,
        quantity: (j['quantity'] as num).toDouble(),
        unit: j['unit'] != null
            ? SgIngredientUnit.fromName(j['unit'] as String)
            : null,
        reason: SgWasteReason.fromName(j['reason'] as String),
        estimatedValueCents: j['estimated_value_cents'] as int,
        reportedBy: j['reported_by'] as String,
        reportedAt: DateTime.parse(j['reported_at'] as String),
        notes: j['notes'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is SgFoodWaste && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'SgFoodWaste($id, $quantity ${unit?.label ?? "pcs"} "$label", ${reason.label}, ${formattedValue()})';
}
