import 'dart:convert';

import '../entities/sg_employee.dart';
import '../entities/sg_event_journal_entry.dart';
import '../entities/sg_onboarding_checklist.dart';
import '../failures.dart';
import '../ports/sg_broc_repository_port.dart';
import '../ports/sg_clock_port.dart';
import '../ports/sg_question_port.dart';
import '../result.dart';

/// Génère une checklist d'onboarding pour un nouvel employé sur un rôle donné, via Claude.
class GenerateOnboardingChecklistUseCase {
  final SgBrocRepositoryPort _repo;
  final SgQuestionPort _engine;
  final SgClockPort _clock;
  final String Function() _idGenerator;
  final String Function() _eventIdGenerator;

  const GenerateOnboardingChecklistUseCase({
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

  Future<Result<SgOnboardingChecklist, SgFailure>> call({
    required String employeeId,
    required SgEmployeeRole role,
    String actor = 'manager',
  }) async {
    final empRes = await _repo.getEmployee(employeeId);
    final emp = empRes.valueOrNull;
    if (emp == null) {
      return Failure(SgNotFoundFailure('Employee $employeeId not found'));
    }
    if (!emp.canHold(role)) {
      return Failure(SgBrocStateFailure(
        '${emp.name} cannot hold role ${role.label} — not in their capabilities',
      ));
    }

    final question = '''
Tu es responsable formation pour la Brasserie Broc (Villeurbanne, Puces du Canal).
Un nouvel employé débute aujourd'hui au poste de **${role.label}**.
Génère une checklist d'onboarding pratique (10-15 items max) qu'il doit cocher pendant ses premiers shifts.

Format STRICT : JSON sur une seule ligne, schéma :
{"items":["item 1 court","item 2 court", ...]}

Règles :
- Items concrets et actionables (pas vagues).
- Spécifiques au rôle ${role.label} en brasserie française.
- Inclure la sécurité, l'hygiène, les procédures internes, le matériel.
- Pas de markdown, pas de backticks, JUSTE le JSON.
''';

    final answer = await _engine.ask(
      question: question,
      contextSnapshot: {
        'kind': 'onboarding',
        'employee_id': employeeId,
        'employee_name': emp.name,
        'role': role.name,
      },
    );

    return answer.when(
      success: (text) async {
        final jsonStr = _extractJson(text);
        List<String> items;
        try {
          final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
          items = ((parsed['items'] as List<dynamic>?) ?? const [])
              .cast<String>();
        } catch (e) {
          return Failure(SgBrocStateFailure('Claude response not parseable JSON: $e'));
        }
        if (items.isEmpty) {
          return const Failure(SgBrocStateFailure('Empty onboarding checklist generated'));
        }
        final checklist = SgOnboardingChecklist(
          id: 'onb-${_idGenerator()}',
          employeeId: employeeId,
          role: role,
          items: items.map((l) => SgOnboardingItem(label: l)).toList(),
          createdAt: _clock.now(),
          engine: _engine.engineId,
        );
        final stored = await _repo.createOnboardingChecklist(checklist);
        return stored.when(
          success: (c) async {
            await _repo.logEvent(SgEventJournalEntry(
              id: _eventIdGenerator(),
              at: _clock.now(),
              actor: actor,
              action: 'onboarding.generated',
              target: 'employee:$employeeId',
              payload: {'role': role.name, 'items_count': c.items.length, 'checklist_id': c.id},
            ));
            return Success<SgOnboardingChecklist, SgFailure>(c);
          },
          failure: (e) async => Failure<SgOnboardingChecklist, SgFailure>(e),
        );
      },
      failure: (e) async => Failure<SgOnboardingChecklist, SgFailure>(e),
    );
  }

  String _extractJson(String s) {
    final start = s.indexOf('{');
    final end = s.lastIndexOf('}');
    if (start < 0 || end <= start) return '{}';
    return s.substring(start, end + 1);
  }
}
