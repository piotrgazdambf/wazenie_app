import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/theme.dart';
import '../../core/constants.dart';

// ── Publiczne entry-point ──────────────────────────────────────────────────────

Future<void> showWpisWageDialog(
  BuildContext context, {
  required String lot,
  required String docId,
  required int drewIl,
  required int plastIl,
  double drewWagaJedn = 20,
  double plastWagaJedn = 10,
}) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _WpisDialog(
      lot: lot, docId: docId,
      drewIl: drewIl, plastIl: plastIl,
      drewWagaJedn: drewWagaJedn, plastWagaJedn: plastWagaJedn,
    ),
  );
}

// ── Dialog tryb 1: bezpośredni wpis wagi netto ─────────────────────────────────

class _WpisDialog extends StatefulWidget {
  final String lot;
  final String docId;
  final int drewIl;
  final int plastIl;
  final double drewWagaJedn;
  final double plastWagaJedn;

  const _WpisDialog({
    required this.lot, required this.docId,
    required this.drewIl, required this.plastIl,
    required this.drewWagaJedn, required this.plastWagaJedn,
  });

  @override
  State<_WpisDialog> createState() => _WpisDialogState();
}

class _WpisDialogState extends State<_WpisDialog> {
  final _ctrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    final val = _ctrl.text.trim();
    if (val.isEmpty) return;
    setState(() => _saving = true);
    await FirebaseFirestore.instance
        .collection(AppConstants.colDeliveries)
        .doc(widget.docId)
        .update({'waga_netto': val, 'waga_netto_brak': false});
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Waga netto', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        Text(widget.lot, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w400)),
      ]),
      content: SizedBox(
        width: 320,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(
            controller: _ctrl,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Waga netto [kg]',
              prefixIcon: Icon(Icons.scale_outlined),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
            onFieldSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 16),
          // Opcja kalkulatora
          GestureDetector(
            onTap: () async {
              Navigator.of(context).pop();
              await showDialog<void>(
                context: context,
                builder: (_) => _KalkulatorDialog(
                  lot: widget.lot, docId: widget.docId,
                  drewIl: widget.drewIl, plastIl: widget.plastIl,
                  drewWagaJedn: widget.drewWagaJedn, plastWagaJedn: widget.plastWagaJedn,
                ),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: const Row(children: [
                Icon(Icons.calculate_outlined, size: 18, color: AppTheme.textSecondary),
                SizedBox(width: 8),
                Text('Nie znam wagi netto — wylicz',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                Spacer(),
                Icon(Icons.arrow_forward_ios, size: 12, color: AppTheme.textSecondary),
              ]),
            ),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Anuluj')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Zapisz'),
        ),
      ],
    );
  }
}

// ── Dialog tryb 2: kalkulator brutto → netto ──────────────────────────────────

class _KalkulatorDialog extends StatefulWidget {
  final String lot;
  final String docId;
  final int drewIl;
  final int plastIl;
  final double drewWagaJedn;
  final double plastWagaJedn;

  const _KalkulatorDialog({
    required this.lot, required this.docId,
    required this.drewIl, required this.plastIl,
    required this.drewWagaJedn, required this.plastWagaJedn,
  });

  @override
  State<_KalkulatorDialog> createState() => _KalkulatorDialogState();
}

