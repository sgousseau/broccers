import 'package:meta/meta.dart';

enum SgIngredientUnit {
  gram('g'),
  kilogram('kg'),
  milliliter('ml'),
  liter('L'),
  piece('pcs'),
  dozen('dz');

  final String label;
  const SgIngredientUnit(this.label);

  static SgIngredientUnit fromName(String n) =>
      SgIngredientUnit.values.firstWhere((u) => u.name == n);

  /// Convertit une qty d'une unité à une autre (g↔kg, ml↔L). Sinon retourne null si incompatible.
  static double? convert(double qty, SgIngredientUnit from, SgIngredientUnit to) {
    if (from == to) return qty;
    if (from == SgIngredientUnit.gram && to == SgIngredientUnit.kilogram) return qty / 1000;
    if (from == SgIngredientUnit.kilogram && to == SgIngredientUnit.gram) return qty * 1000;
    if (from == SgIngredientUnit.milliliter && to == SgIngredientUnit.liter) return qty / 1000;
    if (from == SgIngredientUnit.liter && to == SgIngredientUnit.milliliter) return qty * 1000;
    if (from == SgIngredientUnit.piece && to == SgIngredientUnit.dozen) return qty / 12;
    if (from == SgIngredientUnit.dozen && to == SgIngredientUnit.piece) return qty * 12;
    return null;
  }
}

/// Un ingrédient utilisé dans les recettes. Prix moyen courant.
/// Historique des prix via SgEventJournal (`ingredient.price_changed`).
@immutable
class SgIngredient {
  final String id;
  final String name;
  final SgIngredientUnit unit;
  final int currentPriceCents;
  final String? supplierId;
  final String? notes;
  final DateTime updatedAt;

  const SgIngredient({
    required this.id,
    required this.name,
    required this.unit,
    required this.currentPriceCents,
    required this.updatedAt,
    this.supplierId,
    this.notes,
  });

  /// Coût pour une quantité donnée dans son unité native.
  int costForQuantityCents(double quantity, SgIngredientUnit qtyUnit) {
    final converted = SgIngredientUnit.convert(quantity, qtyUnit, unit);
    if (converted == null) return 0;
    return (currentPriceCents * converted).round();
  }

  String formattedPrice() {
    final euros = currentPriceCents ~/ 100;
    final cents = currentPriceCents % 100;
    return cents == 0
        ? '$euros €/${unit.label}'
        : '$euros,${cents.toString().padLeft(2, '0')} €/${unit.label}';
  }

  SgIngredient copyWith({
    String? id,
    String? name,
    SgIngredientUnit? unit,
    int? currentPriceCents,
    String? supplierId,
    String? notes,
    DateTime? updatedAt,
  }) =>
      SgIngredient(
        id: id ?? this.id,
        name: name ?? this.name,
        unit: unit ?? this.unit,
        currentPriceCents: currentPriceCents ?? this.currentPriceCents,
        supplierId: supplierId ?? this.supplierId,
        notes: notes ?? this.notes,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'unit': unit.name,
        'current_price_cents': currentPriceCents,
        if (supplierId != null) 'supplier_id': supplierId,
        if (notes != null) 'notes': notes,
        'updated_at': updatedAt.toIso8601String(),
        'formatted_price': formattedPrice(),
      };

  factory SgIngredient.fromJson(Map<String, dynamic> j) => SgIngredient(
        id: j['id'] as String,
        name: j['name'] as String,
        unit: SgIngredientUnit.fromName(j['unit'] as String),
        currentPriceCents: j['current_price_cents'] as int,
        supplierId: j['supplier_id'] as String?,
        notes: j['notes'] as String?,
        updatedAt: DateTime.parse(j['updated_at'] as String),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is SgIngredient && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'SgIngredient($id, "$name", ${formattedPrice()})';
}

/// Lien recette → ingrédient avec quantité utilisée.
@immutable
class SgRecipeIngredient {
  final String id;
  final String recipeId;
  final String ingredientId;
  final double quantity;
  final SgIngredientUnit unit;
  final String? notes;
  final bool isSubstitution;
  final String? substitutionReason;

