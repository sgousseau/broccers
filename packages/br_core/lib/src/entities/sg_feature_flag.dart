import 'package:meta/meta.dart';

/// Catégorie d'un feature flag (grouping UI).
enum SgFeatureCategory {
  modules,
  experimental,
  licensing,
  security,
  ui;

  String get label => switch (this) {
        SgFeatureCategory.modules => 'Modules métier',
        SgFeatureCategory.experimental => 'Expérimental',
        SgFeatureCategory.licensing => 'Licence & commercial',
        SgFeatureCategory.security => 'Sécurité',
        SgFeatureCategory.ui => 'Interface',
      };
}

/// Définition immuable d'un feature flag (registry).
@immutable
class SgFeatureFlagDefinition {
  final String key;
  final String label;
  final String description;
  final SgFeatureCategory category;
  final bool defaultEnabled;
  final bool requiresRestart;
  final bool superAdminOnly;
  final String? phase;
  final List<String> dependsOn;

  const SgFeatureFlagDefinition({
    required this.key,
    required this.label,
    required this.description,
    required this.category,
    required this.defaultEnabled,
    this.requiresRestart = false,
    this.superAdminOnly = false,
    this.phase,
    this.dependsOn = const [],
  });
}

/// Valeur courante d'un feature flag avec audit.
@immutable
class SgFeatureFlag {
  final String key;
  final bool enabled;
  final DateTime setAt;
  final String setBy;
  final String? note;

  const SgFeatureFlag({
    required this.key,
    required this.enabled,
    required this.setAt,
    required this.setBy,
    this.note,
  });

  Map<String, dynamic> toJson() => {
        'key': key,
        'enabled': enabled,
        'set_at': setAt.toIso8601String(),
        'set_by': setBy,
        if (note != null) 'note': note,
      };

  factory SgFeatureFlag.fromJson(Map<String, dynamic> j) => SgFeatureFlag(
        key: j['key'] as String,
        enabled: j['enabled'] as bool,
        setAt: DateTime.parse(j['set_at'] as String),
        setBy: j['set_by'] as String,
        note: j['note'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SgFeatureFlag && other.key == key && other.enabled == enabled);

  @override
  int get hashCode => Object.hash(key, enabled);
}

/// Registry des feature flags Broccers (clé → définition).
///
/// Sert deux objectifs :
/// 1. Activer / désactiver progressivement les phases en cours de développement.
/// 2. Commercialiser Broccers en modules indépendants : un client achète
///    un sous-ensemble de modules, les autres restent désactivés visuellement
///    et fonctionnellement.
class SgBrocFeatureFlagsRegistry {
  SgBrocFeatureFlagsRegistry._();

  // === Modules métier (gating commercial) ===
  static const personnelTracking = SgFeatureFlagDefinition(
    key: 'feature.personnel.tracking',
    label: 'Personnel & RH (pointage, planning, rôles)',
    description: 'Gestion équipe, clock-in/out, multi-rôles, pauses légales.',
    category: SgFeatureCategory.modules,
    defaultEnabled: true,
  );

  static const tipsTracking = SgFeatureFlagDefinition(
    key: 'feature.tips.tracking',
    label: 'Suivi pourboires par shift',
    description: 'Enregistrement et analyse des pourboires shift par shift.',
    category: SgFeatureCategory.modules,
    defaultEnabled: true,
    dependsOn: ['feature.personnel.tracking'],
  );

  static const heatmap = SgFeatureFlagDefinition(
    key: 'feature.reports.heatmap',
    label: 'Heatmap activité 7 jours',
    description: 'Vue grille employé × jour avec intensité de couleur.',
    category: SgFeatureCategory.modules,
    defaultEnabled: true,
    dependsOn: ['feature.personnel.tracking'],
  );

  static const onboarding = SgFeatureFlagDefinition(
    key: 'feature.personnel.onboarding',
    label: 'Onboarding par rôle (HACCP-aware)',
    description: 'Checklists générées par Claude adaptées au rôle.',
    category: SgFeatureCategory.modules,
    defaultEnabled: true,
  );

  static const menuEditor = SgFeatureFlagDefinition(
    key: 'feature.menu.editor',
    label: 'Éditeur de cartes',
    description: 'CRUD complet cartes, catégories, plats, allergènes INCO.',
    category: SgFeatureCategory.modules,
    defaultEnabled: true,
  );

  static const menuImportImage = SgFeatureFlagDefinition(
    key: 'feature.menu.import_image',
    label: 'Import carte depuis photo (Claude Vision)',
    description: 'Extraction automatique catégories, plats, prix, allergènes via IA.',
    category: SgFeatureCategory.modules,
    defaultEnabled: true,
    dependsOn: ['feature.menu.editor'],
  );

