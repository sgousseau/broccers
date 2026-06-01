import 'package:meta/meta.dart';

/// Type de valeur d'un setting.
enum SgSettingType {
  intValue,
  doubleValue,
  boolValue,
  stringValue,
  enumValue,
}

/// Catégorie d'un setting (grouping UI).
enum SgSettingCategory {
  margins,
  breaksLegal,
  kiosk,
  notifications,
  costs,
  voice,
  ui,
  other;

  String get label => switch (this) {
        SgSettingCategory.margins => 'Marges',
        SgSettingCategory.breaksLegal => 'Pauses & droit du travail',
        SgSettingCategory.kiosk => 'Mode kiosk',
        SgSettingCategory.notifications => 'Notifications',
        SgSettingCategory.costs => 'Coûts',
        SgSettingCategory.voice => 'Commande vocale',
        SgSettingCategory.ui => 'Interface',
        SgSettingCategory.other => 'Divers',
      };
}

/// Définition d'un setting : metadata + default + bornes (read-only).
@immutable
class SgSettingDefinition {
  final String key;
  final SgSettingType type;
  final SgSettingCategory category;
  final String label;
  final String? description;
  final Object defaultValue;
  final num? minValue;
  final num? maxValue;
  final List<String>? enumOptions;
  final String? unit;

  const SgSettingDefinition({
    required this.key,
    required this.type,
    required this.category,
    required this.label,
    required this.defaultValue,
    this.description,
    this.minValue,
    this.maxValue,
    this.enumOptions,
    this.unit,
  });
}

/// Valeur courante d'un setting, avec audit (setBy + setAt).
@immutable
class SgSetting {
  final String key;
  final Object value;
  final SgSettingType type;
  final DateTime setAt;
  final String setBy;

  const SgSetting({
    required this.key,
    required this.value,
    required this.type,
    required this.setAt,
    required this.setBy,
  });

  int get asInt {
    if (value is int) return value as int;
    if (value is num) return (value as num).toInt();
    if (value is String) return int.parse(value as String);
    return 0;
  }

  double get asDouble {
    if (value is double) return value as double;
    if (value is num) return (value as num).toDouble();
    if (value is String) return double.parse(value as String);
    return 0.0;
  }

  bool get asBool {
    if (value is bool) return value as bool;
    if (value is String) return value == 'true';
    if (value is int) return value != 0;
    return false;
  }

  String get asString => value.toString();

  Map<String, dynamic> toJson() => {
        'key': key,
        'value': value,
        'type': type.name,
        'set_at': setAt.toIso8601String(),
        'set_by': setBy,
      };

  factory SgSetting.fromJson(Map<String, dynamic> j) {
    final type = SgSettingType.values.firstWhere((t) => t.name == j['type']);
    return SgSetting(
      key: j['key'] as String,
      value: j['value'] as Object,
      type: type,
      setAt: DateTime.parse(j['set_at'] as String),
      setBy: j['set_by'] as String,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SgSetting && other.key == key && other.value == value);

  @override
  int get hashCode => Object.hash(key, value);

  @override
  String toString() => 'SgSetting($key = $value)';
}

/// Registry des settings Broccers (key → definition).
class SgBrocSettingsRegistry {
  SgBrocSettingsRegistry._();

  static const margins = [
    SgSettingDefinition(
      key: 'margin.threshold_red_pct',
      type: SgSettingType.intValue,
      category: SgSettingCategory.margins,
      label: 'Seuil ROUGE marge brute',
      description: 'En dessous de ce %, la marge est considérée critique (rouge)',
      defaultValue: 60,
      minValue: 0,
      maxValue: 100,
      unit: '%',
    ),
    SgSettingDefinition(
      key: 'margin.threshold_yellow_pct',
      type: SgSettingType.intValue,
      category: SgSettingCategory.margins,
      label: 'Seuil JAUNE marge brute',
      description: 'En dessous de ce %, la marge est moyenne (jaune)',
      defaultValue: 70,
      minValue: 0,
      maxValue: 100,
      unit: '%',
    ),
    SgSettingDefinition(
      key: 'margin.target_pct',
      type: SgSettingType.intValue,
      category: SgSettingCategory.margins,
      label: 'Cible marge brute',
      description: 'Objectif visé pour publication carte',
      defaultValue: 70,
      minValue: 0,
      maxValue: 100,
      unit: '%',
    ),
    SgSettingDefinition(
      key: 'margin.context',
      type: SgSettingType.enumValue,
      category: SgSettingCategory.margins,
      label: 'Contexte marge',
      description: 'Profil global influençant les seuils par défaut',
      defaultValue: 'standard',
      enumOptions: ['low_cost', 'standard', 'premium'],
    ),
  ];

  static const breaksLegal = [
    SgSettingDefinition(
      key: 'breaks.min_pause_minutes',
      type: SgSettingType.intValue,
      category: SgSettingCategory.breaksLegal,
      label: 'Durée min pause légale (FR Art. L. 3121-16)',
      description: 'Pause minimum dès 6h continues de travail',
      defaultValue: 20,
      minValue: 10,
      maxValue: 60,
      unit: 'min',
    ),
    SgSettingDefinition(
      key: 'breaks.shift_max_continuous_hours',
      type: SgSettingType.intValue,
      category: SgSettingCategory.breaksLegal,
      label: 'Durée max shift sans pause',
      defaultValue: 6,
      minValue: 4,
      maxValue: 10,
      unit: 'h',
    ),
  ];

  static const costs = [
    SgSettingDefinition(
      key: 'costs.charges_pct',
      type: SgSettingType.intValue,
      category: SgSettingCategory.costs,
      label: 'Taux charges + impôts (FR)',
      description: 'Pourcentage du CA grignoté par charges sociales + impôts',
      defaultValue: 66,
      minValue: 0,
      maxValue: 90,
      unit: '%',
    ),
    SgSettingDefinition(
      key: 'costs.waste_alert_threshold_cents',
      type: SgSettingType.intValue,
      category: SgSettingCategory.costs,
      label: 'Seuil alerte gaspillage hebdo',
      description: 'Au-delà de ce montant € de pertes/semaine, alerte manager',
      defaultValue: 10000,
      minValue: 0,
      unit: 'cents',
    ),
  ];

  static const voice = [
    SgSettingDefinition(
      key: 'voice.enable_whisper',
      type: SgSettingType.boolValue,
      category: SgSettingCategory.voice,
      label: 'Activer Whisper Titan pour commande vocale',
      description: 'Si désactivé, mode texte uniquement',
      defaultValue: true,
    ),
    SgSettingDefinition(
      key: 'voice.refuse_86_items',
      type: SgSettingType.boolValue,
      category: SgSettingCategory.voice,
      label: 'Refuser items 86 dans parsing voix',
      description: 'Claude refuse les items en rupture',
      defaultValue: true,
    ),
  ];

  /// Toutes les définitions connues, groupées par catégorie.
  static List<SgSettingDefinition> get allDefinitions => [
        ...margins,
        ...breaksLegal,
        ...costs,
        ...voice,
      ];

  static SgSettingDefinition? find(String key) {
    for (final d in allDefinitions) {
      if (d.key == key) return d;
    }
    return null;
  }
}
