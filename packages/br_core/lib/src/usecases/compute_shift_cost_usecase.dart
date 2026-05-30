import '../entities/sg_employee.dart';
import '../entities/sg_hourly_rate.dart';
import '../entities/sg_shift_segment.dart';
import '../failures.dart';
import '../ports/sg_broc_repository_port.dart';
import '../ports/sg_clock_port.dart';
import '../result.dart';

/// Calcule le coût main d'œuvre d'un shift (somme des segments × tarif horaire correspondant).
class ComputeShiftCostUseCase {
  final SgBrocRepositoryPort _repo;
  final SgClockPort _clock;

  const ComputeShiftCostUseCase({
    required SgBrocRepositoryPort repository,
    required SgClockPort clock,
  })  : _repo = repository,
        _clock = clock;

  Future<Result<ShiftCostBreakdown, SgFailure>> call({required String shiftId}) async {
    final shiftResult = await _repo.getShift(shiftId);
    final shift = shiftResult.valueOrNull;
    if (shift == null) {
      return Failure(SgNotFoundFailure('Shift $shiftId not found'));
    }

    final segResult = await _repo.listSegments(shiftId);
    final segments = segResult.valueOrNull ?? const <SgShiftSegment>[];

    final now = _clock.now();
    final lines = <ShiftCostLine>[];
    int totalCents = 0;
    for (final seg in segments) {
      final start = seg.startedAt;
      final end = seg.endedAt ?? now;
      final duration = end.difference(start);
      final rateRes = await _repo.getActiveHourlyRate(
        employeeId: shift.employeeId,
        role: seg.role,
        at: start,
      );
      var rate = rateRes.valueOrNull;
      if (rate == null) {
        final fallbackRes = await _repo.getActiveHourlyRate(
          employeeId: shift.employeeId,
          role: null,
          at: start,
        );
        rate = fallbackRes.valueOrNull;
      }
      final rateCents = rate?.rateCents ?? 0;
      final segCents = (rateCents * duration.inSeconds / 3600).round();
      totalCents += segCents;
      lines.add(ShiftCostLine(
        segmentId: seg.id,
        role: seg.role,
        startedAt: start,
        endedAt: end,
        duration: duration,
        rateUsed: rate,
        costCents: segCents,
      ));
    }

    return Success(ShiftCostBreakdown(
      shiftId: shiftId,
      employeeId: shift.employeeId,
      totalCents: totalCents,
      lines: lines,
    ));
  }
}

class ShiftCostBreakdown {
  final String shiftId;
  final String employeeId;
  final int totalCents;
  final List<ShiftCostLine> lines;

  const ShiftCostBreakdown({
    required this.shiftId,
    required this.employeeId,
    required this.totalCents,
    required this.lines,
  });

  Map<String, dynamic> toJson() => {
        'shift_id': shiftId,
        'employee_id': employeeId,
        'total_cents': totalCents,
        'total_formatted': _fmt(totalCents),
        'lines': lines.map((l) => l.toJson()).toList(),
      };

  static String _fmt(int cents) {
    final euros = cents ~/ 100;
    final c = cents % 100;
    return c == 0 ? '$euros €' : '$euros,${c.toString().padLeft(2, '0')} €';
  }
}

class ShiftCostLine {
  final String segmentId;
  final SgEmployeeRole role;
  final DateTime startedAt;
  final DateTime endedAt;
  final Duration duration;
  final SgHourlyRate? rateUsed;
  final int costCents;

  const ShiftCostLine({
    required this.segmentId,
    required this.role,
    required this.startedAt,
    required this.endedAt,
    required this.duration,
    required this.rateUsed,
    required this.costCents,
  });

  Map<String, dynamic> toJson() => {
        'segment_id': segmentId,
        'role': role.name,
        'started_at': startedAt.toIso8601String(),
        'ended_at': endedAt.toIso8601String(),
        'duration_minutes': duration.inMinutes,
        if (rateUsed != null) 'rate_cents': rateUsed!.rateCents,
        'cost_cents': costCents,
      };
}
