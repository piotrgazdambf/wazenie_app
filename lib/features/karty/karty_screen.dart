import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import '../../app/theme.dart';
import '../../core/auth/pin_auth_service.dart';
import '../../core/constants.dart';
import '../../shared/widgets/offline_banner.dart';
import '../kw/kw_label_generator.dart';
import '../kw/kw_pdf_generator.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class KartaEntry {
  final String id;
  final String lot;
  final String data;
  final String nrDostawy;
  final String dostawca;
  final String dostawcaKod;
  final String przeznaczenie;
  final String owoc;
  final String odmiana;
  final String skrzynie;
  final String wagaNetto;
  final String wagaBrutto;
  final String wagaA1Zal;
  final String wagaA1Roz;
  final String wagaA2Zal;
  final String wagaA2Roz;
  final String brix;
  final String odpad;
  final String twardosc;
  final String kaliber;
  final String zwrotPct;
  final String stanOpak;
  final String stanAuto;
  final String status;
  final bool isKwg;

  const KartaEntry({
    required this.id,
    required this.lot,
    required this.data,
    required this.nrDostawy,
    required this.dostawca,
    required this.dostawcaKod,
    required this.przeznaczenie,
    required this.owoc,
    required this.odmiana,
    required this.skrzynie,
    required this.wagaNetto,
    required this.wagaBrutto,
    required this.wagaA1Zal,
    required this.wagaA1Roz,
    required this.wagaA2Zal,
    required this.wagaA2Roz,
    required this.brix,
    required this.odpad,
    required this.twardosc,
    required this.kaliber,
    required this.zwrotPct,
    required this.stanOpak,
    required this.stanAuto,
    required this.status,
    required this.isKwg,
  });

  factory KartaEntry.fromFirestore(String id, Map<String, dynamic> d) => KartaEntry(
    id:           id,
    lot:          d['lot'] as String? ?? d['id'] as String? ?? '',
    data:         d['data'] as String? ?? '',
    nrDostawy:    d['nr_dostawy'] as String? ?? '',
    dostawca:     d['dostawca'] as String? ?? '',
    dostawcaKod:  d['dostawca_kod'] as String? ?? '',
    przeznaczenie:d['przeznaczenie'] as String? ?? '',
    owoc:         d['owoc'] as String? ?? '',
    odmiana:      d['odmiana'] as String? ?? '',
    skrzynie:     d['skrzynie'] as String? ?? '',
    wagaNetto:    d['waga_netto'] as String? ?? '',
    wagaBrutto:   d['waga_brutto']?.toString() ?? '',
    wagaA1Zal:    d['waga_a1_zal']?.toString() ?? '',
    wagaA1Roz:    d['waga_a1_roz']?.toString() ?? '',
    wagaA2Zal:    d['waga_a2_zal']?.toString() ?? '',
    wagaA2Roz:    d['waga_a2_roz']?.toString() ?? '',
    brix:         d['brix'] as String? ?? '',
    odpad:        d['odpad'] as String? ?? '',
    twardosc:     d['twardosc'] as String? ?? '',
    kaliber:      d['kaliber'] as String? ?? '',
    zwrotPct:     d['zwrot_pct'] as String? ?? '',
    stanOpak:     d['stan_opakowania'] as String? ?? '',
    stanAuto:     d['stan_samochodu'] as String? ?? '',
    status:       d['status'] as String? ?? '',
    isKwg:        d['is_kwg'] as bool? ?? false,
  );
}

// ── Provider ──────────────────────────────────────────────────────────────────

final kartyListProvider = StreamProvider<List<KartaEntry>>((ref) {
  return FirebaseFirestore.instance
      .collection(AppConstants.colDeliveries)
      .orderBy('createdAt', descending: true)
      .limit(300)
      .snapshots()
      .map((snap) =>
          snap.docs.map((d) => KartaEntry.fromFirestore(d.id, d.data())).toList());
});

