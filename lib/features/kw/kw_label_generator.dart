import 'dart:math' as math;
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
  final String data;        // dd.MM.yyyy
  final String dostawca;
  final String dostawcaKod;
  final String przeznaczenie;

  const KwLabelData({
    required this.lot,
    required this.odmiana,
    required this.data,
    required this.dostawca,
    required this.dostawcaKod,
    required this.przeznaczenie,
  });
}

class KwLabelGenerator {
  /// Generuje PDF z etykietami — jedna strona 100×100mm na każdą etykietę.
  static Future<Uint8List> generate(List<KwLabelData> labels) async {
    final doc  = pw.Document();
    final fontB = await PdfGoogleFonts.notoSansBold();

    for (final d in labels) {
      final qrBytes = await _qrPngBytes(d.lot);
      final qrImage = pw.MemoryImage(qrBytes);

      doc.addPage(pw.Page(
        pageFormat: const PdfPageFormat(
          100 * PdfPageFormat.mm,
          100 * PdfPageFormat.mm,
        ),
        margin: const pw.EdgeInsets.all(5 * PdfPageFormat.mm),
        build: (_) => _buildLabel(d, qrImage, fontB),
      ));
    }

    return doc.save();
  }

  static pw.Widget _buildLabel(
    KwLabelData d,
    pw.MemoryImage qrImage,
    pw.Font fontB,
  ) {
    final sB7  = pw.TextStyle(font: fontB, fontSize: 7);
    final sB12 = pw.TextStyle(font: fontB, fontSize: 12);
    final sB16 = pw.TextStyle(font: fontB, fontSize: 16);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        // ── Odmiana ──────────────────────────────────────────────────────────
        pw.Text(
          d.odmiana.isNotEmpty ? d.odmiana : '—',
          style: sB16,
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 3),

        // ── QR + boczne napisy ────────────────────────────────────────────────
        pw.Expanded(
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Lewa: LOT (czytany od dołu do góry)
              pw.SizedBox(
                width: 13,
                child: pw.Center(
                  child: pw.Transform.rotate(
                    angle: math.pi / 2,
                    child: pw.Text(d.lot, style: sB7),
                  ),
                ),
              ),
              // QR code
              pw.Expanded(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.all(2),
                  child: pw.Image(qrImage, fit: pw.BoxFit.contain),
                ),
              ),
              // Prawa: data (czytana od góry do dołu)
              pw.SizedBox(
                width: 13,
                child: pw.Center(
                  child: pw.Transform.rotate(
                    angle: -math.pi / 2,
                    child: pw.Text(d.data, style: sB7),
                  ),
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 3),

        // ── Dostawca ──────────────────────────────────────────────────────────
        pw.Text(
          '${d.dostawcaKod} — ${d.dostawca}',
          style: sB12,
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 2),

        // ── Przeznaczenie ─────────────────────────────────────────────────────
        pw.Text(
          'Przeznaczenie: ${d.przeznaczenie}',
          style: sB12,
          textAlign: pw.TextAlign.center,
        ),
      ],
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
    final img      = await painter.toImage(400);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }
}
