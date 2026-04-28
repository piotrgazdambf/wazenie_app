import 'dart:convert';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/pdf/logo_mbf_b64.dart';

// ── Modele danych ─────────────────────────────────────────────────────────────

class KwOdmianaData {
  final String nazwa;
  final int drewIl;
  final int plastIl;
  final double zwrotPct;
  final double wagaNetto;
  final String brix;
  final String odpad;
  final String twardosc;
  final String kaliber;

  const KwOdmianaData({
    required this.nazwa,
    required this.drewIl,
    required this.plastIl,
    required this.zwrotPct,
    this.wagaNetto = 0,
    this.brix = '',
    this.odpad = '',
    this.twardosc = '',
    this.kaliber = '',
  });
}

class KwPdfData {
  final String data;
  final String dostawca;
  final String nrDostawy;
  final String lot;
  final String przeznaczenieKod;
  final String nrPojazdu;
  final String nrTelefonu;
  final double wagaA1Zal;
  final double wagaA1Roz;
  final bool drugiAut;
  final double wagaA2Zal;
  final double wagaA2Roz;
  final int drewIl;
  final double drewWagaJedn;
  final int plastIl;
  final double plastWagaJedn;
  // Skrzynie MB (własne MBF)
  final int mbDrewIl;
  final double mbDrewWagaJedn;
  final int mbPlastIl;
  final double mbPlastWagaJedn;
  final double wagaBrutto;
  final double wagaNetto;
  final List<KwOdmianaData> odmiany;
  final String stanOpak;
  final String stanAuto;
  final bool isKwg;

  const KwPdfData({
    required this.data,
    required this.dostawca,
    required this.nrDostawy,
    this.lot = '',
    this.przeznaczenieKod = '',
    this.nrPojazdu = '',
    this.nrTelefonu = '',
    required this.wagaA1Zal,
    required this.wagaA1Roz,
    this.drugiAut = false,
    this.wagaA2Zal = 0,
    this.wagaA2Roz = 0,
    required this.drewIl,
    required this.drewWagaJedn,
    required this.plastIl,
    required this.plastWagaJedn,
    this.mbDrewIl = 0,
    this.mbDrewWagaJedn = 20,
    this.mbPlastIl = 0,
    this.mbPlastWagaJedn = 10,
    required this.wagaBrutto,
    required this.wagaNetto,
    required this.odmiany,
    required this.stanOpak,
    required this.stanAuto,
    this.isKwg = false,
  });

