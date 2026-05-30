import '../entities/sg_shopping_item.dart';
import '../failures.dart';
import '../ports/sg_broc_repository_port.dart';
import '../ports/sg_clock_port.dart';
import '../result.dart';

/// Toggle done / un-done d'un item.
class CheckShoppingItemUseCase {
  final SgBrocRepositoryPort _repo;
  final SgClockPort _clock;

  const CheckShoppingItemUseCase({
    required SgBrocRepositoryPort repository,
    required SgClockPort clock,
  })  : _repo = repository,
        _clock = clock;

  Future<Result<SgShoppingItem, SgFailure>> call({
    required String itemId,
    required bool done,
  }) async {
    final get = await _repo.getShoppingItem(itemId);
    final item = get.valueOrNull;
    if (item == null) {
      return get.when(
        success: (_) =>
            Failure(SgNotFoundFailure('ShoppingItem $itemId not found')),
        failure: (e) => Failure<SgShoppingItem, SgFailure>(e),
      );
    }
    final updated = done ? item.check(at: _clock.now()) : item.uncheck();
    return _repo.updateShoppingItem(updated);
  }
}