  static const menuPdf = SgFeatureFlagDefinition(
    key: 'feature.menu.pdf',
    label: 'Export PDF A4 imprimable',
    description: 'Génération PDF Dart natif aux couleurs Broc.',
    category: SgFeatureCategory.modules,
    defaultEnabled: true,
    dependsOn: ['feature.menu.editor'],
  );

  static const kitchenTickets = SgFeatureFlagDefinition(
    key: 'feature.kitchen.tickets',
    label: 'Tickets cuisine kanban',
    description: 'Vue kanban draft/pending/inProgress/ready avec timers.',
    category: SgFeatureCategory.modules,
    defaultEnabled: true,
  );

  static const kitchenVoiceOrders = SgFeatureFlagDefinition(
    key: 'feature.kitchen.voice_orders',
    label: 'Commande vocale dictée serveur',
    description: 'Audio (Whisper) ou texte → ticket structuré (Claude).',
    category: SgFeatureCategory.modules,
    defaultEnabled: true,
    dependsOn: ['feature.kitchen.tickets'],
  );

  static const kitchenRecipes = SgFeatureFlagDefinition(
    key: 'feature.kitchen.recipes',
    label: 'Recettes + cuissons + tâches cuisine',
    description: 'Étapes par recette, cooking tasks auto, timer overdue.',
    category: SgFeatureCategory.modules,
    defaultEnabled: true,
    dependsOn: ['feature.kitchen.tickets'],
  );

  static const margins = SgFeatureFlagDefinition(
    key: 'feature.margins.compute',
    label: 'Calcul de marges temps réel',
    description: 'Marge par plat avec code couleur paramétrable depuis Settings.',
    category: SgFeatureCategory.modules,
    defaultEnabled: true,
  );

  static const ingredients = SgFeatureFlagDefinition(
    key: 'feature.ingredients.catalog',
    label: 'Référentiel ingrédients',
    description: 'Catalogue avec prix moyen courant, unités, fournisseurs.',
    category: SgFeatureCategory.modules,
    defaultEnabled: true,
    dependsOn: ['feature.margins.compute'],
  );

  static const foodWaste = SgFeatureFlagDefinition(
    key: 'feature.food_waste.tracker',
    label: 'Tracker gaspillage hebdomadaire',
    description: 'Déclaration pertes + récap 7j + breakdown raison/jour.',
    category: SgFeatureCategory.modules,
    defaultEnabled: true,
  );

  static const tablesQr = SgFeatureFlagDefinition(
    key: 'feature.tables.qr',
    label: 'Tables avec QR codes clients',
    description: 'QR offline, consultation publique carte, rotation secret.',
    category: SgFeatureCategory.modules,
    defaultEnabled: true,
  );

  static const mode86 = SgFeatureFlagDefinition(
    key: 'feature.menu.mode_86',
    label: 'Mode 86 / Signalement rupture',
    description: 'Toggle disponibilité item avec raison + propagation temps réel.',
    category: SgFeatureCategory.modules,
    defaultEnabled: true,
    dependsOn: ['feature.menu.editor'],
  );

  static const shopping = SgFeatureFlagDefinition(
    key: 'feature.shopping.lists',
    label: 'Listes de courses partagées',
    description: 'Listes par fournisseur, items checklist, urgences.',
    category: SgFeatureCategory.modules,
    defaultEnabled: true,
  );

  static const briefingMorning = SgFeatureFlagDefinition(
    key: 'feature.briefing.morning',
    label: 'Briefing matinal IA',
    description: 'Bouton AppBar, génération Claude (planning + courses + alertes).',
    category: SgFeatureCategory.modules,
    defaultEnabled: true,
  );

  static const askQuestion = SgFeatureFlagDefinition(
    key: 'feature.ai.question',
    label: 'Question libre à Claude',
    description: 'Chat IA avec contexte Broc (carte + courses).',
    category: SgFeatureCategory.modules,
    defaultEnabled: true,
  );

  static const journalAudit = SgFeatureFlagDefinition(
    key: 'feature.journal.audit',
    label: 'Journal d\'audit consultable',
    description: 'Vue chronologique filtrable des événements système.',
    category: SgFeatureCategory.modules,
    defaultEnabled: true,
  );

  static const kioskMode = SgFeatureFlagDefinition(
    key: 'feature.kiosk.mode',
    label: 'Mode kiosk tablette cuisine',
    description: 'PIN court + auto-relogout pour usage tablette partagée.',
    category: SgFeatureCategory.modules,
    defaultEnabled: true,
  );

  // === Expérimental / Phase H ===
  static const cameraFaceRecognition = SgFeatureFlagDefinition(
    key: 'feature.camera.face_recognition',
    label: 'Caméras ESP32-S3 : reconnaissance faciale',
    description: 'Clock-in automatique via reconnaissance faciale opt-in.',
    category: SgFeatureCategory.experimental,
    defaultEnabled: false,
    phase: 'H',
  );

