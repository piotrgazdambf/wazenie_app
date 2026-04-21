/**
 * FIRESTORE ↔ SHEETS SYNC
 * Backup danych z Firebase Firestore do Google Sheets
 *
 * Jak używać:
 *  1. Wklej ten plik do nowego projektu GAS (script.google.com)
 *  2. Uruchom: setupTriggers() — raz, żeby ustawić automatyczny sync
 *  3. Lub ręcznie: syncAllToSheets() — ciągnie wszystko z Firestore do Sheets
 *  4. Żeby wysłać edytowane wiersze z powrotem do Firestore: syncEditedToFirestore()
 */

// ─── KONFIGURACJA ─────────────────────────────────────────────────────────────

var FS = {
  PROJECT_ID: "mbf-przyjecia",
  API_KEY:    "AIzaSyD5W-xlWcczg7vKgy6_ZgcipYKw3w4nmac",
  BASE_URL:   "https://firestore.googleapis.com/v1/projects/mbf-przyjecia/databases/(default)/documents"
};

// Kolekcje do synchronizacji: { id w Firestore → nazwa zakładki w Sheets }
var COLLECTIONS = {
  deliveries:   "Dostawy",
  pls:          "PLS",
  mcrQueue:     "Kolejka MCR",
  inventory:    "Stany",
  suppliers:    "Dostawcy",
  crateActions: "Akcje Skrzyń",
  crateStates:  "Stany Skrzyń",
  kwDocs:       "Karty Ważenia",
};

// Kolumna "ZMIENIONO" — zaznacz TAK żeby wysłać wiersz z powrotem do Firestore
var COL_CHANGED  = "ZMIENIONO";
var COL_DOC_ID   = "_id";
var COL_SYNCED   = "_ostatni_sync";

// ─── GŁÓWNE FUNKCJE (uruchamiaj z menu lub triggerów) ─────────────────────────

/** Ciągnie jedną kolekcję na raz — bezpieczne w limicie 6 min. */
function syncAllToSheets() {
  var keys = Object.keys(COLLECTIONS);
  var prop = PropertiesService.getScriptProperties();
  var idx  = parseInt(prop.getProperty("syncIdx") || "0", 10);

  if (idx >= keys.length) idx = 0;

  var col       = keys[idx];
  var sheetName = COLLECTIONS[col];
  var ss        = SpreadsheetApp.getActiveSpreadsheet();

  try {
    var docs = fsGetAll_(col);
    writeCollectionToSheet_(ss, sheetName, docs, col);
    updateLogSheet_(ss, "Firestore → Sheets", ["✓ " + sheetName + " (" + docs.length + " wierszy)"]);
    SpreadsheetApp.getUi().alert("✓ " + sheetName + " — pobrano " + docs.length + " wierszy.\n\nUruchom ponownie żeby pobrać kolejną kolekcję (" + (idx + 2) + "/" + keys.length + ").");
  } catch (e) {
    SpreadsheetApp.getUi().alert("✗ Błąd przy " + sheetName + ":\n" + e.message);
  }

  prop.setProperty("syncIdx", String((idx + 1) % keys.length));
}

/** Ciągnie wszystkie kolekcje po kolei — uruchamiaj wielokrotnie aż do końca. */
function syncSingleCollection(colId) {
  var ss        = SpreadsheetApp.getActiveSpreadsheet();
  var sheetName = COLLECTIONS[colId];
  if (!sheetName) throw new Error("Nieznana kolekcja: " + colId);
  var docs = fsGetAll_(colId);
  writeCollectionToSheet_(ss, sheetName, docs, colId);
  updateLogSheet_(ss, "Firestore → Sheets", ["✓ " + sheetName + " (" + docs.length + " wierszy)"]);
}

// Osobne funkcje dla każdej kolekcji — możesz ustawić triggery na każdą z nich
function syncDostawy()     { syncSingleCollection("deliveries"); }
function syncPLS()         { syncSingleCollection("pls"); }
function syncMCR()         { syncSingleCollection("mcrQueue"); }
function syncStany()       { syncSingleCollection("inventory"); }
function syncDostawcy()    { syncSingleCollection("suppliers"); }
function syncAkcjeSkrzyn() { syncSingleCollection("crateActions"); }
function syncStanySkrzyn() { syncSingleCollection("crateStates"); }
function syncKarty()       { syncSingleCollection("kwDocs"); }