class _KalkulatorDialogState extends State<_KalkulatorDialog> {
  final _zalCtrl    = TextEditingController();
  final _rozCtrl    = TextEditingController();
  late  TextEditingController _drewIlCtrl;
  late  TextEditingController _plastIlCtrl;
  late  TextEditingController _drewWagaCtrl;
  late  TextEditingController _plastWagaCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _drewIlCtrl   = TextEditingController(text: widget.drewIl > 0  ? '${widget.drewIl}'  : '');
    _plastIlCtrl  = TextEditingController(text: widget.plastIl > 0 ? '${widget.plastIl}' : '');
    _drewWagaCtrl = TextEditingController();
    _plastWagaCtrl= TextEditingController();
  }

  @override
  void dispose() {
    _zalCtrl.dispose(); _rozCtrl.dispose();
    _drewIlCtrl.dispose(); _plastIlCtrl.dispose();
    _drewWagaCtrl.dispose(); _plastWagaCtrl.dispose();
    super.dispose();
  }

  double _p(String v) => double.tryParse(v.replaceAll(',', '.')) ?? 0;

  double get _brutto => (_p(_zalCtrl.text) - _p(_rozCtrl.text)).clamp(0, double.infinity);
  double get _tara   => _p(_drewIlCtrl.text) * _p(_drewWagaCtrl.text)
                      + _p(_plastIlCtrl.text) * _p(_plastWagaCtrl.text);
  double get _netto  => (_brutto - _tara).clamp(0, double.infinity);

  bool get _canSave => _brutto > 0;

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection(AppConstants.colDeliveries)
          .doc(widget.docId)
          .update({
        'waga_netto':     _netto.toStringAsFixed(0),
        'waga_brutto':    _brutto.toStringAsFixed(0),
        'waga_netto_brak': false,
        if (_p(_zalCtrl.text) > 0) 'waga_a1_zal': _p(_zalCtrl.text),
        if (_p(_rozCtrl.text) > 0) 'waga_a1_roz': _p(_rozCtrl.text),
        if (_p(_drewWagaCtrl.text) > 0) 'drew_waga_jedn': _p(_drewWagaCtrl.text),
        if (_p(_plastWagaCtrl.text) > 0) 'plast_waga_jedn': _p(_plastWagaCtrl.text),
      });
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd: $e'), backgroundColor: AppTheme.errorRed),
        );
      }
    }
  }

  Widget _numField(String label, TextEditingController ctrl, {bool locked = false}) {
    return TextFormField(
      controller: ctrl,
      readOnly: locked,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: locked ? AppTheme.background : Colors.white,
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
      onChanged: locked ? null : (_) => setState(() {}),
    );
  }

  Widget _resultRow(String label, double value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary))),
        Text(
          '${value.toStringAsFixed(0)} kg',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
              color: color ?? AppTheme.primaryDark),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Wylicz wagę netto', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        Text(widget.lot, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w400)),
      ]),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 380,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ── Wagi aut ──
            const Text('WAGI AUT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textSecondary, letterSpacing: 0.8)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _numField('Załadowane [kg]', _zalCtrl)),
              const SizedBox(width: 10),
              Expanded(child: _numField('Rozładowane [kg]', _rozCtrl)),
            ]),
            const SizedBox(height: 8),
            if (_brutto > 0)
              _resultRow('Brutto:', _brutto),

            const SizedBox(height: 16),
            const Divider(),

            // ── Skrzynie ──
            const Text('SKRZYNIE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textSecondary, letterSpacing: 0.8)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _numField('Ilość drewnianych', _drewIlCtrl, locked: widget.drewIl > 0)),
              const SizedBox(width: 10),
              Expanded(child: _numField('Waga szt. [kg]', _drewWagaCtrl)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _numField('Ilość plastikowych', _plastIlCtrl, locked: widget.plastIl > 0)),
              const SizedBox(width: 10),
              Expanded(child: _numField('Waga szt. [kg]', _plastWagaCtrl)),
            ]),
            if (_tara > 0) ...[
              const SizedBox(height: 8),
              _resultRow('Tara:', _tara, color: AppTheme.warningOrange),
            ],

            const SizedBox(height: 12),
            const Divider(),

            // ── Wynik ──
            if (_brutto > 0)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.successGreen.withAlpha(15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.successGreen.withAlpha(60)),
                ),
                child: Column(children: [
                  _resultRow('Brutto:', _brutto),
                  _resultRow('Tara:', _tara, color: AppTheme.warningOrange),
                  const Divider(height: 12),
                  _resultRow('Netto:', _netto, color: AppTheme.successGreen),
                ]),
              ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Anuluj')),
        FilledButton(
          onPressed: _canSave && !_saving ? _save : null,
          style: FilledButton.styleFrom(backgroundColor: AppTheme.successGreen),
          child: _saving
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Prześlij dane'),
        ),
      ],
    );
  }
}
