// Phase H — Caméras IA distribuées (ESP32-S3 Sense).
// Domain pur — pas d'implémentation firmware ici, juste les concepts.

import 'package:meta/meta.dart';

/// Type de zone physique dans le restaurant.
enum SgZoneKind {
  kitchen('Cuisine'),
  bar('Bar'),
  dining('Salle'),
  terrace('Terrasse'),
  entrance('Entrée'),
  staffRoom('Local personnel'),
  storage('Réserve'),
  other('Autre');

  final String label;
  const SgZoneKind(this.label);

  static SgZoneKind fromName(String n) {
    for (final v in values) {
      if (v.name == n) return v;
    }
    return SgZoneKind.other;
  }
}

/// Une zone logique du restaurant. Sert à corréler les événements caméra
/// (présence, mouvement, reconnaissance) à un emplacement métier.
@immutable
class SgZone {
  final String id;
  final String label;
  final SgZoneKind kind;
  final String? notes;
  final bool active;

  const SgZone({
    required this.id,
    required this.label,
    required this.kind,
    this.notes,
    this.active = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'kind': kind.name,
        'kind_label': kind.label,
        if (notes != null) 'notes': notes,
        'active': active,
      };

  factory SgZone.fromJson(Map<String, dynamic> j) => SgZone(
        id: j['id'] as String,
        label: j['label'] as String,
        kind: SgZoneKind.fromName(j['kind'] as String),
        notes: j['notes'] as String?,
        active: j['active'] as bool? ?? true,
      );
}

/// Une caméra physique ESP32-S3 Sense installée dans une zone.
@immutable
class SgCamera {
  final String id;
  final String label;
  final String zoneId;
  final String macAddress;
  final String? firmwareVersion;
  final String? ipAddress;
  final DateTime? lastSeenAt;
  final bool active;
  final SgCameraMode mode;
  final DateTime createdAt;

  const SgCamera({
    required this.id,
    required this.label,
    required this.zoneId,
    required this.macAddress,
    required this.createdAt,
    this.firmwareVersion,
    this.ipAddress,
    this.lastSeenAt,
    this.active = true,
    this.mode = SgCameraMode.presence,
  });

  bool get isOnline {
    if (lastSeenAt == null) return false;
    return DateTime.now().difference(lastSeenAt!).inMinutes < 5;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'zone_id': zoneId,
        'mac_address': macAddress,
        if (firmwareVersion != null) 'firmware_version': firmwareVersion,
        if (ipAddress != null) 'ip_address': ipAddress,
        if (lastSeenAt != null) 'last_seen_at': lastSeenAt!.toIso8601String(),
        'active': active,
        'mode': mode.name,
        'is_online': isOnline,
        'created_at': createdAt.toIso8601String(),
      };

  SgCamera copyWith({
    String? label,
    String? zoneId,
    String? firmwareVersion,
    String? ipAddress,
    DateTime? lastSeenAt,
    bool? active,
    SgCameraMode? mode,
  }) =>
      SgCamera(
        id: id,
        label: label ?? this.label,
        zoneId: zoneId ?? this.zoneId,
        macAddress: macAddress,
        createdAt: createdAt,
        firmwareVersion: firmwareVersion ?? this.firmwareVersion,
        ipAddress: ipAddress ?? this.ipAddress,
        lastSeenAt: lastSeenAt ?? this.lastSeenAt,
        active: active ?? this.active,
        mode: mode ?? this.mode,
      );
}

/// Mode opérationnel d'une caméra. Détermine quels événements elle remonte.
enum SgCameraMode {
  presence('Présence (anonyme)'),
  faceRecognition('Reconnaissance faciale'),
  motionSecurity('Sécurité (post-fermeture)'),
  spatial('Vision spatiale (compter)'),
  disabled('Désactivée');

  final String label;
  const SgCameraMode(this.label);

  static SgCameraMode fromName(String n) {
    for (final v in values) {
      if (v.name == n) return v;
    }
    return SgCameraMode.disabled;
  }
}

/// Profil facial d'un employé (opt-in obligatoire).
/// Le vecteur d'embedding est stocké localement, jamais envoyé en externe.
@immutable
class SgFaceProfile {
  final String id;
  final String employeeId;
  final List<double> embedding;
  final int samplesCount;
  final DateTime enrolledAt;
  final String enrolledBy;
  final String consentVersion;
  final bool active;

