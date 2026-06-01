# Changelog — br_core

## [0.6.0] — 2026-06-01 — Phase F
### Added — Pilotage économique
- `SgSetting` + `SgSettingDefinition` + `SgSettingCategory` + `SgBrocSettingsRegistry` — paramètres globaux versionnés (seuils marges évolutifs, pauses légales, charges, vocal).
- `SgIngredient` + `SgIngredientUnit` (g/kg/ml/L/pcs/dz avec conversions) — référentiel matière avec prix moyen courant + fournisseur.
- `SgRecipeIngredient` — lien recette → ingrédient avec quantité, unité, flag `isSubstitution` + reason pour traçabilité.
- `SgMenuItemCostBreakdown` + `SgIngredientCostLine` — calcul coût matière + marge avec code couleur paramétrable.
- `SgFoodWaste` + `SgWasteReason` + `SgWasteKind` — tracker gaspillage avec auto-estimation valeur (observability bienveillante).
- `SgTable` — table physique avec QR secret unique pour consultation publique de la carte.
- `SgMenuItem.unavailableReason` — raison de mise en rupture (Mode 86).

### Added — UseCases
- `SetSettingUseCase` — validation type/bornes/enum + permission manager-only + audit log.
- `ComputeMenuItemCostUseCase` — agrège coût ingrédients d'une recette → breakdown complet.
- `DeclareFoodWasteUseCase` — auto-estimation valeur depuis l'ingrédient référencé.
- `ToggleMenuItemAvailabilityUseCase` — Mode 86 avec raison + audit log.
- `CreateTableUseCase` — création table avec génération QR secret.

### Added — Port
- 18 nouvelles méthodes sur `SgBrocRepositoryPort` : settings / ingredients / recipe_ingredients / food_waste / tables.

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
