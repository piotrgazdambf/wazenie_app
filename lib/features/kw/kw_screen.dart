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
import 'kw_label_generator.dart';
import 'kw_pdf_generator.dart';

// ── Pomocnicza klasa kontrolerów odmiany ──────────────────────────────────────

class _OdmCtrl {
  final nazwaCtrl   = TextEditingController();
  final drewCtrl    = TextEditingController();
  final plastCtrl   = TextEditingController();
  final zwrotCtrl   = TextEditingController(text: '0');
  final brixCtrl    = TextEditingController();
  final odpadCtrl   = TextEditingController();
  final twardCtrl   = TextEditingController();
  final pwCtrl      = TextEditingController();

  double wagaNetto = 0;

  void dispose() {
    nazwaCtrl.dispose();
    drewCtrl.dispose();
    plastCtrl.dispose();
    zwrotCtrl.dispose();
    brixCtrl.dispose();
    odpadCtrl.dispose();
    twardCtrl.dispose();
    pwCtrl.dispose();
  }
}

// ── Ekran Karty Ważenia ───────────────────────────────────────────────────────

class KwScreen extends ConsumerStatefulWidget {
  final WsgInputData data;
  const KwScreen({super.key, required this.data});

  @override
  ConsumerState<KwScreen> createState() => _KwScreenState();
}

class _KwScreenState extends ConsumerState<KwScreen> {
  final _formKey = GlobalKey<FormState>();

  // Dane pojazdu
  final _nrPojazduCtrl  = TextEditingController();
  final _nrTelefonuCtrl = TextEditingController();

  // Wagi aut
  final _a1ZalCtrl  = TextEditingController();
  final _a1RozCtrl  = TextEditingController();
  bool  _drugiAut   = false;
  final _a2ZalCtrl  = TextEditingController();
  final _a2RozCtrl  = TextEditingController();

  // Skrzynie dostawcy
  final _drewIlCtrl  = TextEditingController();
  final _drewWgCtrl  = TextEditingController(text: '20');
  final _plastIlCtrl = TextEditingController();
  final _plastWgCtrl = TextEditingController(text: '10');

  // Skrzynie MB (własne MBF)
  bool  _maMbSkrzynie  = false;
  final _mbDrewIlCtrl  = TextEditingController();
  final _mbDrewWgCtrl  = TextEditingController(text: '20');
  final _mbPlastIlCtrl = TextEditingController();
  final _mbPlastWgCtrl = TextEditingController(text: '10');

  // Wyniki (auto)
  double _brutto    = 0;
  double _taraDrew  = 0;
  double _taraPlast = 0;
  double _taraMb    = 0;
  double _netto     = 0;

  // Odmiany
  final List<_OdmCtrl> _odm = [_OdmCtrl()];

  // Stan
  String _stanOpak = 'DOBRY';
  String _stanAuto = 'DOBRY';

  bool _saving = false;

