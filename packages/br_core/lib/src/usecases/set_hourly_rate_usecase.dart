import '../entities/sg_employee.dart';
import '../entities/sg_event_journal_entry.dart';
import '../entities/sg_hourly_rate.dart';
import '../failures.dart';
import '../ports/sg_broc_repository_port.dart';
import '../ports/sg_clock_port.dart';
import '../result.dart';

/// Définit un nouveau taux horaire pour un employé (et optionnellement un rôle spécifique).
/// Ferme le tarif précédent (set validTo = validFrom du nouveau) pour le couple
/// (employé, rôle) identique.
class SetHourlyRateUseCase {
  final SgBrocRepositoryPort _repo;
  final SgClockPort _clock;
  final String Function() _idGenerator;
  final String Function() _eventIdGenerator;

  const SetHourlyRateUseCase({
    required SgBrocRepositoryPort repository,
    required SgClockPort clock,
    required String Function() idGenerator,
    required String Function() eventIdGenerator,
  })  : _repo = repository,
        _clock = clock,
        _idGenerator = idGenerator,
        _eventIdGenerator = eventIdGenerator;

  Future<Result<SgHourlyRate, SgFailure>> call({
    required String employeeId,
    SgEmployeeRole? role,
    required int rateCents,
    DateTime? validFrom,
    String actor = 'manager',
    String? reason,
  }) async {
    if (rateCents <= 0) {
      return const Failure(SgValidationFailure('rateCents must be > 0'));
    }

    final emp = await _repo.getEmployee(employeeId);
    if (emp.valueOrNull == null) {
      return Failure(SgNotFoundFailure('Employee $employeeId not found'));
    }
    if (role != null && !emp.valueOrNull!.canHold(role)) {
      return Failure(SgBrocHourlyRateFailure(
        '${emp.valueOrNull!.name} cannot hold role ${role.label} — cannot set rate for it',
      ));
    }

    final now = _clock.now();
    final from = validFrom ?? now;

    final currentResult =
        await _repo.getActiveHourlyRate(employeeId: employeeId, role: role, at: from);
    final current = currentResult.valueOrNull;
    if (current != null) {
      final closed = current.copyWith(validTo: from);
      await _repo.updateHourlyRate(closed);
    }

    final rate = SgHourlyRate(
      id: 'hr-${_idGenerator()}',
      employeeId: employeeId,
      role: role,
      rateCents: rateCents,
      validFrom: from,
      source: actor,
    );
    final stored = await _repo.createHourlyRate(rate);
    return stored.when(
      success: (r) async {
        await _repo.logEvent(SgEventJournalEntry(
          id: _eventIdGenerator(),
          at: now,
          actor: actor,
          action: 'hourly_rate.set',
          target: 'employee:$employeeId',
          payload: {
            'rate_cents': rateCents,
            if (role != null) 'role': role.name,
            'valid_from': from.toIso8601String(),
            if (current != null) 'closed_previous_rate_id': current.id,
          },
          reason: reason,
        ));
        return Success<SgHourlyRate, SgFailure>(r);
      },
      failure: (e) async => Failure<SgHourlyRate, SgFailure>(e),
    );
  }
}
