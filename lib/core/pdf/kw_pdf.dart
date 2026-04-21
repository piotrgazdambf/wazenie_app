import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// ── Kolory ────────────────────────────────────────────────────────────────────

const _black  = PdfColors.black;
const _white  = PdfColors.white;
const _red    = PdfColor.fromInt(0xFFCC0000);
const _grey   = PdfColor.fromInt(0xFF666666);
const _bgGrey = PdfColor.fromInt(0xFFEEEEEE);

// ── Główna funkcja drukowania ─────────────────────────────────────────────────

Future<void> printKwCard(Map<String, dynamic> data) async {
  final pdf   = pw.Document();
  final logo  = await _loadLogo();

  pdf.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(20, 20, 20, 20),
    build: (ctx) => _buildPage(ctx, data, logo),
  ));

  await Printing.layoutPdf(
    onLayout: (_) async => pdf.save(),
    name: 'KW_${data['lot'] ?? 'karta'}',
  );
}

Future<pw.ImageProvider?> _loadLogo() async {
  try {
    final bytes = await rootBundle.load('assets/images/logo_mbf.png');
    return pw.MemoryImage(bytes.buffer.asUint8List());
  } catch (_) {
    return null;
  }
}

// ── Budowanie strony ──────────────────────────────────────────────────────────

pw.Widget _buildPage(pw.Context ctx, Map<String, dynamic> d, pw.ImageProvider? logo) {
  final isKwg    = d['is_kwg'] == true;
  final lot      = d['lot']         as String? ?? '';
  final data     = d['data']        as String? ?? '';
  final nrDost   = d['nr_dostawy']  as String? ?? '';
  final dostawca = d['dostawca']    as String? ?? '';
  final dostawKod= d['dostawca_kod'] as String? ?? '';
  final owoc     = _cap(d['owoc']   as String? ?? '');
  final odmiana  = d['odmiana']     as String? ?? '';
  final przezn   = d['przeznaczenie'] as String? ?? '';
  final wagaNetto= d['waga_netto']  as String? ?? '0';
  final nrPojazdu= d['nr_pojazdu']  as String? ?? '';
  final nrTel    = d['nr_telefonu'] as String? ?? '';

  final drewIl   = _intStr(d['skrzynie_drew']);
  final plastIl  = _intStr(d['skrzynie_plast']);
  final drewWg   = _dblStr(d['drew_waga_jedn']);
  final plastWg  = _dblStr(d['plast_waga_jedn']);
  final wagaBrutto = _dblStr(d['waga_brutto']);
  final a1Zal    = _dblStr(d['waga_a1_zal']);
  final a1Roz    = _dblStr(d['waga_a1_roz']);
  final a2Zal    = _dblStr(d['waga_a2_zal']);
  final a2Roz    = _dblStr(d['waga_a2_roz']);
  final hasA2    = (d['waga_a2_zal'] != null && d['waga_a2_zal'] != 0);

  final brix     = d['brix']      as String? ?? '';
  final odpad    = d['odpad']     as String? ?? '';
  final stanOpak = d['stan_opakowania'] as String? ?? 'DOBRY';
  final stanAuto = d['stan_samochodu']  as String? ?? 'STAN DOBRY';
  final zwrot    = d['zwrot_pct'] as String? ?? '';

  final tara1    = _dblStr(d['tara_drew']);
  final tara2    = _dblStr(d['tara_plast']);

  // oblicz wagę tary skrzyń
  final drewTara  = tara1.isNotEmpty ? tara1 : '0';
  final plastTara = tara2.isNotEmpty ? tara2 : '0';

  final doRozliczenia = '$wagaNetto kg';

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      // ── Nagłówek ────────────────────────────────────────────────────────────
      _buildHeader(logo, isKwg),
      pw.SizedBox(height: 6),

      // ── Tabela danych dostawy ────────────────────────────────────────────────
      _buildInfoTable(data, '$dostawKod — $dostawca', nrDost, nrPojazdu, nrTel, owoc, odmiana, przezn, lot),
      pw.SizedBox(height: 6),

      // ── Tabela główna (ważenia + skrzynie + odmiany) ─────────────────────────
      _buildMainTable(
        isKwg: isKwg,
        a1Zal: a1Zal, a1Roz: a1Roz,
        a2Zal: a2Zal, a2Roz: a2Roz, hasA2: hasA2,
        wagaBrutto: wagaBrutto, wagaNetto: wagaNetto,
        drewIl: drewIl, plastIl: plastIl,
        drewWg: drewWg, plastWg: plastWg,
        drewTara: drewTara, plastTara: plastTara,
        odmiana: odmiana, zwrot: zwrot,
        d: d,
      ),
      pw.SizedBox(height: 6),

      // ── Parametry + rozliczenie ──────────────────────────────────────────────
      _buildParamsRow(brix, odpad, odmiana, doRozliczenia),
      pw.SizedBox(height: 6),

      // ── Stan opakowania + samochodu + podpis ─────────────────────────────────
      _buildStanRow(stanOpak, stanAuto),
    ],
  );
}

