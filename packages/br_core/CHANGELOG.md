# Changelog — br_core

## [0.1.0] — 2026-05-30
### Added
- Pure-Dart Result<T,E> + SgFailure hierarchy (API-compatible with sg_core; MIGRATE LATER).
- Broc-specific failures : SgBrocAuthFailure, SgBrocPdfFailure, SgBrocQuestionFailure, SgBrocComplianceFailure, SgBrocKioskFailure.
- Entities personnel : SgEmployee, SgEmployeeRole, SgShift, SgShiftStatus, SgBreak, SgBreakType.
- Entities menu : SgMenuCard, SgMenuItem, SgMenuCategory, SgAllergen.
- Entities courses : SgShoppingList, SgShoppingItem, SgSupplier.
- Entities IA + kiosk : SgQuestion, SgKioskSession.
- Entity dérivation : SgPdfExport (lineage Source/Derivation).
- Ports : SgBrocRepositoryPort, SgPdfRendererPort, SgQuestionPort, SgClockPort.
- UseCases : ClockIn/Out, StartBreak/EndBreak, PublishMenuCard, ExportMenuCardPdf, AddShoppingItem, CheckShoppingItem, AskQuestion.
