import '../entities/sg_employee.dart';
import '../entities/sg_event_journal_entry.dart';
import '../entities/sg_shift_segment.dart';
import '../failures.dart';
import '../ports/sg_broc_repository_port.dart';
import '../ports/sg_clock_port.dart';
import '../result.dart';

/// Change le rôle tenu pendant un shift actif.
///
/// 1. Charge l'employé → vérifie qu'il a la capability [newRole] dans ses roles
/// 2. Charge le shift actif + segment actif
/// 3. Ferme le segment actif (endedAt = now)
/// 4. Crée un nouveau segment avec [newRole]
/// 5. Log event `segment.role_changed`
///
/// `actor` = qui change : `employee:<id>` ou `manager:<id>` ou `system`.
/// L'employé peut rectifier son propre rôle ; le manager peut changer celui de n'importe qui.
class ChangeRoleInShiftUseCase {
  final SgBrocRepositoryPort _repo;
  final SgClockPort _clock;
  final String Function() _segmentIdGenerator;
  final String Function() _eventIdGenerator;

  const ChangeRoleInShiftUseCase({
    required SgBrocRepositoryPort repository,
    required SgClockPort clock,
    required String Function() segmentIdGenerator,
    required String Function() eventIdGenerator,
  })  : _repo = repository,
        _clock = clock,
        _segmentIdGenerator = segmentIdGenerator,
        _eventIdGenerator = eventIdGenerator;

  Future<Result<ChangeRoleOutcome, SgFailure>> call({
    required String employeeId,
    required SgEmployeeRole newRole,
    required String actor,
    String? reason,
  }) async {
    final empResult = await _repo.getEmployee(employeeId);
    final emp = empResult.valueOrNull;
    if (emp == null) {
      return empResult.when(
        success: (_) => Failure(SgNotFoundFailure('Employee $employeeId not found')),
        failure: (e) => Failure<ChangeRoleOutcome, SgFailure>(e),
      );
    }
    if (!emp.canHold(newRole)) {
      return Failure(SgBrocStateFailure(
        '${emp.name} cannot hold role ${newRole.label} — not in their capabilities {${emp.roles.map((r) => r.name).join(",")}}',
      ));
    }

    final shiftResult = await _repo.getActiveShiftForEmployee(employeeId);
    final shift = shiftResult.valueOrNull;
    if (shift == null) {
      return shiftResult.when(
        success: (_) => Failure(SgBrocStateFailure(
          'Employee $employeeId has no active shift — cannot change role',
        )),
        failure: (e) => Failure<ChangeRoleOutcome, SgFailure>(e),
      );
    }

    final now = _clock.now();

    SgShiftSegment? closedSegment;
    final activeSegResult = await _repo.getActiveSegmentForShift(shift.id);
    final activeSeg = activeSegResult.valueOrNull;

    if (activeSeg != null) {
      if (activeSeg.role == newRole) {
        return Failure(SgBrocStateFailure(
          'Already holding role ${newRole.label} — no change needed',
        ));
      }
      final ended = activeSeg.end(at: now);
      final segUpdate = await _repo.updateSegment(ended);
      if (segUpdate.isFailure) {
        return Failure<ChangeRoleOutcome, SgFailure>(segUpdate.errorOrNull!);
      }
      closedSegment = ended;
    }

    final newSegment = SgShiftSegment(
      id: _segmentIdGenerator(),
      shiftId: shift.id,
      role: newRole,
      startedAt: now,
      reason: reason,
      createdBy: actor,
    );
    final segCreate = await _repo.createSegment(newSegment);
    if (segCreate.isFailure) {
      return Failure<ChangeRoleOutcome, SgFailure>(segCreate.errorOrNull!);
    }

    await _repo.logEvent(SgEventJournalEntry(
      id: _eventIdGenerator(),
      at: now,
      actor: actor,
      action: SgEventActions.segmentRoleChanged,
      target: 'shift:${shift.id}',
      payload: {
        'employee_id': employeeId,
        'from_role': closedSegment?.role.name,
        'to_role': newRole.name,
        'closed_segment_id': closedSegment?.id,
        'new_segment_id': newSegment.id,
      },
      reason: reason,
    ));

    return Success(ChangeRoleOutcome(
      newSegment: newSegment,
      closedSegment: closedSegment,
    ));
  }
}

class ChangeRoleOutcome {
  final SgShiftSegment newSegment;
  final SgShiftSegment? closedSegment;
  const ChangeRoleOutcome({required this.newSegment, this.closedSegment});

  Map<String, dynamic> toJson() => {
        'new_segment': newSegment.toJson(),
        if (closedSegment != null) 'closed_segment': closedSegment!.toJson(),
      };
}