// ── Ekran listy ───────────────────────────────────────────────────────────────

class KartyScreen extends ConsumerStatefulWidget {
  const KartyScreen({super.key});

  @override
  ConsumerState<KartyScreen> createState() => _KartyScreenState();
}

class _KartyScreenState extends ConsumerState<KartyScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final kartyAsync = ref.watch(kartyListProvider);
    final session    = ref.watch(currentSessionProvider);
    final isAdmin    = session?.user.isAdmin ?? false;

    return OfflineOverflowGuard(
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: const Text('Karty Ważenia'),
          leading: BackButton(onPressed: () => context.go('/home')),
        ),
        body: Column(
          children: [
            const OfflineBanner(),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Szukaj (LOT, odmiana, dostawca...)',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onChanged: (v) => setState(() => _search = v.toLowerCase()),
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: kartyAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => _ErrorView(message: e.toString()),
                data: (list) {
                  final filtered = _search.isEmpty
                      ? list
                      : list.where((e) =>
                          e.lot.toLowerCase().contains(_search) ||
                          e.odmiana.toLowerCase().contains(_search) ||
                          e.dostawca.toLowerCase().contains(_search) ||
                          e.nrDostawy.toLowerCase().contains(_search)).toList();

                  if (filtered.isEmpty) return const _EmptyView();

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) =>
                        _KartaCard(entry: filtered[i], isAdmin: isAdmin),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Karta w liście ────────────────────────────────────────────────────────────

class _KartaCard extends ConsumerWidget {
  final KartaEntry entry;
  final bool isAdmin;
  const _KartaCard({required this.entry, required this.isAdmin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = _statusColor(entry.status);
    final typeColor   = entry.isKwg ? AppTheme.primaryLight : AppTheme.primaryMid;
    final typeLabel   = entry.isKwg ? 'KWG' : 'KW';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nagłówek — kliknięcie otwiera surowe dane
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                builder: (_) => _KartaDetailSheet(entry: entry, isAdmin: isAdmin),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: typeColor.withAlpha(20),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: typeColor.withAlpha(60)),
                      ),
                      child: Text(typeLabel,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: typeColor)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(entry.lot,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14,
                              color: AppTheme.primaryDark, fontFamily: 'monospace')),
                    ),
                    if (entry.status.isNotEmpty)
                      _StatusChip(label: _statusLabel(entry.status), color: statusColor),
                  ]),
                  const SizedBox(height: 6),
                  _InfoRow(Icons.eco_outlined,
                      '${_cap(entry.owoc)}${entry.odmiana.isNotEmpty ? " • ${entry.odmiana}" : ""}'),
                  _InfoRow(Icons.business_outlined, entry.dostawca),
                  _InfoRow(Icons.calendar_today_outlined,
                      '${_fmtDate(entry.data)}  •  Dostawa #${entry.nrDostawy}'),
                  if (entry.wagaNetto.isNotEmpty)
                    _InfoRow(Icons.scale_outlined,
                        'Netto: ${entry.wagaNetto} kg  •  Skrz: ${entry.skrzynie}'),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Przyciski akcji
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.visibility_outlined, size: 15),
                  label: const Text('Podgląd'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  onPressed: () => _podglad(context),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.print_outlined, size: 15),
                  label: const Text('Drukuj'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  onPressed: () => _drukuj(context),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.label_outline, size: 15),
                  label: const Text('Etykieta'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  onPressed: () => _etykieta(context),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Future<void> _podglad(BuildContext context) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection(AppConstants.colDeliveries).doc(entry.id).get();
      if (!snap.exists || !context.mounted) return;
      final pdfData = KwPdfData.fromFirestoreMap(snap.data()!);
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text('Podgląd KW: ${entry.lot}')),
          body: PdfPreview(
            pdfFileName: 'KW_${entry.id}',
            build: (_) => KwPdfGenerator.generate(pdfData),
            maxPageWidth: 520,
            allowPrinting: true,
            allowSharing: true,
            canChangePageFormat: false,
            canDebug: false,
          ),
        ),
      ));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd podglądu: $e'), backgroundColor: AppTheme.errorRed));
      }
    }
  }

  Future<void> _etykieta(BuildContext context) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection(AppConstants.colDeliveries).doc(entry.id).get();
      if (!snap.exists) return;
      final d = snap.data()!;
      final dateRaw = d['data'] as String? ?? '';
      final dateStr = dateRaw.length == 10 && dateRaw[4] == '-'
          ? '${dateRaw.substring(8)}.${dateRaw.substring(5,7)}.${dateRaw.substring(0,4)}'
          : dateRaw;
      final label = KwLabelData(
        lot:           d['lot'] as String? ?? entry.lot,
        odmiana:       d['odmiana'] as String? ?? entry.odmiana,
        data:          dateStr,
        dostawca:      d['dostawca'] as String? ?? entry.dostawca,
        dostawcaKod:   d['dostawca_kod'] as String? ?? entry.dostawcaKod,
        przeznaczenie: d['przeznaczenie'] as String? ?? entry.przeznaczenie,
      );
      await Printing.layoutPdf(
        name: 'Etykieta_${entry.lot}',
        onLayout: (_) => KwLabelGenerator.generate([label]),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd etykiety: $e'), backgroundColor: AppTheme.errorRed));
      }
    }
  }

  Future<void> _drukuj(BuildContext context) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection(AppConstants.colDeliveries).doc(entry.id).get();
      if (!snap.exists) return;
      final pdfData = KwPdfData.fromFirestoreMap(snap.data()!);
      await Printing.layoutPdf(
        name: 'KW_${snap.id}',
        onLayout: (_) => KwPdfGenerator.generate(pdfData),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd druku: $e'), backgroundColor: AppTheme.errorRed));
      }
    }
  }

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  static String _fmtDate(String d) {
    if (d.length == 10 && d[4] == '-' && d[7] == '-') {
      return '${d.substring(8)}.${d.substring(5, 7)}.${d.substring(0, 4)}';
    }
    return d;
  }

  Color _statusColor(String s) => switch (s.toUpperCase()) {
        'PRZYJETO'   => AppTheme.warningOrange,
        'PRZESŁANO'  => AppTheme.successGreen,
        'ROZLICZONO' => AppTheme.textSecondary,
        _            => AppTheme.textSecondary,
      };

  String _statusLabel(String s) => switch (s.toUpperCase()) {
        'PRZYJETO'   => 'Przyjęto',
        'PRZESŁANO'  => 'Przesłano',
        'ROZLICZONO' => 'Rozliczono',
        _            => s,
      };
}

