import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import '../../app/theme.dart';
import '../../core/auth/pin_auth_service.dart';
import '../../core/constants.dart';
import '../../core/models/kw_data.dart';
import '../kw/kw_label_generator.dart';
import '../kw/kw_pdf_generator.dart';
import '../wsg/wsg_screen.dart' show wsgResetKeyProvider;

// ── Kontrolery odmiany KWG ────────────────────────────────────────────────────

class _WagaGrupa {
  String typ = 'drew';
  final iloscCtrl = TextEditingController();
  final wagaCtrl  = TextEditingController();
  _WagaGrupa({this.typ = 'drew'});
  void dispose() { iloscCtrl.dispose(); wagaCtrl.dispose(); }
  int    get ilosc => int.tryParse(iloscCtrl.text.trim()) ?? 0;
  double get wagaJedn => double.tryParse(wagaCtrl.text.replaceAll(',', '.').trim()) ?? 0;
  double get tara => ilosc * wagaJedn;
}

class _OdmGCtrl {
  final nazwaCtrl     = TextEditingController();
  final wagaNettoCtrl = TextEditingController();
  final drewCtrl      = TextEditingController();
  final plastCtrl     = TextEditingController();
  final mbDrewCtrl     = TextEditingController();
  final mbPlastCtrl    = TextEditingController();
  final mbDrewWagaCtrl = TextEditingController(text: '60');
  final mbPlastWagaCtrl= TextEditingController(text: '10');
  final zwrotCtrl     = TextEditingController(text: '0');
  final brixCtrl      = TextEditingController();
  final odpadCtrl     = TextEditingController();
  final twardCtrl     = TextEditingController();
  final infoCtrl      = TextEditingController();
  final drewWagaCtrl  = TextEditingController();
  final plastWagaCtrl = TextEditingController();
  // Dla Rylex/Grójecka: indywidualny nr dostawy i data
  final nrCtrl        = TextEditingController();
  DateTime dataDostawy = DateTime.now();
  bool dataBrak       = false;
  bool zwrotVisible   = false;
  bool mbVisible      = false;
  // Różne wagi skrzyń per odmiana
  bool rozneWagi      = false;
  final List<_WagaGrupa> wagiGrupy = [_WagaGrupa()];

  void dispose() {
    for (final c in [nazwaCtrl, wagaNettoCtrl, drewCtrl, plastCtrl,
                     mbDrewCtrl, mbPlastCtrl, mbDrewWagaCtrl, mbPlastWagaCtrl,
                     zwrotCtrl, brixCtrl, odpadCtrl, twardCtrl, infoCtrl,
                     nrCtrl, drewWagaCtrl, plastWagaCtrl]) {
      c.dispose();
    }
    for (final g in wagiGrupy) g.dispose();
  }
}

// ── Ekran KWG ─────────────────────────────────────────────────────────────────

class KwgScreen extends ConsumerStatefulWidget {
  final WsgInputData data;
  const KwgScreen({super.key, required this.data});

  @override
  ConsumerState<KwgScreen> createState() => _KwgScreenState();
}

