// ── Model danych Karty Ważenia ────────────────────────────────────────────────

/// Dane ze ekranu WSG przekazywane do KW / KWG.
class WsgInputData {
  final DateTime data;
  final String nrDostawy;       // np. "1", "42"
  final String dostawcaNazwa;
  final String dostawcaKod;
  final String przeznaczenie;
  final String przeznaczenieKod;
  final String owoc;
  final bool isKWG;
  final bool isRylex;
  final bool isGrojecka;

  const WsgInputData({
    required this.data,
    required this.nrDostawy,
    required this.dostawcaNazwa,
    required this.dostawcaKod,
    required this.przeznaczenie,
    required this.przeznaczenieKod,
    required this.owoc,
    required this.isKWG,
    this.isRylex = false,
    this.isGrojecka = false,
  });

  /// Typ KWG: 'G' dla Grójecka, 'R' dla Rylex, '' dla reszty
  String get kwgType => isGrojecka ? 'G' : (isRylex ? 'R' : '');

  /// LOT bazowy: C/0001/029/26-O (lub W/ dla KWG)
  String get lotBase {
    final prefix = isKWG ? 'W' : 'C';
    final nr = nrDostawy.padLeft(4, '0');
    final year = (data.year % 100).toString().padLeft(2, '0');
    return '$prefix/$nr/$dostawcaKod/$year-$przeznaczenieKod';
  }

  /// LOT dla odmiany [index] (0=brak sufiksu, 1=2, 2=3, ...)
  String lotForOdmiana(int index, int total) {
    if (total <= 1 || index == 0) return lotBase;
    return '$lotBase${index + 1}';
  }
}

/// Dane jednej odmiany w karcie ważenia.
class KwOdmiana {
  String nazwa;
  String skrzynieDrew;   // ilość skrzyń drewnianych
  String skrzyniePlast;  // ilość skrzyń plastikowych
  String zwrotPct;       // zwrot w %
  String skrzynieMBFDrew;  // skrzynie MBF (tylko KWG)
  String skrzynieMBFPlast;

  // Parametry jakości
  String brix;
  String odpadPct;    // ODPAD w %
  String twardosc;    // tylko S, O
  String pw;          // PW (kaliber) tylko O

  KwOdmiana({
    this.nazwa = '',
    this.skrzynieDrew = '',
    this.skrzyniePlast = '',
    this.zwrotPct = '',
    this.skrzynieMBFDrew = '',
    this.skrzynieMBFPlast = '',
    this.brix = '',
    this.odpadPct = '',
    this.twardosc = '',
    this.pw = '',
  });
}

/// Pomocnicze obliczenia KW.
class KwCalculations {
  /// Waga netto odmiany proporcjonalnie do jej skrzyń.
  static double wagaNettoOdmiany({
    required double wagaNettoTotal,
    required int skrzDrew,
    required int skrzPlast,
    required int totalDrew,
    required int totalPlast,
    required double wagaJednejDrew,
    required double wagaJednejPlast,
    required double zwrotPct,
    double odpadPct = 0,
  }) {
    final mianownik = totalDrew * wagaJednejDrew + totalPlast * wagaJednejPlast;
    if (mianownik <= 0) return 0;
    final base = wagaNettoTotal *
        (skrzDrew * wagaJednejDrew + skrzPlast * wagaJednejPlast) /
        mianownik;
    return base * (1 - zwrotPct / 100) * (1 - odpadPct / 100);
  }

  /// ODPAD kg = odpadPct/100 × wagaNetto.
  static double odpadKg(double wagaNetto, double odpadPct) =>
      wagaNetto * odpadPct / 100;

  static double parse(String v) =>
      double.tryParse(v.replaceAll(',', '.')) ?? 0;
  static int parseInt(String v) => int.tryParse(v.trim()) ?? 0;
}
