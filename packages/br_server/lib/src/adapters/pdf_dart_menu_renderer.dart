import 'dart:typed_data';

import 'package:br_core/br_core.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Adapter PDF dart-natif pour `SgPdfRendererPort`. Layout A4 imprimable simple.
class PdfDartMenuRenderer implements SgPdfRendererPort {
  final String _engineVersion;

  const PdfDartMenuRenderer({String engineVersion = '3.11'})
      : _engineVersion = engineVersion;

  @override
  String get engineId => 'pdf-dart-$_engineVersion';

  @override
  Future<Result<Uint8List, SgFailure>> render(SgMenuCard card) async {
    try {
      final doc = pw.Document();
      final grouped = card.groupedByCategory();
      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 32, 40, 32),
        header: (ctx) => _header(card),
        footer: (ctx) => _footer(card, ctx),
        build: (ctx) {
          final widgets = <pw.Widget>[];
          grouped.forEach((cat, items) {
            widgets.add(pw.SizedBox(height: 8));
            widgets.add(_categoryTitle(cat.name));
            widgets.add(pw.Divider(thickness: 0.8));
            widgets.add(pw.SizedBox(height: 6));
            for (final it in items.where((i) => i.available)) {
              widgets.add(_menuItem(it));
              widgets.add(pw.SizedBox(height: 8));
            }
          });
          return widgets;
        },
      ));
      final bytes = await doc.save();
      return Success(bytes);
    } catch (e) {
      return Failure(SgBrocPdfFailure('PDF render failed', cause: e));
    }
  }

  pw.Widget _header(SgMenuCard card) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text('BRASSERIE BROC',
            style: pw.TextStyle(
                fontSize: 24, fontWeight: pw.FontWeight.bold, letterSpacing: 2)),
        pw.SizedBox(height: 2),
        pw.Text('Puces du Canal — Villeurbanne',
            style: pw.TextStyle(
                fontSize: 11, fontStyle: pw.FontStyle.italic)),
        pw.SizedBox(height: 4),
        pw.Text(card.name,
            style: pw.TextStyle(
                fontSize: 13, fontStyle: pw.FontStyle.italic)),
        pw.SizedBox(height: 8),
      ],
    );
  }

  pw.Widget _footer(SgMenuCard card, pw.Context ctx) {
    final now = DateTime.now();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Divider(thickness: 0.4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Prix nets, service compris. Allergènes sur demande.',
                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
            pw.Text(
              'Carte v${card.version} — ${_dateFr(now)} — page ${ctx.pageNumber}/${ctx.pagesCount}',
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _categoryTitle(String name) => pw.Text(
        name.toUpperCase(),
        style: pw.TextStyle(
            fontSize: 14, fontWeight: pw.FontWeight.bold, letterSpacing: 1.2),
      );

  pw.Widget _menuItem(SgMenuItem it) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(
              child: pw.Text(it.name,
                  style:
                      pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Text(it.formattedPrice(),
                style:
                    pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          ],
        ),
        if (it.description != null && it.description!.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 2),
            child: pw.Text(it.description!,
                style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700)),
          ),
        if (it.allergens.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 2),
            child: pw.Text(
              it.allergens.map((a) => a.label).join(' · '),
              style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
            ),
          ),
      ],
    );
  }

  String _dateFr(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mn = d.minute.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year} ${hh}h$mn';
  }
}