  // ── Init / Dispose ───────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    final callers = [
      _a1ZalCtrl, _a1RozCtrl, _a2ZalCtrl, _a2RozCtrl,
      _drewIlCtrl, _drewWgCtrl, _plastIlCtrl, _plastWgCtrl,
      _mbDrewIlCtrl, _mbDrewWgCtrl, _mbPlastIlCtrl, _mbPlastWgCtrl,
    ];
    for (final c in callers) {
      c.addListener(_recalc);
    }
    for (final o in _odm) {
      _listenOdm(o);
    }
  }

  void _listenOdm(_OdmCtrl o) {
    for (final c in [o.drewCtrl, o.plastCtrl, o.zwrotCtrl]) {
      c.addListener(_recalc);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _nrPojazduCtrl, _nrTelefonuCtrl,
      _a1ZalCtrl, _a1RozCtrl, _a2ZalCtrl, _a2RozCtrl,
      _drewIlCtrl, _drewWgCtrl, _plastIlCtrl, _plastWgCtrl,
      _mbDrewIlCtrl, _mbDrewWgCtrl, _mbPlastIlCtrl, _mbPlastWgCtrl,
    ]) {
      c.dispose();
    }
    for (final o in _odm) {
      o.dispose();
    }
    super.dispose();
  }

  // ── Kalkulacje ───────────────────────────────────────────────────────────────

  static double _p(String v) =>
      double.tryParse(v.replaceAll(',', '.').trim()) ?? 0;
  static int _pi(String v) => int.tryParse(v.trim()) ?? 0;

  void _recalc() {
    final a1z = _p(_a1ZalCtrl.text);
    final a1r = _p(_a1RozCtrl.text);
    final a2z = _drugiAut ? _p(_a2ZalCtrl.text) : 0;
    final a2r = _drugiAut ? _p(_a2RozCtrl.text) : 0;

    final tDrew  = _pi(_drewIlCtrl.text);
    final tPlast = _pi(_plastIlCtrl.text);
    final wDrew  = _p(_drewWgCtrl.text);
    final wPlast = _p(_plastWgCtrl.text);

    final mbDrew   = _maMbSkrzynie ? _pi(_mbDrewIlCtrl.text)  : 0;
    final mbPlast  = _maMbSkrzynie ? _pi(_mbPlastIlCtrl.text) : 0;
    final wMbDrew  = _maMbSkrzynie ? _p(_mbDrewWgCtrl.text)   : 0.0;
    final wMbPlast = _maMbSkrzynie ? _p(_mbPlastWgCtrl.text)  : 0.0;

    final brutto    = (a1z - a1r) + (a2z - a2r);
    final taraDrew  = tDrew  * wDrew;
    final taraPlast = tPlast * wPlast;
    final taraMb    = mbDrew * wMbDrew + mbPlast * wMbPlast;
    final netto     = brutto - taraDrew - taraPlast - taraMb;

    for (final o in _odm) {
      o.wagaNetto = KwCalculations.wagaNettoOdmiany(
        wagaNettoTotal: netto,
        skrzDrew:  _pi(o.drewCtrl.text),
        skrzPlast: _pi(o.plastCtrl.text),
        totalDrew:  tDrew,
        totalPlast: tPlast,
        wagaJednejDrew:  wDrew,
        wagaJednejPlast: wPlast,
        zwrotPct:  _p(o.zwrotCtrl.text),
        odpadPct:  _p(o.odpadCtrl.text),
      );
    }

    setState(() {
      _brutto    = brutto;
      _taraDrew  = taraDrew;
      _taraPlast = taraPlast;
      _taraMb    = taraMb;
      _netto     = netto;
    });
  }

  // ── Sprawdzenie twardości ────────────────────────────────────────────────────

  Future<bool> _checkTwardosc() async {
    final kod = widget.data.przeznaczenieKod;
    if (kod != 'S' && kod != 'O') return true;

    for (final o in _odm) {
      final t = _p(o.twardCtrl.text);
      if (o.twardCtrl.text.isNotEmpty && t < 4.5) {
        final go = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Niska twardość!'),
            content: Text(
              'Odmiana "${o.nazwaCtrl.text.isEmpty ? "bez nazwy" : o.nazwaCtrl.text}" '
              'ma twardość $t < 4,5.\n\nCzy przekazać surowiec na PRZECIER?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Nie, zostaw'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Tak, na przecier'),
              ),
            ],
          ),
        );
        if (go == true) return false; // użytkownik chce zmienić przeznaczenie
      }
    }
    return true;
  }

  // ── Zapis do Firestore ───────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_netto <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Waga netto musi być > 0')),
      );
      return;
    }

    final ok = await _checkTwardosc();
    if (!ok) return;

    setState(() => _saving = true);

    final session = ref.read(currentSessionProvider);
    final userId  = session?.user.id ?? 'unknown';
    final d       = widget.data;
    final db      = FirebaseFirestore.instance;
    final batch   = db.batch();

    final total = _odm.length;
    for (int i = 0; i < total; i++) {
      final o   = _odm[i];
      final lot   = d.lotForOdmiana(i, total);
      final docId        = lot.replaceAll('/', '_');
      final skrz         = '${_pi(o.drewCtrl.text)}/${_pi(o.plastCtrl.text)}';
      final drewWagaJedn  = _p(_drewWgCtrl.text);
      final plastWagaJedn = _p(_plastWgCtrl.text);
      final drewCount     = _pi(o.drewCtrl.text);
      final plastCount    = _pi(o.plastCtrl.text);
      final mbDrewCount   = _maMbSkrzynie ? _pi(_mbDrewIlCtrl.text)  : 0;
      final mbPlastCount  = _maMbSkrzynie ? _pi(_mbPlastIlCtrl.text) : 0;
      final mbDrewWaga    = _maMbSkrzynie ? _p(_mbDrewWgCtrl.text)   : 0.0;
      final mbPlastWaga   = _maMbSkrzynie ? _p(_mbPlastWgCtrl.text)  : 0.0;
      final dateStr       = '${d.data.year}-${d.data.month.toString().padLeft(2,'0')}-${d.data.day.toString().padLeft(2,'0')}';

      // deliveries
      final delRef = db.collection(AppConstants.colDeliveries).doc(docId);
      batch.set(delRef, {
        'id':                lot,
        'lot':               lot,
        'data':              dateStr,
        'nr_dostawy':        d.nrDostawy,
        'dostawca':          d.dostawcaNazwa,
        'dostawca_kod':      d.dostawcaKod,
        'przeznaczenie':     d.przeznaczenie,
        'przeznaczenie_kod': d.przeznaczenieKod,
        'owoc':              d.owoc,
        'odmiana':           o.nazwaCtrl.text.trim(),
        'skrzynie':          skrz,
        'skrzynie_drew':     drewCount,
        'skrzynie_plast':    plastCount,
        'drew_waga_jedn':    drewWagaJedn,
        'plast_waga_jedn':   plastWagaJedn,
        'waga_netto':        o.wagaNetto.toStringAsFixed(2),
        'brix':              o.brixCtrl.text.trim(),
        'odpad':             o.odpadCtrl.text.trim(),
        'twardosc':          o.twardCtrl.text.trim(),
        'kaliber':           o.pwCtrl.text.trim(),
        'zwrot_pct':         o.zwrotCtrl.text.trim(),
        'stan_opakowania':   _stanOpak,
        'stan_samochodu':    _stanAuto,
        'waga_brutto':       _brutto.toStringAsFixed(2),
        'waga_netto_total':  _netto.toStringAsFixed(2),
        'waga_a1_zal':       _p(_a1ZalCtrl.text),
        'waga_a1_roz':       _p(_a1RozCtrl.text),
        'waga_a2_zal':       _drugiAut ? _p(_a2ZalCtrl.text) : 0,
        'waga_a2_roz':       _drugiAut ? _p(_a2RozCtrl.text) : 0,
        // Skrzynie MB
        if (_maMbSkrzynie) ...{
          'mb_drew_il':    mbDrewCount,
          'mb_drew_waga':  mbDrewWaga,
          'mb_plast_il':   mbPlastCount,
          'mb_plast_waga': mbPlastWaga,
        },
        'status':            'PRZYJETO',
        'createdBy':         userId,
        'createdAt':         FieldValue.serverTimestamp(),
      });

      // crateStates — stany skrzyń
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
        'drew_total':      drewCount,
        'plast_total':     plastCount,
        'drew_remaining':  drewCount,
        'plast_remaining': plastCount,
        'drew_waga_jedn':  drewWagaJedn,
        'plast_waga_jedn': plastWagaJedn,
        'kg_total':        o.wagaNetto,
        'kg_remaining':    o.wagaNetto,
        'active':          (drewCount + plastCount) > 0 && o.wagaNetto > 0,
        'is_kwg':          false,
        'createdAt':       FieldValue.serverTimestamp(),
      });

      // crateState dla Skrzyń MB (osobny wpis informacyjny)
      if (_maMbSkrzynie && (mbDrewCount + mbPlastCount) > 0) {
        final mbRef = db.collection(AppConstants.colCrateStates).doc('${docId}_mb');
        batch.set(mbRef, {
          'lot':             '${lot}_MB',
          'odmiana':         o.nazwaCtrl.text.trim(),
          'owoc':            d.owoc,
          'dostawca':        'Skrzynie MB',
          'dostawca_kod':    'MB',
          'przeznaczenie':   d.przeznaczenie,
          'nr_dostawy':      d.nrDostawy,
          'data':            dateStr,
          'drew_total':      mbDrewCount,
          'plast_total':     mbPlastCount,
          'drew_remaining':  mbDrewCount,
          'plast_remaining': mbPlastCount,
          'drew_waga_jedn':  mbDrewWaga,
          'plast_waga_jedn': mbPlastWaga,
          'kg_total':        0,
          'kg_remaining':    0,
          'active':          true,
          'is_mb':           true,
          'is_kwg':          false,
          'createdAt':       FieldValue.serverTimestamp(),
        });
      }

      // mcrQueue
      final mcrRef = db.collection(AppConstants.colMcrQueue).doc();
      batch.set(mcrRef, {
        'lot':          lot,
        'czas':         '${d.data.year}-${d.data.month.toString().padLeft(2,'0')}-${d.data.day.toString().padLeft(2,'0')}',
        'akcja':        'Przyjecie',
        'waga_netto':   o.wagaNetto.toStringAsFixed(2),
        'owoc':         d.owoc,
        'odmiana':      o.nazwaCtrl.text.trim(),
        'przeznaczenie':d.przeznaczenie,
        'status':       'done',
        'createdAt':    FieldValue.serverTimestamp(),
      });
    }

    // Zbuduj dane PDF i etykiet przed commitem (pola mogą zostać wyczyszczone)
    final pdfData    = _buildPdfData();
    final labelData  = _buildLabels();

    try {
      await batch.commit().timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw TimeoutException('Przekroczono czas zapisu (20s). Sprawdź połączenie.'),
      );
      if (mounted) {
        await _showSaveDialog(pdfData, labelData);
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

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Karta Ważenia'),
        leading: BackButton(onPressed: () => context.go('/wsg/new')),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _headerCard(d),
            const SizedBox(height: 12),
            _wagiAutCard(),
            const SizedBox(height: 12),
            _skrzyniaCard(),
            const SizedBox(height: 12),
            _wynikCard(),
            const SizedBox(height: 12),
            _odmiawyHeader(),
            ..._odm.asMap().entries.map((e) => _odmCard(e.key, e.value)),
            if (_odm.length < 4)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: OutlinedButton.icon(
                  onPressed: _addOdmiana,
                  icon: const Icon(Icons.add),
                  label: const Text('Dodaj odmianę'),
                ),
              ),
            const SizedBox(height: 12),
            _stanCard(),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Zapisz kartę ważenia'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── Sekcje UI ────────────────────────────────────────────────────────────────

  Widget _headerCard(WsgInputData d) {
    final dateStr = '${d.data.day.toString().padLeft(2,'0')}.${d.data.month.toString().padLeft(2,'0')}.${d.data.year}';
    return _SectionCard(
      title: 'Dane dostawy',
      child: Column(
        children: [
          _InfoRow('Data',        dateStr),
          _InfoRow('Nr dostawy',  d.nrDostawy),
          _InfoRow('Dostawca',    '${d.dostawcaKod} — ${d.dostawcaNazwa}'),
          _InfoRow('Przeznaczenie', d.przeznaczenie),
          _InfoRow('Owoc',        d.owoc),
          _InfoRow('LOT bazowy',  d.lotBase),
          const SizedBox(height: 10),
          TextFormField(
            controller: _nrPojazduCtrl,
            decoration: const InputDecoration(labelText: 'Numer pojazdu'),
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _nrTelefonuCtrl,
            decoration: const InputDecoration(labelText: 'Numer telefonu kierowcy'),
            keyboardType: TextInputType.phone,
          ),
        ],
      ),
    );
  }

  Widget _wagiAutCard() {
    return _SectionCard(
      title: 'Wagi aut',
      child: Column(
        children: [
          _NumField('Waga auta I załadowanego [kg]',  _a1ZalCtrl, required: true),
          const SizedBox(height: 8),
          _NumField('Waga auta I rozładowanego [kg]', _a1RozCtrl, required: true),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Drugie auto'),
            value: _drugiAut,
            onChanged: (v) {
              setState(() => _drugiAut = v);
              _recalc();
            },
          ),
          if (_drugiAut) ...[
            _NumField('Waga auta II załadowanego [kg]',  _a2ZalCtrl),
            const SizedBox(height: 8),
            _NumField('Waga auta II rozładowanego [kg]', _a2RozCtrl),
          ],
        ],
      ),
    );
  }

  Widget _skrzyniaCard() {
    return _SectionCard(
      title: 'Skrzynie',
      child: Column(
        children: [
          // Skrzynie dostawcy
          Row(children: [
            Expanded(child: _NumField('Ilość skrzyń drew.', _drewIlCtrl)),
            const SizedBox(width: 8),
            Expanded(child: _NumField('Waga 1 szt. [kg]',  _drewWgCtrl)),
          ]),
          const SizedBox(height: 4),
          _AutoCalcRow('TARA drew.', _taraDrew),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _NumField('Ilość skrzyń plast.', _plastIlCtrl)),
            const SizedBox(width: 8),
            Expanded(child: _NumField('Waga 1 szt. [kg]',   _plastWgCtrl)),
          ]),
          const SizedBox(height: 4),
          _AutoCalcRow('TARA plast.', _taraPlast),
          const Divider(height: 20),
          // Skrzynie MB
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Czy są skrzynie MB?',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: const Text('Zaznacz jeśli kierowca przywiózł nasze własne skrzynie',
                style: TextStyle(fontSize: 12)),
            value: _maMbSkrzynie,
            onChanged: (v) {
              setState(() => _maMbSkrzynie = v);
              _recalc();
            },
          ),
          if (_maMbSkrzynie) ...[
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _NumField('Skrz. MB drew.', _mbDrewIlCtrl)),
              const SizedBox(width: 8),
              Expanded(child: _NumField('Waga 1 szt. MB [kg]', _mbDrewWgCtrl)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _NumField('Skrz. MB plast.', _mbPlastIlCtrl)),
              const SizedBox(width: 8),
              Expanded(child: _NumField('Waga 1 szt. MB [kg]', _mbPlastWgCtrl)),
            ]),
            const SizedBox(height: 4),
            _AutoCalcRow('TARA MB łącznie', _taraMb),
          ],
        ],
      ),
    );
  }

  Widget _wynikCard() {
    return _SectionCard(
      title: 'Wynik ważenia',
      child: Column(
        children: [
          _AutoCalcRow('WAGA BRUTTO [kg]',        _brutto,  big: true),
          const Divider(height: 16),
          _AutoCalcRow('TARA dostawcy [kg]',      _taraDrew + _taraPlast),
          if (_maMbSkrzynie) ...[
            _AutoCalcRow('TARA MB [kg]',          _taraMb),
          ],
          _AutoCalcRow('TARA łącznie [kg]',       _taraDrew + _taraPlast + _taraMb),
          const Divider(height: 16),
          _AutoCalcRow('WAGA SUROWCA NETTO [kg]', _netto,   big: true, highlight: true),
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

  Widget _odmCard(int idx, _OdmCtrl o) {
    final kod = widget.data.przeznaczenieKod;
    final showTward = kod == 'S' || kod == 'O';
    final showPw    = kod == 'O';

    return _SectionCard(
      title: 'Odmiana ${idx + 1}',
      trailing: _odm.length > 1
          ? IconButton(
              icon: const Icon(Icons.delete_outline, color: AppTheme.errorRed),
              onPressed: () => _removeOdmiana(idx),
            )
          : null,
      child: Column(
        children: [
          TextFormField(
            controller: o.nazwaCtrl,
            decoration: const InputDecoration(labelText: 'Nazwa odmiany'),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _NumField('Skrzynie drew.', o.drewCtrl)),
            const SizedBox(width: 8),
            Expanded(child: _NumField('Skrzynie plast.', o.plastCtrl)),
          ]),
          const SizedBox(height: 8),
          _NumField('Zwrot [%]', o.zwrotCtrl),
          const SizedBox(height: 6),
          _AutoCalcRow('Waga netto odmiany [kg]', o.wagaNetto,
              big: true, highlight: true),
          const Divider(height: 16),
          // Parametry jakości
          Row(children: [
            Expanded(child: _NumField('BRIX', o.brixCtrl, required: true)),
            const SizedBox(width: 8),
            Expanded(child: _NumField('ODPAD [%]', o.odpadCtrl, required: true)),
          ]),
          if (showTward) ...[
            const SizedBox(height: 8),
            _TwardoscField(ctrl: o.twardCtrl, required: true),
          ],
          if (showPw) ...[
            const SizedBox(height: 8),
            _NumField('PW (kaliber ↓68 mm) [%]', o.pwCtrl, required: true),
          ],
          const SizedBox(height: 10),
          // Przycisk etykiety — dostępny od razu
          OutlinedButton.icon(
            icon: const Icon(Icons.label_outline, size: 16),
            label: const Text('Drukuj etykietę'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 36),
              textStyle: const TextStyle(fontSize: 13),
            ),
            onPressed: () => _drukujEtykieteOdmiany(idx, o),
          ),
        ],
      ),
    );
  }

  Future<void> _drukujEtykieteOdmiany(int idx, _OdmCtrl o) async {
    final d       = widget.data;
    final total   = _odm.length;
    final dateStr = '${d.data.day.toString().padLeft(2,'0')}.${d.data.month.toString().padLeft(2,'0')}.${d.data.year}';
    final label   = KwLabelData(
      lot:           d.lotForOdmiana(idx, total),
      odmiana:       o.nazwaCtrl.text.trim().isNotEmpty
                         ? o.nazwaCtrl.text.trim()
                         : 'Odmiana ${idx + 1}',
      data:          dateStr,
      dostawca:      d.dostawcaNazwa,
      dostawcaKod:   d.dostawcaKod,
      przeznaczenie: d.przeznaczenie,
    );
    await Printing.layoutPdf(
      name: 'Etykieta_${label.lot}',
      onLayout: (_) => KwLabelGenerator.generate([label]),
    );
  }

  Widget _stanCard() {
    return _SectionCard(
      title: 'Stan',
      child: Column(
        children: [
          _ToggleRow(
            label:    'Stan opakowania',
            value:    _stanOpak,
            options:  const ['DOBRY', 'USZKODZONY'],
            onChange: (v) => setState(() => _stanOpak = v),
          ),
          const SizedBox(height: 8),
          _ToggleRow(
            label:    'Stan samochodu',
            value:    _stanAuto,
            options:  const ['DOBRY', 'ZŁY'],
            onChange: (v) => setState(() => _stanAuto = v),
          ),
        ],
      ),
    );
  }

  // ── PDF ──────────────────────────────────────────────────────────────────────

  KwPdfData _buildPdfData() {
    final d = widget.data;
    final dateStr =
        '${d.data.day.toString().padLeft(2, '0')}.${d.data.month.toString().padLeft(2, '0')}.${d.data.year}';
    return KwPdfData(
      data:          dateStr,
      dostawca:      '${d.dostawcaKod} — ${d.dostawcaNazwa}',
      nrDostawy:     d.nrDostawy,
      nrPojazdu:     _nrPojazduCtrl.text.trim(),
      nrTelefonu:    _nrTelefonuCtrl.text.trim(),
      wagaA1Zal:     _p(_a1ZalCtrl.text),
      wagaA1Roz:     _p(_a1RozCtrl.text),
      drugiAut:      _drugiAut,
      wagaA2Zal:     _p(_a2ZalCtrl.text),
      wagaA2Roz:     _p(_a2RozCtrl.text),
      drewIl:           _pi(_drewIlCtrl.text),
      drewWagaJedn:     _p(_drewWgCtrl.text),
      plastIl:          _pi(_plastIlCtrl.text),
      plastWagaJedn:    _p(_plastWgCtrl.text),
      mbDrewIl:         _maMbSkrzynie ? _pi(_mbDrewIlCtrl.text)  : 0,
      mbDrewWagaJedn:   _maMbSkrzynie ? _p(_mbDrewWgCtrl.text)   : 0,
      mbPlastIl:        _maMbSkrzynie ? _pi(_mbPlastIlCtrl.text) : 0,
      mbPlastWagaJedn:  _maMbSkrzynie ? _p(_mbPlastWgCtrl.text)  : 0,
      wagaBrutto:       _brutto,
      wagaNetto:     _netto,
      odmiany:       _odm.map((o) => KwOdmianaData(
        nazwa:    o.nazwaCtrl.text.trim(),
        drewIl:   _pi(o.drewCtrl.text),
        plastIl:  _pi(o.plastCtrl.text),
        zwrotPct: _p(o.zwrotCtrl.text),
        wagaNetto:o.wagaNetto,
        brix:     o.brixCtrl.text.trim(),
        odpad:    o.odpadCtrl.text.trim(),
        twardosc: o.twardCtrl.text.trim(),
        kaliber:  o.pwCtrl.text.trim(),
      )).toList(),
      stanOpak: _stanOpak,
      stanAuto: _stanAuto,
    );
  }

  List<KwLabelData> _buildLabels() {
    final d       = widget.data;
    final total   = _odm.length;
    final dateStr = '${d.data.day.toString().padLeft(2,'0')}.${d.data.month.toString().padLeft(2,'0')}.${d.data.year}';
    return List.generate(total, (i) {
      final o = _odm[i];
      return KwLabelData(
        lot:           d.lotForOdmiana(i, total),
        odmiana:       o.nazwaCtrl.text.trim(),
        data:          dateStr,
        dostawca:      d.dostawcaNazwa,
        dostawcaKod:   d.dostawcaKod,
        przeznaczenie: d.przeznaczenie,
      );
    });
  }

  Future<void> _showSaveDialog(KwPdfData pdfData, List<KwLabelData> labels) async {
    final choice = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: AppTheme.successGreen, size: 48),
        title: const Text('Karta zapisana'),
        content: const Text('Co chcesz zrobić?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'skip'),
            child: const Text('Pomiń'),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.label_outline, size: 18),
            label: const Text('Etykiety'),
            onPressed: () => Navigator.pop(context, 'label'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.print_outlined, size: 18),
            label: const Text('Kartę KW'),
            onPressed: () => Navigator.pop(context, 'kw'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (choice == 'kw') {
      await Printing.layoutPdf(
        name: 'KartaWazenia_${widget.data.nrDostawy}',
        onLayout: (_) => KwPdfGenerator.generate(pdfData),
      );
    } else if (choice == 'label') {
      await Printing.layoutPdf(
        name: 'Etykiety_${widget.data.nrDostawy}',
        onLayout: (_) => KwLabelGenerator.generate(labels),
      );
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  void _addOdmiana() {
    final o = _OdmCtrl();
    _listenOdm(o);
    setState(() => _odm.add(o));
  }

  void _removeOdmiana(int idx) {
    _odm[idx].dispose();
    setState(() => _odm.removeAt(idx));
    _recalc();
  }
}

// ── Drobne widgety ─────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  const _SectionCard({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Card(
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

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
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

class _AutoCalcRow extends StatelessWidget {
  final String label;
  final double value;
  final bool big;
  final bool highlight;
  const _AutoCalcRow(this.label, this.value,
      {this.big = false, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final valStr = value.toStringAsFixed(2);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
              fontSize: big ? 14 : 13,
              color: AppTheme.textSecondary,
            )),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: highlight ? AppTheme.primaryDark : AppTheme.borderLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            valStr,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: big ? 16 : 14,
              color: highlight ? Colors.white : AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _NumField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final bool required;
  const _NumField(this.label, this.ctrl, {this.required = false});

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

class _TwardoscField extends StatelessWidget {
  final TextEditingController ctrl;
  final bool required;
  const _TwardoscField({required this.ctrl, this.required = false});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: 'Twardość [kG/cm²]',
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: ctrl,
          builder: (_, v, __) {
            final t = double.tryParse(v.text.replaceAll(',', '.')) ?? 0;
            if (v.text.isEmpty) return const SizedBox.shrink();
            return Icon(
              t < 4.5 ? Icons.warning_amber_rounded : Icons.check_circle_outline,
              color: t < 4.5 ? AppTheme.warningOrange : AppTheme.successGreen,
            );
          },
        ),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Wymagane' : null
          : null,
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChange;
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.options,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
        ),
        ToggleButtons(
          isSelected: options.map((o) => o == value).toList(),
          onPressed: (i) => onChange(options[i]),
          borderRadius: BorderRadius.circular(8),
          selectedColor: Colors.white,
          fillColor: AppTheme.primaryDark,
          children: options
              .map((o) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text(o, style: const TextStyle(fontSize: 13)),
                  ))
              .toList(),
        ),
      ],
    );
  }
}
