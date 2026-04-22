/**
 * KARTA WAŻENIA → GOOGLE SHEETS
 * Dla każdej dostawy z Firestore tworzy osobny plik Sheets w Google Drive.
 *
 * Jak używać:
 *  1. Wklej ten plik do tego samego projektu GAS co FirestoreSync.js
 *  2. Uruchom raz: setupKartaTrigger() — ustawi auto-backup co godzinę
 *  3. Lub ręcznie: backupAllKarty() — tworzy pliki dla wszystkich kart
 *
 * Struktura folderów na Drive:
 *  Karty ważenia MBF/
 *    Kwiecień 2026/
 *      KW_C_0422_215_26-S.sheets
 *      KW_C_0422_215_26-S2.sheets
 *    Maj 2026/
 *      ...
 */

// ─── KONFIGURACJA ─────────────────────────────────────────────────────────────

var KW_FOLDER_ID = '1sSa5CSNSz7yR-LY-Bw1RBEBvlBx0s78t';

var MONTHS_PL = {
  '01': 'Styczeń',    '02': 'Luty',       '03': 'Marzec',
  '04': 'Kwiecień',   '05': 'Maj',         '06': 'Czerwiec',
  '07': 'Lipiec',     '08': 'Sierpień',    '09': 'Wrzesień',
  '10': 'Październik','11': 'Listopad',    '12': 'Grudzień'
};

// ─── GŁÓWNE FUNKCJE ───────────────────────────────────────────────────────────

/** Tworzy pliki Sheets dla WSZYSTKICH dostaw z Firestore. */
function backupAllKarty() {
  var docs = _kwFsGetAll('deliveries');
  var created = 0, skipped = 0;

  docs.forEach(function(doc) {
    var d = _kwParseDoc(doc);
    if (!d.lot && !d.nrDostawy) { skipped++; return; }
    var created_ = _ensureKartaFile(d);
    if (created_) created++; else skipped++;
  });

  Logger.log('Backup zakończony: ' + created + ' nowych, ' + skipped + ' pominiętych');
  return 'Nowych: ' + created + ' | Pominiętych (już istnieją): ' + skipped;
}

/** Tworzy pliki tylko dla dostaw z ostatnich N godzin (domyślnie 2h). */
function backupRecentKarty(hoursBack) {
  hoursBack = hoursBack || 2;
  var docs = _kwFsGetAll('deliveries');
  var cutoff = new Date(Date.now() - hoursBack * 3600 * 1000);
  var created = 0;

  docs.forEach(function(doc) {
    var d = _kwParseDoc(doc);
    if (!d.createdAt) return;
    var ts = new Date(d.createdAt);
    if (ts < cutoff) return;
    var isNew = _ensureKartaFile(d);
    if (isNew) created++;
  });

  Logger.log('Backup ostatnich ' + hoursBack + 'h: ' + created + ' nowych plików');
}

/** Trigger co godzinę. */
function setupKartaTrigger() {
  // Usuń stary trigger jeśli istnieje
  ScriptApp.getProjectTriggers().forEach(function(t) {
    if (t.getHandlerFunction() === 'backupRecentKarty') ScriptApp.deleteTrigger(t);
  });
  ScriptApp.newTrigger('backupRecentKarty').timeBased().everyHours(1).create();
  Logger.log('Trigger ustawiony: backupRecentKarty co godzinę');
}

// ─── TWORZENIE PLIKU SHEETS ───────────────────────────────────────────────────

/** Tworzy plik jeśli nie istnieje. Zwraca true jeśli nowy. */
function _ensureKartaFile(d) {
  var rootFolder  = DriveApp.getFolderById(KW_FOLDER_ID);
  var monthFolder = _kwGetOrCreateFolder(rootFolder, _monthFolderName(d.data));
  var fileName    = _kwFileName(d);

  // Pomiń jeśli plik już istnieje
  var existing = monthFolder.getFilesByName(fileName);
  if (existing.hasNext()) return false;

  // Utwórz nowy arkusz
  var ss   = SpreadsheetApp.create(fileName);
  var file = DriveApp.getFileById(ss.getId());
  DriveApp.getRootFolder().removeFile(file);
  monthFolder.addFile(file);

  var sheet = ss.getActiveSheet();
  sheet.setName('KW');
  _buildKartaSheet(sheet, d);
  SpreadsheetApp.flush();

  return true;
}

// ─── BUDOWANIE LAYOUTU ARKUSZA ────────────────────────────────────────────────

