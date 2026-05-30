import 'dart:convert';

import '../entities/sg_event_journal_entry.dart';
import '../entities/sg_question.dart';
import '../failures.dart';
import '../ports/sg_broc_repository_port.dart';
import '../ports/sg_clock_port.dart';
import '../ports/sg_question_port.dart';
import '../result.dart';

/// Génère un briefing matinal Claude pour la brasserie : planning du jour + carte + courses urgentes.
/// Stocké comme SgQuestion (pour historique journal).
class GenerateMorningBriefingUseCase {
  final SgBrocRepositoryPort _repo;
  final SgQuestionPort _engine;
  final SgClockPort _clock;
  final String Function() _idGenerator;
  final String Function() _eventIdGenerator;

  const GenerateMorningBriefingUseCase({
    required SgBrocRepositoryPort repository,
    required SgQuestionPort engine,
    required SgClockPort clock,
    required String Function() idGenerator,
    required String Function() eventIdGenerator,
  })  : _repo = repository,
        _engine = engine,
        _clock = clock,
        _idGenerator = idGenerator,
        _eventIdGenerator = eventIdGenerator;

  Future<Result<SgQuestion, SgFailure>> call({String actor = 'system'}) async {
    final now = _clock.now();
    final dayStart = DateTime(now.year, now.month, now.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    final empListRes = await _repo.listEmployees();
    final emps = empListRes.valueOrNull ?? const [];
    final shiftsRes = await _repo.listShifts(from: dayStart, to: dayEnd);
    final shifts = shiftsRes.valueOrNull ?? const [];
    final menuRes = await _repo.getCurrentPublishedMenuCard();
    final menu = menuRes.valueOrNull;
    final urgentShoppingRes = await _repo.listShoppingItems(done: false);
    final urgentShopping = (urgentShoppingRes.valueOrNull ?? const [])
        .where((i) => i.urgent).toList();

    final context = <String, dynamic>{
      'date': dayStart.toIso8601String(),
      'employees_count': emps.length,
      'shifts_today': shifts.map((s) => {
            'employee_id': s.employeeId,
            'employee_name':
                emps.where((e) => e.id == s.employeeId).map((e) => e.name).firstOrNull,
            'starts_at': s.startsAt.toIso8601String(),
            if (s.plannedEndsAt != null) 'planned_ends_at': s.plannedEndsAt!.toIso8601String(),
            'status': s.status.name,
          }).toList(),
      if (menu != null) 'current_menu_summary': {
        'name': menu.name,
        'version': menu.version,
        'item_count': menu.items.length,
        'items': menu.items.take(20).map((i) => {
          'name': i.name,
          'available': i.available,
        }).toList(),
      },
      'urgent_shopping': urgentShopping.map((s) => {
        'name': s.name,
        'quantity': s.quantity,
        'unit': s.unit,
      }).toList(),
    };

    final question =
        "Génère le briefing matinal pour l'équipe de la Brasserie Broc. "
        "Format : 5-7 phrases concises. Inclure les points clés du jour : "
        "qui est prévu, plats à mettre en avant, courses urgentes, et un mot d'encouragement. "
        "Pas de markdown, langage parlé direct.";

    final q0 = SgQuestion(
      id: 'brief-${_idGenerator()}',
      askedAt: now,
      question: question,
      contextSnapshot: {...context, 'kind': 'morning_briefing'},
      engine: _engine.engineId,
    );

    final answer = await _engine.ask(
      question: '$question\n\nCONTEXTE :\n${const JsonEncoder.withIndent("  ").convert(context)}',
      contextSnapshot: context,
    );
    return answer.when(
      success: (text) async {
        final q = q0.withAnswer(text: text, at: _clock.now());
        await _repo.storeQuestion(q);
        await _repo.logEvent(SgEventJournalEntry(
          id: _eventIdGenerator(),
          at: now,
          actor: actor,
          action: 'briefing.generated',
          target: 'date:${dayStart.toIso8601String().substring(0, 10)}',
          payload: {'question_id': q.id, 'shifts_today': shifts.length},
        ));
        return Success<SgQuestion, SgFailure>(q);
      },
      failure: (e) async {
        await _repo.storeQuestion(q0);
        return Failure<SgQuestion, SgFailure>(e);
      },
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
