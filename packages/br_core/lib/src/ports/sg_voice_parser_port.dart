import 'dart:typed_data';

import '../entities/sg_kitchen_ticket.dart';
import '../entities/sg_menu_item.dart';
import '../failures.dart';
import '../result.dart';

/// Port pour parser une commande vocale (audio ou texte) en items de ticket cuisine.
///
/// Adapters :
/// - `WhisperClaudeVoiceParser` (Whisper STT → Claude parse → SgKitchenTicketItem) — v1
/// - `ClaudeTextVoiceParser` (texte direct → Claude parse) — fallback si pas de Whisper
abstract interface class SgVoiceParserPort {
  String get engineId;

  /// Parse une commande vocale à partir d'audio brut.
  /// Si l'audio est null, le parser peut se rabattre sur [textFallback].
  Future<Result<VoiceParseResult, SgFailure>> parse({
    Uint8List? audioBytes,
    String? audioMimeType,
    String? textFallback,
    required List<SgMenuItem> menuContext,
    int? tableNumber,
  });
}

/// Résultat d'un parsing voix : items proposés + transcription brute.
class VoiceParseResult {
  final String transcript;
  final List<SgKitchenTicketItem> items;
  final int? tableNumber;
  final String? engineNote;

  const VoiceParseResult({
    required this.transcript,
    required this.items,
    this.tableNumber,
    this.engineNote,
  });
}