var _KW_GREY  = '#cccccc';
var _KW_BSTYLE = null; // ustawiany przy pierwszym wywołaniu

function _kwBorder(range) {
  if (!_KW_BSTYLE) _KW_BSTYLE = SpreadsheetApp.BorderStyle.SOLID;
  range.setBorder(true, true, true, true, true, true, _KW_GREY, _KW_BSTYLE);
  return range;
}

function _buildKartaSheet(s, d) {
  var NAVY   = '#1a3566';
  var LGREY  = '#f2f2f2';
  var GREEN  = '#e8f4e8';
  var FONT   = 'Arial';

  // 6 kolumn: A(nr 35), B(opis 180), C(wartość-L 130), D(sep 8), E(label-P 175), F(wartość-P 130)
  s.setColumnWidth(1, 35);
  s.setColumnWidth(2, 180);
  s.setColumnWidth(3, 130);
  s.setColumnWidth(4, 8);
  s.setColumnWidth(5, 175);
  s.setColumnWidth(6, 130);

  var r = 1;

  // ── NAGŁÓWEK ────────────────────────────────────────────────────────────────
  // Kolumna A+B = lewa (etykieta), kolumny C+D+E+F = prawa (wartość)
  // Nagłówek: A-D = tytuł, E = Wydanie nr, F = Z dnia | I-07/A
  var titleText = d.isKwg ? 'KARTA WAŻENIA G (KWG)' : 'KARTA WAŻENIA';
  _kwBorder(s.getRange(r, 1, 1, 4).merge())
    .setValue(titleText)
    .setBackground(NAVY).setFontColor('#ffffff')
    .setFontSize(15).setFontWeight('bold')
    .setHorizontalAlignment('center').setVerticalAlignment('middle')
    .setFontFamily(FONT);
  _kwBorder(s.getRange(r, 5, 1, 1))
    .setValue('Wydanie nr:\n3')
    .setFontSize(8).setHorizontalAlignment('center').setVerticalAlignment('middle')
    .setFontFamily(FONT).setWrapStrategy(SpreadsheetApp.WrapStrategy.WRAP);
  _kwBorder(s.getRange(r, 6, 1, 1))
    .setValue('Z dnia:\n12.02.2024')
    .setFontSize(8).setHorizontalAlignment('center').setVerticalAlignment('middle')
    .setFontFamily(FONT).setWrapStrategy(SpreadsheetApp.WrapStrategy.WRAP);
  s.setRowHeight(r, 40);
  // Rząd "I-07/A"
  r++;
  s.getRange(r, 1, 1, 4).merge().setValue('')
    .setFontSize(7).setFontColor('#666').setFontFamily(FONT).setHorizontalAlignment('right');
  _kwBorder(s.getRange(r, 5, 1, 2).merge())
    .setValue('I-07/A')
    .setFontSize(8).setFontWeight('bold').setHorizontalAlignment('center')
    .setFontFamily(FONT);
  s.setRowHeight(r, 16);
  r++;

  // ── DANE PODSTAWOWE ──────────────────────────────────────────────────────────
  var basicRows = [
    ['DATA',           _kwFmtDate(d.data)],
    ['DOSTAWCA',       (d.dostawcaKod ? d.dostawcaKod + ' — ' : '') + (d.dostawca || '')],
    ['NUMER DOSTAWY',  d.lot || d.nrDostawy || ''],
    ['NUMER POJAZDU',  d.nrPojazdu  || ''],
    ['NUMER TELEFONU', d.nrTelefonu || ''],
  ];

  basicRows.forEach(function(row) {
    // Etykieta: col A+B merged, right-aligned
    _kwBorder(s.getRange(r, 1, 1, 2).merge())
      .setValue(row[0]).setFontWeight('bold').setHorizontalAlignment('right')
      .setBackground(LGREY).setFontSize(9).setFontFamily(FONT);
    // Wartość: col C+D+E+F merged
    _kwBorder(s.getRange(r, 3, 1, 4).merge())
      .setValue(row[1]).setFontSize(9).setFontFamily(FONT);
    s.setRowHeight(r, 18);
    r++;
  });
  r++;

  // ── TABELA WAŻENIA ───────────────────────────────────────────────────────────
  // Nagłówek: A=Nr, B=Opis, C+D+E+F=Wartość
  _kwBorder(s.getRange(r, 1, 1, 1)).setValue('Nr')
    .setBackground(NAVY).setFontColor('#fff').setFontWeight('bold').setFontSize(9).setFontFamily(FONT);
  _kwBorder(s.getRange(r, 2, 1, 1)).setValue('Opis')
    .setBackground(NAVY).setFontColor('#fff').setFontWeight('bold').setFontSize(9).setFontFamily(FONT);
  _kwBorder(s.getRange(r, 3, 1, 4).merge()).setValue('Wartość / Szczegóły')
    .setBackground(NAVY).setFontColor('#fff').setFontWeight('bold').setFontSize(9).setFontFamily(FONT);
  r++;

  var drewIl    = parseFloat(d.drewIl)    || 0;
  var drewWg    = parseFloat(d.drewWgJedn || d.drewWagaJedn) || 20;
  var plastIl   = parseFloat(d.plastIl)   || 0;
  var plastWg   = parseFloat(d.plastWgJedn || d.plastWagaJedn) || 10;
  var taraDrew  = drewIl  * drewWg;
  var taraPlast = plastIl * plastWg;

  function skrzDesc(il, wg, tara) {
    if (il <= 0) return '';
    return il + '  |  WAGA/szt: ' + wg + ' kg  |  TARA: ' + tara + ' kg';
  }

  var wagaNettoRounded = d.wagaNetto ? Math.round(parseFloat(d.wagaNetto)) : '';

  var tableRows = [
    ['1', 'Waga załadowanego auta I',   parseFloat(d.wagaA1Zal) > 0 ? Math.round(parseFloat(d.wagaA1Zal)) : ''],
    ['2', 'Waga rozładowanego auta I',  parseFloat(d.wagaA1Roz) > 0 ? Math.round(parseFloat(d.wagaA1Roz)) : ''],
    ['3', 'Waga załadowanego auta II',  parseFloat(d.wagaA2Zal) > 0 ? Math.round(parseFloat(d.wagaA2Zal)) : ''],
    ['4', 'Waga rozładowanego auta II', parseFloat(d.wagaA2Roz) > 0 ? Math.round(parseFloat(d.wagaA2Roz)) : ''],
    ['5', 'Ilość skrzyń drewnianych',   skrzDesc(drewIl,  drewWg,  taraDrew)],
    ['6', 'Ilość skrzyń plastikowych',  skrzDesc(plastIl, plastWg, taraPlast)],
    ['7', 'WAGA SUROWCA BRUTTO',        d.wagaBrutto ? Math.round(parseFloat(d.wagaBrutto)) : ''],
    ['8', 'WAGA SUROWCA NETTO',         wagaNettoRounded],
  ];

  // Odmiany (9-12)
  var odmNames = ['I', 'II', 'III', 'IV'];
  var odm0 = d.odmiana || '';
  var odm0val = '';
  if (odm0) {
    var parts = [];
    if (drewIl > 0 && plastIl > 0) {
      parts.push('Ilość skrzyń  |  Drewnianych: ' + drewIl + '  |  Plastikowych: ' + plastIl);
    } else if (drewIl > 0)  parts.push('Ilość skrzyń drewnianych: ' + drewIl);
    else if (plastIl > 0)   parts.push('Ilość skrzyń plastikowych: ' + plastIl);
    if (d.zwrotPct && parseFloat(d.zwrotPct) > 0) parts.push('Zwrot: ' + d.zwrotPct + '%');
    odm0val = parts.join('  |  ');
  }
  for (var i = 0; i < 4; i++) {
    var lbl  = 'ODMIANA ' + odmNames[i];
    var val  = i === 0 ? odm0val : '';
    var desc = i === 0 && odm0 ? lbl + ':  ' + odm0 : lbl;
    tableRows.push([String(9 + i), desc, val]);
  }

  tableRows.forEach(function(row) {
    var isBold = row[1].indexOf('BRUTTO') >= 0 || row[1].indexOf('NETTO') >= 0;
    _kwBorder(s.getRange(r, 1)).setValue(row[0]).setFontSize(9).setFontFamily(FONT);
    _kwBorder(s.getRange(r, 2)).setValue(row[1]).setFontSize(9).setFontFamily(FONT);
    _kwBorder(s.getRange(r, 3, 1, 4).merge()).setValue(row[2]).setFontSize(9).setFontFamily(FONT);
    if (isBold) {
      s.getRange(r, 1, 1, 6).setFontWeight('bold').setBackground(LGREY);
    }
    s.setRowHeight(r, 18);
    r++;
  });
  r++;

  // ── PARAMETRY (lewa) + KALKULACJA (prawa) obok siebie ───────────────────────
  var odpadV = parseFloat(d.odpad) || 0;
  var twardV = d.twardosc || '';
  var brixV  = d.brix     || '';
  var kalibV = d.kaliber  || '';
  var hasParams = odpadV > 0 || twardV || brixV || kalibV;

  if (hasParams) {
    // Nagłówek lewej tabeli
    _kwBorder(s.getRange(r, 1)).setValue('Nr')
      .setBackground(NAVY).setFontColor('#fff').setFontWeight('bold').setFontSize(9).setFontFamily(FONT);
    _kwBorder(s.getRange(r, 2)).setValue('Parametr')
      .setBackground(NAVY).setFontColor('#fff').setFontWeight('bold').setFontSize(9).setFontFamily(FONT);
    _kwBorder(s.getRange(r, 3)).setValue('Wartość')
      .setBackground(NAVY).setFontColor('#fff').setFontWeight('bold').setFontSize(9).setFontFamily(FONT);
    // Prawa: nagłówek kalkulacji (col E+F)
    var wagaN  = Math.round(parseFloat(d.wagaNetto) || 0);
    var doRozl = odpadV > 0 ? Math.round(wagaN * (1 - odpadV / 100)) : wagaN;
    _kwBorder(s.getRange(r, 5, 1, 2).merge())
      .setValue('Odmiana: ' + (odm0 || '—'))
      .setBackground(LGREY).setFontWeight('bold').setFontSize(9).setFontFamily(FONT);
    r++;

    var pNr    = 1;
    var params = [];
    if (odpadV > 0) params.push([pNr++, 'ODPAD w %',              String(d.odpad)]);
    if (twardV)     params.push([pNr++, 'TWARDOŚĆ',               twardV]);
    if (brixV)      params.push([pNr++, 'BRIX',                   brixV]);
    if (kalibV)     params.push([pNr++, 'PW (KALIBER+OCZKA w %)', kalibV]);

    // Prawa strona: Waga netto + Do rozliczenia
    var rightRows = [
      ['Waga netto:', wagaN + ' kg'],
      ['Do rozliczenia z dostawcą:', doRozl + ' kg'],
    ];

    var maxRows = Math.max(params.length, rightRows.length);
    for (var ri = 0; ri < maxRows; ri++) {
      if (ri < params.length) {
        _kwBorder(s.getRange(r, 1)).setValue(params[ri][0]).setFontSize(9).setFontFamily(FONT);
        _kwBorder(s.getRange(r, 2)).setValue(params[ri][1]).setFontSize(9).setFontFamily(FONT);
        _kwBorder(s.getRange(r, 3)).setValue(params[ri][2]).setFontSize(9).setFontFamily(FONT);
      }
      if (ri < rightRows.length) {
        var bg = ri === 1 ? GREEN : LGREY;
        _kwBorder(s.getRange(r, 5)).setValue(rightRows[ri][0])
          .setFontSize(9).setFontFamily(FONT).setBackground(bg);
        _kwBorder(s.getRange(r, 6)).setValue(rightRows[ri][1])
          .setFontSize(9).setFontFamily(FONT).setFontWeight('bold').setBackground(bg);
      }
      s.setRowHeight(r, 18);
      r++;
    }
    r++;
  }

  // ── STAN OPAKOWANIA (lewa) + STAN SAMOCHODU (prawa) obok siebie ─────────────
  s.getRange(r, 1, 1, 3).merge().setValue('STAN OPAKOWANIA:')
    .setFontWeight('bold').setFontSize(9).setFontFamily(FONT);
  s.getRange(r, 5, 1, 2).merge().setValue('STAN SAMOCHODU:')
    .setFontWeight('bold').setFontSize(9).setFontFamily(FONT);
  s.setRowHeight(r, 18); r++;

  var dobryOpak = d.stanOpak === 'DOBRY';
  var uszOpak   = d.stanOpak === 'USZKODZONY';
  var dobryAuto = d.stanAuto === 'DOBRY';
  var zlyAuto   = d.stanAuto === 'ZLY' || d.stanAuto === 'ZŁY';

  s.getRange(r, 1).setValue(dobryOpak ? '☑' : '☐').setFontSize(11).setFontFamily(FONT);
  s.getRange(r, 2, 1, 2).merge().setValue('DOBRY').setFontSize(9).setFontFamily(FONT);
  s.getRange(r, 5).setValue(dobryAuto ? '☑' : '☐').setFontSize(11).setFontFamily(FONT);
  s.getRange(r, 6).setValue('STAN DOBRY').setFontSize(9).setFontFamily(FONT);
  s.setRowHeight(r, 18); r++;

  s.getRange(r, 1).setValue(uszOpak ? '☑' : '☐').setFontSize(11).setFontFamily(FONT);
  s.getRange(r, 2, 1, 2).merge().setValue('USZKODZONY').setFontSize(9).setFontFamily(FONT);
  s.getRange(r, 5).setValue(zlyAuto ? '☑' : '☐').setFontSize(11).setFontFamily(FONT);
  s.getRange(r, 6).setValue('STAN ZŁY').setFontSize(9).setFontFamily(FONT);
  s.setRowHeight(r, 18); r++;
  r++;

  // Podpis
  s.getRange(r, 5, 1, 2).merge().setValue('PODPIS:')
    .setFontWeight('bold').setFontSize(9).setFontFamily(FONT);
}

