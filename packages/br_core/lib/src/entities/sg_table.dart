import 'package:meta/meta.dart';

/// Une table physique du restaurant. Génère un QR code pour consultation client.
///
/// Le secret unique `qrSecret` est inclus dans l'URL publique :
/// `https://broc.tail-xxx.ts.net/menu/{tableId}/{qrSecret}`
///
/// Le secret peut être renouvelé pour invalider d'anciens QR (anti-fraude).
@immutable
class SgTable {
  final String id;
  final String label;
  final int? capacity;
  final String qrSecret;
  final String? position;
  final bool active;
  final DateTime createdAt;
  final DateTime? secretRotatedAt;

  const SgTable({
    required this.id,
    required this.label,
    required this.qrSecret,
    required this.createdAt,
    this.capacity,
    this.position,
    this.active = true,
    this.secretRotatedAt,
  });

  /// Construit l'URL publique de consultation pour cette table.
  String publicMenuUrl(String baseUrl) =>
      '$baseUrl/menu/$id/$qrSecret';

  SgTable rotateSecret({required String newSecret, required DateTime at}) =>
      copyWith(qrSecret: newSecret, secretRotatedAt: at);

  SgTable copyWith({
    String? id,
    String? label,
    int? capacity,
    String? qrSecret,
    String? position,
    bool? active,
    DateTime? createdAt,
    DateTime? secretRotatedAt,
  }) =>
      SgTable(
        id: id ?? this.id,
        label: label ?? this.label,
        capacity: capacity ?? this.capacity,
        qrSecret: qrSecret ?? this.qrSecret,
        position: position ?? this.position,
        active: active ?? this.active,
        createdAt: createdAt ?? this.createdAt,
        secretRotatedAt: secretRotatedAt ?? this.secretRotatedAt,
      );

  Map<String, dynamic> toJson({String? baseUrl}) => {
        'id': id,
        'label': label,
        if (capacity != null) 'capacity': capacity,
        'qr_secret': qrSecret,
        if (position != null) 'position': position,
        'active': active,
        'created_at': createdAt.toIso8601String(),
        if (secretRotatedAt != null)
          'secret_rotated_at': secretRotatedAt!.toIso8601String(),
        if (baseUrl != null) 'public_url': publicMenuUrl(baseUrl),
      };

  factory SgTable.fromJson(Map<String, dynamic> j) => SgTable(
        id: j['id'] as String,
        label: j['label'] as String,
        capacity: j['capacity'] as int?,
        qrSecret: j['qr_secret'] as String,
        position: j['position'] as String?,
        active: j['active'] as bool? ?? true,
        createdAt: DateTime.parse(j['created_at'] as String),
        secretRotatedAt: j['secret_rotated_at'] != null
            ? DateTime.parse(j['secret_rotated_at'] as String)
            : null,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is SgTable && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'SgTable($id, "$label"${capacity != null ? ", $capacity pl." : ""}${active ? "" : " ARCHIVED"})';
}