// ── NAGŁÓWEK ─────────────────────────────────────────────────────────────────

pw.Widget _buildHeader(pw.ImageProvider? logo, bool isKwg) {
  return pw.Container(
    decoration: pw.BoxDecoration(border: pw.Border.all(color: _black, width: 1)),
    child: pw.Row(
      children: [
        // Logo
        pw.Container(
          width: 80,
          height: 40,
          padding: const pw.EdgeInsets.all(4),
          decoration: const pw.BoxDecoration(
            border: pw.Border(right: pw.BorderSide(color: _black, width: 1)),
          ),
          child: logo != null
              ? pw.Image(logo, fit: pw.BoxFit.contain)
              : pw.Text('MBF', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: _red)),
        ),

        // Tytuł
        pw.Expanded(
          child: pw.Container(
            height: 40,
            alignment: pw.Alignment.center,
            child: pw.Text(
              isKwg ? 'KARTA WAŻENIA G (KWG)' : 'KARTA WAŻENIA (KW)',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ),

        // Wydanie / Data / Symbol
        pw.Container(
          decoration: const pw.BoxDecoration(
            border: pw.Border(left: pw.BorderSide(color: _black, width: 1)),
          ),
          child: pw.Column(
            children: [
              _headerCell('Wydanie nr:', '3', width: 70),
              _headerCell('Z dnia:', '12.02.2024', width: 70),
            ],
          ),
        ),
        pw.Container(
          width: 50,
          height: 40,
          alignment: pw.Alignment.center,
          decoration: const pw.BoxDecoration(
            border: pw.Border(left: pw.BorderSide(color: _black, width: 1)),
          ),
          child: pw.Text('I-07/A', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
        ),
      ],
    ),
  );
}

pw.Widget _headerCell(String label, String value, {required double width}) {
  return pw.Container(
    width: width,
    height: 20,
    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: _black, width: 0.5)),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.center,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 6, color: _grey)),
        pw.Text(value, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
      ],
    ),
  );
}

// ── TABELA DANYCH ─────────────────────────────────────────────────────────────

pw.Widget _buildInfoTable(String data, String dostawca, String nrDost,
    String nrPojazdu, String nrTel, String owoc, String odmiana, String przezn, String lot) {
  return pw.Table(
    border: pw.TableBorder.all(color: _black, width: 0.5),
    columnWidths: {
      0: const pw.FixedColumnWidth(110),
      1: const pw.FlexColumnWidth(),
    },
    children: [
      _infoRow('DATA', data),
      _infoRow('DOSTAWCA', dostawca),
      _infoRow('NUMER DOSTAWY', nrDost),
      _infoRow('OWOC / ODMIANA', odmiana.isNotEmpty ? '$owoc / $odmiana' : owoc),
      _infoRow('PRZEZNACZENIE', przezn),
      _infoRow('NUMER POJAZDU', nrPojazdu),
      _infoRow('NUMER TELEFONU', nrTel),
      _infoRow('LOT', lot, bold: true),
    ],
  );
}

