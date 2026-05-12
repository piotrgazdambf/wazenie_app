import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../app/theme.dart';
import '../../core/constants.dart';
import '../../core/offline/hive_buffer.dart';
import '../../core/offline/offline_entry.dart';
import '../../core/auth/pin_auth_service.dart';
import '../../shared/widgets/offline_banner.dart';
import '../../shared/widgets/wpisz_wage_dialog.dart';

String _fmtKg(String s) {
  if (s.isEmpty) return s;
  final v = double.tryParse(s.replaceAll(',', '.'));
  if (v == null) return s;
  return v.round().toString();
}

String _fmtDate(String d) {
  if (d.length == 10 && d[4] == '-' && d[7] == '-') {
    return '${d.substring(8)}.${d.substring(5, 7)}.${d.substring(0, 4)}';
  }
  return d;
}

// ── Model ─────────────────────────────────────────────────────────────────────

class PlsEntry {
  final String id;
  final String lot;
  final String data;
  final String nrDostawy;
  final String dostawca;
  final String dostawcaKod;
  final String przeznaczenie;
  final String odmiana;
  final String skrzynie;
  final String wagaNetto;
  final String wagaBrutto;
  final bool wagaNettoBrak;
  final String owoc;
  final String status;
  final bool isKwg;
  final String kwgType;
  final String dataWsg;
  final String brix;
  final String odpad;
  final String twardosc;
  final String kaliber;
  final String zwrotPct;
  final String stanOpak;
  final String stanAuto;
  final String createdByName;
  final List<Map<String, String>> modifications;
  final int mbDrewIl;
  final int mbPlastIl;

  const PlsEntry({
    required this.id,
    required this.lot,
    required this.data,
    required this.nrDostawy,
    required this.dostawca,
    required this.dostawcaKod,
    required this.przeznaczenie,
    required this.odmiana,
    required this.skrzynie,
    required this.wagaNetto,
    required this.wagaBrutto,
    this.wagaNettoBrak = false,
    required this.owoc,
    required this.status,
    this.isKwg = false,
    this.kwgType = '',
    this.dataWsg = '',
    this.brix = '',
    this.odpad = '',
    this.twardosc = '',
    this.kaliber = '',
    this.zwrotPct = '',
    this.stanOpak = '',
    this.stanAuto = '',
    this.createdByName = '',
    this.modifications = const [],
    this.mbDrewIl = 0,
    this.mbPlastIl = 0,
  });

  factory PlsEntry.fromFirestore(String id, Map<String, dynamic> d) => PlsEntry(
        id:           id,
        lot:          d['lot'] as String? ?? d['id'] as String? ?? '',
        data:         d['data'] as String? ?? '',
        nrDostawy:    d['nr_dostawy'] as String? ?? '',
        dostawca:     d['dostawca'] as String? ?? '',
        dostawcaKod:  d['dostawca_kod'] as String? ?? '',
        przeznaczenie:d['przeznaczenie'] as String? ?? '',
        odmiana:      d['odmiana'] as String? ?? '',
        skrzynie:     d['skrzynie'] as String? ?? '',
        wagaNetto:    d['waga_netto'] as String? ?? '',
        wagaNettoBrak: d['waga_netto_brak'] as bool? ?? false,
        wagaBrutto:   (d['waga_brutto'] != null)
            ? d['waga_brutto'].toString()
            : '',
        owoc:         d['owoc'] as String? ?? '',
        status:       d['status'] as String? ?? '',
        isKwg:        d['is_kwg'] as bool? ?? false,
        kwgType:      d['kwg_type'] as String? ?? '',
        dataWsg:      d['data_wsg'] as String? ?? '',
        brix:         d['brix'] as String? ?? '',
        odpad:        d['odpad'] as String? ?? '',
        twardosc:     d['twardosc'] as String? ?? '',
        kaliber:      d['kaliber'] as String? ?? '',
        zwrotPct:     d['zwrot_pct'] as String? ?? '',
        stanOpak:      d['stan_opakowania'] as String? ?? '',
        stanAuto:      d['stan_samochodu']  as String? ?? '',
        createdByName: d['createdByName']   as String? ?? '',
        modifications: (d['modifications']  as List<dynamic>?)
            ?.map((e) => Map<String, String>.from(
                (e as Map).map((k, v) => MapEntry(k.toString(), v.toString()))))
            .toList() ?? const [],
        mbDrewIl:  d['mb_drew_il']  as int? ?? (d['skrzynie_mb_drew']  as int? ?? 0),
        mbPlastIl: d['mb_plast_il'] as int? ?? (d['skrzynie_mb_plast'] as int? ?? 0),
      );
}

