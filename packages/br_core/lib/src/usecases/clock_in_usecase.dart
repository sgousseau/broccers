import '../entities/sg_employee.dart';
import '../entities/sg_event_journal_entry.dart';
import '../entities/sg_shift.dart';
import '../entities/sg_shift_segment.dart';
import '../failures.dart';
import '../ports/sg_broc_repository_port.dart';
import '../ports/sg_clock_port.dart';
import '../result.dart';

/// Démarrer un shift pour un employé. Refuse si un shift est déjà actif.
///
/// **Phase A (multi-rôles)** : résout le rôle effectif via
/// `override → employee.weeklyDefault[today] → employee.defaultRole → seule cap`.
/// Crée le shift puis ouvre immédiatement le 1er segment + log event.
class ClockInUseCase {
  final SgBrocRepositoryPort _repo;
  final SgClockPort _clock;
  final String Function() _shiftIdGenerator;
  final String Function() _segmentIdGenerator;
  final String Function() _eventIdGenerator;

  const ClockInUseCase({
    required SgBrocRepositoryPort repository,
    required SgClockPort clock,
    required String Function() shiftIdGenerator,
    required String Function() segmentIdGenerator,
    required String Function() eventIdGenerator,
  })  : _repo = repository,
        _clock = clock,
        _shiftIdGenerator = shiftIdGenerator,
        _segmentIdGenerator = segmentIdGenerator,
        _eventIdGenerator = eventIdGenerator;

  Future<Result<ClockInOutcome, SgFailure>> call({
    required String employeeId,
    SgEmployeeRole? roleOverride,
    String actor = 'system',
    String? reason,
    DateTime? plannedEndsAt,
  }) async {
    final empResult = await _repo.getEmployee(employeeId);
    final emp = empResult.valueOrNull;
    if (emp == null) {
      return empResult.when(
        success: (_) =>
            Failure(SgNotFoundFailure('Employee $employeeId not found')),
        failure: (e) => Failure<ClockInOutcome, SgFailure>(e),
      );
    }
    if (emp.roles.isEmpty) {
      return Failure(SgBrocStateFailure(
        'Employee ${emp.id} has no roles configured — set roles first',
      ));
    }

    final existingShift = await _repo.getActiveShiftForEmployee(employeeId);
    if (existingShift.valueOrNull != null) {
      return Failure(SgBrocStateFailure(
        'Employee $employeeId already has an active shift: ${existingShift.valueOrNull!.id}',
      ));
    }

    final now = _clock.now();
    final role = emp.resolveRoleFor(now, override: roleOverride);
    if (role == null) {
      return Failure(SgBrocStateFailure(
        'Cannot resolve role for ${emp.name} on ${SgWeekday.ofDate(now).label}. '
        'Configure weeklyDefault or defaultRole, or pass roleOverride.',
      ));
    }

    final shift = SgShift.clockIn(
      id: _shiftIdGenerator(),
      employeeId: employeeId,
      startsAt: now,
      plannedEndsAt: plannedEndsAt,
    );
    final shiftCreate = await _repo.createShift(shift);
    if (shiftCreate.isFailure) {
      return Failure<ClockInOutcome, SgFailure>(shiftCreate.errorOrNull!);
    }

    final segment = SgShiftSegment(
      id: _segmentIdGenerator(),
      shiftId: shift.id,
      role: role,
      startedAt: now,
      reason: reason ?? 'clock-in initial',
      createdBy: actor,
    );
    final segCreate = await _repo.createSegment(segment);
    if (segCreate.isFailure) {
      return Failure<ClockInOutcome, SgFailure>(segCreate.errorOrNull!);
    }

    await _repo.logEvent(SgEventJournalEntry(
      id: _eventIdGenerator(),
      at: now,
      actor: actor,
      action: SgEventActions.shiftStarted,
      target: 'shift:${shift.id}',
      payload: {
        'employee_id': employeeId,
        'role': role.name,
        'segment_id': segment.id,
        'role_resolution': roleOverride != null
            ? 'override'
            : (emp.weeklyDefault[SgWeekday.ofDate(now)] != null
                ? 'weekly'
                : (emp.defaultRole != null ? 'default' : 'single_capability')),
      },
      reason: reason,
    ));

    return Success(ClockInOutcome(shift: shift, firstSegment: segment));
  }
}

class ClockInOutcome {
  final SgShift shift;
  final SgShiftSegment firstSegment;
  const ClockInOutcome({required this.shift, required this.firstSegment});

  Map<String, dynamic> toJson() => {
        'shift': shift.toJson(),
        'first_segment': firstSegment.toJson(),
      };
}
