import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../app/theme.dart';
import '../../core/constants.dart';
import '../../core/models/kw_data.dart';
import '../../core/models/supplier.dart';
import '../../shared/widgets/offline_banner.dart';

// ── Dane statyczne ─────────────────────────────────────────────────────────────

const _przeznaczenia = [
  ('S', 'Sok',       Icons.water_drop_outlined),
  ('P', 'Przecier',  Icons.blender_outlined),
  ('O', 'Obieranie', Icons.content_cut),
  ('F', 'Świeże',    Icons.eco_outlined),
];

final owocListProvider = StreamProvider<List<String>>((ref) {
  return FirebaseFirestore.instance
      .collection('owoce')
      .orderBy('nazwa')
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => (d.data()['nazwa'] as String? ?? '').toLowerCase())
          .where((n) => n.isNotEmpty)
          .toList());
});

const _owoceDlaKW = {'jabłko', 'gruszka'};

// ── WSG Screen ─────────────────────────────────────────────────────────────────

class WsgScreen extends ConsumerStatefulWidget {
  const WsgScreen({super.key});

  @override
  ConsumerState<WsgScreen> createState() => _WsgScreenState();
}

class _WsgScreenState extends ConsumerState<WsgScreen> {
  final _nrDostawyCtrl = TextEditingController();
  DateTime _data = DateTime.now();
  Supplier? _dostawca;
  String? _przeznaczenieKod;
  String? _owoc;
  bool _rylex = false;
  bool _grojecka = false;
  bool _isEko = false;

  @override
  void dispose() {
    _nrDostawyCtrl.dispose();
    super.dispose();
  }

  String get _owocFinal => (_owoc != null && _isEko) ? '${_owoc!} eko' : (_owoc ?? '');

  bool get _isKWG => _rylex || _grojecka;

  String get _przeznaczenieNazwa {
    for (final p in _przeznaczenia) {
      if (p.$1 == _przeznaczenieKod) return p.$2;
    }
    return '';
  }

  String get _lotPreview {
    final nr   = _nrDostawyCtrl.text.trim().padLeft(4, '0');
    final kod  = _dostawca?.kod ?? '???';
    final p    = _przeznaczenieKod ?? '?';
    final pfx  = _rylex ? 'R' : _grojecka ? 'G' : 'C';
    final year = (_data.year % 100).toString().padLeft(2, '0');
    return '$pfx/$nr/$kod/$year-$p';
  }

  // Rylex/Grójecka: nrDostawy nie jest wymagany (LOT auto z dziennego licznika)
  bool get _nrRequired => !_rylex && !_grojecka;