pw.TableRow _infoRow(String label, String value, {bool bold = false}) {
  return pw.TableRow(children: [
    pw.Container(
      color: _bgGrey,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      child: pw.Text(label, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
    ),
    pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      child: pw.Text(value, style: pw.TextStyle(fontSize: 8, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
    ),
  ]);
}

// ── TABELA GŁÓWNA ─────────────────────────────────────────────────────────────

pw.Widget _buildMainTable({
  required bool isKwg,
  required String a1Zal, required String a1Roz,
  required String a2Zal, required String a2Roz, required bool hasA2,
  required String wagaBrutto, required String wagaNetto,
  required String drewIl, required String plastIl,
  required String drewWg, required String plastWg,
  required String drewTara, required String plastTara,
  required String odmiana, required String zwrot,
  required Map<String, dynamic> d,
}) {
  final rows = <pw.TableRow>[];

  int nr = 1;

  if (!isKwg) {
    rows.add(_mainRow(nr++, 'Waga załadowanego auta I', a1Zal.isNotEmpty ? '$a1Zal kg' : ''));
    rows.add(_mainRow(nr++, 'Waga rozładowanego auta I', a1Roz.isNotEmpty ? '$a1Roz kg' : ''));
    if (hasA2) {
      rows.add(_mainRow(nr++, 'Waga załadowanego auta II', a2Zal.isNotEmpty ? '$a2Zal kg' : ''));
      rows.add(_mainRow(nr++, 'Waga rozładowanego auta II', a2Roz.isNotEmpty ? '$a2Roz kg' : ''));
    } else {
      rows.add(_mainRow(nr++, 'Waga załadowanego auta II', ''));
      rows.add(_mainRow(nr++, 'Waga rozładowanego auta II', ''));
    }
  }

  // Skrzynie
  rows.add(_mainRowSkrzynie(nr++,
    'Ilość skrzyń drewnianych',
    drewIl, drewWg, drewTara,
  ));
  rows.add(_mainRowSkrzynie(nr++,
    'Ilość skrzyń plastikowych',
    plastIl, plastWg, plastTara,
  ));

  // Wagi
  rows.add(_mainRow(nr++, 'WAGA SUROWCA BRUTTO', wagaBrutto.isNotEmpty ? '$wagaBrutto kg' : '0 kg', bold: true));
  rows.add(_mainRowNetto(nr++, wagaNetto, zwrot));

  // Odmiany
  final odmianyList = _parseOdmiany(d);
  for (int i = 0; i < 4; i++) {
    final odm = i < odmianyList.length ? odmianyList[i] : ('', '', '');
    rows.add(_mainRowOdmiana(nr++, 'ODMIANA ${_roman(i + 1)}', odm.$1, odm.$2, odm.$3));
  }

  return pw.Table(
    border: pw.TableBorder.all(color: _black, width: 0.5),
    columnWidths: {
      0: const pw.FixedColumnWidth(22),
      1: const pw.FlexColumnWidth(),
      2: const pw.FixedColumnWidth(120),
    },
    children: rows,
  );
}

pw.TableRow _mainRow(int nr, String label, String value, {bool bold = false}) {
  return pw.TableRow(children: [
    _cell(nr.toString(), center: true, bg: _bgGrey),
    _cell(label, bold: bold),
    _cell(value, bold: bold),
  ]);
}

pw.TableRow _mainRowSkrzynie(int nr, String label, String il, String wg, String tara) {
  return pw.TableRow(children: [
    _cell(nr.toString(), center: true, bg: _bgGrey),
    _cell(label),
    pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: pw.Row(children: [
        pw.Text('IL.: ', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
        pw.Text(il, style: pw.TextStyle(fontSize: 8)),
        pw.SizedBox(width: 10),
        pw.Text('WAGA/SZT: ', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
        pw.Text(wg.isNotEmpty ? '$wg kg' : '', style: pw.TextStyle(fontSize: 8)),
        pw.SizedBox(width: 10),
        pw.Text('TARA: ', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
        pw.Text(tara, style: pw.TextStyle(fontSize: 8)),
      ]),
    ),
  ]);
}

pw.TableRow _mainRowNetto(int nr, String netto, String zwrot) {
  return pw.TableRow(children: [
    _cell(nr.toString(), center: true, bg: _bgGrey),
    _cell('WAGA SUROWCA NETTO', bold: true),
    pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('$netto kg', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
          if (zwrot.isNotEmpty)
            pw.Text('ZWROTY W %: $zwrot%', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    ),
  ]);
}

pw.TableRow _mainRowOdmiana(int nr, String label, String nazwa, String skrzynie, String waga) {
  return pw.TableRow(children: [
    _cell(nr.toString(), center: true, bg: _bgGrey),
    _cell(label, bold: true),
    pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: pw.Row(children: [
        pw.Text(nazwa, style: pw.TextStyle(fontSize: 8)),
        if (skrzynie.isNotEmpty) ...[
          pw.SizedBox(width: 8),
          pw.Text('Il. skrzyń: ', style: pw.TextStyle(fontSize: 7, color: _grey)),
          pw.Text(skrzynie, style: pw.TextStyle(fontSize: 8)),
        ],
        if (waga.isNotEmpty) ...[
          pw.SizedBox(width: 8),
          pw.Text('Waga: ', style: pw.TextStyle(fontSize: 7, color: _grey)),
          pw.Text(waga, style: pw.TextStyle(fontSize: 8)),
        ],
      ]),
    ),
  ]);
}

// ── PARAMETRY + ROZLICZENIE ───────────────────────────────────────────────────

pw.Widget _buildParamsRow(String brix, String odpad, String odmiana, String doRozliczenia) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      // Lewa: BRIX + ODPAD
      pw.Expanded(
        child: pw.Table(
          border: pw.TableBorder.all(color: _black, width: 0.5),
          columnWidths: {
            0: const pw.FixedColumnWidth(22),
            1: const pw.FlexColumnWidth(),
            2: const pw.FixedColumnWidth(60),
          },
          children: [
            pw.TableRow(children: [
              _cell('1', center: true, bg: _bgGrey),
              _cell('BRIX'),
              _cell(brix),
            ]),
            pw.TableRow(children: [
              _cell('2', center: true, bg: _bgGrey),
              _cell('ODPAD w %'),
              _cell(odpad.isNotEmpty ? '$odpad%' : ''),
            ]),
          ],
        ),
      ),
      pw.SizedBox(width: 8),
      // Prawa: Odmiana + Do rozliczenia
      pw.Expanded(
        child: pw.Table(
          border: pw.TableBorder.all(color: _black, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(),
            1: const pw.FixedColumnWidth(70),
          },
          children: [
            pw.TableRow(children: [
              pw.Container(
                color: _bgGrey,
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: pw.Text('Odmiana:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              ),
              _cell(odmiana),
            ]),
            pw.TableRow(children: [
              pw.Container(
                color: _bgGrey,
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: pw.Text('Do rozliczenia z dostawcą:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              ),
              _cell(doRozliczenia, bold: true),
            ]),
          ],
        ),
      ),
    ],
  );
}

// ── STAN OPAKOWANIA + SAMOCHODU ───────────────────────────────────────────────

pw.Widget _buildStanRow(String stanOpak, String stanAuto) {
  final opakDobry    = stanOpak.toUpperCase().contains('DOBRY');
  final autoDobry    = stanAuto.toUpperCase().contains('DOBRY');

  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      // Stan opakowania
      pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: _black, width: 0.5)),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('STAN OPAKOWANIA:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              _checkRow('DOBRY', opakDobry, color: _red),
              _checkRow('USZKODZONY', !opakDobry),
              pw.SizedBox(height: 10),
              pw.Text('(szt.)', style: pw.TextStyle(fontSize: 7, color: _grey)),
            ],
          ),
        ),
      ),
      pw.SizedBox(width: 8),
      // Stan samochodu + podpis
      pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: _black, width: 0.5)),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('STAN SAMOCHODU:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              _checkRow('STAN DOBRY', autoDobry, color: _red),
              _checkRow('STAN ZŁY', !autoDobry),
              pw.SizedBox(height: 10),
              pw.Text('PODPIS: ___________________________',
                  style: pw.TextStyle(fontSize: 8)),
            ],
          ),
        ),
      ),
    ],
  );
}

