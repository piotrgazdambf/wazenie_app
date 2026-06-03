import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// ── Typ produkcji ─────────────────────────────────────────────────────────────

enum TypProdukcji {
  sok,
  przecierNadzienie,
  obieranie;

  String get label {
    switch (this) {
      case TypProdukcji.sok:               return 'Sok';
      case TypProdukcji.przecierNadzienie: return 'Przecier / Nadzienie';
      case TypProdukcji.obieranie:         return 'Obieranie';
    }
  }

  String get firestoreValue {
    switch (this) {
      case TypProdukcji.sok:               return 'sok';
      case TypProdukcji.przecierNadzienie: return 'przecier_nadzienie';
      case TypProdukcji.obieranie:         return 'obieranie';
    }
  }

  static TypProdukcji fromString(String s) {
    switch (s) {
      case 'przecier_nadzienie': return TypProdukcji.przecierNadzienie;
      case 'obieranie':          return TypProdukcji.obieranie;
      default:                   return TypProdukcji.sok;
    }
  }

  Color get color {
    switch (this) {
      case TypProdukcji.sok:               return const Color(0xFF4A90D9);
      case TypProdukcji.przecierNadzienie: return const Color(0xFF2D9B4F);
      case TypProdukcji.obieranie:         return const Color(0xFFE8A020);
    }
  }

  IconData get icon {
    switch (this) {
      case TypProdukcji.sok:               return Icons.local_drink_outlined;
      case TypProdukcji.przecierNadzienie: return Icons.blender_outlined;
      case TypProdukcji.obieranie:         return Icons.cut_outlined;
    }
  }
}

// ── Model karty raportu wstępnego ─────────────────────────────────────────────
//
// INTEGRACJA z Generator LOT:
//   Kolekcja: 'lot_raporty_wstepne' w projekcie Firebase Ważenia.
//   Generator LOT inicjalizuje secondary FirebaseApp z konfiguracją projektu
//   Ważenia i pisze do tej kolekcji — bez żadnych zmian po stronie Ważenia.
//   Raporty końcowe analogicznie czytają 'delivery_assignments'.
//   Docelowo po migracji do Operona: wspólny projekt, kolekcje bez zmian.

class RaportWstepny {
  final String id;
  final String lotProdukcji;
  final TypProdukcji typProdukcji;
  final String owoc;
  final double? brix;
  final double? witaminaC;
  final double? wytlokPct;
  final String status; // otwarty | zamkniety
  final DateTime? dataProdukcji;
  final String sourceApp;

  const RaportWstepny({
    required this.id,
    required this.lotProdukcji,
    required this.typProdukcji,
    required this.owoc,
    this.brix,
    this.witaminaC,
    this.wytlokPct,
    this.status = 'otwarty',
    this.dataProdukcji,
    this.sourceApp = 'wazenie_seed',
  });

  factory RaportWstepny.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return RaportWstepny(
      id:            doc.id,
      lotProdukcji:  d['lot_produkcji']  as String? ?? '',
      typProdukcji:  TypProdukcji.fromString(d['typ_produkcji'] as String? ?? ''),
      owoc:          d['owoc']           as String? ?? '',
      brix:          (d['brix']          as num?)?.toDouble(),
      witaminaC:     (d['witamina_c']    as num?)?.toDouble(),
      wytlokPct:     (d['wytlok_pct']   as num?)?.toDouble(),
      status:        d['status']         as String? ?? 'otwarty',
      dataProdukcji: (d['data_produkcji'] as Timestamp?)?.toDate(),
      sourceApp:     d['source_app']     as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'lot_produkcji':   lotProdukcji,
    'typ_produkcji':   typProdukcji.firestoreValue,
    'owoc':            owoc,
    if (brix      != null) 'brix':       brix,
    if (witaminaC != null) 'witamina_c': witaminaC,
    if (wytlokPct != null) 'wytlok_pct': wytlokPct,
    'status':          status,
    if (dataProdukcji != null)
      'data_produkcji': Timestamp.fromDate(dataProdukcji!),
    'created_at':      FieldValue.serverTimestamp(),
    'source_app':      sourceApp,
  };
}
