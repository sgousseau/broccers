import '../entities/sg_shopping_item.dart';
import '../failures.dart';
import '../ports/sg_broc_repository_port.dart';
import '../ports/sg_clock_port.dart';
import '../result.dart';

/// Ajouter un item à une liste de courses ouverte.
class AddShoppingItemUseCase {
  final SgBrocRepositoryPort _repo;
  final SgClockPort _clock;
  final String Function() _idGenerator;

  const AddShoppingItemUseCase({
    required SgBrocRepositoryPort repository,
    required SgClockPort clock,
    required String Function() idGenerator,
  })  : _repo = repository,
        _clock = clock,
        _idGenerator = idGenerator;

  Future<Result<SgShoppingItem, SgFailure>> call({
    required String listId,
    required String name,
    required double quantity,
    required String unit,
    String? supplierId,
    bool urgent = false,
  }) async {
    if (name.trim().isEmpty) {
      return const Failure(SgValidationFailure('name required'));
    }
    if (quantity <= 0) {
      return const Failure(SgValidationFailure('quantity must be > 0'));
    }
    final list = await _repo.getShoppingList(listId);
    final l = list.valueOrNull;
    if (l == null) {
      return list.when(
        success: (_) => Failure(SgNotFoundFailure('ShoppingList $listId not found')),
        failure: (e) => Failure<SgShoppingItem, SgFailure>(e),
      );
    }
    final item = SgShoppingItem(
      id: _idGenerator(),
      listId: listId,
      supplierId: supplierId,
      name: name.trim(),
      quantity: quantity,
      unit: unit,
      urgent: urgent,
      createdAt: _clock.now(),
    );
    return _repo.createShoppingItem(item);
  }
}