  const SgFaceProfile({
    required this.id,
    required this.employeeId,
    required this.embedding,
    required this.samplesCount,
    required this.enrolledAt,
    required this.enrolledBy,
    required this.consentVersion,
    this.active = true,
  });

  /// Le détail de l'embedding n'est pas exposé via toJson —
  /// seulement les métadonnées pour préserver la confidentialité.
  Map<String, dynamic> toJson() => {
        'id': id,
        'employee_id': employeeId,
        'samples_count': samplesCount,
        'enrolled_at': enrolledAt.toIso8601String(),
        'enrolled_by': enrolledBy,
        'consent_version': consentVersion,
        'active': active,
      };
}

/// Type d'événement remonté par une caméra.
enum SgCameraEventKind {
  faceRecognized,
  facialEnrollmentSample,
  presenceDetected,
  presenceLost,
  motionDetected,
  spatialCount,
  cameraOnline,
  cameraOffline,
  cameraError;

  String get label => switch (this) {
        SgCameraEventKind.faceRecognized => 'Visage reconnu',
        SgCameraEventKind.facialEnrollmentSample => 'Échantillon enrôlement',
        SgCameraEventKind.presenceDetected => 'Présence détectée',
        SgCameraEventKind.presenceLost => 'Présence terminée',
        SgCameraEventKind.motionDetected => 'Mouvement détecté',
        SgCameraEventKind.spatialCount => 'Comptage spatial',
        SgCameraEventKind.cameraOnline => 'Caméra en ligne',
        SgCameraEventKind.cameraOffline => 'Caméra hors ligne',
        SgCameraEventKind.cameraError => 'Erreur caméra',
      };

  static SgCameraEventKind fromName(String n) {
    for (final v in values) {
      if (v.name == n) return v;
    }
    return SgCameraEventKind.cameraError;
  }
}

/// Événement structuré remonté par une caméra ESP32-S3 vers le serveur.
/// Aucune image n'est envoyée — seules les métadonnées.
@immutable
class SgCameraEvent {
  final String id;
  final String cameraId;
  final String zoneId;
  final SgCameraEventKind kind;
  final DateTime at;
  final String? employeeId;
  final double? confidence;
  final int? count;
  final Map<String, dynamic> payload;

  const SgCameraEvent({
    required this.id,
    required this.cameraId,
    required this.zoneId,
    required this.kind,
    required this.at,
    this.employeeId,
    this.confidence,
    this.count,
    this.payload = const {},
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'camera_id': cameraId,
        'zone_id': zoneId,
        'kind': kind.name,
        'kind_label': kind.label,
        'at': at.toIso8601String(),
        if (employeeId != null) 'employee_id': employeeId,
        if (confidence != null) 'confidence': confidence,
        if (count != null) 'count': count,
        if (payload.isNotEmpty) 'payload': payload,
      };

  factory SgCameraEvent.fromJson(Map<String, dynamic> j) => SgCameraEvent(
        id: j['id'] as String,
        cameraId: j['camera_id'] as String,
        zoneId: j['zone_id'] as String,
        kind: SgCameraEventKind.fromName(j['kind'] as String),
        at: DateTime.parse(j['at'] as String),
        employeeId: j['employee_id'] as String?,
        confidence: (j['confidence'] as num?)?.toDouble(),
        count: (j['count'] as num?)?.toInt(),
        payload: (j['payload'] as Map<String, dynamic>?) ?? const {},
      );
}

/// Présence agrégée sur un intervalle (utilisé pour heatmap flux client).
@immutable
class SgPresenceEvent {
  final String id;
  final String zoneId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int peopleCount;

  const SgPresenceEvent({
    required this.id,
    required this.zoneId,
    required this.startedAt,
    required this.peopleCount,
    this.endedAt,
  });

  Duration get duration => (endedAt ?? DateTime.now()).difference(startedAt);

  Map<String, dynamic> toJson() => {
        'id': id,
        'zone_id': zoneId,
        'started_at': startedAt.toIso8601String(),
        if (endedAt != null) 'ended_at': endedAt!.toIso8601String(),
        'people_count': peopleCount,
        'duration_seconds': duration.inSeconds,
      };
}
