import '../entities/sg_menu_card.dart';
import '../failures.dart';
import '../ports/sg_broc_repository_port.dart';
import '../ports/sg_clock_port.dart';
import '../result.dart';

/// Publier une carte : valide structure, incrémente version, set publishedAt.
class PublishMenuCardUseCase {
  final SgBrocRepositoryPort _repo;
  final SgClockPort _clock;

  const PublishMenuCardUseCase({
    required SgBrocRepositoryPort repository,
    required SgClockPort clock,
  })  : _repo = repository,
        _clock = clock;

  Future<Result<SgMenuCard, SgFailure>> call({required String cardId}) async {
    final get = await _repo.getMenuCard(cardId);
    final card = get.valueOrNull;
    if (card == null) {
      return get.when(
        success: (_) => Failure(SgNotFoundFailure('MenuCard $cardId not found')),
        failure: (e) => Failure<SgMenuCard, SgFailure>(e),
      );
    }
    if (card.name.trim().isEmpty) {
      return const Failure(SgValidationFailure('card name required'));
    }
    if (card.categories.isEmpty) {
      return const Failure(SgValidationFailure('card needs at least 1 category'));
    }
    if (card.items.isEmpty) {
      return const Failure(SgValidationFailure('card needs at least 1 item'));
    }

    final nextV = await _repo.nextMenuCardVersion();
    return nextV.when(
      success: (version) async {
        final published =
            card.copyWith(version: version, publishedAt: _clock.now());
        return _repo.updateMenuCard(published);
      },
      failure: (e) async => Failure<SgMenuCard, SgFailure>(e),
    );
  }
}
