import '../entities/sg_break.dart';
import '../entities/sg_cooking_task.dart';
import '../entities/sg_employee.dart';
import '../entities/sg_event_journal_entry.dart';
import '../entities/sg_hourly_rate.dart';
import '../entities/sg_kiosk_session.dart';
import '../entities/sg_kitchen_ticket.dart';
import '../entities/sg_menu_card.dart';
import '../entities/sg_onboarding_checklist.dart';
import '../entities/sg_pdf_export.dart';
import '../entities/sg_question.dart';
import '../entities/sg_recipe.dart';
import '../entities/sg_shift.dart';
import '../entities/sg_shift_segment.dart';
import '../entities/sg_shopping_item.dart';
import '../entities/sg_shopping_list.dart';
import '../entities/sg_staff_consumption.dart';
import '../entities/sg_supplier.dart';
import '../failures.dart';
import '../result.dart';

/// Repository unifié Broccers. v0.1 : un seul port (simplicité).
/// v0.3 : splitter en Query/Command (ISP).
abstract interface class SgBrocRepositoryPort {
  // ============== Employees ==============
  Future<Result<SgEmployee, SgFailure>> createEmployee(SgEmployee e);
  Future<Result<SgEmployee, SgFailure>> updateEmployee(SgEmployee e);
  Future<Result<SgEmployee?, SgFailure>> getEmployee(String id);
  Future<Result<SgEmployee?, SgFailure>> getEmployeeByKioskName(String kioskName);
  Future<Result<List<SgEmployee>, SgFailure>> listEmployees({bool activeOnly = true});

  // ============== Shifts ==============
  Future<Result<SgShift, SgFailure>> createShift(SgShift s);
  Future<Result<SgShift, SgFailure>> updateShift(SgShift s);
  Future<Result<SgShift?, SgFailure>> getShift(String id);
  Future<Result<SgShift?, SgFailure>> getActiveShiftForEmployee(String employeeId);
  Future<Result<List<SgShift>, SgFailure>> listShifts({String? employeeId, DateTime? from, DateTime? to});

  // ============== Shift segments (Phase A — multi-rôles dynamique) ==============
  Future<Result<SgShiftSegment, SgFailure>> createSegment(SgShiftSegment seg);
  Future<Result<SgShiftSegment, SgFailure>> updateSegment(SgShiftSegment seg);
  Future<Result<SgShiftSegment?, SgFailure>> getActiveSegmentForShift(String shiftId);
  Future<Result<List<SgShiftSegment>, SgFailure>> listSegments(String shiftId);

  // ============== Breaks ==============
  Future<Result<SgBreak, SgFailure>> createBreak(SgBreak b);
  Future<Result<SgBreak, SgFailure>> updateBreak(SgBreak b);
  Future<Result<SgBreak?, SgFailure>> getActiveBreakForEmployee(String employeeId);
  Future<Result<List<SgBreak>, SgFailure>> listBreaksForShift(String shiftId);

  // ============== Menu cards / items / categories ==============
  Future<Result<SgMenuCard, SgFailure>> createMenuCard(SgMenuCard card);
  Future<Result<SgMenuCard, SgFailure>> updateMenuCard(SgMenuCard card);
  Future<Result<SgMenuCard?, SgFailure>> getMenuCard(String id);
  Future<Result<SgMenuCard?, SgFailure>> getCurrentPublishedMenuCard();
  Future<Result<List<SgMenuCard>, SgFailure>> listMenuCards({bool includeDrafts = false});
  Future<Result<int, SgFailure>> nextMenuCardVersion();

  // ============== PDF exports ==============
  Future<Result<void, SgFailure>> storePdfExport(SgPdfExport export);
  Future<Result<List<SgPdfExport>, SgFailure>> listPdfExports({String? cardId});

  // ============== Shopping ==============
  Future<Result<SgShoppingList, SgFailure>> createShoppingList(SgShoppingList l);
  Future<Result<SgShoppingList, SgFailure>> updateShoppingList(SgShoppingList l);
  Future<Result<SgShoppingList?, SgFailure>> getShoppingList(String id);
  Future<Result<List<SgShoppingList>, SgFailure>> listShoppingLists({bool openOnly = false});
  Future<Result<SgShoppingItem, SgFailure>> createShoppingItem(SgShoppingItem item);
  Future<Result<SgShoppingItem, SgFailure>> updateShoppingItem(SgShoppingItem item);
  Future<Result<SgShoppingItem?, SgFailure>> getShoppingItem(String id);
  Future<Result<List<SgShoppingItem>, SgFailure>> listShoppingItems({String? listId, bool? done});

