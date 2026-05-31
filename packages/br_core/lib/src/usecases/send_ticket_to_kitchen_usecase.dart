import '../entities/sg_event_journal_entry.dart';
import '../entities/sg_kitchen_ticket.dart';
import '../entities/sg_recipe.dart';
import '../entities/sg_cooking_task.dart';
import '../failures.dart';
import '../ports/sg_broc_repository_port.dart';
import '../ports/sg_clock_port.dart';
import '../result.dart';

/// Envoie un ticket en cuisine. Génère les SgCookingTasks depuis les recettes.
class SendTicketToKitchenUseCase {
  final SgBrocRepositoryPort _repo;
  final SgClockPort _clock;
  final String Function() _taskIdGenerator;
  final String Function() _eventIdGenerator;

  const SendTicketToKitchenUseCase({
    required SgBrocRepositoryPort repository,
    required SgClockPort clock,
    required String Function() taskIdGenerator,
    required String Function() eventIdGenerator,
  })  : _repo = repository,
        _clock = clock,
        _taskIdGenerator = taskIdGenerator,
        _eventIdGenerator = eventIdGenerator;

  Future<Result<SgKitchenTicket, SgFailure>> call({
    required String ticketId,
    String actor = 'server',
  }) async {
    final ticketRes = await _repo.getKitchenTicket(ticketId);
    final ticket = ticketRes.valueOrNull;
    if (ticket == null) {
      return Failure(SgNotFoundFailure('Ticket $ticketId not found'));
    }
    if (ticket.status != SgKitchenTicketStatus.voiceDraft) {
      return Failure(SgBrocStateFailure(
        'Ticket $ticketId not in voiceDraft state (current: ${ticket.status.name})',
      ));
    }

    final now = _clock.now();
    final sent = ticket.sendToKitchen(at: now);
    final updated = await _repo.updateKitchenTicket(sent);
    if (updated.isFailure) {
      return Failure<SgKitchenTicket, SgFailure>(updated.errorOrNull!);
    }

    // Generate cooking tasks from recipes
    int totalTasks = 0;
    for (final item in ticket.items) {
      SgRecipe? recipe;
      if (item.menuItemId != null) {
        final recipeRes = await _repo.getRecipeForMenuItem(item.menuItemId!);
        recipe = recipeRes.valueOrNull;
      }
      if (recipe != null) {
        for (final step in recipe.steps) {
          final task = SgCookingTask(
            id: 'ct-${_taskIdGenerator()}',
            ticketItemId: item.id,
            recipeStepId: step.id,
            label: '${step.label} — ${item.label}',
            status: SgCookingTaskStatus.pending,
            expectedDuration: step.expectedDuration,
            sortOrder: step.sortOrder,
          );
          await _repo.createCookingTask(task);
          totalTasks++;
        }
      } else {
        // No recipe : create a single generic "Préparer" task
        final task = SgCookingTask(
          id: 'ct-${_taskIdGenerator()}',
          ticketItemId: item.id,
          label: 'Préparer ${item.label}',
          status: SgCookingTaskStatus.pending,
          expectedDuration: const Duration(minutes: 10),
          sortOrder: 0,
        );
        await _repo.createCookingTask(task);
        totalTasks++;
      }
    }

    await _repo.logEvent(SgEventJournalEntry(
      id: _eventIdGenerator(),
      at: now,
      actor: actor,
      action: 'ticket.sent_to_kitchen',
      target: 'ticket:${ticket.id}',
      payload: {
        'items_count': ticket.items.length,
        'cooking_tasks_count': totalTasks,
        'table': ticket.tableNumber,
      },
    ));

    return Success(sent);
  }
}
