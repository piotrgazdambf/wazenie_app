import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// ── Kolory MBF ────────────────────────────────────────────────────────────────

const _navy   = PdfColor.fromInt(0xFF0D2137);
const _mid    = PdfColor.fromInt(0xFF1A4566);
const _green  = PdfColor.fromInt(0xFF16A34A);
const _orange = PdfColor.fromInt(0xFFF59E0B);
const _grey   = PdfColor.fromInt(0xFF6B7280);
const _light  = PdfColor.fromInt(0xFFEEF2F7);

// ── Główna funkcja drukowania ─────────────────────────────────────────────────

/// Drukuje / podgląd karty ważenia na podstawie dokumentu Firestore.
/// [data] — mapa z collection `deliveries`.
Future<void> printKwCard(Map<String, dynamic> data) async {
  final pdf = pw.Document();

  pdf.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(24),
    build: (ctx) => _buildPage(ctx, data),
  ));

  await Printing.layoutPdf(
    onLayout: (_) async => pdf.save(),
    name: 'KW_${data['lot'] ?? 'karta'}',
  );
}

// ── Budowanie strony ──────────────────────────────────────────────────────────

pw.Widget _buildPage(pw.Context ctx, Map<String, dynamic> d) {
  final isKwg   = d['is_kwg'] == true;
  final lot      = d['lot']      as String? ?? '';
  final data     = d['data']     as String? ?? '';
  final nrDost   = d['nr_dostawy'] as String? ?? '';
  final dostawca = d['dostawca'] as String? ?? '';
  final dostawKod= d['dostawca_kod'] as String? ?? '';
  final owoc     = _cap(d['owoc'] as String? ?? '');
  final odmiana  = d['odmiana']  as String? ?? '';
  final przezn   = d['przeznaczenie'] as String? ?? '';
  final przKod   = d['przeznaczenie_kod'] as String? ?? '';
  final wagaNetto= d['waga_netto'] as String? ?? '';

  // Skrzynie
  final drewIl   = _intStr(d['skrzynie_drew']);
  final plastIl  = _intStr(d['skrzynie_plast']);
  final drewMbf  = _intStr(d['skrzynie_mbf_drew']);
  final plastMbf = _intStr(d['skrzynie_mbf_plast']);
  final drewWg   = _dblStr(d['drew_waga_jedn']);
  final plastWg  = _dblStr(d['plast_waga_jedn']);

  // Ważenia (tylko KW)
  final wagaBrutto = _dblStr(d['waga_brutto']);
  final a1Zal    = _dblStr(d['waga_a1_zal']);
  final a1Roz    = _dblStr(d['waga_a1_roz']);
  final a2Zal    = _dblStr(d['waga_a2_zal']);
  final a2Roz    = _dblStr(d['waga_a2_roz']);
  final hasA2    = (d['waga_a2_zal'] != null && d['waga_a2_zal'] != 0);

  // Parametry
  final brix     = d['brix']     as String? ?? '';
  final odpad    = d['odpad']    as String? ?? '';
  final tward    = d['twardosc'] as String? ?? '';
  final kaliber  = d['kaliber']  as String? ?? '';
  final zwrot    = d['zwrot_pct'] as String? ?? '';
  final stanOpak = d['stan_opakowania'] as String? ?? '';
  final stanAuto = d['stan_samochodu']  as String? ?? '';

  final hasParams = brix.isNotEmpty || odpad.isNotEmpty || tward.isNotEmpty
      || kaliber.isNotEmpty || zwrot.isNotEmpty;

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      // ── Nagłówek ────────────────────────────────────────────────────────────
      _Header(isKwg: isKwg),
      pw.SizedBox(height: 10),

      // ── LOT + dane dostawy ──────────────────────────────────────────────────
      _SectionBox(
        title: 'DANE DOSTAWY',
        child: pw.Column(
          children: [
            _Row2('LOT', lot, bold: true),
            _Row2('Data', data),
            _Row2('Nr dostawy', nrDost),
            _Row2('Dostawca', '$dostawKod — $dostawca'),
            _Row2('Owoc', owoc),
            if (odmiana.isNotEmpty) _Row2('Odmiana', odmiana),
            _Row2('Przeznaczenie', '$przezn ($przKod)'),
          ],
        ),
      ),
      pw.SizedBox(height: 8),

      // ── Skrzynie ─────────────────────────────────────────────────────────────
      _SectionBox(
        title: 'SKRZYNIE',
        child: pw.Column(
          children: [
            _Row4('Drewniane', drewIl, 'Plastikowe', plastIl),
            if (drewWg.isNotEmpty || plastWg.isNotEmpty)
              _Row4('Waga drew. [kg/szt]', drewWg, 'Waga plast. [kg/szt]', plastWg),
            if (drewMbf != '0' || plastMbf != '0')
              _Row4('MBF drewniane', drewMbf, 'MBF plastikowe', plastMbf),
          ],
        ),
      ),
      pw.SizedBox(height: 8),

      // ── Ważenia (tylko KW, nie KWG) ──────────────────────────────────────────
      if (!isKwg) ...[
        _SectionBox(
          title: 'WAŻENIA',
          child: pw.Column(
            children: [
              _Row4('A1 Założeniowe [kg]', a1Zal, 'A1 Rozliczeniowe [kg]', a1Roz),
              if (hasA2)
                _Row4('A2 Założeniowe [kg]', a2Zal, 'A2 Rozliczeniowe [kg]', a2Roz),
              pw.SizedBox(height: 4),
              _Row2('Brutto łącznie', '$wagaBrutto kg', bold: true),
            ],
          ),
        ),
        pw.SizedBox(height: 8),
      ],

      // ── Waga netto ────────────────────────────────────────────────────────────
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: pw.BoxDecoration(
          color: _navy,
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              isKwg ? 'WAGA NETTO (wg dostawcy)' : 'WAGA NETTO',
              style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              '$wagaNetto kg',
              style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      ),

      // ── Parametry jakości ─────────────────────────────────────────────────────
      if (hasParams) ...[
        pw.SizedBox(height: 8),
        _SectionBox(
          title: 'PARAMETRY JAKOŚCI',
          child: pw.Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (brix.isNotEmpty) _ParamBox('BRIX', brix, _mid),
              if (odpad.isNotEmpty) _ParamBox('ODPAD', '$odpad%', _orange),
              if (tward.isNotEmpty) _ParamBox('TWARDOŚĆ', tward, _green),
              if (kaliber.isNotEmpty) _ParamBox('KALIBER', '$kaliber%', _mid),
              if (zwrot.isNotEmpty) _ParamBox('ZWROT', '$zwrot%', PdfColors.red700),
            ],
          ),
        ),
      ],

      // ── Stan opakowania + samochodu ───────────────────────────────────────────
      if (stanOpak.isNotEmpty || stanAuto.isNotEmpty) ...[
        pw.SizedBox(height: 8),
        _SectionBox(
          title: 'UWAGI',
          child: pw.Column(
            children: [
              if (stanOpak.isNotEmpty) _Row2('Stan opakowania', stanOpak),
              if (stanAuto.isNotEmpty) _Row2('Stan samochodu', stanAuto),
            ],
          ),
        ),
      ],

      pw.Spacer(),

      // ── Stopka ───────────────────────────────────────────────────────────────
      pw.Divider(color: _grey, thickness: 0.5),
      pw.Text(
        'MBF S.A. | System Ważenia | Wydruk automatyczny',
        style: pw.TextStyle(fontSize: 8, color: _grey),
        textAlign: pw.TextAlign.center,
      ),
    ],
  );
}