  factory KwPdfData.fromFirestoreMap(Map<String, dynamic> d) {
    final p  = _parse;
    final pi = _parseInt;

    double a1z = (d['waga_a1_zal'] is num) ? (d['waga_a1_zal'] as num).toDouble() : 0;
    double a1r = (d['waga_a1_roz'] is num) ? (d['waga_a1_roz'] as num).toDouble() : 0;
    double a2z = (d['waga_a2_zal'] is num) ? (d['waga_a2_zal'] as num).toDouble() : 0;
    double a2r = (d['waga_a2_roz'] is num) ? (d['waga_a2_roz'] as num).toDouble() : 0;

    final drewIl  = (d['skrzynie_drew']  is int) ? d['skrzynie_drew']  as int : pi(d['skrzynie_drew']?.toString()  ?? '0');
    final plastIl = (d['skrzynie_plast'] is int) ? d['skrzynie_plast'] as int : pi(d['skrzynie_plast']?.toString() ?? '0');

    final wagaNetto  = p(d['waga_netto']?.toString()  ?? '0');
    final wagaBrutto = (d['waga_brutto'] is num)
        ? (d['waga_brutto'] as num).toDouble()
        : p(d['waga_brutto']?.toString() ?? '0');

    final zwrotPct = p(d['zwrot_pct']?.toString() ?? '0');

    return KwPdfData(
      data:             d['data']             as String? ?? '',
      dostawca:         '${d['dostawca_kod'] ?? ''} — ${d['dostawca'] ?? ''}',
      nrDostawy:        d['nr_dostawy']       as String? ?? '',
      lot:              d['lot']              as String? ?? '',
      przeznaczenieKod: d['przeznaczenie_kod'] as String? ?? '',
      nrPojazdu:        d['nr_pojazdu']       as String? ?? '',
      nrTelefonu:       d['nr_telefonu']      as String? ?? '',
      wagaA1Zal:    a1z,
      wagaA1Roz:    a1r,
      drugiAut:     a2z > 0 || a2r > 0,
      wagaA2Zal:    a2z,
      wagaA2Roz:    a2r,
      drewIl:           drewIl,
      drewWagaJedn:     (d['drew_waga_jedn']   is num) ? (d['drew_waga_jedn']   as num).toDouble() : 20,
      plastIl:          plastIl,
      plastWagaJedn:    (d['plast_waga_jedn']  is num) ? (d['plast_waga_jedn']  as num).toDouble() : 10,
      mbDrewIl:         (d['mb_drew_il']  is int)  ? d['mb_drew_il']  as int  : pi(d['mb_drew_il']?.toString()  ?? '0'),
      mbDrewWagaJedn:   (d['mb_drew_waga'] is num) ? (d['mb_drew_waga'] as num).toDouble() : 20,
      mbPlastIl:        (d['mb_plast_il'] is int)  ? d['mb_plast_il'] as int  : pi(d['mb_plast_il']?.toString()  ?? '0'),
      mbPlastWagaJedn:  (d['mb_plast_waga'] is num)? (d['mb_plast_waga'] as num).toDouble(): 10,
      wagaBrutto:       wagaBrutto,
      wagaNetto:    wagaNetto,
      odmiany: [
        KwOdmianaData(
          nazwa:    d['odmiana']  as String? ?? '',
          drewIl:   drewIl,
          plastIl:  plastIl,
          zwrotPct: zwrotPct,
          wagaNetto: wagaNetto,
          brix:     d['brix']     as String? ?? '',
          odpad:    d['odpad']    as String? ?? '',
          twardosc: d['twardosc'] as String? ?? '',
          kaliber:  d['kaliber']  as String? ?? '',
        ),
      ],
      stanOpak: d['stan_opakowania'] as String? ?? '',
      stanAuto: d['stan_samochodu']  as String? ?? '',
      isKwg:    d['is_kwg'] == true,
    );
  }