// ── Detail sheet ──────────────────────────────────────────────────────────────

class _KartaDetailSheet extends StatefulWidget {
  final KartaEntry entry;
  final bool isAdmin;
  const _KartaDetailSheet({required this.entry, required this.isAdmin});

  @override
  State<_KartaDetailSheet> createState() => _KartaDetailSheetState();
}

class _KartaDetailSheetState extends State<_KartaDetailSheet> {
  bool _editing = false;
  bool _saving  = false;

  late final TextEditingController _brixCtrl;
  late final TextEditingController _odpadCtrl;
  late final TextEditingController _twardCtrl;
  late final TextEditingController _kaliberCtrl;
  late final TextEditingController _zwrotCtrl;
  late final TextEditingController _wagaNettoCtrl;
  late String _status;

  @override
  void initState() {
    super.initState();
    final e      = widget.entry;
    _brixCtrl    = TextEditingController(text: e.brix);
    _odpadCtrl   = TextEditingController(text: e.odpad);
    _twardCtrl   = TextEditingController(text: e.twardosc);
    _kaliberCtrl = TextEditingController(text: e.kaliber);
    _zwrotCtrl   = TextEditingController(text: e.zwrotPct);
    _wagaNettoCtrl = TextEditingController(text: e.wagaNetto);
    _status      = e.status;
  }

