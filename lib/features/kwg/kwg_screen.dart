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

// ── Kontrolery odmiany KWG ────────────────────────────────────────────────────

class _OdmGCtrl {
  final nazwaCtrl     = TextEditingController();
  final wagaNettoCtrl = TextEditingController();
  final drewCtrl      = TextEditingController();
  final plastCtrl     = TextEditingController();
  final mbDrewCtrl    = TextEditingController();
  final mbPlastCtrl   = TextEditingController();
  final zwrotCtrl     = TextEditingController(text: '0');
  final brixCtrl      = TextEditingController();
  final odpadCtrl     = TextEditingController();
  final twardCtrl     = TextEditingController();
  final infoCtrl      = TextEditingController();
  // Dla Rylex/Grójecka: indywidualny nr dostawy i data
  final nrCtrl        = TextEditingController();
  DateTime dataDostawy = DateTime.now();
  bool zwrotVisible   = false;
  bool mbVisible      = false;

  void dispose() {
    for (final c in [nazwaCtrl, wagaNettoCtrl, drewCtrl, plastCtrl,
                     mbDrewCtrl, mbPlastCtrl, zwrotCtrl, brixCtrl,
                     odpadCtrl, twardCtrl, infoCtrl, nrCtrl]) {
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

  /// Pełny LOT dla odmiany Rylex/Grójecka
  String _lotForOdmRG(_OdmGCtrl o) {
    final nr = o.nrCtrl.text.trim().isNotEmpty
        ? o.nrCtrl.text.trim()
        : _lotBaseCtrl.text.trim();
    return '$nr/${widget.data.kwgType}-${widget.data.przeznaczenieKod}';
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

    final session = ref.read(currentSessionProvider);
    final userId  = session?.user.id ?? 'unknown';
    final d       = widget.data;
    final db      = FirebaseFirestore.instance;
    final batch   = db.batch();

    final isRG    = d.kwgType.isNotEmpty; // Rylex lub Grójecka
    final lotBase = _lotBaseCtrl.text.trim().isNotEmpty ? _lotBaseCtrl.text.trim() : d.lotBase;
    final total   = _odm.length;
    for (int i = 0; i < total; i++) {
      final o      = _odm[i];
      // LOT: dla RG - indywidualny numer, dla innych - standardowy
      final lot    = isRG
          ? _lotForOdmRG(o)
          : (total <= 1 || i == 0 ? lotBase : '$lotBase${i + 1}');
      final docId  = lot.replaceAll('/', '_');
      final wagaNetto = double.tryParse(o.wagaNettoCtrl.text.replaceAll(',', '.').trim()) ?? 0;
      final skrz   = '${o.drewCtrl.text.trim()}/${o.plastCtrl.text.trim()}';

      // Data: dla RG - indywidualna data odmiany, dla innych - data z WSG
      final dataOdm = isRG ? o.dataDostawy : d.data;
      final dateStr = '${dataOdm.year}-${dataOdm.month.toString().padLeft(2,'0')}-${dataOdm.day.toString().padLeft(2,'0')}';
      final drewCnt  = int.tryParse(o.drewCtrl.text.trim()) ?? 0;
      final plastCnt = int.tryParse(o.plastCtrl.text.trim()) ?? 0;
      final mbDrewCnt= int.tryParse(o.mbDrewCtrl.text.trim()) ?? 0;

      final delRef = db.collection(AppConstants.colDeliveries).doc(docId);
      batch.set(delRef, {
        'id':                lot,
        'lot':               lot,
        'data':              dateStr,
        'nr_dostawy':        isRG ? (o.nrCtrl.text.trim().isNotEmpty ? o.nrCtrl.text.trim() : lot) : d.nrDostawy,
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
        'waga_netto_brak':   wagaNetto == 0 && isRG, // flaga "waga do uzupełnienia"
        'brix':              o.brixCtrl.text.trim(),
        'odpad':             isRG ? '' : o.odpadCtrl.text.trim(),
        'twardosc':          o.twardCtrl.text.trim(),
        'zwrot_pct':         isRG ? '' : o.zwrotCtrl.text.trim(),
        'is_kwg':            true,
        'kwg_type':          d.kwgType,
        'data_wsg':          '${d.data.year}-${d.data.month.toString().padLeft(2,'0')}-${d.data.day.toString().padLeft(2,'0')}',
        'status':            'PRZESŁANO',
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
        'drew_waga_jedn':  mbDrewCnt > 0 ? 60.0 : 20.0,  // MB drew = 60kg
        'plast_waga_jedn': 10.0,
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
                child: TextFormField(
                  controller: o.nrCtrl,
                  decoration: const InputDecoration(labelText: 'Nr dostawy'),
                  style: const TextStyle(fontFamily: 'monospace'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: o.dataDostawy,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      locale: const Locale('pl'),
                    );
                    if (picked != null) setState(() => o.dataDostawy = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Data dostarczenia'),
                    child: Text(
                      '${o.dataDostawy.day.toString().padLeft(2,'0')}.${o.dataDostawy.month.toString().padLeft(2,'0')}.${o.dataDostawy.year}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 8),
          ],
          TextFormField(
            controller: o.nazwaCtrl,
            decoration: const InputDecoration(labelText: 'Odmiana'),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 8),
          _KwgNumField(
            isRG ? 'Waga netto [kg] (do korekty)' : 'Waga netto [kg]',
            o.wagaNettoCtrl,
            required: !isRG,
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _KwgNumField('Skrzynie drew.', o.drewCtrl)),
            const SizedBox(width: 8),
            Expanded(child: _KwgNumField('Skrzynie plast.', o.plastCtrl)),
          ]),
          const SizedBox(height: 8),
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
              Expanded(child: _KwgNumField('Sk. MB plast.', o.mbPlastCtrl)),
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
        ],
      ),
    );
  }

  Future<void> _showSaveDialog() async {
    final d       = widget.data;
    final lotBase = _lotBaseCtrl.text.trim();
    final total   = _odm.length;
    final dateStr = '${d.data.day.toString().padLeft(2,'0')}.${d.data.month.toString().padLeft(2,'0')}.${d.data.year}';

    final labels = List.generate(total, (i) {
      final o = _odm[i];
      final lot = isRG
          ? _lotForOdmRG(o)
          : (total <= 1 || i == 0 ? lotBase : '$lotBase${i + 1}');
      final dataDostarczenia = isRG
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