// ── Provider ──────────────────────────────────────────────────────────────────

final plsListProvider = StreamProvider<List<PlsEntry>>((ref) {
  return FirebaseFirestore.instance
      .collection(AppConstants.colDeliveries)
      .orderBy('createdAt', descending: true)
      .limit(200)
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => PlsEntry.fromFirestore(d.id, d.data()))
          .toList());
});

// ── Ekran ─────────────────────────────────────────────────────────────────────

class PlsScreen extends ConsumerStatefulWidget {
  const PlsScreen({super.key});

  @override
  ConsumerState<PlsScreen> createState() => _PlsScreenState();
}

class _PlsScreenState extends ConsumerState<PlsScreen>
    with SingleTickerProviderStateMixin {
  String _search = '';
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plsAsync = ref.watch(plsListProvider);

    return OfflineOverflowGuard(
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: const Text('Lista dostaw (PLS)'),
          leading: BackButton(onPressed: () => context.go('/home')),
          bottom: TabBar(
            controller: _tabCtrl,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: const [
              Tab(text: 'Wszystkie'),
              Tab(text: 'Nierozliczone'),
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onChanged: (v) => setState(() => _search = v.toLowerCase()),
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: plsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => _ErrorView(message: e.toString()),
                data: (list) {
                  final searched = _search.isEmpty
                      ? list
                      : list.where((e) =>
                          e.lot.toLowerCase().contains(_search) ||
                          e.odmiana.toLowerCase().contains(_search) ||
                          e.dostawca.toLowerCase().contains(_search) ||
                          e.owoc.toLowerCase().contains(_search)).toList();
                  final nierozliczone = searched
                      .where((e) => e.status != 'ROZLICZONO')
                      .toList();

                  Widget buildList(List<PlsEntry> items) {
                    if (items.isEmpty) return const _EmptyView();
                    final grouped = <String, List<PlsEntry>>{};
                    for (final e in items) {
                      final baseLot = e.lot.replaceAll(RegExp(r'\d+$'), '');
                      final key = (e.kwgType.isNotEmpty && e.dataWsg.isNotEmpty)
                          ? '${baseLot}_${e.dataWsg}'
                          : baseLot;
                      grouped.putIfAbsent(key, () => []);
                      grouped[key]!.add(e);
                    }
                    final keys = grouped.keys.toList();
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
                      itemCount: keys.length,
                      itemBuilder: (ctx, i) {
                        final entries = grouped[keys[i]]!;
                        final displayLot = entries.first.lot.replaceAll(RegExp(r'\d+$'), '');
                        if (entries.length == 1) return _PlsCard(entry: entries[0]);
                        return _PlsGroup(baseLot: displayLot, entries: entries);
                      },
                    );
                  }

                  return TabBarView(
                    controller: _tabCtrl,
                    children: [
                      buildList(searched),
                      buildList(nierozliczone),
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

class _PlsGroup extends StatefulWidget {
  final String baseLot;
  final List<PlsEntry> entries;
  const _PlsGroup({required this.baseLot, required this.entries});

  @override
  State<_PlsGroup> createState() => _PlsGroupState();
}

class _PlsGroupState extends State<_PlsGroup> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final e0 = widget.entries.first;
    final totalNetto = widget.entries.fold(0.0, (s, e) {
      return s + (double.tryParse(e.wagaNetto.replaceAll(',', '.')) ?? 0);
    });
    final odmiany = widget.entries.map((e) => e.odmiana).where((o) => o.isNotEmpty).toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.baseLot,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14,
                          color: AppTheme.primaryDark, fontFamily: 'monospace')),
                  const SizedBox(height: 3),
                  Text('${e0.owoc}${odmiany.isNotEmpty ? "  •  ${odmiany.join(" / ")}" : ""}',
                      style: const TextStyle(fontSize: 13)),
                  Builder(builder: (_) {
                    final isRG = e0.kwgType.isNotEmpty;
                    final dateStr = isRG && e0.dataWsg.isNotEmpty
                        ? 'KW: ${_fmtDate(e0.dataWsg)}'
                        : _fmtDate(e0.data);
                    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${e0.dostawca}  •  $dateStr  •  ${totalNetto.round()} kg  •  ${widget.entries.length} odm.',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      if (isRG)
                        const Text('Daty dostaw — rozwiń odmiany',
                            style: TextStyle(fontSize: 10, color: AppTheme.primaryLight)),
                    ]);
                  }),
                ])),
                Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppTheme.textSecondary),
              ]),
            ),
          ),
          if (_expanded)
            ...widget.entries.map((e) => Container(
              decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFEEEEEE)))),
              child: _PlsCard(entry: e),
            )),
        ],
      ),
    );
  }
}

