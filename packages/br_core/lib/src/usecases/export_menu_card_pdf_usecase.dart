import '../entities/sg_pdf_export.dart';
import '../failures.dart';
import '../ports/sg_broc_repository_port.dart';
import '../ports/sg_clock_port.dart';
import '../ports/sg_pdf_renderer_port.dart';
import '../result.dart';

/// Exporte une `SgMenuCard` en PDF imprimable.
/// Délègue la persistance des bytes au caller (qui doit appeler `_repo.storePdfExport`
/// après avoir écrit sur disque). Retourne les bytes + un `SgPdfExport` non encore persisté.
class ExportMenuCardPdfUseCase {
  final SgBrocRepositoryPort _repo;
  final SgPdfRendererPort _pdf;
  final SgClockPort _clock;
  final String Function() _idGenerator;

  const ExportMenuCardPdfUseCase({
    required SgBrocRepositoryPort repository,
    required SgPdfRendererPort pdfRenderer,
    required SgClockPort clock,
    required String Function() idGenerator,
  })  : _repo = repository,
        _pdf = pdfRenderer,
        _clock = clock,
        _idGenerator = idGenerator;

  Future<Result<MenuCardPdfBytes, SgFailure>> call({required String cardId}) async {
    final get = await _repo.getMenuCard(cardId);
    final card = get.valueOrNull;
    if (card == null) {
      return get.when(
        success: (_) => Failure(SgNotFoundFailure('MenuCard $cardId not found')),
        failure: (e) => Failure<MenuCardPdfBytes, SgFailure>(e),
      );
    }
    final render = await _pdf.render(card);
    return render.when(
      success: (bytes) => Success(MenuCardPdfBytes(
        bytes: bytes,
        export: SgPdfExport(
          id: _idGenerator(),
          cardId: card.id,
          cardVersion: card.version,
          renderedAt: _clock.now(),
          filePath: '',
          byteSize: bytes.length,
          engine: _pdf.engineId,
        ),
      )),
      failure: (e) => Failure<MenuCardPdfBytes, SgFailure>(e),
    );
  }
}

class MenuCardPdfBytes {
  final List<int> bytes;
  final SgPdfExport export;
  const MenuCardPdfBytes({required this.bytes, required this.export});
}
