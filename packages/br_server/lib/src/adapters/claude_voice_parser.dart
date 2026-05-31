import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:br_core/br_core.dart';
import 'package:http/http.dart' as http;

/// Adapter `SgVoiceParserPort` :
/// 1. Si [audioBytes] fourni : appelle Whisper Titan via Tailscale (faster-whisper) pour STT
/// 2. Sinon : utilise [textFallback]
/// 3. Demande à Claude `-p` de parser le texte en items structurés JSON
///
/// Sortie : ticket items prêts à valider.
class ClaudeVoiceParser implements SgVoiceParserPort {
  final String _claudeCliPath;
  final String _model;
  final String? _whisperUrl;
  final http.Client _http;

  ClaudeVoiceParser({
    required String claudeCliPath,
    String? whisperUrl,
    String model = 'claude-opus-4-7',
    http.Client? httpClient,
  })  : _claudeCliPath = claudeCliPath,
        _model = model,
        _whisperUrl = whisperUrl,
        _http = httpClient ?? http.Client();

  @override
  String get engineId => 'claude-voice-parser-$_model';

  @override
  Future<Result<VoiceParseResult, SgFailure>> parse({
    Uint8List? audioBytes,
    String? audioMimeType,
    String? textFallback,
    required List<SgMenuItem> menuContext,
    int? tableNumber,
  }) async {
    String transcript = textFallback ?? '';
    String? engineNote;

    if (audioBytes != null && audioBytes.isNotEmpty && _whisperUrl != null) {
      try {
        final req = http.MultipartRequest(
          'POST',
          Uri.parse('$_whisperUrl/v1/audio/transcriptions'),
        );
        req.fields['model'] = 'large-v3';
        req.fields['language'] = 'fr';
        req.fields['response_format'] = 'json';
        req.files.add(http.MultipartFile.fromBytes(
          'file',
          audioBytes,
          filename: 'order.${(audioMimeType ?? "webm").split("/").last}',
        ));
        final resp =
            await _http.send(req).timeout(const Duration(seconds: 30));
        final body = await resp.stream.bytesToString();
        if (resp.statusCode == 200) {
          final json = jsonDecode(body) as Map<String, dynamic>;
          transcript = (json['text'] as String? ?? '').trim();
          engineNote = 'whisper-titan';
        } else {
          engineNote = 'whisper-failed-${resp.statusCode}';
        }
      } catch (e) {
        engineNote = 'whisper-error: $e';
      }
    }

    if (transcript.isEmpty) {
      return const Failure(SgValidationFailure(
        'No transcript : audio failed and no textFallback provided',
      ));
    }

    final menuJson = menuContext
        .where((m) => m.available)
        .map((m) => {
              'id': m.id,
              'name': m.name,
              if (m.description != null) 'description': m.description,
              'price': '${m.priceCents / 100} €',
            })
        .toList();

    final prompt = '''
Tu es un parseur de commande pour la Brasserie Broc (Villeurbanne).
Un serveur dicte une commande vocale ${tableNumber != null ? "pour la table $tableNumber" : ""}. Voici la transcription :

"$transcript"

Et voici la carte courante (avec ids) :
${const JsonEncoder.withIndent('  ').convert(menuJson)}

Parse la commande en items structurés. Réponds STRICTEMENT en JSON sur une seule ligne :
{"table_number":N|null,"items":[{"menu_item_id":"id-or-null","label":"texte court de l'item","quantity":N,"modifiers":["saignant","sans oignon",...],"notes":"texte libre|null"}]}

Règles :
- Si l'item correspond à la carte, mets son menu_item_id, sinon null + label libre
- "modifiers" pour cuisson (saignant/à point/bien cuit), exclusions, ajouts (extra fromage)
- "notes" pour les remarques spéciales (allergie, urgence)
- "table_number" si mentionné, sinon null
- Pas de markdown. Pas de backticks. JUSTE le JSON.
''';

    try {
      final result = await Process.run(
        _claudeCliPath,
        ['-p', prompt, '--model', _model, '--output-format', 'text'],
        runInShell: false,
      ).timeout(const Duration(seconds: 60));
      if (result.exitCode != 0) {
        return Failure(SgBrocQuestionFailure(
          'claude exit ${result.exitCode}: ${result.stderr}',
        ));
      }
      final stdout = (result.stdout as String).trim();
      final jsonStr = _extractJson(stdout);
      final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
      final parsedItems = (parsed['items'] as List<dynamic>?) ?? const [];
      final items = parsedItems.map((it) {
        final m = it as Map<String, dynamic>;
        return SgKitchenTicketItem(
          id: '__pending__', // remplacé en UseCase
          ticketId: '__pending__',
          menuItemId: m['menu_item_id'] as String?,
          label: m['label'] as String? ?? '?',
          quantity: m['quantity'] as int? ?? 1,
          modifiers: ((m['modifiers'] as List<dynamic>?) ?? const [])
              .cast<String>(),
          status: SgKitchenItemStatus.pending,
          notes: m['notes'] as String?,
        );
      }).toList();
      return Success(VoiceParseResult(
        transcript: transcript,
        items: items,
        tableNumber: parsed['table_number'] as int? ?? tableNumber,
        engineNote: engineNote,
      ));
    } catch (e) {
      return Failure(SgBrocQuestionFailure('voice parse failed', cause: e));
    }
  }

  String _extractJson(String s) {
    final start = s.indexOf('{');
    final end = s.lastIndexOf('}');
    if (start < 0 || end <= start) return '{}';
    return s.substring(start, end + 1);
  }
}
