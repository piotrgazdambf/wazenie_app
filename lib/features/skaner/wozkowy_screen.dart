import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'skaner_entry_screen.dart';

// ── Model danych dostawy (uproszczony dla skanera) ────────────────────────────

class _DeliveryInfo {
  final String lot;
  final String odmiana;
  final String owoc;
  final String dostawca;
  final String data;
  final int skrzynieDrew;
  final int skrzyniePlast;
  final double drewWagaJedn;
  final double plastWagaJedn;
  final double wagaNetto;

  const _DeliveryInfo({
    required this.lot,
    required this.odmiana,
    required this.owoc,
    required this.dostawca,
    required this.data,
    required this.skrzynieDrew,
    required this.skrzyniePlast,
    required this.drewWagaJedn,
    required this.plastWagaJedn,
    required this.wagaNetto,
  });

  factory _DeliveryInfo.fromFirestore(Map<String, dynamic> d) {
    final wn = double.tryParse(
          (d['waga_netto'] ?? '').toString().replaceAll(',', '.').replaceAll(RegExp(r'[^0-9.]'), '')) ??
        0.0;
    return _DeliveryInfo(
      lot:           d['lot'] as String? ?? '',
      odmiana:       d['odmiana'] as String? ?? '',
      owoc:          d['owoc'] as String? ?? '',
      dostawca:      d['dostawca'] as String? ?? '',
      data:          d['data'] as String? ?? '',
      skrzynieDrew:  d['skrzynie_drew']  as int? ?? 0,
      skrzyniePlast: d['skrzynie_plast'] as int? ?? 0,
      drewWagaJedn:  (d['drew_waga_jedn']  as num?)?.toDouble() ?? 0.0,
      plastWagaJedn: (d['plast_waga_jedn'] as num?)?.toDouble() ?? 0.0,
      wagaNetto:     wn,
    );
  }

  int get totalSkrzynie => skrzynieDrew + skrzyniePlast;

  // szacunkowa waga owocu w jednej skrzyni
  double avgKgPerCrate(int typ) {
    // typ: 0=drew, 1=plast, -1=avg
    if (totalSkrzynie == 0 || wagaNetto == 0) return 0;
    if (typ == -1) return wagaNetto / totalSkrzynie;
    if (typ == 0 && skrzynieDrew == 0) return 0;
    if (typ == 1 && skrzyniePlast == 0) return 0;
    final totalTara = skrzynieDrew * drewWagaJedn + skrzyniePlast * plastWagaJedn;
    if (totalTara == 0) return wagaNetto / totalSkrzynie;
    if (typ == 0) return wagaNetto * drewWagaJedn / totalTara;
    return wagaNetto * plastWagaJedn / totalTara;
  }
}

// ── Ekran Wózkowego ───────────────────────────────────────────────────────────

class WozkowyScreen extends StatefulWidget {
  const WozkowyScreen({super.key});

  @override
  State<WozkowyScreen> createState() => _WozkowyScreenState();
}

class _WozkowyScreenState extends State<WozkowyScreen> {
  final _lotCtrl       = TextEditingController();
  final _iloscCtrl     = TextEditingController();
  final _lotFocus      = FocusNode();

  _DeliveryInfo? _delivery;
  bool _loading   = false;
  bool _sending   = false;
  String? _error;

  @override
  void dispose() {
    _lotCtrl.dispose();
    _iloscCtrl.dispose();
    _lotFocus.dispose();
    super.dispose();
  }

