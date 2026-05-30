import '../entities/sg_event_journal_entry.dart';
import '../entities/sg_staff_consumption.dart';
import '../failures.dart';
import '../ports/sg_broc_repository_port.dart';
import '../ports/sg_clock_port.dart';
import '../result.dart';

/// Enregistre une consommation au bar par un membre du staff.
/// Si [menuItemId] fourni, le prix est auto-déduit depuis le SgMenuItem
/// (sinon utiliser amountCents libre).
class RecordStaffConsumptionUseCase {
  final SgBrocRepositoryPort _repo;
  final SgClockPort _clock;
  final String Function() _idGenerator;
  final String Function() _eventIdGenerator;

  const RecordStaffConsumptionUseCase({
    required SgBrocRepositoryPort repository,
    required SgClockPort clock,
    required String Function() idGenerator,
    required String Function() eventIdGenerator,
  })  : _repo = repository,
        _clock = clock,
        _idGenerator = idGenerator,
        _eventIdGenerator = eventIdGenerator;

  Future<Result<SgStaffConsumption, SgFailure>> call({
    required String employeeId,
    required String label,
    int? amountCents,
    String? menuItemId,
    String? shiftId,
    bool paid = false,
    String? note,
    String actor = 'system',
  }) async {
    if (label.trim().isEmpty) {
      return const Failure(SgValidationFailure('label required'));
    }
    int finalAmount = amountCents ?? 0;
    if (finalAmount <= 0) {
      return const Failure(SgValidationFailure('amount_cents must be > 0'));
    }

    final emp = await _repo.getEmployee(employeeId);
    if (emp.valueOrNull == null) {
      return Failure(SgNotFoundFailure('Employee $employeeId not found'));
    }

    final now = _clock.now();
    String? finalShiftId = shiftId;
    if (finalShiftId == null) {
      final active = await _repo.getActiveShiftForEmployee(employeeId);
      finalShiftId = active.valueOrNull?.id;
    }

    final consumption = SgStaffConsumption(
      id: 'sc-${_idGenerator()}',
      employeeId: employeeId,
      shiftId: finalShiftId,
      menuItemId: menuItemId,
      label: label.trim(),
      amountCents: finalAmount,
      consumedAt: now,
      paid: paid,
      note: note,
    );
    final stored = await _repo.createStaffConsumption(consumption);
    return stored.when(
      success: (c) async {
        await _repo.logEvent(SgEventJournalEntry(
          id: _eventIdGenerator(),
          at: now,
          actor: actor,
          action: 'staff_consumption.recorded',
          target: 'employee:$employeeId',
          payload: {
            'label': label,
            'amount_cents': finalAmount,
            if (menuItemId != null) 'menu_item_id': menuItemId,
            if (finalShiftId != null) 'shift_id': finalShiftId,
            'paid': paid,
          },
        ));
        return Success<SgStaffConsumption, SgFailure>(c);
      },
      failure: (e) async => Failure<SgStaffConsumption, SgFailure>(e),
    );
  }
}
