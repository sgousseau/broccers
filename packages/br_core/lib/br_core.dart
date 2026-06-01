/// br_core — Broccers Domain layer (pure Dart, zero Flutter).
///
/// Clean Architecture domain : entities + ports + usecases + failures.
/// Tous les types publics sont préfixés `Sg` ou `Br` conformément SG conventions.
///
/// Migration plan : Result<T,E> et SgFailure seront remplacés par sg_core
/// dès que sg_core aura une variante pure-Dart.
library br_core;

// === Foundation (MIGRATE LATER to sg_core when pure-Dart) ===
export 'src/result.dart';
export 'src/failures.dart';

// === Entities — Personnel ===
export 'src/entities/sg_employee.dart';
export 'src/entities/sg_shift.dart';
export 'src/entities/sg_shift_segment.dart';
export 'src/entities/sg_break.dart';

// === Entities — Menu ===
export 'src/entities/sg_menu_card.dart';
export 'src/entities/sg_menu_card_kind.dart';
export 'src/entities/sg_menu_item.dart';
export 'src/entities/sg_menu_category.dart';
export 'src/entities/sg_allergen.dart';
export 'src/entities/sg_pdf_export.dart';

// === Entities — Courses ===
export 'src/entities/sg_shopping_list.dart';
export 'src/entities/sg_shopping_item.dart';
export 'src/entities/sg_supplier.dart';

// === Entities — Question + Kiosk + Journal ===
export 'src/entities/sg_question.dart';
export 'src/entities/sg_kiosk_session.dart';
export 'src/entities/sg_event_journal_entry.dart';

// === Entities — Phase B (taux horaires + conso staff) ===
export 'src/entities/sg_hourly_rate.dart';
export 'src/entities/sg_staff_consumption.dart';

// === Entities — Phase D (onboarding) ===
export 'src/entities/sg_onboarding_checklist.dart';

// === Entities — Phase E (kitchen tickets + recipes + cooking tasks) ===
export 'src/entities/sg_kitchen_ticket.dart';
export 'src/entities/sg_recipe.dart';
export 'src/entities/sg_cooking_task.dart';

// === Entities — Phase F (settings + ingredients + waste + tables) ===
export 'src/entities/sg_setting.dart';
export 'src/entities/sg_ingredient.dart';
export 'src/entities/sg_food_waste.dart';
export 'src/entities/sg_table.dart';

// === Entities — Phase H (feature flags + portabilité) ===
export 'src/entities/sg_feature_flag.dart';

// === Ports ===
export 'src/ports/sg_broc_repository_port.dart';
export 'src/ports/sg_pdf_renderer_port.dart';
export 'src/ports/sg_question_port.dart';
export 'src/ports/sg_clock_port.dart';
export 'src/ports/sg_voice_parser_port.dart';

// === UseCases ===
export 'src/usecases/clock_in_usecase.dart';
export 'src/usecases/clock_out_usecase.dart';
export 'src/usecases/start_break_usecase.dart';
export 'src/usecases/end_break_usecase.dart';
export 'src/usecases/publish_menu_card_usecase.dart';
export 'src/usecases/export_menu_card_pdf_usecase.dart';
export 'src/usecases/add_shopping_item_usecase.dart';
export 'src/usecases/check_shopping_item_usecase.dart';
export 'src/usecases/ask_question_usecase.dart';
export 'src/usecases/change_role_in_shift_usecase.dart';
export 'src/usecases/set_weekly_default_usecase.dart';
export 'src/usecases/set_employee_roles_usecase.dart';
export 'src/usecases/set_hourly_rate_usecase.dart';
export 'src/usecases/record_staff_consumption_usecase.dart';
export 'src/usecases/compute_shift_cost_usecase.dart';
export 'src/usecases/archive_employee_usecase.dart';
export 'src/usecases/record_shift_tip_usecase.dart';
export 'src/usecases/generate_morning_briefing_usecase.dart';
export 'src/usecases/generate_onboarding_checklist_usecase.dart';
export 'src/usecases/check_onboarding_item_usecase.dart';
export 'src/usecases/parse_voice_order_usecase.dart';
export 'src/usecases/send_ticket_to_kitchen_usecase.dart';
export 'src/usecases/cooking_task_lifecycle_usecase.dart';
export 'src/usecases/phase_f_usecases.dart';
