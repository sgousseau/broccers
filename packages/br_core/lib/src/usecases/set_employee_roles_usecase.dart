import '../entities/sg_employee.dart';
import '../entities/sg_event_journal_entry.dart';
import '../failures.dart';
import '../ports/sg_broc_repository_port.dart';
import '../ports/sg_clock_port.dart';
import '../result.dart';

/// Manager met à jour les capabilities (roles) + defaultRole d'un employé.
class SetEmployeeRolesUseCase {
  final SgBrocRepositoryPort _repo;
  final SgClockPort _clock;
  final String Function() _eventIdGenerator;

  const SetEmployeeRolesUseCase({
    required SgBrocRepositoryPort repository,
    required SgClockPort clock,
    required String Function() eventIdGenerator,
  })  : _repo = repository,
        _clock = clock,
        _eventIdGenerator = eventIdGenerator;

  Future<Result<SgEmployee, SgFailure>> call({
    required String employeeId,
    required Set<SgEmployeeRole> roles,
    SgEmployeeRole? defaultRole,
    required String actor,
    String? reason,
  }) async {
    if (roles.isEmpty) {
      return const Failure(SgValidationFailure('roles must contain at least one capability'));
    }
    if (defaultRole != null && !roles.contains(defaultRole)) {
      return Failure(SgValidationFailure(
        'defaultRole ${defaultRole.label} must be in the roles set',
      ));
    }
    final empResult = await _repo.getEmployee(employeeId);
    final emp = empResult.valueOrNull;
    if (emp == null) {
      return empResult.when(
        success: (_) => Failure(SgNotFoundFailure('Employee $employeeId not found')),
        failure: (e) => Failure<SgEmployee, SgFailure>(e),
      );
    }

    final prevRoles = emp.roles.toList();
    final prevDefault = emp.defaultRole;

    final cleanedWeekly = Map<SgWeekday, SgEmployeeRole>.fromEntries(
      emp.weeklyDefault.entries.where((e) => roles.contains(e.value)),
    );

    final updated = emp.copyWith(
      roles: roles,
      defaultRole: defaultRole ?? (roles.contains(emp.defaultRole) ? emp.defaultRole : null),
      weeklyDefault: cleanedWeekly,
    );
    final result = await _repo.updateEmployee(updated);
    return result.when(
      success: (e) async {
        await _repo.logEvent(SgEventJournalEntry(
          id: _eventIdGenerator(),
          at: _clock.now(),
          actor: actor,
          action: SgEventActions.employeeRolesChanged,
          target: 'employee:${e.id}',
          payload: {
            'from_roles': prevRoles.map((r) => r.name).toList(),
            'to_roles': roles.map((r) => r.name).toList(),
            'from_default': prevDefault?.name,
            'to_default': updated.defaultRole?.name,
            'weekly_pruned_count': emp.weeklyDefault.length - cleanedWeekly.length,
          },
          reason: reason,
        ));
        return Success<SgEmployee, SgFailure>(e);
      },
      failure: (e) async => Failure<SgEmployee, SgFailure>(e),
    );
  }
}