// ── Karta dostawy ─────────────────────────────────────────────────────────────

class _PlsCard extends ConsumerWidget {
  final PlsEntry entry;
  const _PlsCard({required this.entry});



  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session     = ref.watch(currentSessionProvider);
    final isAdmin     = session?.user.isAdmin ?? false;
    final userName    = session?.user.name ?? '';
    final statusColor = _statusColor(entry.status);
    final statusLabel = _statusLabel(entry.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: entry.wagaNettoBrak
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppTheme.errorRed, width: 1.5))
          : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showDetail(context, isAdmin: isAdmin, userName: userName),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Baner "brak wagi netto"
            if (entry.wagaNettoBrak) ...[
              _WpisWageButton(entry: entry),
              const SizedBox(height: 8),
            ],
            // Nagłówek: LOT + status
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.lot.isNotEmpty ? entry.lot : entry.id,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15,
                        color: AppTheme.primaryDark),
                  ),
                ),
                if (entry.status.isNotEmpty)
                  _StatusChip(label: statusLabel, color: statusColor),
              ],
            ),
            const SizedBox(height: 6),

            // Owoc + przeznaczenie + odmiana
            _InfoRow(Icons.eco_outlined, '${_capitalize(entry.owoc)} • ${entry.przeznaczenie}'),
            if (entry.odmiana.isNotEmpty)
              _InfoRow(Icons.grass_outlined, entry.odmiana),

            // Dostawca + data
            if (entry.dostawca.isNotEmpty)
              _InfoRow(Icons.business_outlined, entry.dostawca),
            if (entry.kwgType.isNotEmpty && entry.dataWsg.isNotEmpty) ...[
              _InfoRow(Icons.calendar_today_outlined, 'KW: ${_fmtDate(entry.dataWsg)}'),
              if (entry.data.isNotEmpty)
                _InfoRow(Icons.local_shipping_outlined,
                    'Dostarczone: ${_fmtDate(entry.data)}  •  #${entry.nrDostawy}'),
            ] else if (entry.data.isNotEmpty)
              _InfoRow(Icons.calendar_today_outlined, '${_fmtDate(entry.data)}  •  ${entry.lot}'),

            // Skrzynie + waga
            if (entry.skrzynie.isNotEmpty || entry.wagaNetto.isNotEmpty)
              _InfoRow(
                Icons.inventory_2_outlined,
                [
                  if (entry.skrzynie.isNotEmpty) 'Skrz: ${entry.skrzynie}',
                  if (entry.wagaNetto.isNotEmpty) 'Netto: ${_fmtKg(entry.wagaNetto)} kg',
                  if (entry.wagaBrutto.isNotEmpty) 'Brutto: ${_fmtKg(entry.wagaBrutto)} kg',
                ].join('   '),
              ),

            // Jakość
            if (entry.brix.isNotEmpty || entry.odpad.isNotEmpty ||
                entry.twardosc.isNotEmpty || entry.kaliber.isNotEmpty ||
                entry.zwrotPct.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (entry.brix.isNotEmpty) _QualityChip('BRIX', entry.brix),
                  if (entry.odpad.isNotEmpty) _QualityChip('ODPAD', '${entry.odpad}%'),
                  if (entry.twardosc.isNotEmpty) _QualityChip('TWARD.', entry.twardosc),
                  if (entry.kaliber.isNotEmpty) _QualityChip('KALIB.', '${entry.kaliber}%'),
                  if (entry.zwrotPct.isNotEmpty && (double.tryParse(entry.zwrotPct) ?? 0) > 0)
                    _QualityChip('ZWROT', '${entry.zwrotPct}%'),
                ],
              ),
            ],

            // Akcje statusowe
            const SizedBox(height: 8),
            Row(
              children: [
                const Spacer(),
                if (entry.status == 'PRZESŁANO' || entry.status == 'PRZYJETO')
                  TextButton.icon(
                    onPressed: () => _rozlicz(context, ref),
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('Rozlicz (Zejście)'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.successGreen,
                      textStyle:
                          const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ],
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, {required bool isAdmin, String userName = ''}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PlsDetailSheet(entry: entry, isAdmin: isAdmin, userName: userName),
    );
  }

  Future<void> _przeslijDoStanow(BuildContext context, WidgetRef ref) async {
    final buffer = ref.read(hiveBufferProvider);
    try {
      await FirebaseFirestore.instance
          .collection(AppConstants.colDeliveries)
          .doc(entry.id)
          .update({'status': 'PRZESŁANO'});

      // Dopisz do MCR jako Przyjęcie
      final now = DateTime.now();
      final mcrId = 'mcr_${now.millisecondsSinceEpoch}';
      final mcrData = {
        'id': mcrId,
        'lot': entry.lot,
        'czas': '${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}',
        'akcja': 'Przyjecie',
        'waga_netto': entry.wagaNetto,
        'owoc': entry.owoc,
        'odmiana': entry.odmiana,
        'przeznaczenie': entry.przeznaczenie,
        'status': 'pending',
        'createdAt': now.toIso8601String(),
      };
      try {
        await FirebaseFirestore.instance
            .collection(AppConstants.colMcrQueue)
            .doc(mcrId)
            .set({...mcrData, 'createdAt': FieldValue.serverTimestamp()});
      } catch (_) {
        await buffer.enqueue(OfflineEntry(
          id: mcrId,
          type: 'mcr_zejscie',
          data: mcrData,
          createdAt: now,
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd: $e'), backgroundColor: AppTheme.errorRed),
        );
      }
      return;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Przesłano do Stanów + MCR'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    }
  }

  Future<void> _rozlicz(BuildContext context, WidgetRef ref) async {
    await showDialog<bool>(
      context: context,
      builder: (_) => _RozliczDialog(entry: entry, ref: ref),
    );
  }

  String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  Color _statusColor(String s) => switch (s.toUpperCase()) {
    'PRZYJETO' => AppTheme.warningOrange,
    'PRZESŁANO' => AppTheme.successGreen,
    'ROZLICZONO' => AppTheme.textSecondary,
    _ => AppTheme.textSecondary,
  };

  String _statusLabel(String s) => switch (s.toUpperCase()) {
    'PRZYJETO' => 'Przyjęto',
    'PRZESŁANO' => 'Przesłano',
    'ROZLICZONO' => 'Rozliczono',
    _ => s,
  };
}

// ── Helpers ───────────────────────────────────────────────────────────────────

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
        child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      );
}