  Future<void> _lookupLot(String lot) async {
    final trimmed = lot.trim();
    if (trimmed.isEmpty) return;
    setState(() { _loading = true; _error = null; _delivery = null; _iloscCtrl.clear(); });

    try {
      // Próba 1: po doc ID (lot z / → _)
      final docId = trimmed.replaceAll('/', '_');
      var doc = await FirebaseFirestore.instance.collection('deliveries').doc(docId).get();

      // Próba 2: query po polu lot
      if (!doc.exists) {
        final snap = await FirebaseFirestore.instance
            .collection('deliveries')
            .where('lot', isEqualTo: trimmed)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) doc = snap.docs.first as DocumentSnapshot<Map<String, dynamic>>;
      }

      if (!doc.exists || doc.data() == null) {
        setState(() { _error = 'Nie znaleziono dostawy: $trimmed'; _loading = false; });
        return;
      }

      setState(() {
        _delivery = _DeliveryInfo.fromFirestore(doc.data()!);
        _loading  = false;
      });
      // Przenieś fokus na pole ilości
      FocusScope.of(context).nextFocus();
    } catch (e) {
      setState(() { _error = 'Błąd połączenia: $e'; _loading = false; });
    }
  }

  Future<void> _submit() async {
    final delivery = _delivery;
    if (delivery == null) return;
    final ilosc = int.tryParse(_iloscCtrl.text.trim()) ?? 0;
    if (ilosc <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Podaj liczbę skrzyń'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _sending = true);
    try {
      // Szacunkowe kg
      final kgPerCrate = delivery.totalSkrzynie > 0
          ? delivery.wagaNetto / delivery.totalSkrzynie
          : 0.0;
      final kgSzacunek = ilosc * kgPerCrate;

      await FirebaseFirestore.instance.collection('skaner_wnioski').add({
        'lot':           delivery.lot,
        'odmiana':       delivery.odmiana,
        'owoc':          delivery.owoc,
        'dostawca':      delivery.dostawca,
        'data_dostawy':  delivery.data,
        'skrzynie_ilosc': ilosc,
        'kg_szacunek':   kgSzacunek,
        'status':        'oczekujacy',
        'created_at':    FieldValue.serverTimestamp(),
        'dyspozytor_id':   null,
        'dyspozytor_name': null,
      });

      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: kSkanerCard,
            title: const Text('Wysłano', style: TextStyle(color: Colors.white)),
            content: Text(
              'Zlecenie na $ilosc skrz. z dostawy ${delivery.lot} zostało wysłane do dyspozytora.',
              style: const TextStyle(color: kSkanerTextSec),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: kSkanerAccent),
                onPressed: () => Navigator.pop(context),
                child: const Text('OK', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        // Reset — gotowy na kolejny skan
        setState(() {
          _delivery = null;
          _error    = null;
          _sending  = false;
          _lotCtrl.clear();
          _iloscCtrl.clear();
        });
        _lotFocus.requestFocus();
      }
    } catch (e) {
      setState(() => _sending = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSkanerBg,
      appBar: AppBar(
        backgroundColor: kSkanerCard,
        foregroundColor: Colors.white,
        leading: BackButton(onPressed: () => context.go('/skaner')),
        title: const Text('Wózkowy', style: TextStyle(color: Colors.white)),
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Pole skanowania LOT ──────────────────────────────────────────
            _SectionLabel('SKANUJ KOD / LOT DOSTAWY'),
            const SizedBox(height: 8),
            TextField(
              controller: _lotCtrl,
              focusNode: _lotFocus,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Przyłóż skaner lub wpisz LOT...',
                hintStyle: const TextStyle(color: kSkanerTextSec),
                filled: true,
                fillColor: kSkanerCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kSkanerPrimary),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kSkanerAccent, width: 2),
                ),
                suffixIcon: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: kSkanerAccent)),
                      )
                    : IconButton(
                        icon: const Icon(Icons.search, color: kSkanerAccent),
                        onPressed: () => _lookupLot(_lotCtrl.text),
                      ),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: _lookupLot,
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
              ),
            ],

            // ── Info o dostawie ──────────────────────────────────────────────
            if (_delivery != null) ...[
              const SizedBox(height: 20),
              _DeliveryCard(delivery: _delivery!),
              const SizedBox(height: 20),

              // ── Liczba skrzyń ────────────────────────────────────────────
              _SectionLabel('LICZBA SKRZYŃ DO ŚCIĄGNIĘCIA'),
              const SizedBox(height: 8),
              _KgEstimateField(
                ctrl: _iloscCtrl,
                delivery: _delivery!,
              ),
              const SizedBox(height: 24),

              // ── Przycisk Prześlij ────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kSkanerAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _sending ? null : _submit,
                  icon: _sending
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.send_rounded),
                  label: const Text('Prześlij do dyspozytora',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Karta informacji o dostawie ───────────────────────────────────────────────

class _DeliveryCard extends StatelessWidget {
  final _DeliveryInfo delivery;
  const _DeliveryCard({required this.delivery});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.#', 'pl_PL');
    final d   = delivery;
    final avgDrew  = d.avgKgPerCrate(0);
    final avgPlast = d.avgKgPerCrate(1);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSkanerCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kSkanerPrimary, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${d.owoc}${d.odmiana.isNotEmpty ? " · ${d.odmiana}" : ""}',
            style: const TextStyle(
                color: kSkanerAccent, fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(d.lot,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 12, fontFamily: 'monospace')),
          const Divider(color: kSkanerPrimary, height: 20),
          _Row('Dostawca',  d.dostawca),
          _Row('Data',      d.data),
          _Row('Waga netto','${fmt.format(d.wagaNetto)} kg'),
          if (d.skrzynieDrew > 0)
            _Row('Skrz. drew.',
                '${d.skrzynieDrew} szt.'
                '${avgDrew > 0 ? " · ~${fmt.format(avgDrew)} kg/szt." : ""}'),
          if (d.skrzyniePlast > 0)
            _Row('Skrz. plast.',
                '${d.skrzyniePlast} szt.'
                '${avgPlast > 0 ? " · ~${fmt.format(avgPlast)} kg/szt." : ""}'),
        ],
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(color: kSkanerTextSec, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ── Pole liczby skrzyń z podglądem szacunku kg ───────────────────────────────

class _KgEstimateField extends StatefulWidget {
  final TextEditingController ctrl;
  final _DeliveryInfo delivery;
  const _KgEstimateField({required this.ctrl, required this.delivery});

  @override
  State<_KgEstimateField> createState() => _KgEstimateFieldState();
}

class _KgEstimateFieldState extends State<_KgEstimateField> {
  @override
  void initState() {
    super.initState();
    widget.ctrl.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    widget.ctrl.removeListener(_rebuild);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ilosc = int.tryParse(widget.ctrl.text.trim()) ?? 0;
    final total = widget.delivery.totalSkrzynie;
    final kgPerCrate = total > 0 ? widget.delivery.wagaNetto / total : 0.0;
    final szacunekKg = ilosc * kgPerCrate;
    final fmt = NumberFormat('#,##0', 'pl_PL');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.ctrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: '0',
            hintStyle: const TextStyle(color: kSkanerTextSec),
            filled: true,
            fillColor: kSkanerCard,
            suffixText: 'szt.',
            suffixStyle: const TextStyle(color: kSkanerTextSec),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kSkanerPrimary),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kSkanerAccent, width: 2),
            ),
          ),
        ),
        if (ilosc > 0 && kgPerCrate > 0) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: kSkanerAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kSkanerAccent.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.scale_outlined, color: kSkanerAccent, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Szacunkowa waga: ~${fmt.format(szacunekKg)} kg',
                  style: const TextStyle(
                      color: kSkanerAccent, fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ── Helper widget ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
          color: kSkanerTextSec, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2),
    );
  }
}
