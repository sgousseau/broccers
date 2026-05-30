import '../failures.dart';
import '../result.dart';

/// Port pour répondre à une question Broc via un moteur LLM.
///
/// **CONTRAINTE FORTE** (mémoire utilisateur) : utiliser `claude -p` cluster Tailscale,
/// NE PAS appeler l'API Anthropic directement.
///
/// Adapters :
/// - `BrClaudeQuestionAdapter` (subprocess `claude -p`, v1) — réutilise pattern nc
/// - `BrLmStudioQuestionAdapter` (LM Studio local, futur)
abstract interface class SgQuestionPort {
  String get engineId;

  /// Pose la question avec un contexte arbitraire (carte, courses, règles…).
  /// Retourne la réponse texte ou une failure.
  Future<Result<String, SgFailure>> ask({
    required String question,
    required Map<String, dynamic> contextSnapshot,
  });
}
