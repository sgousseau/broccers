import 'package:meta/meta.dart';

/// Trace d'une exportation PDF d'une carte. Source/Derivation : lien direct vers
/// la version de la `SgMenuCard` d'origine.
@immutable
class SgPdfExport {
  final String id;
  final String cardId;
  final int cardVersion;
  final DateTime renderedAt;
  final String filePath;
  final int byteSize;
  final String engine;

  const SgPdfExport({
    required this.id,
    required this.cardId,
    required this.cardVersion,
    required this.renderedAt,
    required this.filePath,
    required this.byteSize,
    required this.engine,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'card_id': cardId,
        'card_version': cardVersion,
        'rendered_at': renderedAt.toIso8601String(),
        'file_path': filePath,
        'byte_size': byteSize,
        'engine': engine,
      };

  factory SgPdfExport.fromJson(Map<String, dynamic> json) => SgPdfExport(
        id: json['id'] as String,
        cardId: json['card_id'] as String,
        cardVersion: json['card_version'] as int,
        renderedAt: DateTime.parse(json['rendered_at'] as String),
        filePath: json['file_path'] as String,
        byteSize: json['byte_size'] as int,
        engine: json['engine'] as String,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SgPdfExport && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'SgPdfExport($id, card=$cardId@v$cardVersion, ${(byteSize / 1024).toStringAsFixed(1)} KB)';
}
