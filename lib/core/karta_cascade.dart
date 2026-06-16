import 'package:cloud_firestore/cloud_firestore.dart';
import 'constants.dart';

// ── Kaskadowe usuwanie karty ważenia ──────────────────────────────────────────
//
// Karta ważenia (KW/KWG) przy zapisie tworzy ślady w wielu kolekcjach. Przy
// usuwaniu testowej/błędnej karty trzeba je wszystkie sprzątnąć, żeby stany się
// nie rozjeżdżały. Ten moduł liczy powiązania (do potwierdzenia) i usuwa wszystko
// jedną operacją.
//
// Co tworzy karta (i co usuwamy) dla danego LOT-u:
//   deliveries/{docId}            — sama dostawa
//   crateStates/{docId}           — stan skrzyń (pełne/puste)
//   mcrQueue   where lot==lot      — wpisy MCR (Przyjęcie + ew. Zejście)
//   crateActions where lot==lot    — akcje skrzyń (Przyjęcie)
//   skaner_zejscia where lot==lot  — zejścia surowca (jeśli były)
//   skaner_wnioski where lot==lot  — wnioski skanera (jeśli były)
//   delivery_assignments where lot_dostawy==lot — przypisania do raportów Matiego
//   crate_loans karta_{key}_{typ}  — auto-zwrot skrzyń MB z tej karty

class KartaPowiazania {
  final int zejscia;
  final int wnioski;
  final int przypisania;
  final int akcjeSkrzyn;
  final int mcr;
  final bool maStanSkrzyn;
  const KartaPowiazania({
    required this.zejscia, required this.wnioski, required this.przypisania,
    required this.akcjeSkrzyn, required this.mcr, required this.maStanSkrzyn,
  });

  // Czy karta ma „prawdziwą" aktywność (zejścia/przypisania) — ostrzeżenie, że to nie test
  bool get maAktywnosc => zejscia > 0 || przypisania > 0;
}

Future<KartaPowiazania> policzPowiazaniaKarty(String lot, String docId) async {
  final db = FirebaseFirestore.instance;
  Future<int> cnt(String col, String field) async =>
      (await db.collection(col).where(field, isEqualTo: lot).get()).docs.length;

  final zejscia    = await cnt('skaner_zejscia', 'lot');
  final wnioski    = await cnt('skaner_wnioski', 'lot');
  final przypis    = await cnt(AppConstants.colDeliveryAssign, 'lot_dostawy');
  final akcje      = await cnt(AppConstants.colCrateActions, 'lot');
  final mcr        = await cnt(AppConstants.colMcrQueue, 'lot');
  final stan       = (await db.collection(AppConstants.colCrateStates).doc(docId).get()).exists;

  return KartaPowiazania(
    zejscia: zejscia, wnioski: wnioski, przypisania: przypis,
    akcjeSkrzyn: akcje, mcr: mcr, maStanSkrzyn: stan,
  );
}

Future<void> usunKarteKaskadowo({
  required String lot,
  required String docId,
  required String nrDostawy,
}) async {
  final db = FirebaseFirestore.instance;
  final batch = db.batch();

  // 1. dostawa + stan skrzyń (po docId)
  batch.delete(db.collection(AppConstants.colDeliveries).doc(docId));
  batch.delete(db.collection(AppConstants.colCrateStates).doc(docId));
  batch.delete(db.collection(AppConstants.colCrateStates).doc('${docId}_mb')); // legacy MB

  // 2. usuwanie po polu == lot
  Future<void> delWhere(String col, String field) async {
    final s = await db.collection(col).where(field, isEqualTo: lot).get();
    for (final d in s.docs) {
      batch.delete(d.reference);
    }
  }
  await delWhere(AppConstants.colMcrQueue, 'lot');
  await delWhere(AppConstants.colCrateActions, 'lot');
  await delWhere('skaner_zejscia', 'lot');
  await delWhere('skaner_wnioski', 'lot');
  await delWhere(AppConstants.colDeliveryAssign, 'lot_dostawy');

  // 3. crate_loans — auto-zwrot skrzyń MB (doc id karta_{key}_{typ}); klucz to
  //    docId (KWG) albo numer dostawy (KW) — usuwamy obie warianty.
  final keys = <String>{docId, nrDostawy.replaceAll('/', '_')};
  for (final k in keys) {
    if (k.isEmpty) continue;
    for (final t in ['drewno', 'plastik', 'metal']) {
      batch.delete(db.collection(AppConstants.colCrateLoans).doc('karta_${k}_$t'));
    }
  }

  await batch.commit();
}
