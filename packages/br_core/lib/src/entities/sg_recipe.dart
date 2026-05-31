import 'package:meta/meta.dart';

/// Type d'étape de recette.
enum SgRecipeStepType {
  prep,    // préparation (épluchage, taille, marinade)
  cooking, // cuisson (timer critique)
  plating, // dressage
  rest,    // repos (cuit puis repose 2 min)
}

/// Étape d'une recette. Avec durée attendue (utilisée pour timers en cuisine).
@immutable
class SgRecipeStep {
  final String id;
  final String recipeId;
  final int sortOrder;
  final SgRecipeStepType type;
  final String label;
  final Duration expectedDuration;
  final String? instructions;

  const SgRecipeStep({
    required this.id,
    required this.recipeId,
    required this.sortOrder,
    required this.type,
    required this.label,
    required this.expectedDuration,
    this.instructions,
  });

  SgRecipeStep copyWith({
    String? id,
    String? recipeId,
    int? sortOrder,
    SgRecipeStepType? type,
    String? label,
    Duration? expectedDuration,
    String? instructions,
  }) =>
      SgRecipeStep(
        id: id ?? this.id,
        recipeId: recipeId ?? this.recipeId,
        sortOrder: sortOrder ?? this.sortOrder,
        type: type ?? this.type,
        label: label ?? this.label,
        expectedDuration: expectedDuration ?? this.expectedDuration,
        instructions: instructions ?? this.instructions,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'recipe_id': recipeId,
        'sort_order': sortOrder,
        'type': type.name,
        'label': label,
        'expected_duration_ms': expectedDuration.inMilliseconds,
        if (instructions != null) 'instructions': instructions,
      };

  factory SgRecipeStep.fromJson(Map<String, dynamic> j) => SgRecipeStep(
        id: j['id'] as String,
        recipeId: j['recipe_id'] as String,
        sortOrder: j['sort_order'] as int,
        type: SgRecipeStepType.values.firstWhere((t) => t.name == j['type']),
        label: j['label'] as String,
        expectedDuration: Duration(milliseconds: j['expected_duration_ms'] as int),
        instructions: j['instructions'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SgRecipeStep && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'SgRecipeStep($id, ${type.name}, "$label", ${expectedDuration.inMinutes}min)';
}

/// Recette attachée à un SgMenuItem. Liste ordonnée d'étapes.
@immutable
class SgRecipe {
  final String id;
  final String menuItemId;
  final String name;
  final List<SgRecipeStep> steps;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? createdBy;

  const SgRecipe({
    required this.id,
    required this.menuItemId,
    required this.name,
    required this.steps,
    required this.createdAt,
    this.updatedAt,
    this.createdBy,
  });

  Duration get totalDuration => steps.fold(
        Duration.zero,
        (sum, s) => sum + s.expectedDuration,
      );

  Duration get cookingDuration => steps
      .where((s) => s.type == SgRecipeStepType.cooking)
      .fold(Duration.zero, (sum, s) => sum + s.expectedDuration);

  SgRecipe copyWith({
    String? id,
    String? menuItemId,
    String? name,
    List<SgRecipeStep>? steps,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) =>
      SgRecipe(
        id: id ?? this.id,
        menuItemId: menuItemId ?? this.menuItemId,
        name: name ?? this.name,
        steps: steps ?? this.steps,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        createdBy: createdBy ?? this.createdBy,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'menu_item_id': menuItemId,
        'name': name,
        'steps': steps.map((s) => s.toJson()).toList(),
        'created_at': createdAt.toIso8601String(),
        if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
        if (createdBy != null) 'created_by': createdBy,
        'total_duration_ms': totalDuration.inMilliseconds,
        'cooking_duration_ms': cookingDuration.inMilliseconds,
      };

  factory SgRecipe.fromJson(Map<String, dynamic> j) => SgRecipe(
        id: j['id'] as String,
        menuItemId: j['menu_item_id'] as String,
        name: j['name'] as String,
        steps: ((j['steps'] as List<dynamic>?) ?? const [])
            .map((s) => SgRecipeStep.fromJson(s as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.parse(j['created_at'] as String),
        updatedAt: j['updated_at'] != null
            ? DateTime.parse(j['updated_at'] as String)
            : null,
        createdBy: j['created_by'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SgRecipe && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'SgRecipe($id, "$name", ${steps.length} steps, ${totalDuration.inMinutes}min)';
}