  /// Buduje KwPdfData z wielu dokumentów Firestore (jedna odmiana = jeden doc).
  /// Pierwszy doc dostarcza dane nagłówkowe (wagi aut, brutto, pojazd itd.).
  factory KwPdfData.fromMultipleDocs(List<Map<String, dynamic>> docs) {
    if (docs.isEmpty) throw ArgumentError('docs cannot be empty');

    // Sortuj wg LOT: odmiana bez sufiksu (np. 26-S) przed odmiany z sufiksem (26-S2, 26-S3)
    docs.sort((a, b) {
      final la = a['lot'] as String? ?? '';
      final lb = b['lot'] as String? ?? '';
      return la.compareTo(lb);
    });

    final d0 = docs.first;
    final p  = _parse;
    final pi = _parseInt;

    // LOT bazowy — bez sufiksu odmiany (2, 3, 4…)
    final rawLot  = d0['lot'] as String? ?? '';
    final baseLot = rawLot.replaceAll(RegExp(r'\d+$'), '');

    double a1z = (d0['waga_a1_zal'] is num) ? (d0['waga_a1_zal'] as num).toDouble() : 0;
    double a1r = (d0['waga_a1_roz'] is num) ? (d0['waga_a1_roz'] as num).toDouble() : 0;
    double a2z = (d0['waga_a2_zal'] is num) ? (d0['waga_a2_zal'] as num).toDouble() : 0;
    double a2r = (d0['waga_a2_roz'] is num) ? (d0['waga_a2_roz'] as num).toDouble() : 0;

    final wagaBrutto = (d0['waga_brutto'] is num)
        ? (d0['waga_brutto'] as num).toDouble()
        : p(d0['waga_brutto']?.toString() ?? '0');

    int    totalDrew  = 0;
    int    totalPlast = 0;
    double totalNetto = 0;

    final odmiany = docs.map((d) {
      final drewIl   = (d['skrzynie_drew']  is int) ? d['skrzynie_drew']  as int : pi(d['skrzynie_drew']?.toString()  ?? '0');
      final plastIl  = (d['skrzynie_plast'] is int) ? d['skrzynie_plast'] as int : pi(d['skrzynie_plast']?.toString() ?? '0');
      final wagaNetto = p(d['waga_netto']?.toString() ?? '0');
      final zwrotPct  = p(d['zwrot_pct']?.toString()  ?? '0');
      totalDrew  += drewIl;
      totalPlast += plastIl;
      totalNetto += wagaNetto;
      return KwOdmianaData(
        nazwa:     d['odmiana']  as String? ?? '',
        drewIl:    drewIl,
        plastIl:   plastIl,
        zwrotPct:  zwrotPct,
        wagaNetto: wagaNetto,
        brix:      d['brix']     as String? ?? '',
        odpad:     d['odpad']    as String? ?? '',
        twardosc:  d['twardosc'] as String? ?? '',
        kaliber:   d['kaliber']  as String? ?? '',
      );
    }).toList();

    return KwPdfData(
      data:             d0['data']              as String? ?? '',
      dostawca:         '${d0['dostawca_kod'] ?? ''} — ${d0['dostawca'] ?? ''}',
      nrDostawy:        baseLot.isNotEmpty ? baseLot : (d0['nr_dostawy'] as String? ?? ''),
      lot:              baseLot,
      przeznaczenieKod: d0['przeznaczenie_kod'] as String? ?? '',
      nrPojazdu:        d0['nr_pojazdu']        as String? ?? '',
      nrTelefonu:       d0['nr_telefonu']       as String? ?? '',
      wagaA1Zal:  a1z,
      wagaA1Roz:  a1r,
      drugiAut:   a2z > 0 || a2r > 0,
      wagaA2Zal:  a2z,
      wagaA2Roz:  a2r,
      drewIl:         totalDrew,
      drewWagaJedn:   (d0['drew_waga_jedn']   is num) ? (d0['drew_waga_jedn']   as num).toDouble() : 20,
      plastIl:        totalPlast,
      plastWagaJedn:  (d0['plast_waga_jedn']  is num) ? (d0['plast_waga_jedn']  as num).toDouble() : 10,
      mbDrewIl:       (d0['mb_drew_il']   is int)  ? d0['mb_drew_il']   as int  : pi(d0['mb_drew_il']?.toString()   ?? '0'),
      mbDrewWagaJedn: (d0['mb_drew_waga'] is num)  ? (d0['mb_drew_waga'] as num).toDouble() : 20,
      mbPlastIl:      (d0['mb_plast_il']  is int)  ? d0['mb_plast_il']  as int  : pi(d0['mb_plast_il']?.toString()  ?? '0'),
      mbPlastWagaJedn:(d0['mb_plast_waga'] is num) ? (d0['mb_plast_waga'] as num).toDouble() : 10,
      wagaBrutto:  wagaBrutto,
      wagaNetto:   (d0['waga_netto_total'] is num)
          ? (d0['waga_netto_total'] as num).toDouble()
          : totalNetto,
      odmiany:     odmiany,
      stanOpak: d0['stan_opakowania'] as String? ?? '',
      stanAuto: d0['stan_samochodu']  as String? ?? '',
      isKwg:    d0['is_kwg'] == true,
    );
  }

  static double _parse(String s)  => double.tryParse(s.replaceAll(',', '.').trim()) ?? 0;
  static int    _parseInt(String s) => int.tryParse(s.trim()) ?? 0;
}

// ── Generator PDF ─────────────────────────────────────────────────────────────