  @override
  void dispose() {
    _brixCtrl.dispose();
    _odpadCtrl.dispose();
    _twardCtrl.dispose();
    _kaliberCtrl.dispose();
    _zwrotCtrl.dispose();
    _wagaNettoCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection(AppConstants.colDeliveries)
          .doc(widget.entry.id)
          .update({
        'brix':       _brixCtrl.text.trim(),
        'odpad':      _odpadCtrl.text.trim(),
        'twardosc':   _twardCtrl.text.trim(),
        'kaliber':    _kaliberCtrl.text.trim(),
        'zwrot_pct':  _zwrotCtrl.text.trim(),
        'waga_netto': _wagaNettoCtrl.text.trim(),
        'status':     _status,
      });
      if (mounted) {
        setState(() { _editing = false; _saving = false; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Zapisano zmiany'),
            backgroundColor: AppTheme.successGreen));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Błąd: $e'),
            backgroundColor: AppTheme.errorRed));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      builder: (_, ctrl) => Column(
        children: [
          // Handle + nagłówek
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                      color: AppTheme.borderLight,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.lot,
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primaryDark,
                              fontFamily: 'monospace')),
                      Text(
                          '${e.isKwg ? "KWG" : "KW"}  •  ${e.data}  •  Dostawa #${e.nrDostawy}',
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                if (widget.isAdmin)
                  _editing
                      ? Row(children: [
                          TextButton(
                              onPressed: _saving
                                  ? null
                                  : () => setState(() => _editing = false),
                              child: const Text('Anuluj')),
                          ElevatedButton(
                            onPressed: _saving ? null : _save,
                            style: ElevatedButton.styleFrom(
                                minimumSize: const Size(80, 36)),
                            child: _saving
                                ? const SizedBox(
                                    width: 16, height: 16,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2))
                                : const Text('Zapisz'),
                          ),
                        ])
                      : IconButton(
                          icon: const Icon(Icons.edit_outlined,
                              color: AppTheme.primaryMid),
                          tooltip: 'Edytuj (admin)',
                          onPressed: () => setState(() => _editing = true),
                        ),
              ]),
            ]),
          ),
          const Divider(height: 16),
          Expanded(
            child: ListView(
              controller: ctrl,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
              children: [
                _Section('DANE DOSTAWY', [
                  _Row('Dostawca', e.dostawca),
                  _Row('Kod dostawcy', e.dostawcaKod),
                  _Row('Owoc', _cap(e.owoc)),
                  if (e.odmiana.isNotEmpty) _Row('Odmiana', e.odmiana),
                  _Row('Przeznaczenie', e.przeznaczenie),
                  _Row('Status', e.status),
                ]),
                const SizedBox(height: 12),

                _Section('WAGI', [
                  if (e.wagaBrutto.isNotEmpty)
                    _Row('Brutto', '${e.wagaBrutto} kg'),
                  _editing
                      ? _EditRow('Netto', _wagaNettoCtrl, suffix: 'kg')
                      : _Row('Netto', '${e.wagaNetto} kg', bold: true),
                  if (e.skrzynie.isNotEmpty)
                    _Row('Skrzynie (D/P)', e.skrzynie),
                ]),
                const SizedBox(height: 12),

                if (e.wagaA1Zal.isNotEmpty || e.wagaA1Roz.isNotEmpty) ...[
                  _Section('WAGI AUT', [
                    if (e.wagaA1Zal.isNotEmpty)
                      _Row('Auto 1 — załadunek', '${e.wagaA1Zal} kg'),
                    if (e.wagaA1Roz.isNotEmpty)
                      _Row('Auto 1 — rozładunek', '${e.wagaA1Roz} kg'),
                    if (e.wagaA2Zal.isNotEmpty)
                      _Row('Auto 2 — załadunek', '${e.wagaA2Zal} kg'),
                    if (e.wagaA2Roz.isNotEmpty)
                      _Row('Auto 2 — rozładunek', '${e.wagaA2Roz} kg'),
                  ]),
                  const SizedBox(height: 12),
                ],

                _Section('PARAMETRY JAKOŚCI', [
                  _editing
                      ? _EditRow('BRIX', _brixCtrl)
                      : _Row('BRIX', e.brix.isNotEmpty ? e.brix : '—'),
                  _editing
                      ? _EditRow('Odpad %', _odpadCtrl, suffix: '%')
                      : _Row('Odpad', e.odpad.isNotEmpty ? '${e.odpad}%' : '—'),
                  _editing
                      ? _EditRow('Twardość', _twardCtrl)
                      : _Row('Twardość',
                          e.twardosc.isNotEmpty ? e.twardosc : '—'),
                  _editing
                      ? _EditRow('PW %', _kaliberCtrl, suffix: '%')
                      : _Row('PW (kaliber+oczka)',
                          e.kaliber.isNotEmpty ? '${e.kaliber}%' : '—'),
                  _editing
                      ? _EditRow('Zwrot %', _zwrotCtrl, suffix: '%')
                      : _Row('Zwrot',
                          e.zwrotPct.isNotEmpty ? '${e.zwrotPct}%' : '—'),
                ]),
                const SizedBox(height: 12),

                _Section('STAN', [
                  _Row('Opakowanie',
                      e.stanOpak.isNotEmpty ? e.stanOpak : '—'),
                  _Row('Samochód',
                      e.stanAuto.isNotEmpty ? e.stanAuto : '—'),
                ]),

                if (_editing && widget.isAdmin) ...[
                  const SizedBox(height: 12),
                  _Section('STATUS', [
                    _StatusSelector(
                      current: _status,
                      onChanged: (s) => setState(() => _status = s),
                    ),
                  ]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ── Status selector ───────────────────────────────────────────────────────────

class _StatusSelector extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;
  const _StatusSelector({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const statuses = ['PRZYJETO', 'PRZESŁANO', 'ROZLICZONO'];
    return Row(
      children: statuses.map((s) {
        final sel = s == current;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => onChanged(s),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: sel
                      ? AppTheme.primaryDark.withAlpha(15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color:
                        sel ? AppTheme.primaryDark : AppTheme.borderLight,
                    width: sel ? 1.5 : 1,
                  ),
                ),
                child: Text(s,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight:
                            sel ? FontWeight.w700 : FontWeight.normal,
                        color: sel
                            ? AppTheme.primaryDark
                            : AppTheme.textSecondary)),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Widget helpers ────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> rows;
  const _Section(this.title, this.rows);

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary,
                      letterSpacing: 1.2)),
              const SizedBox(height: 10),
              ...rows,
            ],
          ),
        ),
      );
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _Row(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textSecondary)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        bold ? FontWeight.w700 : FontWeight.w500,
                    color: bold
                        ? AppTheme.primaryDark
                        : AppTheme.textPrimary)),
          ),
        ]),
      );
}

class _EditRow extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final String? suffix;
  const _EditRow(this.label, this.ctrl, {this.suffix});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textSecondary)),
          ),
          Expanded(
            child: TextField(
              controller: ctrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                suffixText: suffix,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ]),
      );
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withAlpha(25),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withAlpha(80)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Row(children: [
          Icon(icon, size: 14, color: AppTheme.textSecondary),
          const SizedBox(width: 6),
          Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.textSecondary))),
        ]),
      );
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline,
                size: 48, color: AppTheme.errorRed),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary)),
          ]),
        ),
      );
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) => const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.description_outlined,
              size: 64, color: AppTheme.borderLight),
          SizedBox(height: 12),
          Text('Brak kart ważenia',
              style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 15)),
          SizedBox(height: 4),
          Text('Karty pojawią się po przyjęciu przez WSG',
              style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13)),
        ]),
      );
}
