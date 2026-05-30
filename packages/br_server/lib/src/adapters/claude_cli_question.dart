import 'dart:convert';
import 'dart:io';

import 'package:br_core/br_core.dart';

/// Adapter `SgQuestionPort` via `claude -p` (Claude Max cluster Tailscale).
///
/// **CONTRAINTE FORTE** (mémoire utilisateur) : NE JAMAIS appeler l'API Anthropic
/// directement sauf validation explicite. Utiliser claude -p cluster.
class ClaudeCliQuestion implements SgQuestionPort {
  final String _claudeCliPath;
  final String _model;

  const ClaudeCliQuestion({
    required String claudeCliPath,
    String model = 'claude-opus-4-7',
  })  : _claudeCliPath = claudeCliPath,
        _model = model;

  @override
  String get engineId => _model;

  @override
  Future<Result<String, SgFailure>> ask({
    required String question,
    required Map<String, dynamic> contextSnapshot,
  }) async {
    final prompt = '''
Tu es l'assistant de la **Brasserie Broc** (Villeurbanne, Puces du Canal).
Réponds aux questions du manager sur la carte, les courses, le personnel ou la gestion courante.
Sois bref, concret, et donne une réponse actionnable.

CONTEXTE BROC (snapshot JSON) :
${const JsonEncoder.withIndent('  ').convert(contextSnapshot)}

QUESTION DU MANAGER :
$question

Réponds en français, max 5-7 phrases. Si tu manques d'info, dis-le explicitement.
''';

    try {
      final result = await Process.run(
        _claudeCliPath,
        ['-p', prompt, '--model', _model, '--output-format', 'text'],
        runInShell: false,
      ).timeout(const Duration(seconds: 90));

      if (result.exitCode != 0) {
        return Failure(SgBrocQuestionFailure(
          'claude exit ${result.exitCode}: ${result.stderr}',
        ));
      }
      final text = (result.stdout as String).trim();
      if (text.isEmpty) {
        return const Failure(SgBrocQuestionFailure('claude returned empty'));
      }
      return Success(text);
    } on ProcessException catch (e) {
      return Failure(SgBrocQuestionFailure(
        'claude CLI unavailable at $_claudeCliPath',
        cause: e,
      ));
    } catch (e) {
      return Failure(SgBrocQuestionFailure('ask failed', cause: e));
    }
  }
}
