import '../entities/sg_event_journal_entry.dart';
import '../entities/sg_shift.dart';
import '../entities/sg_shift_segment.dart';
import '../failures.dart';
import '../ports/sg_broc_repository_port.dart';
import '../ports/sg_clock_port.dart';
import '../result.dart';

/// Terminer le shift actif d'un employé.
///
/// **Phase A** : ferme aussi le segment actif + log event.
class ClockOutUseCase {
  final SgBrocRepositoryPort _repo;
  final SgClockPort _clock;
  final String Function() _eventIdGenerator;

  const ClockOutUseCase({
    required SgBrocRepositoryPort repository,
    required SgClockPort clock,
    required String Function() eventIdGenerator,
  })  : _repo = repository,
        _clock = clock,
        _eventIdGenerator = eventIdGenerator;

  Future<Result<ClockOutOutcome, SgFailure>> call({
    required String employeeId,
    String actor = 'system',
    String? reason,
  }) async {
    final activeResult = await _repo.getActiveShiftForEmployee(employeeId);
    final active = activeResult.valueOrNull;
    if (active == null) {
      return activeResult.when(
        success: (_) => Failure(SgBrocStateFailure(
          'Employee $employeeId has no active shift',
        )),
        failure: (e) => Failure<ClockOutOutcome, SgFailure>(e),
      );
    }

    final now = _clock.now();

    SgShiftSegment? closedSegment;
    final segResult = await _repo.getActiveSegmentForShift(active.id);
    final activeSeg = segResult.valueOrNull;
    if (activeSeg != null) {
      final endedSeg = activeSeg.end(at: now);
      final segUpdate = await _repo.updateSegment(endedSeg);
      if (segUpdate.isFailure) {
        return Failure<ClockOutOutcome, SgFailure>(segUpdate.errorOrNull!);
      }
      closedSegment = endedSeg;
    }

    final ended = active.end(at: now);
    final updated = await _repo.updateShift(ended);
    if (updated.isFailure) {
      return Failure<ClockOutOutcome, SgFailure>(updated.errorOrNull!);
    }

    await _repo.logEvent(SgEventJournalEntry(
      id: _eventIdGenerator(),
      at: now,
      actor: actor,
      action: SgEventActions.shiftEnded,
      target: 'shift:${active.id}',
      payload: {
        'employee_id': employeeId,
        'duration_minutes': ended.duration.inMinutes,
        if (closedSegment != null) 'closed_segment_id': closedSegment.id,
      },
      reason: reason,
    ));

    return Success(ClockOutOutcome(shift: ended, closedSegment: closedSegment));
  }
}

class ClockOutOutcome {
  final SgShift shift;
  final SgShiftSegment? closedSegment;
  const ClockOutOutcome({required this.shift, this.closedSegment});

  Map<String, dynamic> toJson() => {
        'shift': shift.toJson(),
        if (closedSegment != null) 'closed_segment': closedSegment!.toJson(),
      };
}
