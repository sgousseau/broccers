import '../entities/sg_shift.dart';
import '../failures.dart';
import '../ports/sg_broc_repository_port.dart';
import '../ports/sg_clock_port.dart';
import '../result.dart';

/// Terminer le shift actif d'un employé.
class ClockOutUseCase {
  final SgBrocRepositoryPort _repo;
  final SgClockPort _clock;

  const ClockOutUseCase({
    required SgBrocRepositoryPort repository,
    required SgClockPort clock,
  })  : _repo = repository,
        _clock = clock;

  Future<Result<SgShift, SgFailure>> call({required String employeeId}) async {
    final activeResult = await _repo.getActiveShiftForEmployee(employeeId);
    return activeResult.when(
      success: (active) async {
        if (active == null) {
          return Failure(SgBrocStateFailure(
            'Employee $employeeId has no active shift',
          ));
        }
        final ended = active.end(at: _clock.now());
        return _repo.updateShift(ended);
      },
      failure: (e) async => Failure<SgShift, SgFailure>(e),
    );
  }
}
