import '../entities/sg_employee.dart';
import '../entities/sg_event_journal_entry.dart';
import '../failures.dart';
import '../ports/sg_broc_repository_port.dart';
import '../ports/sg_clock_port.dart';
import '../result.dart';

/// Manager assigne / met à jour le planning hebdomadaire d'un employé.
/// Tous les rôles assignés doivent être dans les capabilities de l'employé.
class SetWeeklyDefaultUseCase {
  final SgBrocRepositoryPort _repo;
  final SgClockPort _clock;
  final String Function() _eventIdGenerator;

  const SetWeeklyDefaultUseCase({
    required SgBrocRepositoryPort repository,
    required SgClockPort clock,
    required String Function() eventIdGenerator,
  })  : _repo = repository,
        _clock = clock,
        _eventIdGenerator = eventIdGenerator;

  Future<Result<SgEmployee, SgFailure>> call({
    required String employeeId,
    required Map<SgWeekday, SgEmployeeRole> weekly,
    required String actor,
    String? reason,
  }) async {
    final empResult = await _repo.getEmployee(employeeId);
    final emp = empResult.valueOrNull;
    if (emp == null) {
      return empResult.when(
        success: (_) => Failure(SgNotFoundFailure('Employee $employeeId not found')),
        failure: (e) => Failure<SgEmployee, SgFailure>(e),
      );
    }

    for (final entry in weekly.entries) {
      if (!emp.canHold(entry.value)) {
        return Failure(SgBrocStateFailure(
          '${emp.name} cannot be scheduled as ${entry.value.label} on ${entry.key.label} — not in their roles',
        ));
      }
    }

    final previous = emp.weeklyDefault;
    final updated = emp.copyWith(weeklyDefault: weekly);
    final result = await _repo.updateEmployee(updated);
    return result.when(
      success: (e) async {
        await _repo.logEvent(SgEventJournalEntry(
          id: _eventIdGenerator(),
          at: _clock.now(),
          actor: actor,
          action: SgEventActions.employeeWeeklyChanged,
          target: 'employee:${e.id}',
          payload: {
            'from': previous.map((k, v) => MapEntry(k.isoDay.toString(), v.name)),
            'to': weekly.map((k, v) => MapEntry(k.isoDay.toString(), v.name)),
          },
          reason: reason,
        ));
        return Success<SgEmployee, SgFailure>(e);
      },
      failure: (e) async => Failure<SgEmployee, SgFailure>(e),
    );
  }
}
