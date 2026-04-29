import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import '../../app/theme.dart';
import '../../core/auth/pin_auth_service.dart';
import '../../core/constants.dart';
import '../../shared/widgets/offline_banner.dart';
import '../../shared/widgets/wpisz_wage_dialog.dart';
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
  final String kwgType;
  final bool wagaNettoBrak;
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
    this.kwgType = '',
    this.wagaNettoBrak = false,
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
    kwgType:      d['kwg_type'] as String? ?? '',
    wagaNettoBrak: d['waga_netto_brak'] as bool? ?? false,
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

class _KartyScreenState extends ConsumerState<KartyScreen>
    with SingleTickerProviderStateMixin {
  String _search = '';
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  List<KartaEntry> _filter(List<KartaEntry> list, String tab) {
    switch (tab) {
      case 'czaplin': return list.where((e) => !e.isKwg).toList();
      case 'grojecka': return list.where((e) => e.isKwg && e.kwgType == 'G').toList();
      case 'rylex': return list.where((e) => e.isKwg && e.kwgType == 'R').toList();
      default: return list;
    }
  }

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
          bottom: TabBar(
            controller: _tabCtrl,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            isScrollable: true,
            tabs: const [
              Tab(text: 'Wszystkie'),
              Tab(text: 'Czaplin'),
              Tab(text: 'Grójecka'),
              Tab(text: 'RYLEX'),
            ],
          ),
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
                  final searched = _search.isEmpty
                      ? list
                      : list.where((e) =>
                          e.lot.toLowerCase().contains(_search) ||
                          e.odmiana.toLowerCase().contains(_search) ||
                          e.dostawca.toLowerCase().contains(_search) ||
                          e.nrDostawy.toLowerCase().contains(_search)).toList();

                  Widget buildTab(List<KartaEntry> items) {
                    if (items.isEmpty) return const _EmptyView();
                    final grouped = <String, List<KartaEntry>>{};
                    for (final e in items) {
                      final key = e.lot.replaceAll(RegExp(r'\d+$'), '');
                      grouped.putIfAbsent(key, () => []);
                      grouped[key]!.add(e);
                    }
                    final keys = grouped.keys.toList();
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
                      itemCount: keys.length,
                      itemBuilder: (ctx, i) => _DeliveryGroup(
                        baseLot: keys[i],
                        entries: grouped[keys[i]]!,
                        isAdmin: isAdmin,
                      ),
                    );
                  }

                  return TabBarView(
                    controller: _tabCtrl,
                    children: [
                      buildTab(searched),
                      buildTab(_filter(searched, 'czaplin')),
                      buildTab(_filter(searched, 'grojecka')),
                      buildTab(_filter(searched, 'rylex')),
                    ],
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

// ── Grupowanie dostaw ─────────────────────────────────────────────────────────

class _DeliveryGroup extends ConsumerStatefulWidget {
  final String baseLot;
  final List<KartaEntry> entries;
  final bool isAdmin;
  const _DeliveryGroup({required this.baseLot, required this.entries, required this.isAdmin});

  @override
  ConsumerState<_DeliveryGroup> createState() => _DeliveryGroupState();
}

class _DeliveryGroupState extends ConsumerState<_DeliveryGroup> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final e0 = widget.entries.first;
    final totalNetto = widget.entries.fold(0.0, (s, e) {
      return s + (double.tryParse(e.wagaNetto.replaceAll(',', '.')) ?? 0);
    });
    final odmiany = widget.entries.map((e) => e.odmiana).where((o) => o.isNotEmpty).toList();
    final owocLabel = _cap(e0.owoc) +
        (odmiany.isNotEmpty ? '  •  ${odmiany.join(' / ')}' : '');

    final hasIncomplete = widget.entries.any((e) => e.wagaNettoBrak);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: hasIncomplete
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppTheme.errorRed, width: 1.5))
          : null,
      child: Column(
        children: [
          // ── Nagłówek grupy ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(widget.baseLot,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 15,
                                color: AppTheme.primaryDark, fontFamily: 'monospace')),
                        if (hasIncomplete) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.warning_amber_rounded,
                              color: AppTheme.errorRed, size: 14),
                        ],
                      ]),
                      const SizedBox(height: 4),
                      Text(owocLabel, style: const TextStyle(fontSize: 13)),
                      Text(e0.dostawca,
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      Text('${_fmtDate(e0.data)}  •  ${totalNetto.toStringAsFixed(0)} kg  •  ${widget.entries.length} ${widget.entries.length == 1 ? 'odmiana' : 'odmiany'}',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                // Akcje: Dane | Podgląd PDF | Drukuj | Rozwiń
                Column(
                  children: [
                    Row(children: [
                      IconButton(
                        icon: const Icon(Icons.info_outline, size: 20),
                        tooltip: 'Dane',
                        onPressed: () => _showDetail(context, widget.entries.first),
                      ),
                      IconButton(
                        icon: const Icon(Icons.visibility_outlined, size: 20),
                        tooltip: 'Podgląd karty (PDF)',
                        onPressed: () => _podgladPDF(context),
                      ),
                      IconButton(
                        icon: const Icon(Icons.print_outlined, size: 20),
                        tooltip: 'Drukuj kartę',
                        onPressed: () => _drukuj(context, widget.entries.first),
                      ),
                      IconButton(
                        icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 22),
                        tooltip: 'Odmiany',
                        onPressed: () => setState(() => _expanded = !_expanded),
                      ),
                    ]),
                  ],
                ),
              ],
            ),
          ),
          // ── Lista odmian (rozwijana) ────────────────────────────────────
          if (_expanded)
            ...widget.entries.map((e) => Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
              ),
              child: _KartaCard(entry: e, isAdmin: widget.isAdmin, compact: true),
            )),
        ],
      ),
    );
  }

  void _showDetail(BuildContext context, KartaEntry e) {
    showModalBottomSheet<void>(
      context: context, isScrollControlled: true, useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _KartaDetailSheet(entry: e, isAdmin: widget.isAdmin),
    );
  }

  Future<void> _podgladPDF(BuildContext context) async {
    try {
      final snaps = await Future.wait(
        widget.entries.map((e) => FirebaseFirestore.instance
            .collection(AppConstants.colDeliveries).doc(e.id).get()),
      );
      final docs = snaps.where((d) => d.exists).map((d) => d.data()!).toList();
      if (docs.isEmpty || !context.mounted) return;
      final pdfData = KwPdfData.fromMultipleDocs(docs);
      if (!context.mounted) return;
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text('Podgląd: ${widget.baseLot}')),
          body: PdfPreview(
            build: (_) => KwPdfGenerator.generate(pdfData),
            maxPageWidth: 700,
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
          SnackBar(content: Text('Błąd podglądu: $e'),
              backgroundColor: AppTheme.errorRed));
      }
    }
  }

  Future<void> _drukuj(BuildContext context, KartaEntry _) async {
    try {
      final snaps = await Future.wait(
        widget.entries.map((e) => FirebaseFirestore.instance
            .collection(AppConstants.colDeliveries).doc(e.id).get()),
      );
      final docs = snaps.where((d) => d.exists).map((d) => d.data()!).toList();
      if (docs.isEmpty || !context.mounted) return;
      final pdfData = KwPdfData.fromMultipleDocs(docs);
      await Printing.layoutPdf(
        name: 'KartaWazenia_${widget.entries.first.lot}',
        onLayout: (_) => KwPdfGenerator.generate(pdfData),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd druku: $e'),
              backgroundColor: AppTheme.errorRed));
      }
    }
  }

  static String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
  static String _fmtDate(String d) {
    if (d.isEmpty) return '';
    try {
      final parts = d.split('-');
      if (parts.length == 3) return '${parts[2]}.${parts[1]}.${parts[0]}';
    } catch (_) {}
    return d;
  }
}