/** Wysyła do Firestore tylko wiersze z kolumną ZMIENIONO = TAK. */
function syncEditedToFirestore() {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var log = [];
  var totalSent = 0;

  for (var col in COLLECTIONS) {
    var sheetName = COLLECTIONS[col];
    var sh = ss.getSheetByName(sheetName);
    if (!sh) continue;

    try {
      var sent = pushEditedRows_(sh, col);
      totalSent += sent;
      if (sent > 0) log.push("✓ " + sheetName + ": wysłano " + sent + " wierszy");
    } catch (e) {
      log.push("✗ " + sheetName + ": " + e.message);
    }
  }

  if (totalSent === 0) {
    SpreadsheetApp.getUi().alert('Brak wierszy do wysłania.\n\nW kolumnie "ZMIENIONO" wpisz TAK przy wierszu który chcesz zaktualizować w Firestore.');
    return;
  }

  updateLogSheet_(ss, "Sheets → Firestore", log);
  SpreadsheetApp.getUi().alert("Wysłano:\n\n" + log.join("\n"));
}

/** Synchronizuje tylko jedną wybraną zakładkę z Firestore. */
function syncActiveSheetOnly() {
  var ss  = SpreadsheetApp.getActiveSpreadsheet();
  var sh  = ss.getActiveSheet();
  var col = null;

  for (var c in COLLECTIONS) {
    if (COLLECTIONS[c] === sh.getName()) { col = c; break; }
  }

  if (!col) {
    SpreadsheetApp.getUi().alert('Ta zakładka nie jest powiązana z żadną kolekcją Firestore.\nObsługiwane zakładki: ' + Object.values(COLLECTIONS).join(', '));
    return;
  }

  var docs = fsGetAll_(col);
  writeCollectionToSheet_(ss, sh.getName(), docs, col);
  SpreadsheetApp.getUi().alert("✓ Zaktualizowano: " + sh.getName() + " (" + docs.length + " wierszy)");
}

// ─── MENU ─────────────────────────────────────────────────────────────────────

function onOpen() {
  SpreadsheetApp.getUi()
    .createMenu("🔄 Firestore Sync")
    .addItem("Pobierz wszystko (Firestore → Sheets)", "syncAllToSheets")
    .addSeparator()
    .addItem("Wyślij zmienione (Sheets → Firestore)", "syncEditedToFirestore")
    .addItem("Odśwież tę zakładkę", "syncActiveSheetOnly")
    .addSeparator()
    .addItem("Ustaw auto-sync co godzinę", "setupTriggers")
    .addItem("Usuń auto-sync", "removeTriggers")
    .addToUi();
}

// ─── TRIGGERY (auto-sync) ─────────────────────────────────────────────────────

function setupTriggers() {
  removeTriggers();
  ScriptApp.newTrigger("syncAllToSheets")
    .timeBased()
    .everyHours(1)
    .create();
  SpreadsheetApp.getUi().alert("✓ Auto-sync ustawiony: co godzinę.\n\nMożesz zmienić częstotliwość w: Rozszerzenia → Apps Script → Triggery.");
}

function removeTriggers() {
  ScriptApp.getProjectTriggers().forEach(function(t) {
    if (t.getHandlerFunction() === "syncAllToSheets") {
      ScriptApp.deleteTrigger(t);
    }
  });
}

// ─── ZAPIS DO SHEETS ──────────────────────────────────────────────────────────

function writeCollectionToSheet_(ss, sheetName, docs, collectionId) {
  var sh = ss.getSheetByName(sheetName);
  if (!sh) sh = ss.insertSheet(sheetName);

  if (docs.length === 0) {
    sh.clearContents();
    sh.getRange(1, 1).setValue("(brak danych w kolekcji: " + collectionId + ")");
    return;
  }

  // Zbierz wszystkie klucze z wszystkich dokumentów
  var keysSet = {};
  docs.forEach(function(doc) {
    Object.keys(doc.fields || {}).forEach(function(k) { keysSet[k] = true; });
  });
  var fields = Object.keys(keysSet);
  fields.sort();

  // Nagłówki: _id | ZMIENIONO | _ostatni_sync | ...pola...
  var headers = [COL_DOC_ID, COL_CHANGED, COL_SYNCED].concat(fields);

  var rows = [headers];
  var now  = new Date().toLocaleString("pl-PL");

  docs.forEach(function(doc) {
    var row = [doc.id, "", now];
    fields.forEach(function(f) {
      row.push(fsReadValue_(doc.fields[f]));
    });
    rows.push(row);
  });

  sh.clearContents();
  sh.getRange(1, 1, rows.length, headers.length).setValues(rows);

  // Formatowanie nagłówka
  var headerRange = sh.getRange(1, 1, 1, headers.length);
  headerRange.setBackground("#1a237e").setFontColor("#ffffff").setFontWeight("bold");

  // Kolumna ZMIENIONO — jasnożółte tło
  var changedCol = headers.indexOf(COL_CHANGED) + 1;
  if (changedCol > 0 && docs.length > 0) {
    sh.getRange(2, changedCol, docs.length, 1).setBackground("#fff9c4");
  }

  sh.setFrozenRows(1);
  sh.autoResizeColumns(1, headers.length);
}

// ─── WYSYŁKA ZMIAN DO FIRESTORE ───────────────────────────────────────────────

