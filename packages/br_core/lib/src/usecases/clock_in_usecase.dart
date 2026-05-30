import '../entities/sg_shift.dart';
import '../failures.dart';
import '../ports/sg_broc_repository_port.dart';
import '../ports/sg_clock_port.dart';
import '../result.dart';

/// Démarrer un shift pour un employé. Refuse si un shift est déjà actif.
class ClockInUseCase {
  final SgBrocRepositoryPort _repo;
  final SgClockPort _clock;
  final String Function() _idGenerator;

  const ClockInUseCase({
    required SgBrocRepositoryPort repository,
    required SgClockPort clock,
    required String Function() idGenerator,
  })  : _repo = repository,
        _clock = clock,
        _idGenerator = idGenerator;

  Future<Result<SgShift, SgFailure>> call({
    required String employeeId,
    SgShiftPosition position = SgShiftPosition.service,
    DateTime? plannedEndsAt,
  }) async {
    final existing = await _repo.getActiveShiftForEmployee(employeeId);
    return existing.when(
      success: (active) async {
        if (active != null) {
          return Failure(SgBrocStateFailure(
            'Employee $employeeId already has an active shift: ${active.id}',
          ));
        }
        final shift = SgShift.clockIn(
          id: _idGenerator(),
          employeeId: employeeId,
          startsAt: _clock.now(),
          position: position,
          plannedEndsAt: plannedEndsAt,
        );
        return _repo.createShift(shift);
      },
      failure: (e) async => Failure<SgShift, SgFailure>(e),
    );
  }
}