  const SgRecipeIngredient({
    required this.id,
    required this.recipeId,
    required this.ingredientId,
    required this.quantity,
    required this.unit,
    this.notes,
    this.isSubstitution = false,
    this.substitutionReason,
  });

  /// Calcule le coût en cents pour cette utilisation (via le prix de l'ingrédient fourni).
  int costCents(SgIngredient ingredient) =>
      ingredient.costForQuantityCents(quantity, unit);

  SgRecipeIngredient copyWith({
    String? id,
    String? recipeId,
    String? ingredientId,
    double? quantity,
    SgIngredientUnit? unit,
    String? notes,
    bool? isSubstitution,
    String? substitutionReason,
  }) =>
      SgRecipeIngredient(
        id: id ?? this.id,
        recipeId: recipeId ?? this.recipeId,
        ingredientId: ingredientId ?? this.ingredientId,
        quantity: quantity ?? this.quantity,
        unit: unit ?? this.unit,
        notes: notes ?? this.notes,
        isSubstitution: isSubstitution ?? this.isSubstitution,
        substitutionReason: substitutionReason ?? this.substitutionReason,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'recipe_id': recipeId,
        'ingredient_id': ingredientId,
        'quantity': quantity,
        'unit': unit.name,
        if (notes != null) 'notes': notes,
        'is_substitution': isSubstitution,
        if (substitutionReason != null) 'substitution_reason': substitutionReason,
      };

  factory SgRecipeIngredient.fromJson(Map<String, dynamic> j) =>
      SgRecipeIngredient(
        id: j['id'] as String,
        recipeId: j['recipe_id'] as String,
        ingredientId: j['ingredient_id'] as String,
        quantity: (j['quantity'] as num).toDouble(),
        unit: SgIngredientUnit.fromName(j['unit'] as String),
        notes: j['notes'] as String?,
        isSubstitution: j['is_substitution'] as bool? ?? false,
        substitutionReason: j['substitution_reason'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SgRecipeIngredient && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'SgRecipeIngredient(${quantity.toStringAsFixed(1)} ${unit.label} of $ingredientId${isSubstitution ? " [SUB]" : ""})';
}

/// Résultat de calcul du coût matière d'un menu item.
@immutable
class SgMenuItemCostBreakdown {
  final String menuItemId;
  final int totalCostCents;
  final int priceCents;
  final List<SgIngredientCostLine> lines;

  const SgMenuItemCostBreakdown({
    required this.menuItemId,
    required this.totalCostCents,
    required this.priceCents,
    required this.lines,
  });

  int get marginCents => priceCents - totalCostCents;

  double get marginPct => priceCents == 0 ? 0 : (marginCents * 100.0 / priceCents);

  /// Categorise selon les seuils (red < redThreshold, yellow < yellowThreshold, green sinon).
  String marginColor(int redThreshold, int yellowThreshold) {
    if (marginPct < redThreshold) return 'red';
    if (marginPct < yellowThreshold) return 'yellow';
    return 'green';
  }

  Map<String, dynamic> toJson({int? redThreshold, int? yellowThreshold}) => {
        'menu_item_id': menuItemId,
        'total_cost_cents': totalCostCents,
        'price_cents': priceCents,
        'margin_cents': marginCents,
        'margin_pct': marginPct,
        if (redThreshold != null && yellowThreshold != null)
          'margin_color': marginColor(redThreshold, yellowThreshold),
        'lines': lines.map((l) => l.toJson()).toList(),
      };
}

@immutable
class SgIngredientCostLine {
  final String ingredientId;
  final String ingredientName;
  final double quantity;
  final SgIngredientUnit unit;
  final int costCents;
  final bool isSubstitution;

  const SgIngredientCostLine({
    required this.ingredientId,
    required this.ingredientName,
    required this.quantity,
    required this.unit,
    required this.costCents,
    this.isSubstitution = false,
  });

  Map<String, dynamic> toJson() => {
        'ingredient_id': ingredientId,
        'ingredient_name': ingredientName,
        'quantity': quantity,
        'unit': unit.name,
        'cost_cents': costCents,
        'is_substitution': isSubstitution,
      };
}