// ─── HELPERS ─────────────────────────────────────────────────────────────────

function _monthFolderName(dateStr) {
  if (!dateStr || dateStr.length < 7) return 'Inne';
  var mm   = dateStr.substring(5, 7);
  var yyyy = dateStr.substring(0, 4);
  return (MONTHS_PL[mm] || mm) + ' ' + yyyy;
}

function _kwFileName(d) {
  var lot = (d.lot || d.nrDostawy || 'KW').replace(/\//g, '_');
  return 'KW_' + lot;
}

function _kwFmtDate(s) {
  if (!s || s.length < 10) return s || '';
  return s.substring(8) + '.' + s.substring(5, 7) + '.' + s.substring(0, 4);
}

function _kwGetOrCreateFolder(parent, name) {
  var it = parent.getFoldersByName(name);
  return it.hasNext() ? it.next() : parent.createFolder(name);
}

// ─── FIRESTORE ────────────────────────────────────────────────────────────────

function _kwFsGetAll(collection) {
  var docs = [], pageToken = null;
  do {
    var url = FS.BASE_URL + '/' + collection + '?key=' + FS.API_KEY + '&pageSize=300';
    if (pageToken) url += '&pageToken=' + pageToken;
    var body = JSON.parse(UrlFetchApp.fetch(url, { muteHttpExceptions: true }).getContentText());
    if (body.error) throw new Error(body.error.message);
    (body.documents || []).forEach(function(d) {
      docs.push({ id: d.name.split('/').pop(), fields: d.fields || {} });
    });
    pageToken = body.nextPageToken || null;
  } while (pageToken);
  return docs;
}

function _kwParseDoc(doc) {
  var f = doc.fields || {};
  function s(key) { return (f[key] && f[key].stringValue) || ''; }
  function n(key) {
    if (!f[key]) return '';
    return f[key].doubleValue || f[key].integerValue || f[key].stringValue || '';
  }
  function b(key) { return f[key] && f[key].booleanValue; }

  return {
    id:           doc.id,
    lot:          s('lot') || s('id'),
    data:         s('data'),
    dostawca:     s('dostawca'),
    dostawcaKod:  s('dostawca_kod'),
    nrDostawy:    s('nr_dostawy'),
    przeznaczenie:s('przeznaczenie'),
    owoc:         s('owoc'),
    odmiana:      s('odmiana'),
    nrPojazdu:    s('nr_pojazdu'),
    nrTelefonu:   s('nr_telefonu'),
    wagaA1Zal:    n('waga_a1_zal'),
    wagaA1Roz:    n('waga_a1_roz'),
    wagaA2Zal:    n('waga_a2_zal'),
    wagaA2Roz:    n('waga_a2_roz'),
    drewIl:       n('skrzynie_drew'),
    drewWgJedn:   n('drew_waga_jedn'),
    plastIl:      n('skrzynie_plast'),
    plastWgJedn:  n('plast_waga_jedn'),
    wagaBrutto:   n('waga_brutto'),
    wagaNetto:    s('waga_netto') || String(n('waga_netto')),
    skrzynie:     s('skrzynie'),
    brix:         s('brix'),
    odpad:        s('odpad'),
    twardosc:     s('twardosc'),
    kaliber:      s('kaliber'),
    zwrotPct:     s('zwrot_pct'),
    stanOpak:     s('stan_opakowania'),
    stanAuto:     s('stan_samochodu'),
    isKwg:        b('is_kwg'),
    createdAt:    (f['createdAt'] && f['createdAt'].timestampValue) || null,
  };
}