  bool get _canProceed =>
      (!_nrRequired || _nrDostawyCtrl.text.trim().isNotEmpty) &&
      _dostawca != null &&
      _przeznaczenieKod != null &&
      _owoc != null;

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('pl'),
    );
    if (d != null) setState(() => _data = d);
  }

  Future<int> _getNextDeliveryNumber() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection(AppConstants.colDeliveries)
          .get();
      int max = 0;
      for (final doc in snap.docs) {
        final raw = doc.data()['nr_dostawy'] as String? ?? '';
        // ignoruj LOT-y (zawierają '/') - bierz tylko czyste liczby
        if (raw.contains('/')) continue;
        final n = int.tryParse(raw.trim()) ?? 0;
        if (n > max) max = n;
      }
      return max + 1;
    } catch (_) {
      return 1;
    }
  }

  void _proceed() {
    final input = WsgInputData(
      data: _data,
      nrDostawy: _nrDostawyCtrl.text.trim(),
      dostawcaNazwa: _dostawca!.nazwa,
      dostawcaKod: _dostawca!.kod,
      przeznaczenie: _przeznaczenieNazwa,
      przeznaczenieKod: _przeznaczenieKod!,
      owoc: _owocFinal,
      isKWG: _isKWG,
      isRylex: _rylex,
      isGrojecka: _grojecka,
    );
    if (_isKWG) {
      context.go('/kwg/new', extra: input);
    } else {
      context.go('/kw/new', extra: input);
    }
  }

  @override
  Widget build(BuildContext context) {
    final suppliersAsync = ref.watch(suppliersProvider);
    final owocyAsync     = ref.watch(owocListProvider);
    final df = DateFormat('dd.MM.yyyy');
    final owoce = owocyAsync.valueOrNull ?? const ['jabłko', 'gruszka', 'wiśnia', 'rabarbar', 'truskawka', 'marchewka', 'mango'];

    return OfflineOverflowGuard(
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: const Text('Nowe przyjęcie (WSG)'),
          leading: BackButton(onPressed: () => context.go('/home')),
        ),
        body: Column(
          children: [
            const OfflineBanner(),
            Expanded(
              child: Stack(
                children: [
                  // ── Watermark ──────────────────────────────────────────────
                  Positioned(
                    right: -20, bottom: 60,
                    child: Opacity(
                      opacity: 0.07,
                      child: Icon(
                        Icons.inventory_2_outlined,
                        size: 280,
                        color: AppTheme.primaryDark,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 40, bottom: 110,
                    child: Opacity(
                      opacity: 0.07,
                      child: Icon(
                        Icons.eco_outlined,
                        size: 90,
                        color: AppTheme.primaryMid,
                      ),
                    ),
                  ),
                  // ── Treść ──────────────────────────────────────────────────
                  SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [

                    // ── 1. Typ karty (animated header) ──────────────────────
                    _KartaTypeCard(isKWG: _isKWG),
                    const SizedBox(height: 16),

                    // ── 2. Opcje dostawy (RYLEX / GRÓJECKA) — TOP ───────────
                    _SectionLabel('Opcje dostawy', icon: Icons.local_shipping_outlined, step: 1),
                    Row(children: [
                      Expanded(
                        child: _ToggleTile(
                          label: 'RYLEX',
                          icon: Icons.local_shipping_outlined,
                          active: _rylex,
                          color: const Color(0xFF7C3AED),
                          onTap: () => setState(() { _rylex = !_rylex; if (_rylex) _grojecka = false; }),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ToggleTile(
                          label: 'GRÓJECKA',
                          icon: Icons.agriculture_outlined,
                          active: _grojecka,
                          color: AppTheme.successGreen,
                          onTap: () => setState(() { _grojecka = !_grojecka; if (_grojecka) _rylex = false; }),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 16),

                    // ── 3. Data + Nr dostawy ────────────────────────────────
                    _SectionLabel('Dane dostawy', icon: Icons.calendar_today_outlined, step: 2),
                    _FormCard(
                      child: Column(children: [
                        InkWell(
                          onTap: _pickDate,
                          borderRadius: BorderRadius.circular(10),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Data dostarczenia',
                              prefixIcon: Icon(Icons.calendar_today_outlined),
                            ),
                            child: Text(df.format(_data)),
                          ),
                        ),
                        if (_nrRequired) ...[
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(
                            child: TextFormField(
                              controller: _nrDostawyCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Nr dostawy *',
                                prefixIcon: Icon(Icons.tag),
                                hintText: '1, 42...',
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: () async {
                              final n = await _getNextDeliveryNumber();
                              _nrDostawyCtrl.text = n.toString();
                              setState(() {});
                            },
                            icon: const Icon(Icons.auto_fix_high, size: 16),
                            label: const Text('Auto'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.primaryMid,
                              minimumSize: const Size(0, 52),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                            ),
                          ),
                        ]),
                        ] else
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text('Nr dostawy: auto (Rylex/Grójecka)',
                              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary,
                                  fontStyle: FontStyle.italic)),
                          ),
                      ]),
                    ),
                    const SizedBox(height: 16),

                    // ── 4. Dostawca ─────────────────────────────────────────
                    _SectionLabel('Dostawca', icon: Icons.business_outlined, step: 3),
                    _FormCard(
                      child: suppliersAsync.when(
                        loading: () => const Center(child: LinearProgressIndicator()),
                        error: (e, _) => Text('Błąd ładowania: $e',
                            style: const TextStyle(color: AppTheme.errorRed)),
                        data: (suppliers) => _DostawcaSelector(
                          suppliers: suppliers,
                          selected: _dostawca,
                          onSelected: (s) => setState(() {
                            _dostawca = s;
                            final n = s.nazwa.toUpperCase();
                            if (n.contains('RYLEX')) _rylex = true;
                            if (n.contains('GRÓJECKA') || n.contains('GROJECKA')) {
                              _grojecka = true;
                            }
                          }),
                          onClear: () => setState(() {
                            _dostawca = null;
                            _rylex = false;
                            _grojecka = false;
                          }),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── 5. Przeznaczenie (tap-kafelki) ──────────────────────
                    _SectionLabel('Przeznaczenie', icon: Icons.category_outlined, step: 4),
                    _FormCard(
                      child: Row(
                        children: List.generate(_przeznaczenia.length, (i) {
                          final p = _przeznaczenia[i];
                          final sel = _przeznaczenieKod == p.$1;
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(right: i < _przeznaczenia.length - 1 ? 8 : 0),
                              child: _OptionTile(
                                label: p.$2,
                                icon: p.$3,
                                selected: sel,
                                color: AppTheme.primaryMid,
                                onTap: () => setState(() => _przeznaczenieKod = p.$1),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── 6. Owoc (tap-kafelki grid) ──────────────────────────
                    _SectionLabel('Owoc / Surowiec', icon: Icons.eco_outlined, step: 5),
                    _FormCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: owoce.map((o) {
                              final sel    = _owoc == o;
                              final active = sel ? AppTheme.primaryMid : AppTheme.textSecondary;
                              return GestureDetector(
                                onTap: () => setState(() {
                                  _owoc = o;
                                  _isEko = false;
                                }),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                  decoration: BoxDecoration(
                                    color: sel
                                        ? AppTheme.primaryMid.withAlpha(20)
                                        : AppTheme.background,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: sel ? AppTheme.primaryMid : AppTheme.borderLight,
                                      width: sel ? 2 : 1,
                                    ),
                                  ),
                                  child: Text(
                                    o[0].toUpperCase() + o.substring(1),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                                      color: active,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          if (_owoc != null) ...[
                            const SizedBox(height: 10),
                            FilterChip(
                              label: const Text('EKO'),
                              selected: _isEko,
                              avatar: const Icon(Icons.eco, size: 14),
                              onSelected: (v) => setState(() => _isEko = v),
                              selectedColor: AppTheme.successGreen.withAlpha(30),
                              checkmarkColor: AppTheme.successGreen,
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _isEko ? AppTheme.successGreen : AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // ── 7. LOT preview z prawdziwym QR ──────────────────────
                    if (_canProceed) ...[
                      const SizedBox(height: 16),
                      _LotPreviewCard(lot: _lotPreview, isKWG: _isKWG, isRG: _rylex || _grojecka),
                    ],

                    const SizedBox(height: 24),

                    // ── 8. Przycisk ─────────────────────────────────────────
                    ElevatedButton.icon(
                      onPressed: _canProceed ? _proceed : null,
                      icon: const Icon(Icons.arrow_forward),
                      label: Text(_isKWG ? 'Przejdź do KWG' : 'Przejdź do KW'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
          ],
        ),
      ),
    );
  }
}

// ── Widgety ────────────────────────────────────────────────────────────────────

class _KartaTypeCard extends StatelessWidget {
  final bool isKWG;
  const _KartaTypeCard({required this.isKWG});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isKWG
              ? [const Color(0xFFB45309), const Color(0xFFF59E0B)]
              : [AppTheme.primaryDark, AppTheme.primaryMid],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isKWG ? Icons.warehouse_outlined : Icons.scale,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isKWG ? 'KARTA KWG' : 'KARTA KW',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                isKWG ? 'Grójecka / Rylex / Inny owoc' : 'Ważenie standardowe (jabłko/gruszka)',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  const _ToggleTile({
    required this.label,
    required this.icon,
    required this.active,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: active ? color.withAlpha(25) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: active ? color : AppTheme.borderLight, width: active ? 2 : 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(active ? Icons.check_box : Icons.check_box_outline_blank,
              size: 20, color: active ? color : AppTheme.textSecondary),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(
            fontWeight: FontWeight.w700, fontSize: 14,
            color: active ? color : AppTheme.textSecondary,
          )),
        ],
      ),
    ),
  );
}

class _OptionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _OptionTile({
    required this.label, required this.icon, required this.selected,
    required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: selected ? color.withAlpha(20) : AppTheme.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: selected ? color : AppTheme.borderLight, width: selected ? 2 : 1),
      ),
      child: Column(children: [
        Icon(icon, size: 20, color: selected ? color : AppTheme.textSecondary),
        const SizedBox(height: 4),
        Text(label, textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: selected ? color : AppTheme.textSecondary,
            )),
      ]),
    ),
  );
}

class _FormCard extends StatelessWidget {
  final Widget child;
  const _FormCard({required this.child});

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: const EdgeInsets.all(14), child: child),
  );
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final IconData? icon;
  final int? step;
  const _SectionLabel(this.text, {this.icon, this.step});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        // Krok numeryczny
        if (step != null) ...[
          Container(
            width: 24, height: 24,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppTheme.primaryMid,
              shape: BoxShape.circle,
            ),
            child: Text('$step', style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white,
            )),
          ),
          const SizedBox(width: 8),
        ],
        // Ikona
        if (icon != null) ...[
          Icon(icon, size: 15, color: AppTheme.primaryMid),
          const SizedBox(width: 6),
        ],
        // Tekst
        Text(text.toUpperCase(), style: const TextStyle(
          fontSize: 11, fontWeight: FontWeight.w700,
          letterSpacing: 1.0, color: AppTheme.textSecondary,
        )),
      ],
    ),
  );
}

// ── Dostawca selector ─────────────────────────────────────────────────────────

class _DostawcaSelector extends StatefulWidget {
  final List<Supplier> suppliers;
  final Supplier? selected;
  final ValueChanged<Supplier> onSelected;
  final VoidCallback onClear;
  const _DostawcaSelector({
    required this.suppliers, required this.selected,
    required this.onSelected, required this.onClear,
  });

  @override
  State<_DostawcaSelector> createState() => _DostawcaSelectorState();
}

class _DostawcaSelectorState extends State<_DostawcaSelector> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    if (widget.selected != null) {
      return Row(children: [
        const Icon(Icons.check_circle_outline, color: AppTheme.accent, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(widget.selected!.pelnaNazwa,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
        IconButton(icon: const Icon(Icons.close, size: 18), onPressed: widget.onClear),
      ]);
    }

    final filtered = _search.isEmpty
        ? widget.suppliers
        : widget.suppliers
            .where((s) => s.pelnaNazwa.toLowerCase().contains(_search.toLowerCase()))
            .toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(
        decoration: const InputDecoration(
          labelText: 'Szukaj dostawcy...',
          prefixIcon: Icon(Icons.search_outlined),
        ),
        onChanged: (v) => setState(() => _search = v),
      ),
      if (_search.isNotEmpty) ...[
        const SizedBox(height: 6),
        Container(
          constraints: const BoxConstraints(maxHeight: 200),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppTheme.borderLight),
            borderRadius: BorderRadius.circular(10),
          ),
          child: filtered.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Brak wyników', style: TextStyle(color: AppTheme.textSecondary)),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) => ListTile(
                    dense: true,
                    leading: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryMid.withAlpha(20),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(filtered[i].kod, style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primaryDark)),
                    ),
                    title: Text(filtered[i].nazwa, style: const TextStyle(fontSize: 13)),
                    onTap: () => widget.onSelected(filtered[i]),
                  ),
                ),
        ),
      ],
    ]);
  }
}

