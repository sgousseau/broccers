import '../entities/sg_question.dart';
import '../failures.dart';
import '../ports/sg_broc_repository_port.dart';
import '../ports/sg_clock_port.dart';
import '../ports/sg_question_port.dart';
import '../result.dart';

/// Pose une question à Claude avec contexte Broc (carte + courses + règles).
class AskQuestionUseCase {
  final SgBrocRepositoryPort _repo;
  final SgQuestionPort _engine;
  final SgClockPort _clock;
  final String Function() _idGenerator;

  const AskQuestionUseCase({
    required SgBrocRepositoryPort repository,
    required SgQuestionPort engine,
    required SgClockPort clock,
    required String Function() idGenerator,
  })  : _repo = repository,
        _engine = engine,
        _clock = clock,
        _idGenerator = idGenerator;

  Future<Result<SgQuestion, SgFailure>> call({
    required String question,
    Set<String> scope = const {'menu', 'shopping'},
  }) async {
    if (question.trim().isEmpty) {
      return const Failure(SgValidationFailure('question required'));
    }

    final context = <String, dynamic>{
      'asked_at': _clock.now().toIso8601String(),
      'scope': scope.toList(),
    };

    if (scope.contains('menu')) {
      final card = await _repo.getCurrentPublishedMenuCard();
      context['current_menu'] = card.valueOrNull?.toJson();
    }
    if (scope.contains('shopping')) {
      final items = await _repo.listShoppingItems(done: false);
      context['open_shopping_items'] =
          items.valueOrNull?.map((i) => i.toJson()).toList();
    }

    final q0 = SgQuestion(
      id: _idGenerator(),
      askedAt: _clock.now(),
      question: question.trim(),
      contextSnapshot: context,
      engine: _engine.engineId,
    );

    final answer = await _engine.ask(
      question: question.trim(),
      contextSnapshot: context,
    );
    return answer.when(
      success: (text) async {
        final q = q0.withAnswer(text: text, at: _clock.now());
        final stored = await _repo.storeQuestion(q);
        return stored.when(
          success: (_) => Success<SgQuestion, SgFailure>(q),
          failure: (e) => Failure<SgQuestion, SgFailure>(e),
        );
      },
      failure: (e) async {
        await _repo.storeQuestion(q0);
        return Failure<SgQuestion, SgFailure>(e);
      },
    );
  }
}
