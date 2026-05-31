import '../entities/sg_cooking_task.dart';
import '../entities/sg_event_journal_entry.dart';
import '../failures.dart';
import '../ports/sg_broc_repository_port.dart';
import '../ports/sg_clock_port.dart';
import '../result.dart';

/// Démarre une cooking task (cuisson, prep, dressage).
class StartCookingTaskUseCase {
  final SgBrocRepositoryPort _repo;
  final SgClockPort _clock;
  final String Function() _eventIdGenerator;

  const StartCookingTaskUseCase({
    required SgBrocRepositoryPort repository,
    required SgClockPort clock,
    required String Function() eventIdGenerator,
  })  : _repo = repository,
        _clock = clock,
        _eventIdGenerator = eventIdGenerator;

  Future<Result<SgCookingTask, SgFailure>> call({
    required String taskId,
    String? assignedTo,
    String actor = 'cook',
  }) async {
    final taskRes = await _repo.getCookingTask(taskId);
    final task = taskRes.valueOrNull;
    if (task == null) {
      return Failure(SgNotFoundFailure('CookingTask $taskId not found'));
    }
    if (task.status != SgCookingTaskStatus.pending) {
      return Failure(SgBrocStateFailure(
        'Task ${task.id} is not pending (current: ${task.status.name})',
      ));
    }
    final now = _clock.now();
    final started = task.start(at: now, by: assignedTo ?? actor);
    final updated = await _repo.updateCookingTask(started);
    return updated.when(
      success: (t) async {
        await _repo.logEvent(SgEventJournalEntry(
          id: _eventIdGenerator(),
          at: now,
          actor: actor,
          action: 'cooking_task.started',
          target: 'cooking_task:${t.id}',
          payload: {
            'label': t.label,
            'expected_duration_ms': t.expectedDuration.inMilliseconds,
            'assigned_to': t.assignedTo,
          },
        ));
        return Success<SgCookingTask, SgFailure>(t);
      },
      failure: (e) async => Failure<SgCookingTask, SgFailure>(e),
    );
  }
}

/// Termine une cooking task. Log si dépassement temps.
class CompleteCookingTaskUseCase {
  final SgBrocRepositoryPort _repo;
  final SgClockPort _clock;
  final String Function() _eventIdGenerator;

  const CompleteCookingTaskUseCase({
    required SgBrocRepositoryPort repository,
    required SgClockPort clock,
    required String Function() eventIdGenerator,
  })  : _repo = repository,
        _clock = clock,
        _eventIdGenerator = eventIdGenerator;

  Future<Result<SgCookingTask, SgFailure>> call({
    required String taskId,
    String actor = 'cook',
  }) async {
    final taskRes = await _repo.getCookingTask(taskId);
    final task = taskRes.valueOrNull;
    if (task == null) {
      return Failure(SgNotFoundFailure('CookingTask $taskId not found'));
    }
    if (task.status != SgCookingTaskStatus.inProgress) {
      return Failure(SgBrocStateFailure(
        'Task ${task.id} is not in progress (current: ${task.status.name})',
      ));
    }
    final now = _clock.now();
    final done = task.complete(at: now);
    final updated = await _repo.updateCookingTask(done);
    return updated.when(
      success: (t) async {
        final elapsedMs = t.elapsed?.inMilliseconds ?? 0;
        final overtime = elapsedMs - t.expectedDuration.inMilliseconds;
        await _repo.logEvent(SgEventJournalEntry(
          id: _eventIdGenerator(),
          at: now,
          actor: actor,
          action: 'cooking_task.completed',
          target: 'cooking_task:${t.id}',
          payload: {
            'label': t.label,
            'elapsed_ms': elapsedMs,
            'expected_ms': t.expectedDuration.inMilliseconds,
            'overtime_ms': overtime,
            'was_overdue': overtime > 0,
          },
        ));
        return Success<SgCookingTask, SgFailure>(t);
      },
      failure: (e) async => Failure<SgCookingTask, SgFailure>(e),
    );
  }
}

/// Set ou update la recette d'un menu item.
class UpsertRecipeUseCase {
  final SgBrocRepositoryPort _repo;
  final SgClockPort _clock;
  final String Function() _eventIdGenerator;

  const UpsertRecipeUseCase({
    required SgBrocRepositoryPort repository,
    required SgClockPort clock,
    required String Function() eventIdGenerator,
  })  : _repo = repository,
        _clock = clock,
        _eventIdGenerator = eventIdGenerator;

  Future<Result<void, SgFailure>> call({
    required String menuItemId,
    required String recipeId,
    required String name,
    required List<dynamic> steps, // List<SgRecipeStep>
    String actor = 'manager',
  }) async {
    await _repo.logEvent(SgEventJournalEntry(
      id: _eventIdGenerator(),
      at: _clock.now(),
      actor: actor,
      action: 'recipe.upserted',
      target: 'menu_item:$menuItemId',
      payload: {'recipe_id': recipeId, 'steps_count': steps.length, 'name': name},
    ));
    return const Success(null);
  }
}