function pushEditedRows_(sh, collectionId) {
  var data    = sh.getDataRange().getValues();
  if (data.length < 2) return 0;

  var headers  = data[0];
  var idCol    = headers.indexOf(COL_DOC_ID);
  var chgCol   = headers.indexOf(COL_CHANGED);
  var syncCol  = headers.indexOf(COL_SYNCED);

  if (idCol === -1 || chgCol === -1) return 0;

  var sent = 0;
  var now  = new Date().toLocaleString("pl-PL");

  for (var r = 1; r < data.length; r++) {
    var row = data[r];
    if (String(row[chgCol]).trim().toUpperCase() !== "TAK") continue;

    var docId  = String(row[idCol]).trim();
    if (!docId) continue;

    // Zbuduj obiekt pól
    var fields = {};
    headers.forEach(function(h, i) {
      if (h === COL_DOC_ID || h === COL_CHANGED || h === COL_SYNCED) return;
      fields[h] = fsWriteValue_(row[i]);
    });

    fsPatch_(collectionId, docId, fields);

    // Wyczyść flagę ZMIENIONO, zaktualizuj czas sync
    sh.getRange(r + 1, chgCol + 1).setValue("");
    if (syncCol !== -1) sh.getRange(r + 1, syncCol + 1).setValue(now);

    sent++;
  }

  return sent;
}

// ─── FIRESTORE REST API ───────────────────────────────────────────────────────

function fsGetAll_(collectionId) {
  var docs    = [];
  var pageToken = null;

  do {
    var url = FS.BASE_URL + "/" + collectionId + "?key=" + FS.API_KEY + "&pageSize=300";
    if (pageToken) url += "&pageToken=" + pageToken;

    var resp = UrlFetchApp.fetch(url, { muteHttpExceptions: true });
    var body = JSON.parse(resp.getContentText());

    if (body.error) throw new Error(body.error.message);

    (body.documents || []).forEach(function(d) {
      var id = d.name.split("/").pop();
      docs.push({ id: id, fields: d.fields || {} });
    });

    pageToken = body.nextPageToken || null;
  } while (pageToken);

  return docs;
}

function fsPatch_(collectionId, docId, fields) {
  var fieldPaths = Object.keys(fields).map(function(f) {
    return "updateMask.fieldPaths=" + encodeURIComponent(f);
  }).join("&");

  var url = FS.BASE_URL + "/" + collectionId + "/" + encodeURIComponent(docId)
          + "?" + fieldPaths + "&key=" + FS.API_KEY;

  var resp = UrlFetchApp.fetch(url, {
    method: "PATCH",
    contentType: "application/json",
    payload: JSON.stringify({ fields: fields }),
    muteHttpExceptions: true,
  });

  var body = JSON.parse(resp.getContentText());
  if (body.error) throw new Error(body.error.message);
}

// ─── POMOCNICZE: Firestore value ↔ JS value ───────────────────────────────────

function fsReadValue_(v) {
  if (!v) return "";
  if (v.stringValue    !== undefined) return v.stringValue;
  if (v.integerValue   !== undefined) return Number(v.integerValue);
  if (v.doubleValue    !== undefined) return Number(v.doubleValue);
  if (v.booleanValue   !== undefined) return v.booleanValue ? "TAK" : "NIE";
  if (v.timestampValue !== undefined) return v.timestampValue;
  if (v.nullValue      !== undefined) return "";
  if (v.mapValue       !== undefined) return JSON.stringify(v.mapValue.fields || {});
  if (v.arrayValue     !== undefined) return JSON.stringify(v.arrayValue.values || []);
  return JSON.stringify(v);
}

function fsWriteValue_(raw) {
  if (raw === null || raw === undefined || raw === "") return { nullValue: null };
  if (typeof raw === "boolean")  return { booleanValue: raw };
  if (raw === "TAK")             return { booleanValue: true };
  if (raw === "NIE")             return { booleanValue: false };
  if (typeof raw === "number")   return { doubleValue: raw };
  if (!isNaN(Number(raw)) && raw !== "") return { doubleValue: Number(raw) };
  return { stringValue: String(raw) };
}

// ─── LOG SHEET ────────────────────────────────────────────────────────────────

function updateLogSheet_(ss, operacja, lines) {
  var sh = ss.getSheetByName("📋 Log");
  if (!sh) {
    sh = ss.insertSheet("📋 Log");
    sh.getRange(1, 1, 1, 3).setValues([["Data", "Operacja", "Szczegóły"]]);
    sh.getRange(1, 1, 1, 3).setBackground("#37474f").setFontColor("#fff").setFontWeight("bold");
    sh.setFrozenRows(1);
  }
  var now = new Date().toLocaleString("pl-PL");
  sh.insertRowAfter(1);
  sh.getRange(2, 1, 1, 3).setValues([[now, operacja, lines.join(" | ")]]);
}
