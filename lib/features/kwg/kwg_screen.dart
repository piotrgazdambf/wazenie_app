import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
import '../../core/auth/pin_auth_service.dart';
import '../../core/constants.dart';
import '../../core/models/kw_data.dart';

// ── Kontrolery odmiany KWG ────────────────────────────────────────────────────

class _OdmGCtrl {
  final nazwaCtrl     = TextEditingController();
  final wagaNettoCtrl = TextEditingController();  // waga podawana przez dostawcę
  final drewCtrl      = TextEditingController();
  final plastCtrl     = TextEditingController();
  final mbfDrewCtrl   = TextEditingController();
  final mbfPlastCtrl  = TextEditingController();
  final zwrotCtrl     = TextEditingController(text: '0');
  final brixCtrl      = TextEditingController();
  final odpadCtrl     = TextEditingController();
  final twardCtrl     = TextEditingController();

  void dispose() {
    for (final c in [nazwaCtrl, wagaNettoCtrl, drewCtrl, plastCtrl,
                     mbfDrewCtrl, mbfPlastCtrl, zwrotCtrl, brixCtrl,
                     odpadCtrl, twardCtrl]) {
      c.dispose();
    }
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
  final _formKey = GlobalKey<FormState>();
  final List<_OdmGCtrl> _odm = [_OdmGCtrl()];
  bool _saving = false;

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

    final session = ref.read(currentSessionProvider);
    final userId  = session?.user.id ?? 'unknown';
    final d       = widget.data;
    final db      = FirebaseFirestore.instance;
    final batch   = db.batch();

    final total = _odm.length;
    for (int i = 0; i < total; i++) {
      final o   = _odm[i];
      final lot    = d.lotForOdmiana(i, total);
      final docId  = lot.replaceAll('/', '_');
      final wagaNetto = double.tryParse(
              o.wagaNettoCtrl.text.replaceAll(',', '.').trim()) ??
          0;
      final skrz = '${o.drewCtrl.text.trim()}/${o.plastCtrl.text.trim()}';

      // deliveries
      final dateStr  = '${d.data.year}-${d.data.month.toString().padLeft(2,'0')}-${d.data.day.toString().padLeft(2,'0')}';
      final drewCnt  = int.tryParse(o.drewCtrl.text.trim()) ?? 0;
      final plastCnt = int.tryParse(o.plastCtrl.text.trim()) ?? 0;

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
        'skrzynie_drew':     drewCnt,
        'skrzynie_plast':    plastCnt,
        'skrzynie_mbf_drew': int.tryParse(o.mbfDrewCtrl.text.trim()) ?? 0,
        'skrzynie_mbf_plast':int.tryParse(o.mbfPlastCtrl.text.trim()) ?? 0,
        'waga_netto':        wagaNetto.toStringAsFixed(2),
        'brix':              o.brixCtrl.text.trim(),
        'odpad':             o.odpadCtrl.text.trim(),
        'twardosc':          o.twardCtrl.text.trim(),
        'zwrot_pct':         o.zwrotCtrl.text.trim(),
        'is_kwg':            true,
        'status':            'PRZYJETO',
        'createdBy':         userId,
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
        'drew_waga_jedn':  20.0,
        'plast_waga_jedn': 10.0,
        'kg_total':        wagaNetto,
        'kg_remaining':    wagaNetto,
        'active':          (drewCnt + plastCnt) > 0 && wagaNetto > 0,
        'is_kwg':          true,
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Karta KWG zapisana pomyślnie'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
        context.go('/pls');
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
        title: const Text('Karta Ważenia G'),
        leading: BackButton(onPressed: () => context.go('/wsg/new')),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _headerCard(d),
            const SizedBox(height: 12),
            _infoCard(),
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
            const SizedBox(height: 24),
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
    final showTward= kod == 'S' || kod == 'O';

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
          TextFormField(
            controller: o.nazwaCtrl,
            decoration: const InputDecoration(labelText: 'Nazwa odmiany'),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 8),
          _KwgNumField(
            'Waga netto [kg]',
            o.wagaNettoCtrl,
            required: true,
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _KwgNumField('Skrzynie drew.', o.drewCtrl)),
            const SizedBox(width: 8),
            Expanded(child: _KwgNumField('Skrzynie plast.', o.plastCtrl)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _KwgNumField('Sk. MBF drew.', o.mbfDrewCtrl)),
            const SizedBox(width: 8),
            Expanded(child: _KwgNumField('Sk. MBF plast.', o.mbfPlastCtrl)),
          ]),
          const SizedBox(height: 8),
          _KwgNumField('Zwrot [%]', o.zwrotCtrl),
          const Divider(height: 16),
          Row(children: [
            Expanded(child: _KwgNumField('BRIX', o.brixCtrl)),
            const SizedBox(width: 8),
            Expanded(child: _KwgNumField('ODPAD [%]', o.odpadCtrl)),
          ]),
          if (showTward) ...[
            const SizedBox(height: 8),
            _KwgNumField('Twardość [kG/cm²]', o.twardCtrl),
          ],
        ],
      ),
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