pw.Widget _checkRow(String label, bool checked, {PdfColor? color}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 4),
    child: pw.Row(
      children: [
        pw.Container(
          width: 12,
          height: 12,
          decoration: pw.BoxDecoration(border: pw.Border.all(color: _black, width: 0.8)),
          alignment: pw.Alignment.center,
          child: checked
              ? pw.Text('✕', style: pw.TextStyle(fontSize: 9, color: color ?? _black, fontWeight: pw.FontWeight.bold))
              : pw.SizedBox(),
        ),
        pw.SizedBox(width: 6),
        pw.Text(label, style: pw.TextStyle(
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
          color: checked ? (color ?? _black) : _black,
        )),
      ],
    ),
  );
}

// ── POMOCNICZE ────────────────────────────────────────────────────────────────

pw.Widget _cell(String text, {bool bold = false, bool center = false, PdfColor? bg}) {
  return pw.Container(
    color: bg,
    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
    alignment: center ? pw.Alignment.center : pw.Alignment.centerLeft,
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 8,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    ),
  );
}

String _roman(int n) {
  const r = ['I', 'II', 'III', 'IV'];
  return n <= r.length ? r[n - 1] : n.toString();
}

List<(String, String, String)> _parseOdmiany(Map<String, dynamic> d) {
  final result = <(String, String, String)>[];
  for (int i = 1; i <= 4; i++) {
    final nazwa    = d['odmiana_$i']         as String? ?? '';
    final skrzynie = _intStr(d['skrzynie_$i']);
    final waga     = _dblStr(d['waga_$i']);
    if (nazwa.isNotEmpty || skrzynie != '0') {
      result.add((nazwa, skrzynie, waga.isNotEmpty ? '$waga kg' : ''));
    }
  }
  return result;
}

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
