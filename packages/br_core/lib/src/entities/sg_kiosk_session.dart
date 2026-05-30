import 'package:meta/meta.dart';

/// Session kiosk active sur un device tablette (cuisine/comptoir).
/// Créée par le manager, expire automatiquement (par défaut : minuit).
@immutable
class SgKioskSession {
  final String id;
  final String deviceId;
  final String? deviceLabel;
  final DateTime startedAt;
  final DateTime expiresAt;
  final String createdBy;

  const SgKioskSession({
    required this.id,
    required this.deviceId,
    required this.startedAt,
    required this.expiresAt,
    required this.createdBy,
    this.deviceLabel,
  });

  bool get isActive => DateTime.now().isBefore(expiresAt);

  SgKioskSession copyWith({
    String? id,
    String? deviceId,
    String? deviceLabel,
    DateTime? startedAt,
    DateTime? expiresAt,
    String? createdBy,
  }) =>
      SgKioskSession(
        id: id ?? this.id,
        deviceId: deviceId ?? this.deviceId,
        deviceLabel: deviceLabel ?? this.deviceLabel,
        startedAt: startedAt ?? this.startedAt,
        expiresAt: expiresAt ?? this.expiresAt,
        createdBy: createdBy ?? this.createdBy,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'device_id': deviceId,
        if (deviceLabel != null) 'device_label': deviceLabel,
        'started_at': startedAt.toIso8601String(),
        'expires_at': expiresAt.toIso8601String(),
        'created_by': createdBy,
      };

  factory SgKioskSession.fromJson(Map<String, dynamic> json) => SgKioskSession(
        id: json['id'] as String,
        deviceId: json['device_id'] as String,
        deviceLabel: json['device_label'] as String?,
        startedAt: DateTime.parse(json['started_at'] as String),
        expiresAt: DateTime.parse(json['expires_at'] as String),
        createdBy: json['created_by'] as String,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SgKioskSession && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'SgKioskSession($id, device=$deviceId, until ${expiresAt.toIso8601String()})';
}