class _QualityChip extends StatelessWidget {
  final String label;
  final String value;
  const _QualityChip(this.label, this.value);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppTheme.primaryDark.withAlpha(10),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text('$label: $value',
            style: const TextStyle(fontSize: 11, color: AppTheme.primaryDark, fontWeight: FontWeight.w600)),
      );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Row(
          children: [
            Icon(icon, size: 14, color: AppTheme.textSecondary),
            const SizedBox(width: 6),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary))),
          ],
        ),
      );
}

// ── Arkusz szczegółów dostawy ─────────────────────────────────────────────────

class _PlsDetailSheet extends StatefulWidget {
  final PlsEntry entry;
  final bool isAdmin;
  final String userName;
  const _PlsDetailSheet({required this.entry, required this.isAdmin, this.userName = ''});

  @override
  State<_PlsDetailSheet> createState() => _PlsDetailSheetState();
}

class _PlsDetailSheetState extends State<_PlsDetailSheet> {
  bool _editing = false;
  bool _saving  = false;

  late final TextEditingController _brixCtrl;
  late final TextEditingController _odpadCtrl;
  late final TextEditingController _twardCtrl;
  late final TextEditingController _kaliberCtrl;
  late final TextEditingController _zwrotCtrl;
  late final TextEditingController _wagaNettoCtrl;
  late final TextEditingController _odmianaCtrl;
  late final TextEditingController _stanOpakCtrl;
  late final TextEditingController _stanAutoCtrl;
  late String _status;
  late String _przeznaczenie;