class KwPdfGenerator {
  static Future<Uint8List> generate(KwPdfData d) async {
    final doc = pw.Document();

    final logoBytes = base64.decode(kLogoMbfBase64);
    final logoImage = pw.MemoryImage(logoBytes);

    final fontR = await PdfGoogleFonts.notoSansRegular();
    final fontB = await PdfGoogleFonts.notoSansBold();

    final sR8  = pw.TextStyle(font: fontR, fontSize: 8);
    final sB8  = pw.TextStyle(font: fontB, fontSize: 8);
    final sR9  = pw.TextStyle(font: fontR, fontSize: 9);
    final sB9  = pw.TextStyle(font: fontB, fontSize: 9);
    final sB14 = pw.TextStyle(font: fontB, fontSize: 14);

    const pad  = pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3);
    const padH = pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2);

    final taraDrew    = d.drewIl    * d.drewWagaJedn;
    final taraPlast   = d.plastIl   * d.plastWagaJedn;
    final taraMbDrew  = d.mbDrewIl  * d.mbDrewWagaJedn;
    final taraMbPlast = d.mbPlastIl * d.mbPlastWagaJedn;
    final hasMb       = d.mbDrewIl > 0 || d.mbPlastIl > 0;

    pw.Widget chk(bool checked) => pw.Container(
      width: 12, height: 12,
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
      child: checked ? pw.Text('X', style: sB9, textAlign: pw.TextAlign.center) : pw.SizedBox(),
    );

    bool hasZwroty() => d.odmiany.any((o) => o.zwrotPct > 0);

    final firstOdm    = d.odmiany.isNotEmpty ? d.odmiany.first : null;
    final przKod      = d.przeznaczenieKod.toUpperCase();
    final isSok       = przKod == 'S';
    final isObieranie = przKod == 'O';
    final hasOdpad    = !d.isKwg && d.odmiany.any((o) => o.odpad.isNotEmpty);
    final hasBrix     = d.odmiany.any((o) => o.brix.isNotEmpty);
    final hasTward    = (isSok || d.isKwg) && d.odmiany.any((o) => o.twardosc.isNotEmpty);
    final hasKaliber  = isObieranie && d.odmiany.any((o) => o.kaliber.isNotEmpty);
    // KWG: wymagane BRIX + twardość; KW: odpad/tward/kaliber wg przeznaczenia
    final hasParams   = d.isKwg
        ? (hasBrix && hasTward)
        : (hasOdpad || hasTward || hasKaliber);

    // Szerokość kolumny nr — 26px żeby dwucyfrowe liczby się mieściły
    const nrW = pw.FixedColumnWidth(26);

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(18, 18, 18, 18),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [

          // ── NAGŁÓWEK ────────────────────────────────────────────────────────
          pw.Table(
            border: pw.TableBorder.all(width: 0.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(70),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FixedColumnWidth(68),
              3: const pw.FixedColumnWidth(68),
              4: const pw.FixedColumnWidth(52),
            },
            defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
            children: [
              pw.TableRow(children: [
                pw.Container(
                  height: 44, padding: pad,
                  child: pw.Center(
                    child: pw.Image(logoImage, width: 62, height: 38, fit: pw.BoxFit.contain),
                  ),
                ),
                pw.Container(
                  padding: pad,
                  child: pw.Center(
                    child: pw.Text(
                      'KARTA WAŻENIA',
                      style: sB14,
                    ),
                  ),
                ),
                pw.Container(
                  padding: pad,
                  child: pw.Column(mainAxisSize: pw.MainAxisSize.min, children: [
                    pw.Text('Wydanie nr:', style: sR8),
                    pw.SizedBox(height: 2),
                    pw.Text('3', style: sB9),
                  ]),
                ),
                pw.Container(
                  padding: pad,
                  child: pw.Column(mainAxisSize: pw.MainAxisSize.min, children: [
                    pw.Text('Z dnia:', style: sR8),
                    pw.SizedBox(height: 2),
                    pw.Text('12.02.2024', style: sB9),
                  ]),
                ),
                pw.Container(
                  padding: pad,
                  child: pw.Center(child: pw.Text('I-07/A', style: sB9)),
                ),
              ]),
            ],
          ),

          pw.SizedBox(height: 6),

          // ── DANE PODSTAWOWE ──────────────────────────────────────────────────
          pw.Table(
            border: pw.TableBorder.all(width: 0.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(130),
              1: const pw.FlexColumnWidth(1),
            },
            defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
            children: [
              _infoRow('DATA',           d.data,      pad, sB9, sR9),
              _infoRow('DOSTAWCA',       d.dostawca,  pad, sB9, sR9),
              _infoRow('NUMER DOSTAWY',  d.lot.isNotEmpty ? d.lot : d.nrDostawy, pad, sB9, sR9),
              _infoRow('NUMER POJAZDU',  d.nrPojazdu,  pad, sB9, sR9),
              _infoRow('NUMER TELEFONU', d.nrTelefonu, pad, sB9, sR9),
            ],
          ),

          pw.SizedBox(height: 6),

          // ── TABELA WAŻENIA ───────────────────────────────────────────────────
          // 3 kolumny: [nr | opis | wartość/szczegóły]
          pw.Table(
            border: pw.TableBorder.all(width: 0.5),
            columnWidths: {
              0: nrW,
              1: const pw.FlexColumnWidth(2.2),
              2: const pw.FlexColumnWidth(2.8),
            },
            defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
            children: [
              if (d.isKwg) ...[
                // KWG: 1=Netto, 2=Drew, 3=Plast, [2a/3a MB], 4-7=Odmiany
                pw.TableRow(children: [
                  pw.Container(padding: padH, child: pw.Text('1', style: sB9)),
                  pw.Container(padding: padH, child: pw.Text('WAGA SUROWCA NETTO', style: sB9)),
                  pw.Container(
                    padding: padH,
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(_n(d.wagaNetto), style: sB9),
                        if (hasZwroty()) pw.Text('ZWROTY W %:', style: sB9),
                      ],
                    ),
                  ),
                ]),
                _w3skrzynie('2', 'Ilość skrzyń drewnianych',  d.drewIl,  d.drewWagaJedn,  taraDrew,  pad, sR9, sB9),
                _w3skrzynie('3', 'Ilość skrzyń plastikowych', d.plastIl, d.plastWagaJedn, taraPlast, pad, sR9, sB9),
                if (hasMb && d.mbDrewIl > 0)
                  _w3skrzynie('2a', 'Ilość skrzyń MB drewnianych',  d.mbDrewIl,  d.mbDrewWagaJedn,  taraMbDrew,  pad, sR9, sB9),
                if (hasMb && d.mbPlastIl > 0)
                  _w3skrzynie('3a', 'Ilość skrzyń MB plastikowych', d.mbPlastIl, d.mbPlastWagaJedn, taraMbPlast, pad, sR9, sB9),
                ...List.generate(4, (i) {
                  final hasO = i < d.odmiany.length;
                  final o    = hasO ? d.odmiany[i] : null;
                  final lbl  = 'ODMIANA ${["I","II","III","IV"][i]}';
                  final nazwaTxt = (o != null && o.nazwa.isNotEmpty) ? '$lbl:  ${o.nazwa}' : lbl;
                  final hasDrew  = o != null && o.drewIl  > 0;
                  final hasPlast = o != null && o.plastIl > 0;
                  final hasZwrot = o != null && o.zwrotPct > 0;
                  return pw.TableRow(children: [
                    pw.Container(padding: padH, child: pw.Text('${i + 4}', style: sB9)),
                    pw.Container(padding: padH, child: pw.Text(nazwaTxt, style: sB9)),
                    pw.Container(
                      padding: padH,
                      child: !hasO ? pw.SizedBox() : pw.Row(children: [
                        if (hasDrew && !hasPlast) ...[
                          pw.Text('Ilość skrzyń drewnianych: ', style: sR9),
                          pw.Text('${o!.drewIl}', style: sB9),
                        ],
                        if (hasPlast && !hasDrew) ...[
                          pw.Text('Ilość skrzyń plastikowych: ', style: sR9),
                          pw.Text('${o!.plastIl}', style: sB9),
                        ],
                        if (hasDrew && hasPlast) ...[
                          pw.Text('Ilość skrzyń  |  Drewnianych: ', style: sR9),
                          pw.Text('${o!.drewIl}', style: sB9),
                          pw.Text('  |  Plastikowych: ', style: sR9),
                          pw.Text('${o.plastIl}', style: sB9),
                        ],
                        if (hasZwrot) ...[
                          pw.Text('  |  Zwrot: ', style: sR9),
                          pw.Text('${o!.zwrotPct}%', style: sB9),
                        ],
                      ]),
                    ),
                  ]);
                }),
              ] else ...[
                // KW: wagi aut 1-4, skrzynie 5-6, brutto 7, netto 8, odmiany 9-12
                _w3('1', 'Waga załadowanego auta I',   d.wagaA1Zal > 0 ? _n(d.wagaA1Zal) : '', pad, sR9, sB9),
                _w3('2', 'Waga rozładowanego auta I',  d.wagaA1Roz > 0 ? _n(d.wagaA1Roz) : '', pad, sR9, sB9),
                if (d.drugiAut && (d.wagaA2Zal > 0 || d.wagaA2Roz > 0)) ...[
                  _w3('3', 'Waga załadowanego auta II',  _n(d.wagaA2Zal), pad, sR9, sB9),
                  _w3('4', 'Waga rozładowanego auta II', _n(d.wagaA2Roz), pad, sR9, sB9),
                ],
                _w3skrzynie('5', 'Ilość skrzyń drewnianych',  d.drewIl,  d.drewWagaJedn,  taraDrew,  pad, sR9, sB9),
                _w3skrzynie('6', 'Ilość skrzyń plastikowych', d.plastIl, d.plastWagaJedn, taraPlast, pad, sR9, sB9),
                if (hasMb && d.mbDrewIl > 0)
                  _w3skrzynie('5a', 'Ilość skrzyń MB drewnianych',  d.mbDrewIl,  d.mbDrewWagaJedn,  taraMbDrew,  pad, sR9, sB9),
                if (hasMb && d.mbPlastIl > 0)
                  _w3skrzynie('6a', 'Ilość skrzyń MB plastikowych', d.mbPlastIl, d.mbPlastWagaJedn, taraMbPlast, pad, sR9, sB9),
                _w3('7', 'WAGA SUROWCA BRUTTO', _n(d.wagaBrutto), pad, sB9, sB9),
                pw.TableRow(children: [
                  pw.Container(padding: padH, child: pw.Text('8', style: sB9)),
                  pw.Container(padding: padH, child: pw.Text('WAGA SUROWCA NETTO', style: sB9)),
                  pw.Container(
                    padding: padH,
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(_n(d.wagaNetto), style: sB9),
                        if (hasZwroty()) pw.Text('ZWROTY W %:', style: sB9),
                      ],
                    ),
                  ),
                ]),
                ...List.generate(4, (i) {
                  final hasO = i < d.odmiany.length;
                  final o    = hasO ? d.odmiany[i] : null;
                  final lbl  = 'ODMIANA ${["I","II","III","IV"][i]}';
                  final nazwaTxt = (o != null && o.nazwa.isNotEmpty) ? '$lbl:  ${o.nazwa}' : lbl;
                  final hasDrew  = o != null && o.drewIl  > 0;
                  final hasPlast = o != null && o.plastIl > 0;
                  final hasZwrot = o != null && o.zwrotPct > 0;
                  return pw.TableRow(children: [
                    pw.Container(padding: padH, child: pw.Text('${i + 9}', style: sB9)),
                    pw.Container(padding: padH, child: pw.Text(nazwaTxt, style: sB9)),
                    pw.Container(
                      padding: padH,
                      child: !hasO ? pw.SizedBox() : pw.Row(children: [
                        if (hasDrew && !hasPlast) ...[
                          pw.Text('Ilość skrzyń drewnianych: ', style: sR9),
                          pw.Text('${o!.drewIl}', style: sB9),
                        ],
                        if (hasPlast && !hasDrew) ...[
                          pw.Text('Ilość skrzyń plastikowych: ', style: sR9),
                          pw.Text('${o!.plastIl}', style: sB9),
                        ],
                        if (hasDrew && hasPlast) ...[
                          pw.Text('Ilość skrzyń  |  Drewnianych: ', style: sR9),
                          pw.Text('${o!.drewIl}', style: sB9),
                          pw.Text('  |  Plastikowych: ', style: sR9),
                          pw.Text('${o.plastIl}', style: sB9),
                        ],
                        if (hasZwrot) ...[
                          pw.Text('  |  Zwrot: ', style: sR9),
                          pw.Text('${o!.zwrotPct}%', style: sB9),
                        ],
                      ]),
                    ),
                  ]);
                }),
              ],
            ],
          ),

          // ── PARAMETRY JAKOŚCI — osobno dla każdej odmiany ───────────────────
          if (d.isKwg && !hasParams) ...[
            pw.SizedBox(height: 6),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5, color: PdfColors.orange700)),
              child: pw.Text('Należy uzupełnić parametry jakości',
                  style: pw.TextStyle(fontSize: 9, color: PdfColors.orange700)),
            ),
          ],

          if (hasParams) ...[
            pw.SizedBox(height: 6),
            ...d.odmiany.map((odm) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 5,
                    child: pw.Table(
                      border: pw.TableBorder.all(width: 0.5),
                      columnWidths: {
                        0: nrW,
                        1: const pw.FlexColumnWidth(3),
                        2: const pw.FlexColumnWidth(2),
                      },
                      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
                      children: [
                        if (odm.nazwa.isNotEmpty)
                          pw.TableRow(children: [
                            pw.Container(padding: pad, color: PdfColors.grey100,
                                child: pw.Text('', style: sR9)),
                            pw.Container(padding: pad, color: PdfColors.grey100,
                                child: pw.Text('Odmiana: ${odm.nazwa}', style: sB9)),
                            pw.Container(padding: pad, color: PdfColors.grey100,
                                child: pw.SizedBox()),
                          ]),
                        if (hasBrix && odm.brix.isNotEmpty)
                          _pRow('1', 'BRIX', odm.brix, pad, sR9, sB9),
                        if (hasOdpad && odm.odpad.isNotEmpty)
                          _pRow('2', 'ODPAD w %', odm.odpad, pad, sR9, sB9),
                        if (hasTward && odm.twardosc.isNotEmpty)
                          _pRow('3', 'TWARDOŚĆ', odm.twardosc, pad, sR9, sB9),
                        if (hasKaliber && odm.kaliber.isNotEmpty)
                          _pRow('4', 'PW (KALIBER I OCZKA W %)', odm.kaliber, pad, sR9, sB9),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    flex: 5,
                    child: _buildCalcBox(d, odm, isObieranie, pad, sR8, sB8, sR9, sB9),
                  ),
                ],
              ),
            )),
          ],

          pw.SizedBox(height: 14),

          // ── STAN OPAKOWANIA + SAMOCHODU ──────────────────────────────────────
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.only(bottom: 4),
                      decoration: const pw.BoxDecoration(
                          border: pw.Border(bottom: pw.BorderSide(width: 0.5))),
                      child: pw.Text('STAN OPAKOWANIA:', style: sB9),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(children: [
                      pw.SizedBox(width: 16),
                      pw.Text('DOBRY', style: sR9), pw.SizedBox(width: 10),
                      chk(d.stanOpak.toUpperCase() == 'DOBRY'),
                    ]),
                    pw.SizedBox(height: 6),
                    pw.Row(children: [
                      pw.SizedBox(width: 16),
                      pw.Text('USZKODZONY', style: sR9), pw.SizedBox(width: 10),
                      chk(d.stanOpak.toUpperCase() == 'USZKODZONY'),
                    ]),
                    pw.SizedBox(height: 10),
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(left: 16),
                      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                        pw.Text('................................', style: sR9),
                        pw.SizedBox(height: 2),
                        pw.Text('(szt.)', style: sR8),
                      ]),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 40),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.only(bottom: 4),
                      decoration: const pw.BoxDecoration(
                          border: pw.Border(bottom: pw.BorderSide(width: 0.5))),
                      child: pw.Text('STAN SAMOCHODU:', style: sB9),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(children: [
                      pw.Text('STAN DOBRY', style: sR9), pw.SizedBox(width: 10),
                      chk(d.stanAuto.toUpperCase() == 'DOBRY'),
                    ]),
                    pw.SizedBox(height: 6),
                    pw.Row(children: [
                      pw.Text('STAN ZŁY', style: sR9), pw.SizedBox(width: 10),
                      chk(d.stanAuto.toUpperCase() == 'ZLY' || d.stanAuto.toUpperCase() == 'ZŁY'),
                    ]),
                    pw.SizedBox(height: 16),
                    pw.Text('PODPIS:', style: sB9),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    ));

    return doc.save();
  }

  // ── Prawa tabela rozliczeniowa ────────────────────────────────────────────────

  static pw.Widget _buildCalcBox(
    KwPdfData d, KwOdmianaData? odm, bool isObieranie,
    pw.EdgeInsets pad,
    pw.TextStyle sR8, pw.TextStyle sB8,
    pw.TextStyle sR9, pw.TextStyle sB9,
  ) {
    if (odm == null) return pw.SizedBox();

    final wN      = odm.wagaNetto > 0 ? odm.wagaNetto : d.wagaNetto;
    final odpadV  = double.tryParse(odm.odpad.replaceAll(',',   '.')) ?? 0;
    final kalibV  = double.tryParse(odm.kaliber.replaceAll(',', '.')) ?? 0;

    final doRozliczenia   = wN * (1 - odpadV / 100);
    final wCenieZakupu    = doRozliczenia * (1 - kalibV / 100);
    final wCenieObnizOnej = doRozliczenia - wCenieZakupu;

    return pw.Table(
      border: pw.TableBorder.all(width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(2.5),
        1: const pw.FlexColumnWidth(1.5),
      },
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: [
        pw.TableRow(children: [
          pw.Container(
            padding: pad, color: PdfColors.grey200,
            child: pw.Text('Odmiana: ${odm.nazwa.isNotEmpty ? odm.nazwa : "—"}', style: sB8),
          ),
          pw.Container(
            padding: pad, color: PdfColors.grey200,
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('Waga netto:', style: sR8),
              pw.Text('${wN.toStringAsFixed(0)} kg', style: sB9),
            ]),
          ),
        ]),
        pw.TableRow(children: [
          pw.Container(padding: pad, child: pw.Text('Do rozliczenia z dostawcą:', style: sR9)),
          pw.Container(padding: pad, child: pw.Text('${doRozliczenia.toStringAsFixed(0)} kg', style: sB9)),
        ]),
        if (isObieranie) ...[
          pw.TableRow(children: [
            pw.Container(padding: pad, child: pw.Text('W cenie zakupu:', style: sR9)),
            pw.Container(padding: pad, child: pw.Text('${wCenieZakupu.toStringAsFixed(0)} kg', style: sB9)),
          ]),
          pw.TableRow(children: [
            pw.Container(padding: pad, child: pw.Text('W cenie obniżonej:', style: sR9)),
            pw.Container(padding: pad, child: pw.Text('${wCenieObnizOnej.toStringAsFixed(0)} kg', style: sB9)),
          ]),
        ],
      ],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  static pw.TableRow _infoRow(String label, String value,
      pw.EdgeInsets pad, pw.TextStyle ls, pw.TextStyle vs) =>
      pw.TableRow(children: [
        pw.Container(
          padding: pad,
          child: pw.Align(alignment: pw.Alignment.centerRight,
              child: pw.Text(label, style: ls)),
        ),
        pw.Container(padding: pad, child: pw.Text(value, style: vs)),
      ]);

  // Wiersz 3-kolumnowy: nr | opis | wartość (pełna szerokość)
  static pw.TableRow _w3(String num, String desc, String val,
      pw.EdgeInsets pad, pw.TextStyle s, pw.TextStyle bs) =>
      pw.TableRow(children: [
        pw.Container(padding: pad, child: pw.Text(num, style: bs)),
        pw.Container(padding: pad, child: pw.Text(desc, style: s)),
        pw.Container(padding: pad, child: pw.Text(val, style: bs)),
      ]);

  // Wiersz skrzyń: jeśli ilość == 0 → pusta prawa komórka
  static pw.TableRow _w3skrzynie(String num, String desc,
      int il, double wagaJedn, double tara,
      pw.EdgeInsets pad, pw.TextStyle s, pw.TextStyle bs) =>
      pw.TableRow(children: [
        pw.Container(padding: pad, child: pw.Text(num, style: bs)),
        pw.Container(padding: pad, child: pw.Text(desc, style: s)),
        pw.Container(
          padding: pad,
          child: il == 0
              ? pw.SizedBox()
              : pw.Row(children: [
                    pw.Text('$il', style: bs),
                    pw.Text('  |  ', style: s),
                    pw.Text('WAGA/szt: ', style: s),
                    pw.Text('${wagaJedn.toStringAsFixed(0)} kg', style: bs),
                    pw.Text('  |  ', style: s),
                    pw.Text('TARA: ', style: s),
                    pw.Text('${tara.toStringAsFixed(0)} kg', style: bs),
                  ]),
        ),
      ]);

  static pw.TableRow _pRow(String num, String label, String value,
      pw.EdgeInsets pad, pw.TextStyle s, pw.TextStyle bs) =>
      pw.TableRow(children: [
        pw.Container(padding: pad, child: pw.Text(num, style: bs)),
        pw.Container(padding: pad, child: pw.Text(label, style: s)),
        pw.Container(padding: pad, child: pw.Text(value, style: bs)),
      ]);

  static String _n(double v) => v.toStringAsFixed(0);
}
