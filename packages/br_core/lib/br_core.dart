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
export 'src/entities/sg_break.dart';

// === Entities — Menu ===
export 'src/entities/sg_menu_card.dart';
export 'src/entities/sg_menu_item.dart';
export 'src/entities/sg_menu_category.dart';
export 'src/entities/sg_allergen.dart';
export 'src/entities/sg_pdf_export.dart';

// === Entities — Courses ===
export 'src/entities/sg_shopping_list.dart';
export 'src/entities/sg_shopping_item.dart';
export 'src/entities/sg_supplier.dart';

// === Entities — Question + Kiosk ===
export 'src/entities/sg_question.dart';
export 'src/entities/sg_kiosk_session.dart';

// === Ports ===
export 'src/ports/sg_broc_repository_port.dart';
export 'src/ports/sg_pdf_renderer_port.dart';
export 'src/ports/sg_question_port.dart';
export 'src/ports/sg_clock_port.dart';

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
