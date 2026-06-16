import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants.dart';

// ── Przepływ skrzyń: PEŁNE (z produktem) ↔ PUSTE (do wydania) ─────────────────
//
// Model na dokumencie crateStates (per dostawa, docId = lot z _ zamiast /):
//   drew_remaining/plast_remaining = ile skrzyń fizycznie trzymamy (pełne+puste)
//   drew_pelne/plast_pelne         = z produktem
//   drew_puste/plast_puste         = puste, gotowe do wydania
// Niezmiennik: pelne + puste == remaining.
//
// Stare dostawy (sprzed wdrożenia) nie mają pól pelne/puste → traktujemy je jako
// w całości PUSTE (pelne=0, puste=remaining) — czyli zachowują się jak dawniej.

int _i(Map<String, dynamic> d, String k) => (d[k] as num?)?.toInt() ?? 0;

/// Akceptacja zejścia: N skrzyń dostawy przechodzi PEŁNE → PUSTE.
/// Split przy dostawie mieszanej: najpierw drewniane, potem plastikowe.
Future<void> zejscieOprozniaSkrzynie(String lot, int ilosc) async {
  if (ilosc <= 0 || lot.isEmpty) return;
  final db  = FirebaseFirestore.instance;
  final ref = db.collection(AppConstants.colCrateStates).doc(lot.replaceAll('/', '_'));
  try {
    await db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final d = snap.data()!;
      // brak pola pelne (stara dostawa) => skrzynie są pełne (= remaining)
      final drewPelne  = (d['drew_pelne']  as num?)?.toInt() ?? _i(d, 'drew_remaining');
      final plastPelne = (d['plast_pelne'] as num?)?.toInt() ?? _i(d, 'plast_remaining');
      final drewPuste  = _i(d, 'drew_puste');
      final plastPuste = _i(d, 'plast_puste');
      final drewMove  = ilosc.clamp(0, drewPelne);
      final plastMove = (ilosc - drewMove).clamp(0, plastPelne);
      if (drewMove + plastMove == 0) return;
      tx.update(ref, {
        'drew_pelne':  drewPelne  - drewMove,
        'plast_pelne': plastPelne - plastMove,
        'drew_puste':  drewPuste  + drewMove,
        'plast_puste': plastPuste + plastMove,
      });
    });
  } catch (_) {
    // brak dokumentu / sieci — nie blokujemy akceptacji zejścia
  }
}

/// Cofnięcie zejścia: odwrotnie — N skrzyń PUSTE → PEŁNE.
/// Split: najpierw drewniane (lustrzane do opróżniania).
Future<void> cofnijOproznienieSkrzynie(String lot, int ilosc) async {
  if (ilosc <= 0 || lot.isEmpty) return;
  final db  = FirebaseFirestore.instance;
  final ref = db.collection(AppConstants.colCrateStates).doc(lot.replaceAll('/', '_'));
  try {
    await db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final d = snap.data()!;
      final drewPelne  = _i(d, 'drew_pelne');
      final plastPelne = _i(d, 'plast_pelne');
      final drewPuste  = _i(d, 'drew_puste');
      final plastPuste = _i(d, 'plast_puste');
      final drewMove  = ilosc.clamp(0, drewPuste);
      final plastMove = (ilosc - drewMove).clamp(0, plastPuste);
      if (drewMove + plastMove == 0) return;
      tx.update(ref, {
        'drew_pelne':  drewPelne  + drewMove,
        'plast_pelne': plastPelne + plastMove,
        'drew_puste':  drewPuste  - drewMove,
        'plast_puste': plastPuste - plastMove,
      });
    });
  } catch (_) {}
}