  static const cameraPresence = SgFeatureFlagDefinition(
    key: 'feature.camera.presence',
    label: 'Caméras ESP32-S3 : présence zones',
    description: 'Détection présence par zone (cuisine/salle/bar/entrée).',
    category: SgFeatureCategory.experimental,
    defaultEnabled: false,
    phase: 'H',
  );

  static const cameraClientHeatmap = SgFeatureFlagDefinition(
    key: 'feature.camera.client_heatmap',
    label: 'Caméras ESP32-S3 : heatmap flux client',
    description: 'Agrégation présence pour dimensionnement shifts.',
    category: SgFeatureCategory.experimental,
    defaultEnabled: false,
    phase: 'H',
    dependsOn: ['feature.camera.presence'],
  );

  static const cameraMotionSecurity = SgFeatureFlagDefinition(
    key: 'feature.camera.motion_security',
    label: 'Caméras ESP32-S3 : détection mouvement post-fermeture',
    description: 'Mode sécurité hors heures d\'ouverture, alerte manager.',
    category: SgFeatureCategory.experimental,
    defaultEnabled: false,
    phase: 'H',
  );

  static const reservations = SgFeatureFlagDefinition(
    key: 'feature.reservations',
    label: 'Réservations en ligne',
    description: 'Gestion des réservations + planning service.',
    category: SgFeatureCategory.experimental,
    defaultEnabled: false,
    phase: 'K',
  );

  static const qrClientOrdering = SgFeatureFlagDefinition(
    key: 'feature.qr.client_ordering',
    label: 'Commande client au QR',
    description: 'Le client commande directement depuis son téléphone via QR table.',
    category: SgFeatureCategory.experimental,
    defaultEnabled: false,
    phase: 'J',
    dependsOn: ['feature.tables.qr'],
  );

  // === Licence / commercial (super-admin only) ===
  static const advancedSettings = SgFeatureFlagDefinition(
    key: 'feature.advanced_settings',
    label: 'Paramètres avancés (charges, seuils, profils)',
    description: 'Accès aux paramètres système avancés. OFF chez clients tiers par défaut.',
    category: SgFeatureCategory.licensing,
    defaultEnabled: true,
    superAdminOnly: true,
  );

  static const multiInstance = SgFeatureFlagDefinition(
    key: 'feature.multi_instance',
    label: 'Multi-instance / multi-BD',
    description: 'Switch entre plusieurs bases (démo A, démo B, prod). Super-admin uniquement.',
    category: SgFeatureCategory.licensing,
    defaultEnabled: false,
    superAdminOnly: true,
    requiresRestart: true,
  );

  static const branding = SgFeatureFlagDefinition(
    key: 'feature.branding.custom',
    label: 'Personnalisation branding (logo, couleurs)',
    description: 'Permet de personnaliser branding pour un client spécifique.',
    category: SgFeatureCategory.licensing,
    defaultEnabled: false,
    superAdminOnly: true,
  );

  // === Sécurité ===
  static const rateLimitStrict = SgFeatureFlagDefinition(
    key: 'feature.security.rate_limit_strict',
    label: 'Rate limit strict (3/15min au lieu de 5)',
    description: 'Mode anti-bruteforce renforcé.',
    category: SgFeatureCategory.security,
    defaultEnabled: false,
  );

  /// Tous les flags connus.
  static List<SgFeatureFlagDefinition> get allFlags => const [
        // modules
        personnelTracking, tipsTracking, heatmap, onboarding,
        menuEditor, menuImportImage, menuPdf, mode86,
        kitchenTickets, kitchenVoiceOrders, kitchenRecipes,
        margins, ingredients,
        foodWaste, tablesQr, shopping,
        briefingMorning, askQuestion, journalAudit, kioskMode,
        // experimental
        cameraFaceRecognition, cameraPresence, cameraClientHeatmap,
        cameraMotionSecurity, reservations, qrClientOrdering,
        // licensing
        advancedSettings, multiInstance, branding,
        // security
        rateLimitStrict,
      ];

  static SgFeatureFlagDefinition? find(String key) {
    for (final d in allFlags) {
      if (d.key == key) return d;
    }
    return null;
  }

  /// Vérifie si toutes les dépendances d'un flag sont activées.
  /// Retourne null si OK, sinon la première clé manquante.
  static String? checkDependencies(String key, Map<String, bool> enabledByKey) {
    final def = find(key);
    if (def == null) return null;
    for (final dep in def.dependsOn) {
      if (enabledByKey[dep] != true) return dep;
    }
    return null;
  }
}
