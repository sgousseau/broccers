import '../entities/sg_break.dart';
import '../failures.dart';
import '../ports/sg_broc_repository_port.dart';
import '../ports/sg_clock_port.dart';
import '../result.dart';

/// Démarrer une pause pour un employé en shift actif.
class StartBreakUseCase {
  final SgBrocRepositoryPort _repo;
  final SgClockPort _clock;
  final String Function() _idGenerator;

  const StartBreakUseCase({
    required SgBrocRepositoryPort repository,
    required SgClockPort clock,
    required String Function() idGenerator,
  })  : _repo = repository,
        _clock = clock,
        _idGenerator = idGenerator;

  Future<Result<SgBreak, SgFailure>> call({
    required String employeeId,
    SgBreakType type = SgBreakType.legal,
    Duration? expectedDuration,
  }) async {
    final shiftResult = await _repo.getActiveShiftForEmployee(employeeId);
    final shift = shiftResult.valueOrNull;
    if (shift == null) {
      return shiftResult.when(
        success: (_) => Failure(SgBrocStateFailure(
          'Employee $employeeId has no active shift; cannot start break',
        )),
        failure: (e) => Failure<SgBreak, SgFailure>(e),
      );
    }

    final activeBreak = await _repo.getActiveBreakForEmployee(employeeId);
    return activeBreak.when(
      success: (active) async {
        if (active != null) {
          return Failure(SgBrocStateFailure(
            'Employee $employeeId already on break: ${active.id}',
          ));
        }
        final b = SgBreak.start(
          id: _idGenerator(),
          employeeId: employeeId,
          shiftId: shift.id,
          type: type,
          startedAt: _clock.now(),
          expectedDuration: expectedDuration,
        );
        return _repo.createBreak(b);
      },
      failure: (e) async => Failure<SgBreak, SgFailure>(e),
    );
  }
}
