import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';

class KwLabelData {
  final String lot;
  final String odmiana;
  final String data;               // dd.MM.yyyy — data z WSG (przyjęcia)
  final String dataDostarczenia;   // dd.MM.yyyy — data dostarczenia do Rylex/Grójecka
  final String dostawca;
  final String dostawcaKod;
  final String przeznaczenie;

  const KwLabelData({
    required this.lot,
    required this.odmiana,
    required this.data,
    this.dataDostarczenia = '',
    required this.dostawca,
    required this.dostawcaKod,
    required this.przeznaczenie,
  });
}

class KwLabelGenerator {
  static Future<Uint8List> generate(List<KwLabelData> labels) async {
    final doc   = pw.Document();
    final fontB = await PdfGoogleFonts.notoSansBold();
    final fontR = await PdfGoogleFonts.notoSansRegular();

    for (final d in labels) {
      final qrBytes = await _qrPngBytes(d.lot);
      final qrImage = pw.MemoryImage(qrBytes);

      doc.addPage(pw.Page(
        pageFormat: const PdfPageFormat(
          100 * PdfPageFormat.mm,
          100 * PdfPageFormat.mm,
        ),
        margin: pw.EdgeInsets.zero,
        build: (_) => _buildLabel(d, qrImage, fontB, fontR),
      ));
    }

    return doc.save();
  }

  static pw.Widget _buildLabel(
    KwLabelData d,
    pw.MemoryImage qrImage,
    pw.Font fontB,
    pw.Font fontR,
  ) {
    final sB10     = pw.TextStyle(font: fontB, fontSize: 10);
    final sB13     = pw.TextStyle(font: fontB, fontSize: 13);
    final sB22     = pw.TextStyle(font: fontB, fontSize: 22);
    final padding  = 5 * PdfPageFormat.mm;
    final border   = pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 0.5)));

    return pw.Container(
      color: PdfColors.white,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [

          // ── ODMIANA ──────────────────────────────────────────────────────────
          pw.Padding(
            padding: pw.EdgeInsets.fromLTRB(padding, padding, padding, 0),
            child: pw.Text(
              d.odmiana.isNotEmpty ? d.odmiana : '—',
              style: sB22,
              textAlign: pw.TextAlign.center,
            ),
          ),

          pw.SizedBox(height: 2 * PdfPageFormat.mm),

          // ── QR CODE (wyśrodkowany) ────────────────────────────────────────────
          pw.Expanded(
            child: pw.Center(
              child: pw.SizedBox(
                width: 70 * PdfPageFormat.mm,
                height: 70 * PdfPageFormat.mm,
                child: pw.Image(qrImage, fit: pw.BoxFit.contain),
              ),
            ),
          ),

          pw.SizedBox(height: 2 * PdfPageFormat.mm),

          // ── LOT (lewo, opcjonalnie z datą dostarczenia) + DATA WSG (prawo) ──────
          pw.Container(
            decoration: border,
            padding: pw.EdgeInsets.symmetric(horizontal: padding, vertical: 2 * PdfPageFormat.mm),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  d.dataDostarczenia.isNotEmpty
                      ? '${d.lot} - ${d.dataDostarczenia}'
                      : d.lot,
                  style: sB13,
                ),
                pw.Text(d.data, style: sB13),
              ],
            ),
          ),

          // ── DOSTAWCA ─────────────────────────────────────────────────────────
          pw.Container(
            decoration: border,
            padding: pw.EdgeInsets.symmetric(horizontal: padding, vertical: 2 * PdfPageFormat.mm),
            child: pw.Text(
              '${d.dostawcaKod} — ${d.dostawca}',
              style: pw.TextStyle(font: fontB, fontSize: 11),
              textAlign: pw.TextAlign.center,
            ),
          ),

          // ── PRZEZNACZENIE ─────────────────────────────────────────────────────
          pw.Container(
            decoration: border,
            padding: pw.EdgeInsets.fromLTRB(padding, 2 * PdfPageFormat.mm, padding, padding),
            child: pw.Text(
              'Przeznaczenie: ${d.przeznaczenie}',
              style: sB10,
              textAlign: pw.TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  static Future<Uint8List> _qrPngBytes(String data) async {
    final painter = QrPainter(
      data: data.isNotEmpty ? data : 'N/A',
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
      color: const Color(0xFF000000),
      emptyColor: const Color(0xFFFFFFFF),
    );
    final img      = await painter.toImage(500);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }
}
