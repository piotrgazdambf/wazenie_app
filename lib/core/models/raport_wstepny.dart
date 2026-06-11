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
  final double? uzyskPct;
  final String? smak;              // indeks smaku z Generatora LOT, np. "jabłko gruszka"
  final double? pojemnosc;         // pojemność opakowania z Generatora LOT
  final String? pojemnoscJednostka; // "L" lub "kg"
  final String? pojemnoscTekst;    // gotowy tekst np. "3 L" (opcjonalny)
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
    this.uzyskPct,
    this.smak,
    this.pojemnosc,
    this.pojemnoscJednostka,
    this.pojemnoscTekst,
    this.status = 'otwarty',
    this.dataProdukcji,
    this.sourceApp = 'wazenie_seed',
  });

  /// Zwraca czytelny tekst pojemności, np. "3 L" lub "140 kg".
  /// Preferuje gotowy pojemnosc_tekst, a w razie braku składa z liczby + jednostki.
  String? get pojemnoscLabel {
    if (pojemnoscTekst != null && pojemnoscTekst!.isNotEmpty) return pojemnoscTekst;
    if (pojemnosc == null) return null;
    final num = pojemnosc! == pojemnosc!.truncateToDouble()
        ? pojemnosc!.toInt().toString()
        : pojemnosc!.toString();
    final jed = pojemnoscJednostka ?? '';
    return jed.isNotEmpty ? '$num $jed' : num;
  }

  factory RaportWstepny.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    try {
      final d = doc.data() ?? {};
      return RaportWstepny(
        id:            doc.id,
        lotProdukcji:  _str(d['lot_produkcji']),
        typProdukcji:  TypProdukcji.fromString(_str(d['typ_produkcji'])),
        owoc:          _str(d['owoc']),
        brix:               _toDouble(d['brix']),
        witaminaC:          _toDouble(d['witamina_c_val'] ?? d['witamina_c']),
        uzyskPct:           _toDouble(d['uzysk_pct']),
        smak:               d['smak'] as String?,
        pojemnosc:          _toDouble(d['pojemnosc']),
        pojemnoscJednostka: d['pojemnosc_jednostka'] as String?,
        pojemnoscTekst:     d['pojemnosc_tekst'] as String?,
        status:        _str(d['status'], fallback: 'otwarty'),
        dataProdukcji: _toDate(d['data_produkcji']),
        sourceApp:     _str(d['source_app']),
      );
    } catch (_) {
      return RaportWstepny(
        id: doc.id, lotProdukcji: doc.id,
        typProdukcji: TypProdukcji.sok, owoc: '?', status: 'otwarty',
      );
    }
  }

  static String _str(dynamic v, {String fallback = ''}) {
    if (v == null) return fallback;
    return v.toString();
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '.'));
    return null;
  }

  static DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is String) {
      // obsługa formatu dd.MM.yyyy
      final parts = v.split(RegExp(r'[./\-]'));
      if (parts.length == 3) {
        final d = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final y = int.tryParse(parts[2]);
        if (d != null && m != null && y != null) return DateTime(y, m, d);
      }
    }
    return null;
  }

  Map<String, dynamic> toMap() => {
    'lot_produkcji':   lotProdukcji,
    'typ_produkcji':   typProdukcji.firestoreValue,
    'owoc':            owoc,
    if (brix      != null) 'brix':       brix,
    if (witaminaC != null) 'witamina_c': witaminaC,
    if (uzyskPct  != null) 'uzysk_pct':  uzyskPct,
    'status':          status,
    if (dataProdukcji != null)
      'data_produkcji': Timestamp.fromDate(dataProdukcji!),
    'created_at':      FieldValue.serverTimestamp(),
    'source_app':      sourceApp,
  };
}