  @override
  void initState() {
    super.initState();
    final e        = widget.entry;
    _brixCtrl      = TextEditingController(text: e.brix);
    _odpadCtrl     = TextEditingController(text: e.odpad);
    _twardCtrl     = TextEditingController(text: e.twardosc);
    _kaliberCtrl   = TextEditingController(text: e.kaliber);
    _zwrotCtrl     = TextEditingController(text: e.zwrotPct);
    _wagaNettoCtrl = TextEditingController(text: e.wagaNetto);
    _odmianaCtrl   = TextEditingController(text: e.odmiana);
    _stanOpakCtrl  = TextEditingController(text: e.stanOpak);
    _stanAutoCtrl  = TextEditingController(text: e.stanAuto);
    _status        = e.status;
    _przeznaczenie = e.przeznaczenie;
  }

  @override
  void dispose() {
    for (final c in [_brixCtrl, _odpadCtrl, _twardCtrl, _kaliberCtrl,
        _zwrotCtrl, _wagaNettoCtrl, _odmianaCtrl, _stanOpakCtrl, _stanAutoCtrl]) c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final now = DateTime.now();
    final nowStr = '${now.day.toString().padLeft(2,'0')}.${now.month.toString().padLeft(2,'0')}.${now.year} ${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}';
    final db    = FirebaseFirestore.instance;
    final docId = widget.entry.id;
    try {
      final ent = widget.entry;
      final diffs = <String>[];
      void chk(String label, String oldVal, String newVal) {
        final o = oldVal.isEmpty ? '—' : oldVal;
        final n = newVal.isEmpty ? '—' : newVal;
        if (o != n) diffs.add('$label: $o -> $n');
      }
      chk('BRIX',      ent.brix,          _brixCtrl.text.trim());
      chk('Odpad',     ent.odpad,         _odpadCtrl.text.trim());
      chk('Twardość',  ent.twardosc,      _twardCtrl.text.trim());
      chk('PW',        ent.kaliber,       _kaliberCtrl.text.trim());
      chk('Zwrot',     ent.zwrotPct,      _zwrotCtrl.text.trim());
      chk('Netto',     ent.wagaNetto,     _wagaNettoCtrl.text.trim());
      chk('Odmiana',   ent.odmiana,       _odmianaCtrl.text.trim());
      chk('Przezn.',   ent.przeznaczenie, _przeznaczenie);
      chk('St.opak.',  ent.stanOpak,      _stanOpakCtrl.text.trim());
      chk('St.auto',   ent.stanAuto,      _stanAutoCtrl.text.trim());
      chk('Status',    ent.status,        _status);
      final changesStr = diffs.join(', ');

      final batch = db.batch();
      // deliveries
      batch.update(db.collection(AppConstants.colDeliveries).doc(docId), {
        'brix':            _brixCtrl.text.trim(),
        'odpad':           _odpadCtrl.text.trim(),
        'twardosc':        _twardCtrl.text.trim(),
        'kaliber':         _kaliberCtrl.text.trim(),
        'zwrot_pct':       _zwrotCtrl.text.trim(),
        'waga_netto':      _wagaNettoCtrl.text.trim(),
        'odmiana':         _odmianaCtrl.text.trim(),
        'przeznaczenie':   _przeznaczenie,
        'stan_opakowania': _stanOpakCtrl.text.trim(),
        'stan_samochodu':  _stanAutoCtrl.text.trim(),
        'status':          _status,
        'editedAt':        FieldValue.serverTimestamp(),
        'modifications':   FieldValue.arrayUnion([{
          'by': widget.userName,
          'at': nowStr,
          if (changesStr.isNotEmpty) 'changes': changesStr,
        }]),
      });
      // crateStates — sync wagaNetto i przeznaczenie
      final crateSnap = await db.collection(AppConstants.colCrateStates).doc(docId).get();
      if (crateSnap.exists) {
        final newKg = double.tryParse(_wagaNettoCtrl.text.replaceAll(',', '.')) ?? 0;
        batch.update(crateSnap.reference, {
          'kg_total':      newKg,
          'przeznaczenie': _przeznaczenie,
          'odmiana':       _odmianaCtrl.text.trim(),
        });
      }
      await batch.commit();
      if (mounted) {
        setState(() { _editing = false; _saving = false; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Zapisano i zsynchronizowano'), backgroundColor: AppTheme.successGreen));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Błąd: $e'), backgroundColor: AppTheme.errorRed));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final statusColor = switch (e.status.toUpperCase()) {
      'PRZYJETO'   => AppTheme.warningOrange,
      'PRZESŁANO'  => AppTheme.successGreen,
      'ROZLICZONO' => AppTheme.textSecondary,
      _            => AppTheme.textSecondary,
    };

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      builder: (_, ctrl) => Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(children: [
            Center(child: Container(width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(color: AppTheme.borderLight, borderRadius: BorderRadius.circular(2)))),
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.lot.isNotEmpty ? e.lot : e.id,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
                        color: AppTheme.primaryDark, fontFamily: 'monospace')),
                Text('${e.data}  •  ${e.lot}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ])),
              if (e.status.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: statusColor.withAlpha(25), borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor.withAlpha(80))),
                  child: Text(e.status, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              if (widget.isAdmin) ...[
                const SizedBox(width: 8),
                _editing
                    ? Row(children: [
                        TextButton(onPressed: _saving ? null : () => setState(() => _editing = false),
                            child: const Text('Anuluj')),
                        ElevatedButton(
                          onPressed: _saving ? null : _save,
                          style: ElevatedButton.styleFrom(minimumSize: const Size(80, 36)),
                          child: _saving
                              ? const SizedBox(width: 16, height: 16,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Zapisz'),
                        ),
                      ])
                    : IconButton(
                        icon: const Icon(Icons.edit_outlined, color: AppTheme.primaryMid),
                        tooltip: 'Edytuj (admin)',
                        onPressed: () => setState(() => _editing = true),
                      ),
              ],
            ]),
          ]),
        ),
        const Divider(height: 16),
        Expanded(child: ListView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
          children: [
            _DetailSection('DANE DOSTAWY', [
              _DetailRow('Dostawca', e.dostawca),
              _DetailRow('Data', e.data),
              _DetailRow('Owoc', e.owoc),
              _editing
                  ? _PlsEditRow('Odmiana', _odmianaCtrl)
                  : (e.odmiana.isNotEmpty ? _DetailRow('Odmiana', e.odmiana) : const SizedBox.shrink()),
              _editing
                  ? _PlsDropRow('Przeznaczenie', _przeznaczenie,
                      ['Przecier', 'Sok', 'Obieranie', 'Świeże'],
                      (v) => setState(() => _przeznaczenie = v!))
                  : _DetailRow('Przeznaczenie', e.przeznaczenie),
            ]),
            const SizedBox(height: 12),
            _DetailSection('WAGI', [
              if (e.wagaBrutto.isNotEmpty) _DetailRow('Brutto', '${_fmtKg(e.wagaBrutto)} kg'),
              _editing
                  ? _PlsEditRow('Netto', _wagaNettoCtrl, suffix: 'kg')
                  : _DetailRow('Netto', '${_fmtKg(e.wagaNetto)} kg', bold: true),
              if (e.skrzynie.isNotEmpty) _DetailRow('Skrzynie (D/P)', e.skrzynie),
            ]),
            const SizedBox(height: 12),
            _DetailSection('PARAMETRY JAKOŚCI', [
              _editing ? _PlsEditRow('BRIX', _brixCtrl)
                  : _DetailRow('BRIX', e.brix.isNotEmpty ? e.brix : '—'),
              _editing ? _PlsEditRow('Odpad %', _odpadCtrl, suffix: '%')
                  : _DetailRow('Odpad', e.odpad.isNotEmpty ? '${e.odpad}%' : '—'),
              _editing ? _PlsEditRow('Twardość', _twardCtrl)
                  : _DetailRow('Twardość', e.twardosc.isNotEmpty ? e.twardosc : '—'),
              _editing ? _PlsEditRow('PW %', _kaliberCtrl, suffix: '%')
                  : _DetailRow('PW (kaliber)', e.kaliber.isNotEmpty ? '${e.kaliber}%' : '—'),
              _editing ? _PlsEditRow('Zwrot %', _zwrotCtrl, suffix: '%')
                  : _DetailRow('Zwrot', e.zwrotPct.isNotEmpty ? '${e.zwrotPct}%' : '—'),
            ]),
            const SizedBox(height: 12),
            _DetailSection('STAN', [
              _editing
                  ? _PlsEditRow('Opakowanie', _stanOpakCtrl)
                  : _DetailRow('Stan opakowania', e.stanOpak.isNotEmpty ? e.stanOpak : '—'),
              _editing
                  ? _PlsEditRow('Samochód', _stanAutoCtrl)
                  : _DetailRow('Stan samochodu', e.stanAuto.isNotEmpty ? e.stanAuto : '—'),
            ]),
            if (!_editing && widget.isAdmin &&
                (e.createdByName.isNotEmpty || e.modifications.isNotEmpty)) ...[
              const SizedBox(height: 12),
              _DetailSection('HISTORIA', [
                if (e.createdByName.isNotEmpty)
                  _DetailRow('Stworzył', e.createdByName, bold: true),
                if (e.modifications.isNotEmpty) ...[
                  const Divider(height: 16),
                  ...e.modifications.reversed.map((m) =>
                    _DetailRow(m['at'] ?? '', m['by'] ?? ''),
                  ),
                ],
              ]),
            ],
            if (_editing && widget.isAdmin) ...[
              const SizedBox(height: 12),
              _DetailSection('STATUS', [
                _PlsStatusSelector(current: _status, onChanged: (s) => setState(() => _status = s)),
              ]),
            ],
          ],
        )),
      ]),
    );
  }
}