// ── Nagłówek dokumentu ────────────────────────────────────────────────────────

class _Header extends pw.StatelessWidget {
  final bool isKwg;
  _Header({required this.isKwg});

  @override
  pw.Widget build(pw.Context context) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: pw.BoxDecoration(
        gradient: const pw.LinearGradient(
          colors: [_navy, _mid],
          begin: pw.Alignment.topLeft,
          end: pw.Alignment.bottomRight,
        ),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('MBF S.A.',
                  style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 1.5)),
              pw.Text('System Ważenia Surowca',
                  style: pw.TextStyle(color: PdfColors.grey300, fontSize: 9)),
            ],
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: pw.BoxDecoration(
              color: isKwg ? _orange : _green,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Text(
              isKwg ? 'KARTA WAŻENIA G (KWG)' : 'KARTA WAŻENIA (KW)',
              style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sekcja z tytułem ─────────────────────────────────────────────────────────

class _SectionBox extends pw.StatelessWidget {
  final String title;
  final pw.Widget child;
  _SectionBox({required this.title, required this.child});

  @override
  pw.Widget build(pw.Context context) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _light, width: 1),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: const pw.BoxDecoration(
              color: _light,
              borderRadius: pw.BorderRadius.only(
                topLeft: pw.Radius.circular(5),
                topRight: pw.Radius.circular(5),
              ),
            ),
            child: pw.Text(title,
                style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: _grey,
                    letterSpacing: 1.2)),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(10),
            child: child,
          ),
        ],
      ),
    );
  }
}

// ── Wiersz 2-kolumnowy ────────────────────────────────────────────────────────

pw.Widget _Row2(String label, String value, {bool bold = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 3),
    child: pw.Row(
      children: [
        pw.SizedBox(
          width: 130,
          child: pw.Text(label,
              style: pw.TextStyle(fontSize: 9, color: _grey)),
        ),
        pw.Expanded(
          child: pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ),
      ],
    ),
  );
}

// ── Wiersz 4-kolumnowy (dwa pola obok siebie) ─────────────────────────────────

pw.Widget _Row4(String l1, String v1, String l2, String v2) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 3),
    child: pw.Row(
      children: [
        pw.SizedBox(
          width: 130,
          child: pw.Text(l1, style: pw.TextStyle(fontSize: 9, color: _grey)),
        ),
        pw.SizedBox(
          width: 60,
          child: pw.Text(v1, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ),
        pw.SizedBox(width: 16),
        pw.SizedBox(
          width: 130,
          child: pw.Text(l2, style: pw.TextStyle(fontSize: 9, color: _grey)),
        ),
        pw.Expanded(
          child: pw.Text(v2, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ),
      ],
    ),
  );
}

// ── Chip parametru jakości ────────────────────────────────────────────────────

pw.Widget _ParamBox(String label, String value, PdfColor color) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: pw.BoxDecoration(
      color: PdfColor(color.red, color.green, color.blue, 0.08),
      border: pw.Border.all(
          color: PdfColor(color.red, color.green, color.blue, 0.4)),
      borderRadius: pw.BorderRadius.circular(6),
    ),
    child: pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text(label,
            style: pw.TextStyle(
                fontSize: 7,
                fontWeight: pw.FontWeight.bold,
                color: color,
                letterSpacing: 0.5)),
        pw.Text(value,
            style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: color)),
      ],
    ),
  );
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

String _intStr(dynamic v) {
  if (v == null) return '0';
  if (v is int) return v.toString();
  if (v is double) return v.toInt().toString();
  return v.toString();
}

String _dblStr(dynamic v) {
  if (v == null) return '';
  if (v is double) return v == 0 ? '' : v.toStringAsFixed(2);
  if (v is int) return v == 0 ? '' : v.toString();
  final s = v.toString();
  return s == '0' || s == '0.0' ? '' : s;
}
