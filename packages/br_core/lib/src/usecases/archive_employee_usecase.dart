import '../entities/sg_employee.dart';
import '../entities/sg_event_journal_entry.dart';
import '../failures.dart';
import '../ports/sg_broc_repository_port.dart';
import '../ports/sg_clock_port.dart';
import '../result.dart';

/// Archive (soft-delete) un employé : set active=false. Refuse si shift actif.
class ArchiveEmployeeUseCase {
  final SgBrocRepositoryPort _repo;
  final SgClockPort _clock;
  final String Function() _eventIdGenerator;

  const ArchiveEmployeeUseCase({
    required SgBrocRepositoryPort repository,
    required SgClockPort clock,
    required String Function() eventIdGenerator,
  })  : _repo = repository,
        _clock = clock,
        _eventIdGenerator = eventIdGenerator;

  Future<Result<SgEmployee, SgFailure>> call({
    required String employeeId,
    required String actor,
    String? reason,
  }) async {
    final empRes = await _repo.getEmployee(employeeId);
    final emp = empRes.valueOrNull;
    if (emp == null) {
      return Failure(SgNotFoundFailure('Employee $employeeId not found'));
    }
    if (!emp.active) {
      return Failure(SgBrocStateFailure('Employee ${emp.name} is already archived'));
    }
    final activeShift = await _repo.getActiveShiftForEmployee(employeeId);
    if (activeShift.valueOrNull != null) {
      return Failure(SgBrocStateFailure(
        'Cannot archive ${emp.name} — they have an active shift. Clock-out first.',
      ));
    }

    final archived = emp.copyWith(active: false);
    final result = await _repo.updateEmployee(archived);
    return result.when(
      success: (e) async {
        await _repo.logEvent(SgEventJournalEntry(
          id: _eventIdGenerator(),
          at: _clock.now(),
          actor: actor,
          action: 'employee.archived',
          target: 'employee:${e.id}',
          payload: {'name': e.name},
          reason: reason,
        ));
        return Success<SgEmployee, SgFailure>(e);
      },
      failure: (e) async => Failure<SgEmployee, SgFailure>(e),
    );
  }
}
