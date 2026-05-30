import '../entities/sg_event_journal_entry.dart';
import '../entities/sg_onboarding_checklist.dart';
import '../failures.dart';
import '../ports/sg_broc_repository_port.dart';
import '../ports/sg_clock_port.dart';
import '../result.dart';

/// Coche / décoche un item de checklist onboarding (par index).
class CheckOnboardingItemUseCase {
  final SgBrocRepositoryPort _repo;
  final SgClockPort _clock;
  final String Function() _eventIdGenerator;

  const CheckOnboardingItemUseCase({
    required SgBrocRepositoryPort repository,
    required SgClockPort clock,
    required String Function() eventIdGenerator,
  })  : _repo = repository,
        _clock = clock,
        _eventIdGenerator = eventIdGenerator;

  Future<Result<SgOnboardingChecklist, SgFailure>> call({
    required String checklistId,
    required int itemIndex,
    required bool done,
    String actor = 'employee',
  }) async {
    final res = await _repo.getOnboardingChecklist(checklistId);
    final cl = res.valueOrNull;
    if (cl == null) {
      return Failure(SgNotFoundFailure('Checklist $checklistId not found'));
    }
    if (itemIndex < 0 || itemIndex >= cl.items.length) {
      return Failure(SgValidationFailure('item_index out of range (0..${cl.items.length - 1})'));
    }
    final now = _clock.now();
    final newItems = List<SgOnboardingItem>.from(cl.items);
    newItems[itemIndex] = done
        ? newItems[itemIndex].check(at: now)
        : newItems[itemIndex].uncheck();
    final updated = cl.withItems(newItems);
    final stored = await _repo.updateOnboardingChecklist(updated);
    return stored.when(
      success: (c) async {
        await _repo.logEvent(SgEventJournalEntry(
          id: _eventIdGenerator(),
          at: now,
          actor: actor,
          action: done ? 'onboarding.item_checked' : 'onboarding.item_unchecked',
          target: 'checklist:$checklistId',
          payload: {
            'item_index': itemIndex,
            'label': c.items[itemIndex].label,
            'progress': c.progress,
          },
        ));
        return Success<SgOnboardingChecklist, SgFailure>(c);
      },
      failure: (e) async => Failure<SgOnboardingChecklist, SgFailure>(e),
    );
  }
}
