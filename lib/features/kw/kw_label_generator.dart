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
        margin: const pw.EdgeInsets.fromLTRB(
          4 * PdfPageFormat.mm,
          4 * PdfPageFormat.mm,
          4 * PdfPageFormat.mm,
          4 * PdfPageFormat.mm,
        ),
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
    final NAVY = PdfColor.fromHex('#1a3566');

    final sB11 = pw.TextStyle(font: fontB, fontSize: 11);
    final sB13 = pw.TextStyle(font: fontB, fontSize: 13);
    final sB20 = pw.TextStyle(font: fontB, fontSize: 20, color: PdfColors.white);

    // Szerokość boczna (QR ma ~58% szerokości, tekst boczny ~21% z każdej strony)
    const sideW = 18.0 * PdfPageFormat.mm;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [

        // ── ODMIANA (header navy) ──────────────────────────────────────────────
        pw.Container(
          color: NAVY,
          padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
          child: pw.Text(
            d.odmiana.isNotEmpty ? d.odmiana : '—',
            style: sB20,
            textAlign: pw.TextAlign.center,
          ),
        ),
        pw.SizedBox(height: 4),

        // ── ŚRODEK: boczny tekst + QR ─────────────────────────────────────────
        pw.Expanded(
          child: pw.Stack(
            overflow: pw.Overflow.visible,
            children: [
              // QR code — wyśrodkowany z marginesami bocznymi
              pw.Positioned(
                left: sideW,
                right: sideW,
                top: 0,
                bottom: 0,
                child: pw.Center(
                  child: pw.Image(qrImage, fit: pw.BoxFit.contain),
                ),
              ),

              // Lewy tekst: LOT (rotacja CCW — czytasz od dołu do góry)
              pw.Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: pw.Container(
                  width: sideW,
                  child: pw.Center(
                    child: pw.Transform.rotate(
                      angle: math.pi / 2,
                      child: pw.Text(
                        d.lot,
                        style: sB11,
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),

              // Prawy tekst: DATA (rotacja CW — czytasz od góry do dołu)
              pw.Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: pw.Container(
                  width: sideW,
                  child: pw.Center(
                    child: pw.Transform.rotate(
                      angle: -math.pi / 2,
                      child: pw.Text(
                        d.data,
                        style: sB11,
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 4),

        // ── DOSTAWCA ──────────────────────────────────────────────────────────
        pw.Text(
          '${d.dostawcaKod} — ${d.dostawca}',
          style: sB13,
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 2),

        // ── PRZEZNACZENIE ─────────────────────────────────────────────────────
        pw.Text(
          'Przeznaczenie: ${d.przeznaczenie}',
          style: sB13,
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
    final img      = await painter.toImage(500);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }
}