class _PlsEditRow extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final String? suffix;
  const _PlsEditRow(this.label, this.ctrl, {this.suffix});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      SizedBox(width: 120, child: Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary))),
      Expanded(child: TextFormField(
        controller: ctrl,
        decoration: InputDecoration(isDense: true,
            suffix: suffix != null ? Text(suffix!) : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
        keyboardType: TextInputType.number,
      )),
    ]),
  );
}

class _PlsDropRow extends StatelessWidget {
  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  const _PlsDropRow(this.label, this.value, this.options, this.onChanged);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      SizedBox(width: 120, child: Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary))),
      Expanded(child: DropdownButtonFormField<String>(
        value: options.contains(value) ? value : null,
        decoration: const InputDecoration(isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
        items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
        onChanged: onChanged,
      )),
    ]),
  );
}

class _PlsStatusSelector extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;
  const _PlsStatusSelector({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const statuses = ['PRZYJETO', 'PRZESŁANO', 'ROZLICZONO'];
    return Row(children: statuses.map((s) {
      final sel = s == current;
      return Expanded(child: Padding(
        padding: const EdgeInsets.only(right: 6),
        child: GestureDetector(
          onTap: () => onChanged(s),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: sel ? AppTheme.primaryDark.withAlpha(15) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: sel ? AppTheme.primaryDark : AppTheme.borderLight, width: sel ? 1.5 : 1),
            ),
            child: Text(s, textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.normal,
                    color: sel ? AppTheme.primaryDark : AppTheme.textSecondary)),
          ),
        ),
      ));
    }).toList());
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final List<Widget> rows;
  const _DetailSection(this.title, this.rows);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary, letterSpacing: 1.2)),
            const SizedBox(height: 10),
            ...rows,
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _DetailRow(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                    color: bold ? AppTheme.primaryDark : AppTheme.textPrimary)),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppTheme.errorRed),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textSecondary)),
            ],
          ),
        ),
      );
}

