import 'dart:typed_data';

import '../entities/sg_menu_card.dart';
import '../failures.dart';
import '../result.dart';

/// Port pour générer un PDF imprimable depuis une `SgMenuCard`.
///
/// Adapters :
/// - `PdfDartMenuRenderer` (package `pdf`, server-side, v1)
/// - `ChromiumHtmlMenuRenderer` (HTML→PDF, plus riche, v2)
abstract interface class SgPdfRendererPort {
  /// Identifiant moteur (ex `"pdf-dart-2.4"`).
  String get engineId;

  /// Génère les bytes du PDF. Retourne un Result conformément SG.
  Future<Result<Uint8List, SgFailure>> render(SgMenuCard card);
}
