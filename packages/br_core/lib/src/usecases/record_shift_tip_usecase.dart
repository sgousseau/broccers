import '../entities/sg_event_journal_entry.dart';
import '../entities/sg_shift.dart';
import '../failures.dart';
import '../ports/sg_broc_repository_port.dart';
import '../ports/sg_clock_port.dart';
import '../result.dart';

/// Manager ou employé déclare le pourboire perçu pour un shift terminé.
class RecordShiftTipUseCase {
  final SgBrocRepositoryPort _repo;
  final SgClockPort _clock;
  final String Function() _eventIdGenerator;

  const RecordShiftTipUseCase({
    required SgBrocRepositoryPort repository,
    required SgClockPort clock,
    required String Function() eventIdGenerator,
  })  : _repo = repository,
        _clock = clock,
        _eventIdGenerator = eventIdGenerator;

  Future<Result<SgShift, SgFailure>> call({
    required String shiftId,
    required int tipCents,
    required String actor,
    String? reason,
  }) async {
    if (tipCents < 0) {
      return const Failure(SgValidationFailure('tip_cents must be >= 0'));
    }
    final shiftRes = await _repo.getShift(shiftId);
    final shift = shiftRes.valueOrNull;
    if (shift == null) {
      return Failure(SgNotFoundFailure('Shift $shiftId not found'));
    }
    final previous = shift.tipCents;
    final updated = shift.withTip(tipCents);
    final stored = await _repo.updateShift(updated);
    return stored.when(
      success: (s) async {
        await _repo.logEvent(SgEventJournalEntry(
          id: _eventIdGenerator(),
          at: _clock.now(),
          actor: actor,
          action: 'shift.tip_recorded',
          target: 'shift:${s.id}',
          payload: {
            'employee_id': s.employeeId,
            'from_tip_cents': previous,
            'to_tip_cents': tipCents,
          },
          reason: reason,
        ));
        return Success<SgShift, SgFailure>(s);
      },
      failure: (e) async => Failure<SgShift, SgFailure>(e),
    );
  }
}