// ── Przycisk "Wpisz wagę netto" ───────────────────────────────────────────────

class _WpisWageButton extends StatelessWidget {
  final PlsEntry entry;
  const _WpisWageButton({required this.entry});

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
        mbDrewIl: entry.mbDrewIl,
        mbPlastIl: entry.mbPlastIl,
        showDateField: entry.isKwg && entry.data.isEmpty,
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

// ── Dialog rozliczenia (otwierany z PLS) ─────────────────────────────────────

class _RozliczDialog extends StatefulWidget {
  final PlsEntry entry;
  final WidgetRef ref;
  const _RozliczDialog({required this.entry, required this.ref});

  @override
  State<_RozliczDialog> createState() => _RozliczDialogState();
}

class _RozliczDialogState extends State<_RozliczDialog> {
  final _formKey    = GlobalKey<FormState>();
  final _naCoCtrl   = TextEditingController();
  final _kgCtrl     = TextEditingController();
  final _skrCtrl    = TextEditingController();
  final _odmianaCtrl = TextEditingController();
  DateTime _data    = DateTime.now();
  bool _saving      = false;

  static const _naCo = ['Obieranie', 'Sok', 'Gruszka', 'Rylex', 'Grójecka', 'Odpad', 'Burak'];

  @override
  void initState() {
    super.initState();
    _odmianaCtrl.text = widget.entry.odmiana;
    _kgCtrl.text      = widget.entry.wagaNetto;
  }

