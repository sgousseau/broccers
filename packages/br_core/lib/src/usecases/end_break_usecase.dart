import '../entities/sg_break.dart';
import '../failures.dart';
import '../ports/sg_broc_repository_port.dart';
import '../ports/sg_clock_port.dart';
import '../result.dart';

/// Terminer la pause active de l'employé. Renvoie la pause + un warning si trop courte.
class EndBreakUseCase {
  final SgBrocRepositoryPort _repo;
  final SgClockPort _clock;

  const EndBreakUseCase({
    required SgBrocRepositoryPort repository,
    required SgClockPort clock,
  })  : _repo = repository,
        _clock = clock;

  Future<Result<EndBreakOutcome, SgFailure>> call({required String employeeId}) async {
    final activeResult = await _repo.getActiveBreakForEmployee(employeeId);
    final active = activeResult.valueOrNull;
    if (active == null) {
      return activeResult.when(
        success: (_) => Failure(SgBrocStateFailure(
          'Employee $employeeId has no active break',
        )),
        failure: (e) => Failure<EndBreakOutcome, SgFailure>(e),
      );
    }
    final ended = active.end(at: _clock.now());
    final update = await _repo.updateBreak(ended);
    return update.when(
      success: (b) => Success(EndBreakOutcome(
        breakRecord: b,
        warning:
            b.isShorterThanExpected ? 'BREAK_TOO_SHORT' : null,
      )),
      failure: (e) => Failure<EndBreakOutcome, SgFailure>(e),
    );
  }
}

class EndBreakOutcome {
  final SgBreak breakRecord;
  final String? warning;
  const EndBreakOutcome({required this.breakRecord, this.warning});
}