// ── LOT preview z QR ──────────────────────────────────────────────────────────

class _LotPreviewCard extends StatelessWidget {
  final String lot;
  final bool isKWG;
  final bool isRG;
  const _LotPreviewCard({required this.lot, required this.isKWG, this.isRG = false});

  @override
  Widget build(BuildContext context) {
    final badgeColor = isKWG ? AppTheme.warningOrange : AppTheme.accent;
    final badgeLabel = isKWG ? 'KWG' : 'KW Standard';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isKWG
              ? [const Color(0xFFB45309), const Color(0xFF92400E)]
              : [AppTheme.primaryDark, AppTheme.primaryMid],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        // QR code
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(4),
          child: QrImageView(
            data: lot,
            version: QrVersions.auto,
            size: 80,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: AppTheme.primaryDark,
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: AppTheme.primaryDark,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isRG ? 'PRZEKIEROWANIE DO KWG' : 'STWORZONY LOT',
                style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700,
                  letterSpacing: 1.2, color: Colors.white.withValues(alpha: 0.6),
                )),
            const SizedBox(height: 4),
            Text(
              isRG ? 'Numer dostawy nadawany per odmiana' : lot,
              style: TextStyle(
                fontSize: isRG ? 13 : 15,
                fontWeight: FontWeight.w800,
                color: Colors.white.withValues(alpha: isRG ? 0.7 : 1.0),
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor.withAlpha(50),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: badgeColor.withAlpha(120)),
              ),
              child: Text(badgeLabel, style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: badgeColor,
              )),
            ),
          ],
        )),
      ]),
    );
  }
}