class _KwgScreenState extends ConsumerState<KwgScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _lotBaseCtrl = TextEditingController();
  final List<_OdmGCtrl> _odm = [_OdmGCtrl()];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _initLot();
  }

  Future<void> _initLot() async {
    final d = widget.data;
    if (d.kwgType.isEmpty) {
      // Inny owoc — stary format, LOT bazowy edytowalny
      _lotBaseCtrl.text = d.lotBase;
    }
    // Rylex/Grójecka: użytkownik wpisuje nr dostawy sam, nie auto-generujemy
  }

  bool get isRG => widget.data.kwgType.isNotEmpty;

  String _nrForOdm(_OdmGCtrl o) =>
      o.nrCtrl.text.trim().isNotEmpty
          ? o.nrCtrl.text.trim()
          : _lotBaseCtrl.text.trim();

  /// Zwraca unikalny LOT dla każdej odmiany.
  /// Gdy kilka odmian ma ten sam nr dostawy, pierwsza dostaje bazowy LOT,
  /// kolejne dostają suffix 2, 3, itd. (np. "81/123/G-O", "81/123/G-O2").
  List<String> _computeAllLots() {
    if (!isRG) {
      final lotBase = _lotBaseCtrl.text.trim().isNotEmpty
          ? _lotBaseCtrl.text.trim()
          : widget.data.lotBase;
      return List.generate(_odm.length,
          (i) => _odm.length <= 1 || i == 0 ? lotBase : '$lotBase${i + 1}');
    }

    // Policz ile odmian dzieli ten sam nr dostawy
    final nrCount = <String, int>{};
    for (final o in _odm) {
      final nr = _nrForOdm(o);
      nrCount[nr] = (nrCount[nr] ?? 0) + 1;
    }

    // Przypisz unikalne LOT-y
    final nrIndex = <String, int>{};
    return List.generate(_odm.length, (i) {
      final o   = _odm[i];
      final nr  = _nrForOdm(o);
      final base = '$nr/${widget.data.kwgType}-${widget.data.przeznaczenieKod}';
      final total = nrCount[nr] ?? 1;
      final idx   = nrIndex[nr] ?? 0;
      nrIndex[nr] = idx + 1;
      return total <= 1 || idx == 0 ? base : '$base${idx + 1}';
    });
  }

  @override
  void dispose() {
    for (final o in _odm) {
      o.dispose();
    }
    super.dispose();
  }

  // ── Zapis do Firestore ───────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);

    final session  = ref.read(currentSessionProvider);
    final userId   = session?.user.id   ?? 'unknown';
    final userName = session?.user.name ?? '';
    final d       = widget.data;
    final db      = FirebaseFirestore.instance;
    final batch   = db.batch();

    final isRG    = d.kwgType.isNotEmpty; // Rylex lub Grójecka
    final total   = _odm.length;
    final allLots = _computeAllLots();
    final docIds  = <String>[];
    for (int i = 0; i < total; i++) {
      final o   = _odm[i];
      final lot = allLots[i];
      final docId  = lot.replaceAll('/', '_');
      docIds.add(docId);
      final wagaNetto = double.tryParse(o.wagaNettoCtrl.text.replaceAll(',', '.').trim()) ?? 0;
      final skrz   = '${o.drewCtrl.text.trim()}/${o.plastCtrl.text.trim()}';

      // Data: dla RG - indywidualna data odmiany (lub BRAK), dla innych - data z WSG
      final dataOdm = isRG ? o.dataDostawy : d.data;
      final dateStr = (isRG && o.dataBrak)
          ? ''
          : '${dataOdm.year}-${dataOdm.month.toString().padLeft(2,'0')}-${dataOdm.day.toString().padLeft(2,'0')}';
      // Skrzynie: liczba i wagi — z grup jeśli rozneWagi, inaczej z pól
      final int drewCnt, plastCnt;
      final double? drewWagaJedn, plastWagaJedn;
      final List<Map<String, dynamic>> wagiGrupyData;
      if (o.rozneWagi && o.wagiGrupy.isNotEmpty) {
        var dIl = 0; var pIl = 0; var dTara = 0.0; var pTara = 0.0;
        wagiGrupyData = [];
        for (final g in o.wagiGrupy) {
          final il = g.ilosc; final wg = g.wagaJedn;
          wagiGrupyData.add({'typ': g.typ, 'ilosc': il, 'waga': wg});
          if (g.typ == 'drew') { dIl += il; dTara += il * wg; }
          else                 { pIl += il; pTara += il * wg; }
        }
        drewCnt      = dIl;
        plastCnt     = pIl;
        drewWagaJedn  = dIl > 0 ? dTara / dIl : null;
        plastWagaJedn = pIl > 0 ? pTara / pIl : null;
      } else {
        drewCnt       = int.tryParse(o.drewCtrl.text.trim()) ?? 0;
        plastCnt      = int.tryParse(o.plastCtrl.text.trim()) ?? 0;
        drewWagaJedn  = double.tryParse(o.drewWagaCtrl.text.replaceAll(',', '.').trim());
        plastWagaJedn = double.tryParse(o.plastWagaCtrl.text.replaceAll(',', '.').trim());
        wagiGrupyData = [];
      }
      final mbDrewCnt     = int.tryParse(o.mbDrewCtrl.text.trim()) ?? 0;

      final delRef = db.collection(AppConstants.colDeliveries).doc(docId);
      batch.set(delRef, {
        'id':                lot,
        'lot':               lot,
        'data':              dateStr,
        'nr_dostawy':        isRG ? _nrForOdm(o) : d.nrDostawy,
        'dostawca':          d.dostawcaNazwa,
        'dostawca_kod':      d.dostawcaKod,
        'przeznaczenie':     d.przeznaczenie,
        'przeznaczenie_kod': d.przeznaczenieKod,
        'owoc':              d.owoc,
        'odmiana':           o.nazwaCtrl.text.trim(),
        'skrzynie':          skrz,
        'skrzynie_drew':     drewCnt,
        'skrzynie_plast':    plastCnt,
        'skrzynie_mb_drew':  mbDrewCnt,
        'skrzynie_mb_plast': int.tryParse(o.mbPlastCtrl.text.trim()) ?? 0,
        'waga_netto':        wagaNetto > 0 ? wagaNetto.toStringAsFixed(2) : '',
        'waga_netto_brak':         wagaNetto == 0 && isRG,
        'data_dostarczenia_brak': isRG && o.dataBrak,
        'brix':              o.brixCtrl.text.trim(),
        'odpad':             isRG ? '' : o.odpadCtrl.text.trim(),
        'twardosc':          o.twardCtrl.text.trim(),
        'zwrot_pct':         isRG ? '' : o.zwrotCtrl.text.trim(),
        'is_kwg':            true,
        'kwg_type':          d.kwgType,
        'data_wsg':          '${d.data.year}-${d.data.month.toString().padLeft(2,'0')}-${d.data.day.toString().padLeft(2,'0')}',
        'status':            'PRZESŁANO',
        'stan_opakowania':   'DOBRY',
        'stan_samochodu':    'DOBRY',
        'createdBy':         userId,
        'createdByName':     userName,
        if (mbDrewCnt > 0) ...{
          'mb_drew_il':   mbDrewCnt,
          'mb_drew_waga': double.tryParse(o.mbDrewWagaCtrl.text.replaceAll(',', '.').trim()) ?? 60.0,
        },
        if ((int.tryParse(o.mbPlastCtrl.text.trim()) ?? 0) > 0) ...{
          'mb_plast_il':   int.tryParse(o.mbPlastCtrl.text.trim()) ?? 0,
          'mb_plast_waga': double.tryParse(o.mbPlastWagaCtrl.text.replaceAll(',', '.').trim()) ?? 10.0,
        },
        if (drewWagaJedn != null) ...{'drew_waga_jedn': drewWagaJedn, 'drew_waga_set': true},
        if (plastWagaJedn != null) ...{'plast_waga_jedn': plastWagaJedn, 'plast_waga_set': true},
        if (o.rozneWagi && wagiGrupyData.isNotEmpty) ...{
          'rozne_wagi': true,
          'wagi_grupy': wagiGrupyData,
        },
        'createdAt':         FieldValue.serverTimestamp(),
      });

      // crateStates — stany skrzyń KWG (domyślne wagi: drew=20kg, plast=10kg)
      final crateRef = db.collection(AppConstants.colCrateStates).doc(docId);
      batch.set(crateRef, {
        'lot':             lot,
        'odmiana':         o.nazwaCtrl.text.trim(),
        'owoc':            d.owoc,
        'dostawca':        d.dostawcaNazwa,
        'dostawca_kod':    d.dostawcaKod,
        'przeznaczenie':   d.przeznaczenie,
        'nr_dostawy':      d.nrDostawy,
        'data':            dateStr,
        'drew_total':      drewCnt,
        'plast_total':     plastCnt,
        'drew_remaining':  drewCnt,
        'plast_remaining': plastCnt,
        if (mbDrewCnt > 0) ...{
          'mb_drew_il':   mbDrewCnt,
          'mb_drew_waga': double.tryParse(o.mbDrewWagaCtrl.text.replaceAll(',', '.').trim()) ?? 60.0,
        },
        if ((int.tryParse(o.mbPlastCtrl.text.trim()) ?? 0) > 0) ...{
          'mb_plast_il':   int.tryParse(o.mbPlastCtrl.text.trim()) ?? 0,
          'mb_plast_waga': double.tryParse(o.mbPlastWagaCtrl.text.replaceAll(',', '.').trim()) ?? 10.0,
        },
        if (drewWagaJedn != null) ...{'drew_waga_jedn': drewWagaJedn, 'drew_waga_set': true},
        if (plastWagaJedn != null) ...{'plast_waga_jedn': plastWagaJedn, 'plast_waga_set': true},
        if (o.rozneWagi && wagiGrupyData.isNotEmpty) ...{
          'rozne_wagi': true,
          'wagi_grupy': wagiGrupyData,
        },
        'kg_total':        wagaNetto,
        'kg_remaining':    wagaNetto,
        'active':          (drewCnt + plastCnt) > 0,
        'is_kwg':          true,
        'kwg_type':        d.kwgType,
        'createdAt':       FieldValue.serverTimestamp(),
      });

      // mcrQueue
      final mcrRef = db.collection(AppConstants.colMcrQueue).doc();
      batch.set(mcrRef, {
        'lot':          lot,
        'czas':         '${d.data.year}-${d.data.month.toString().padLeft(2,'0')}-${d.data.day.toString().padLeft(2,'0')}',
        'akcja':        'Przyjecie',
        'waga_netto':   wagaNetto.toStringAsFixed(2),
        'owoc':         d.owoc,
        'odmiana':      o.nazwaCtrl.text.trim(),
        'przeznaczenie':d.przeznaczenie,
        'status':       'done',
        'createdAt':    FieldValue.serverTimestamp(),
      });
    }

    try {
      await batch.commit().timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw TimeoutException('Przekroczono czas zapisu (20s). Sprawdź połączenie.'),
      );
      if (mounted) {
        await _showSaveDialog();
        if (mounted) context.go('/pls');
      }
    } catch (e) {
      if (mounted) {
        showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            icon: const Icon(Icons.error_outline, color: AppTheme.errorRed, size: 40),
            title: const Text('Błąd zapisu'),
            content: Text(e.toString()),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted && _saving) setState(() => _saving = false);
    }
  }

  bool _hasData() => _odm.any((o) =>
      o.nazwaCtrl.text.isNotEmpty ||
      o.nrCtrl.text.isNotEmpty ||
      o.wagaNettoCtrl.text.isNotEmpty ||
      o.drewCtrl.text.isNotEmpty ||
      o.plastCtrl.text.isNotEmpty);

  Future<void> _confirmReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Odrzuć kartę?'),
        content: const Text('Wszystkie wpisane dane zostaną usunięte.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            child: const Text('Odrzuć'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      ref.read(wsgResetKeyProvider.notifier).state++;
      context.go('/wsg/new');
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (!_hasData()) { if (mounted) context.go('/wsg/new'); return; }
        await _confirmReset();
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: const Text('Karta Ważenia G'),
          leading: BackButton(onPressed: () async {
            if (!_hasData()) { context.go('/wsg/new'); return; }
            await _confirmReset();
          }),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _headerCard(d),
              const SizedBox(height: 12),
              // Dla innych owoc (nie Rylex/Grójecka): LOT bazowy edytowalny
              if (d.kwgType.isEmpty) ...[
                _KwgCard(
                  title: 'LOT bazowy',
                  child: TextFormField(
                    controller: _lotBaseCtrl,
                    decoration: const InputDecoration(
                      labelText: 'LOT (edytowalny)',
                      hintText: 'W/001/2104',
                      prefixIcon: Icon(Icons.qr_code_outlined, size: 18),
                    ),
                    style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              _odmiawyHeader(),
              ..._odm.asMap().entries.map((e) => _odmCard(e.key, e.value)),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: OutlinedButton.icon(
                  onPressed: _addOdmiana,
                  icon: const Icon(Icons.add),
                  label: const Text('Dodaj odmianę'),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _saving ? null : _confirmReset,
                icon: const Icon(Icons.delete_sweep_outlined, color: AppTheme.errorRed),
                label: const Text('Odrzuć kartę ważenia',
                    style: TextStyle(color: AppTheme.errorRed)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.errorRed),
                  minimumSize: const Size(double.infinity, 44),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Zapisz kartę KWG'),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerCard(WsgInputData d) {
    final dateStr =
        '${d.data.day.toString().padLeft(2,'0')}.${d.data.month.toString().padLeft(2,'0')}.${d.data.year}';
    return _KwgCard(
      title: 'Dane dostawy',
      child: Column(
        children: [
          _Row('Data',           dateStr),
          _Row('Nr dostawy',     d.nrDostawy),
          _Row('Dostawca',       '${d.dostawcaKod} — ${d.dostawcaNazwa}'),
          _Row('Przeznaczenie',  d.przeznaczenie),
          _Row('Owoc',           d.owoc),
          _Row('LOT bazowy',     d.lotBase),
        ],
      ),
    );
  }

  Widget _infoCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.warningOrange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.warningOrange.withValues(alpha: 0.4)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: AppTheme.warningOrange, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'KWG: waga netto surowca podawana przez dostawcę. '
              'Brak ważenia własnego.',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _odmiawyHeader() {
    return const Padding(
      padding: EdgeInsets.only(bottom: 6, left: 2),
      child: Text(
        'ODMIANY',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppTheme.textSecondary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _odmCard(int idx, _OdmGCtrl o) {
    final kod      = widget.data.przeznaczenieKod;
    final showTward = kod == 'S' || kod == 'O';
    final showOdpad = !widget.data.isRylex && !widget.data.isGrojecka;

    return _KwgCard(
      title: 'Odmiana ${idx + 1}',
      trailing: _odm.length > 1
          ? IconButton(
              icon: const Icon(Icons.delete_outline, color: AppTheme.errorRed),
              onPressed: () => _removeOdmiana(idx),
            )
          : null,
      child: Column(
        children: [
          // Dla Rylex/Grójecka: indywidualny numer + data odmiany
          if (isRG) ...[
            Row(children: [
              Expanded(
                flex: 2,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1565C0).withAlpha(18),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF1565C0), width: 1.5),
                  ),
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.tag, color: Color(0xFF1565C0), size: 14),
                          SizedBox(width: 4),
                          Text(
                            'NR DOSTAWY',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1565C0),
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      TextFormField(
                        controller: o.nrCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Wpisz nr dostawy...',
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 4),
                        ),
                        style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w600),
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFE65100).withAlpha(18),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE65100), width: 1.5),
                  ),
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.calendar_today_outlined, color: Color(0xFFE65100), size: 14),
                          SizedBox(width: 4),
                          Text(
                            'DATA DOSTARCZENIA',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFE65100),
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: o.dataBrak ? null : () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: o.dataDostawy,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                            locale: const Locale('pl'),
                          );
                          if (picked != null) setState(() => o.dataDostawy = picked);
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              o.dataBrak
                                  ? 'BRAK'
                                  : '${o.dataDostawy.day.toString().padLeft(2,'0')}.${o.dataDostawy.month.toString().padLeft(2,'0')}.${o.dataDostawy.year}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: o.dataBrak ? AppTheme.textSecondary : null,
                                fontStyle: o.dataBrak ? FontStyle.italic : null,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setState(() => o.dataBrak = !o.dataBrak),
                              child: Text(
                                o.dataBrak ? 'Wpisz datę' : 'Brak daty',
                                style: const TextStyle(fontSize: 11, color: AppTheme.primaryMid),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Pierwotna data dostarczenia surowca',
                        style: TextStyle(fontSize: 9, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 8),
          ],
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32).withAlpha(18),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF2E7D32), width: 1.5),
            ),
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2, bottom: 4),
                  child: Row(
                    children: [
                      Icon(Icons.eco_outlined, color: Color(0xFF2E7D32), size: 14),
                      SizedBox(width: 4),
                      Text(
                        'NAZWA ODMIANY',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2E7D32),
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
                TextFormField(
                  controller: o.nazwaCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Wpisz odmianę...',
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 4),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _KwgNumField(
            isRG ? 'Waga netto [kg] (do korekty)' : 'Waga netto [kg]',
            o.wagaNettoCtrl,
            required: !isRG,
          ),
          const SizedBox(height: 8),
          if (!o.rozneWagi) ...[
            Row(children: [
              Expanded(child: _KwgNumField('Skrzynie drew.', o.drewCtrl)),
              const SizedBox(width: 8),
              Expanded(child: _KwgNumField('Skrzynie plast.', o.plastCtrl)),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: _KwgNumField('Waga skrzyni drew. [kg]', o.drewWagaCtrl)),
              const SizedBox(width: 8),
              Expanded(child: _KwgNumField('Waga skrzyni plast. [kg]', o.plastWagaCtrl)),
            ]),
          ],
          // Toggle: różne wagi skrzyń
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Czy skrzynie mają różną wagę?',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: const Text('Zaznacz jeśli skrzynie mają różne wagi jednostkowe',
                style: TextStyle(fontSize: 11)),
            value: o.rozneWagi,
            onChanged: (v) => setState(() => o.rozneWagi = v),
          ),
          if (o.rozneWagi) ...[
            const SizedBox(height: 4),
            ...o.wagiGrupy.asMap().entries.map((e) => _wagaGrupaRow(o, e.key, e.value)),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => o.wagiGrupy.add(_WagaGrupa())),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Dodaj grupę'),
              ),
            ),
            const SizedBox(height: 4),
          ],
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => setState(() => o.mbVisible = !o.mbVisible),
            child: Row(children: [
              Icon(o.mbVisible ? Icons.expand_less : Icons.expand_more,
                  size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              const Text('Skrzynie MB',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              const SizedBox(width: 6),
              if (!o.mbVisible && (int.tryParse(o.mbDrewCtrl.text) ?? 0) + (int.tryParse(o.mbPlastCtrl.text) ?? 0) > 0)
                Text(
                  '${o.mbDrewCtrl.text}D / ${o.mbPlastCtrl.text}P',
                  style: const TextStyle(fontSize: 12, color: AppTheme.warningOrange,
                      fontWeight: FontWeight.w600),
                ),
            ]),
          ),
          if (o.mbVisible) ...[
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: _KwgNumField('Sk. MB drew.', o.mbDrewCtrl)),
              const SizedBox(width: 8),
              Expanded(child: _KwgNumField('Waga 1 szt. MB drew. [kg]', o.mbDrewWagaCtrl)),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: _KwgNumField('Sk. MB plast.', o.mbPlastCtrl)),
              const SizedBox(width: 8),
              Expanded(child: _KwgNumField('Waga 1 szt. MB plast. [kg]', o.mbPlastWagaCtrl)),
            ]),
          ],
          const SizedBox(height: 8),
          // Zwrot wysuwany — ukryty dla Rylex/Grójecka
          if (!isRG) GestureDetector(
            onTap: () => setState(() => o.zwrotVisible = !o.zwrotVisible),
            child: Row(children: [
              Icon(o.zwrotVisible ? Icons.expand_less : Icons.expand_more,
                  size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              const Text('Zwrot [%]',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              const SizedBox(width: 6),
              if (!o.zwrotVisible && (double.tryParse(o.zwrotCtrl.text) ?? 0) > 0)
                Text('${o.zwrotCtrl.text}%',
                    style: const TextStyle(fontSize: 12, color: AppTheme.warningOrange,
                        fontWeight: FontWeight.w600)),
            ]),
          ),
          if (o.zwrotVisible) ...[
            const SizedBox(height: 6),
            SizedBox(
              width: 120,
              child: _KwgNumField('Zwrot [%]', o.zwrotCtrl),
            ),
          ],
          if (!isRG) const Divider(height: 16),
          if (isRG) const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _KwgNumField('BRIX', o.brixCtrl)),
            if (showOdpad) ...[
              const SizedBox(width: 8),
              Expanded(child: _KwgNumField('ODPAD [%]', o.odpadCtrl)),
            ],
          ]),
          if (showTward) ...[
            const SizedBox(height: 8),
            _KwgNumField('Twardość [kG/cm²]', o.twardCtrl),
          ],
          const SizedBox(height: 8),
          TextFormField(
            controller: o.infoCtrl,
            decoration: const InputDecoration(
              labelText: 'Dodatkowe informacje (opcjonalne)',
              hintText: 'np. 5 skrzyń z 2024-03-10 od Kowalski',
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            icon: const Icon(Icons.label, size: 16),
            label: const Text('Drukuj etykietę'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 40),
              backgroundColor: AppTheme.primaryMid,
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            onPressed: () => _drukujEtykieteOdmiany(idx, o),
          ),
        ],
      ),
    );
  }

  Future<void> _drukujEtykieteOdmiany(int idx, _OdmGCtrl o) async {
    if (isRG && o.nrCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Wpisz nr dostawy przed drukowaniem etykiety'),
        backgroundColor: AppTheme.errorRed,
      ));
      return;
    }
    if (o.nazwaCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Wpisz nazwę odmiany przed drukowaniem etykiety'),
        backgroundColor: AppTheme.errorRed,
      ));
      return;
    }
    final d   = widget.data;
    final lot = _computeAllLots()[idx];
    final dateStr = '${d.data.day.toString().padLeft(2,'0')}.${d.data.month.toString().padLeft(2,'0')}.${d.data.year}';
    final dataDostarczenia = (isRG && !o.dataBrak)
        ? '${o.dataDostawy.day.toString().padLeft(2,'0')}.${o.dataDostawy.month.toString().padLeft(2,'0')}.${o.dataDostawy.year}'
        : '';
    final label = KwLabelData(
      lot:              lot,
      odmiana:          o.nazwaCtrl.text.trim().isNotEmpty ? o.nazwaCtrl.text.trim() : d.owoc,
      data:             dateStr,
      dataDostarczenia: dataDostarczenia,
      dostawca:         d.dostawcaNazwa,
      dostawcaKod:      d.dostawcaKod,
      przeznaczenie:    d.przeznaczenie,
    );
    await Printing.layoutPdf(
      name: 'Etykieta_$lot',
      onLayout: (_) => KwLabelGenerator.generate([label]),
    );
  }

  Future<void> _showSaveDialog() async {
    final d       = widget.data;
    final total   = _odm.length;
    final dateStr = '${d.data.day.toString().padLeft(2,'0')}.${d.data.month.toString().padLeft(2,'0')}.${d.data.year}';
    final allLots = _computeAllLots();

    final labels = List.generate(total, (i) {
      final o   = _odm[i];
      final lot = allLots[i];
      final dataDostarczenia = (isRG && !o.dataBrak)
          ? '${o.dataDostawy.day.toString().padLeft(2,'0')}.${o.dataDostawy.month.toString().padLeft(2,'0')}.${o.dataDostawy.year}'
          : '';
      return KwLabelData(
        lot: lot,
        odmiana: o.nazwaCtrl.text.trim().isNotEmpty ? o.nazwaCtrl.text.trim() : d.owoc,
        data: dateStr,           // zawsze data z WSG po prawej
        dataDostarczenia: dataDostarczenia,
        dostawca: d.dostawcaNazwa,
        dostawcaKod: d.dostawcaKod,
        przeznaczenie: d.przeznaczenie,
      );
    });

    while (mounted) {
      final choice = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: AppTheme.successGreen, size: 48),
          title: const Text('Karta KWG zapisana'),
          content: const Text('Co chcesz wydrukować?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'done'),
              child: const Text('Gotowe'),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.label_outline, size: 18),
              label: const Text('Etykiety'),
              onPressed: () => Navigator.pop(context, 'label'),
            ),
          ],
        ),
      );
      if (!mounted || choice == null || choice == 'done') break;
      if (choice == 'label') {
        if (labels.length == 1) {
          await Printing.layoutPdf(
            name: 'Etykieta_${labels[0].lot}',
            onLayout: (_) => KwLabelGenerator.generate(labels),
          );
        } else {
          final idx = await showDialog<int>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Wybierz etykietę'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...List.generate(labels.length, (i) => ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primaryMid,
                      child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 13)),
                    ),
                    title: Text(labels[i].odmiana),
                    onTap: () => Navigator.pop(context, i),
                  )),
                  const Divider(),
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppTheme.accent,
                      child: Icon(Icons.select_all, color: Colors.white, size: 18),
                    ),
                    title: const Text('Wszystkie'),
                    onTap: () => Navigator.pop(context, -1),
                  ),
                ],
              ),
            ),
          );
          if (idx != null && mounted) {
            final toPrint = idx == -1 ? labels : [labels[idx]];
            await Printing.layoutPdf(
              name: 'Etykieta_${toPrint[0].lot}',
              onLayout: (_) => KwLabelGenerator.generate(toPrint),
            );
          }
        }
      }
    }
  }

  Widget _wagaGrupaRow(_OdmGCtrl o, int idx, _WagaGrupa g) {
    final subtara = g.tara;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          SizedBox(
            width: 120,
            child: DropdownButtonFormField<String>(
              value: g.typ,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'drew',  child: Text('Drew.')),
                DropdownMenuItem(value: 'plast', child: Text('Plast.')),
              ],
              onChanged: (v) => setState(() => g.typ = v!),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: _KwgNumField('Ilość szt.', g.iloscCtrl)),
          const SizedBox(width: 8),
          Expanded(child: _KwgNumField('Waga 1 szt. [kg]', g.wagaCtrl)),
          if (o.wagiGrupy.length > 1)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => setState(() {
                g.dispose();
                o.wagiGrupy.removeAt(idx);
              }),
            )
          else
            const SizedBox(width: 40),
        ]),
        if (subtara > 0)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 2),
            child: Text(
              'TARA grupy ${idx + 1}: ${subtara.toStringAsFixed(0)} kg',
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ),
      ]),
    );
  }

  void _addOdmiana() => setState(() => _odm.add(_OdmGCtrl()));

  void _removeOdmiana(int idx) {
    _odm[idx].dispose();
    setState(() => _odm.removeAt(idx));
  }
}

// ── Drobne widgety KWG ────────────────────────────────────────────────────────

class _KwgCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  const _KwgCard({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _KwgNumField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final bool required;
  const _KwgNumField(this.label, this.ctrl, {this.required = false});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl,
      decoration: InputDecoration(labelText: label),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Wymagane' : null
          : null,
    );
  }
}