// ── Karta w liście ────────────────────────────────────────────────────────────

class _KartaCard extends ConsumerWidget {
  final KartaEntry entry;
  final bool isAdmin;
  final bool compact;
  const _KartaCard({required this.entry, required this.isAdmin, this.compact = false});

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
            // Baner "brak wagi netto"
            if (entry.wagaNettoBrak) ...[
              const SizedBox(height: 8),
              _KartaWpisButton(entry: entry),
            ],
            const SizedBox(height: 10),
            // compact: tylko Etykieta; pełny widok: Podgląd + Drukuj + Etykieta
            Row(children: [
              if (!compact) ...[
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
              ],
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
      String _fmt(String raw) => raw.length == 10 && raw[4] == '-'
          ? '${raw.substring(8)}.${raw.substring(5,7)}.${raw.substring(0,4)}'
          : raw;
      final isKwgRG = (d['is_kwg'] == true) && (d['kwg_type'] as String? ?? '').isNotEmpty;
      final rawData    = d['data']     as String? ?? '';
      final rawDataWsg = d['data_wsg'] as String? ?? '';
      // Dla RG: prawa data = WSG, lewa w LOT = data dostarczenia
      final rightDate          = _fmt(isKwgRG && rawDataWsg.isNotEmpty ? rawDataWsg : rawData);
      final dataDostarczenia   = isKwgRG ? _fmt(rawData) : '';
      final label = KwLabelData(
        lot:               d['lot'] as String? ?? entry.lot,
        odmiana:           d['odmiana'] as String? ?? entry.odmiana,
        data:              rightDate,
        dataDostarczenia:  dataDostarczenia,
        dostawca:          d['dostawca'] as String? ?? entry.dostawca,
        dostawcaKod:       d['dostawca_kod'] as String? ?? entry.dostawcaKod,
        przeznaczenie:     d['przeznaczenie'] as String? ?? entry.przeznaczenie,
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
  late final TextEditingController _drewCtrl;
  late final TextEditingController _plastCtrl;
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
    // Parsuj skrzynie "drew/plast"
    final parts  = e.skrzynie.split('/');
    _drewCtrl    = TextEditingController(text: parts.isNotEmpty ? parts[0].trim() : '');
    _plastCtrl   = TextEditingController(text: parts.length > 1 ? parts[1].trim() : '');
  }

  @override
  void dispose() {
    _brixCtrl.dispose();
    _odpadCtrl.dispose();
    _twardCtrl.dispose();
    _kaliberCtrl.dispose();
    _zwrotCtrl.dispose();
    _wagaNettoCtrl.dispose();
    _drewCtrl.dispose();
    _plastCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Usuń kartę ważenia'),
        content: Text(
          'Na pewno usunąć kartę ${widget.entry.lot.isNotEmpty ? widget.entry.lot : widget.entry.nrDostawy}?\n\nTej operacji nie można cofnąć.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            child: const Text('Usuń', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final nav = Navigator.of(context);
    await FirebaseFirestore.instance
        .collection(AppConstants.colDeliveries)
        .doc(widget.entry.id)
        .delete();
    if (mounted) nav.pop();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final wagaNetto = _wagaNettoCtrl.text.trim();
      final brix      = _brixCtrl.text.trim();
      final przezn    = widget.entry.przeznaczenie.toLowerCase();
      // Flaga "brak wagi" znika gdy waga uzupełniona i BRIX (dla przecieru)
      final brakFlaga = wagaNetto.isEmpty || (przezn == 'przecier' && brix.isEmpty);
      final drew  = int.tryParse(_drewCtrl.text.trim())  ?? 0;
      final plast = int.tryParse(_plastCtrl.text.trim()) ?? 0;

      await FirebaseFirestore.instance
          .collection(AppConstants.colDeliveries)
          .doc(widget.entry.id)
          .update({
        'brix':            brix,
        'odpad':           _odpadCtrl.text.trim(),
        'twardosc':        _twardCtrl.text.trim(),
        'kaliber':         _kaliberCtrl.text.trim(),
        'zwrot_pct':       _zwrotCtrl.text.trim(),
        'waga_netto':      wagaNetto,
        'waga_netto_brak': brakFlaga,
        'skrzynie':        '${_drewCtrl.text.trim()}/${_plastCtrl.text.trim()}',
        'skrzynie_drew':   drew,
        'skrzynie_plast':  plast,
        'status':          _status,
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
                      : Row(children: [
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppTheme.errorRed),
                            tooltip: 'Usuń kartę (admin)',
                            onPressed: () => _confirmDelete(context),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: AppTheme.primaryMid),
                            tooltip: 'Edytuj (admin)',
                            onPressed: () => setState(() => _editing = true),
                          ),
                        ]),
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
                  _editing
                      ? Row(children: [
                          Expanded(child: _EditRow('Skrz. drew.', _drewCtrl, suffix: 'szt')),
                          const SizedBox(width: 8),
                          Expanded(child: _EditRow('Skrz. plast.', _plastCtrl, suffix: 'szt')),
                        ])
                      : _Row('Skrzynie (D/P)', e.skrzynie.isNotEmpty ? e.skrzynie : '—'),
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

// ── Przycisk "Wpisz wagę netto" w karcie ─────────────────────────────────────

class _KartaWpisButton extends StatelessWidget {
  final KartaEntry entry;
  const _KartaWpisButton({required this.entry});

  int get _drewIl {
    final p = entry.skrzynie.split('/');
    return int.tryParse(p.isNotEmpty ? p[0].trim() : '') ?? 0;
  }

  int get _plastIl {
    final p = entry.skrzynie.split('/');
    return int.tryParse(p.length > 1 ? p[1].trim() : '') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showWpisWageDialog(
        context,
        lot: entry.lot,
        docId: entry.id,
        drewIl: _drewIl,
        plastIl: _plastIl,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: AppTheme.errorRed.withAlpha(15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.errorRed.withAlpha(80)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.warning_amber_rounded, color: AppTheme.errorRed, size: 16),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Brak wagi netto — uzupełnij',
                style: TextStyle(fontSize: 13, color: AppTheme.errorRed, fontWeight: FontWeight.w600)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.errorRed,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text('WPISZ',
                style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
          ),
        ]),
      ),
    );
  }
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