  @override
  void dispose() {
    _naCoCtrl.dispose();
    _kgCtrl.dispose();
    _skrCtrl.dispose();
    _odmianaCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _data = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final e       = widget.entry;
    final session = widget.ref.read(currentSessionProvider);
    final buffer  = widget.ref.read(hiveBufferProvider);
    final db      = FirebaseFirestore.instance;
    final kg      = double.tryParse(_kgCtrl.text.replaceAll(',', '.')) ?? 0;
    final skr     = int.tryParse(_skrCtrl.text) ?? 0;

    try {
      // 1. Wpis rozliczenia
      await db.collection('rozliczone').add({
        'na_co':           _naCoCtrl.text.trim(),
        'data':            DateFormat('dd.MM.yyyy').format(_data),
        'lot':             e.lot,
        'odmiana':         _odmianaCtrl.text.trim(),
        'kg':              kg,
        'skrzyny':         skr,
        'created_at':      FieldValue.serverTimestamp(),
        'created_by_name': session?.user.name ?? '',
      });

      // 2. Status ROZLICZONO
      await db.collection(AppConstants.colDeliveries)
          .doc(e.id)
          .update({'status': 'ROZLICZONO'});

      // 3. MCR Zejście
      final now   = DateTime.now();
      final mcrId = 'mcr_zejscie_${now.millisecondsSinceEpoch}';
      final mcrData = {
        'id':           mcrId,
        'lot':          e.lot,
        'czas':         '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
        'akcja':        'Zejscie',
        'waga_netto':   e.wagaNetto,
        'owoc':         e.owoc,
        'odmiana':      e.odmiana,
        'przeznaczenie':e.przeznaczenie,
        'status':       'pending',
        'createdAt':    now.toIso8601String(),
      };
      try {
        await db.collection(AppConstants.colMcrQueue)
            .doc(mcrId)
            .set({...mcrData, 'createdAt': FieldValue.serverTimestamp()});
      } catch (_) {
        await buffer.enqueue(OfflineEntry(
          id: mcrId, type: 'mcr_zejscie', data: mcrData, createdAt: now,
        ));
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Rozliczono + Zejście do MCR'),
          backgroundColor: AppTheme.successGreen,
        ));
      }
    } catch (err) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Błąd: $err'), backgroundColor: AppTheme.errorRed));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Dodaj wpis rozliczenia'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Na co',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6, runSpacing: 4,
                  children: _naCo.map((s) => ActionChip(
                    label: Text(s, style: const TextStyle(fontSize: 12)),
                    onPressed: () => setState(() => _naCoCtrl.text = s),
                  )).toList(),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _naCoCtrl,
                  decoration: const InputDecoration(labelText: 'Na co (np. obieranie, sok)', isDense: true),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Wymagane' : null,
                ),
                const SizedBox(height: 14),

                // LOT — read-only, pre-filled
                InputDecorator(
                  decoration: const InputDecoration(labelText: 'LOT / Nr dostawy', isDense: true),
                  child: Text(widget.entry.lot,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 14, color: AppTheme.primaryDark)),
                ),
                const SizedBox(height: 14),

                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(10),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Data', isDense: true,
                      suffixIcon: Icon(Icons.calendar_today, size: 18),
                    ),
                    child: Text(DateFormat('dd.MM.yyyy').format(_data)),
                  ),
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _kgCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                  decoration: const InputDecoration(labelText: 'Kg', isDense: true, suffixText: 'kg'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Wymagane';
                    if ((double.tryParse(v.replaceAll(',', '.')) ?? 0) <= 0) return 'Podaj wartość > 0';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _skrCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Skrzynie (opcjonalnie)', isDense: true),
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _odmianaCtrl,
                  decoration: const InputDecoration(labelText: 'Odmiana (opcjonalnie)', isDense: true),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Anuluj')),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Zapisz'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: AppTheme.borderLight),
            SizedBox(height: 12),
            Text('Brak dostaw', style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
            SizedBox(height: 4),
            Text('Dodaj przyjęcie przez WSG', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          ],
        ),
      );
}