  // ============== Suppliers ==============
  Future<Result<SgSupplier, SgFailure>> createSupplier(SgSupplier s);
  Future<Result<List<SgSupplier>, SgFailure>> listSuppliers();

  // ============== Questions ==============
  Future<Result<void, SgFailure>> storeQuestion(SgQuestion q);
  Future<Result<List<SgQuestion>, SgFailure>> listQuestions({int? limit});

  // ============== Kiosk sessions ==============
  Future<Result<SgKioskSession, SgFailure>> createKioskSession(SgKioskSession s);
  Future<Result<SgKioskSession?, SgFailure>> getActiveKioskSession(String deviceId);

  // ============== Event journal (Phase A — observability bienveillante) ==============
  Future<Result<void, SgFailure>> logEvent(SgEventJournalEntry e);
  Future<Result<List<SgEventJournalEntry>, SgFailure>> listEvents({
    String? actor,
    String? action,
    String? targetPrefix,
    DateTime? from,
    DateTime? to,
    int? limit,
  });

  // ============== Hourly rates (Phase B) ==============
  Future<Result<SgHourlyRate, SgFailure>> createHourlyRate(SgHourlyRate rate);
  Future<Result<SgHourlyRate, SgFailure>> updateHourlyRate(SgHourlyRate rate);
  Future<Result<SgHourlyRate?, SgFailure>> getActiveHourlyRate({
    required String employeeId,
    SgEmployeeRole? role,
    required DateTime at,
  });
  Future<Result<List<SgHourlyRate>, SgFailure>> listHourlyRates({String? employeeId});

  // ============== Staff consumption (Phase B) ==============
  Future<Result<SgStaffConsumption, SgFailure>> createStaffConsumption(SgStaffConsumption c);
  Future<Result<SgStaffConsumption, SgFailure>> updateStaffConsumption(SgStaffConsumption c);
  Future<Result<List<SgStaffConsumption>, SgFailure>> listStaffConsumptions({
    String? employeeId,
    String? shiftId,
    DateTime? from,
    DateTime? to,
    bool? paid,
  });

  // ============== Onboarding (Phase D) ==============
  Future<Result<SgOnboardingChecklist, SgFailure>> createOnboardingChecklist(SgOnboardingChecklist cl);
  Future<Result<SgOnboardingChecklist, SgFailure>> updateOnboardingChecklist(SgOnboardingChecklist cl);
  Future<Result<SgOnboardingChecklist?, SgFailure>> getOnboardingChecklist(String id);
  Future<Result<List<SgOnboardingChecklist>, SgFailure>> listOnboardingChecklists({String? employeeId});

  // ============== Kitchen tickets (Phase E1) ==============
  Future<Result<SgKitchenTicket, SgFailure>> createKitchenTicket(SgKitchenTicket t);
  Future<Result<SgKitchenTicket, SgFailure>> updateKitchenTicket(SgKitchenTicket t);
  Future<Result<SgKitchenTicket?, SgFailure>> getKitchenTicket(String id);
  Future<Result<List<SgKitchenTicket>, SgFailure>> listKitchenTickets({
    SgKitchenTicketStatus? status,
    DateTime? from,
    DateTime? to,
    int? limit,
  });
  Future<Result<SgKitchenTicketItem, SgFailure>> updateKitchenTicketItem(SgKitchenTicketItem item);

  // ============== Recipes (Phase E2) ==============
  Future<Result<SgRecipe, SgFailure>> createRecipe(SgRecipe r);
  Future<Result<SgRecipe, SgFailure>> updateRecipe(SgRecipe r);
  Future<Result<SgRecipe?, SgFailure>> getRecipe(String id);
  Future<Result<SgRecipe?, SgFailure>> getRecipeForMenuItem(String menuItemId);
  Future<Result<List<SgRecipe>, SgFailure>> listRecipes();

  // ============== Cooking tasks (Phase E2) ==============
  Future<Result<SgCookingTask, SgFailure>> createCookingTask(SgCookingTask t);
  Future<Result<SgCookingTask, SgFailure>> updateCookingTask(SgCookingTask t);
  Future<Result<SgCookingTask?, SgFailure>> getCookingTask(String id);
  Future<Result<List<SgCookingTask>, SgFailure>> listCookingTasks({
    String? ticketItemId,
    SgCookingTaskStatus? status,
    DateTime? from,
    DateTime? to,
  });
}
