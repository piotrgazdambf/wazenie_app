import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
import '../../core/constants.dart';
import '../../shared/widgets/offline_banner.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class PsEntry {
  final String id;
  final String lot;
  final String nrDostawy;
  final String data;
  final String dostawca;
  final String owoc;
  final String odmiana;
  final String przeznaczenie;
  final String brix;
  final String odpad;
  final String twardosc;
  final String kaliber;
  final String zwrotPct;
  final String wagaNetto;
  final String status;
  final bool isKwg;
  final String kwgType;

  const PsEntry({
    required this.id,
    required this.lot,
    required this.nrDostawy,
    required this.data,
    required this.dostawca,
    required this.owoc,
    required this.odmiana,
    required this.przeznaczenie,
    required this.brix,
    required this.odpad,
    required this.twardosc,
    required this.kaliber,
    required this.zwrotPct,
    required this.wagaNetto,
    required this.status,
    required this.isKwg,
    required this.kwgType,
  });

  factory PsEntry.fromFirestore(String id, Map<String, dynamic> d) => PsEntry(
    id:           id,
    lot:          d['lot'] as String? ?? '',
    nrDostawy:    d['nr_dostawy'] as String? ?? '',
    data:         d['data'] as String? ?? '',
    dostawca:     d['dostawca'] as String? ?? '',
    owoc:         d['owoc'] as String? ?? '',
    odmiana:      d['odmiana'] as String? ?? '',
    przeznaczenie:d['przeznaczenie'] as String? ?? '',
    brix:         d['brix'] as String? ?? '',
    odpad:        d['odpad'] as String? ?? '',
    twardosc:     d['twardosc'] as String? ?? '',
    kaliber:      d['kaliber'] as String? ?? '',
    zwrotPct:     d['zwrot_pct'] as String? ?? '',
    wagaNetto:    d['waga_netto'] as String? ?? '',
    status:       d['status'] as String? ?? '',
    isKwg:        d['is_kwg'] == true,
    kwgType:      d['kwg_type'] as String? ?? '',
  );

  bool get hasParams =>
      brix.isNotEmpty || odpad.isNotEmpty || twardosc.isNotEmpty ||
      kaliber.isNotEmpty || zwrotPct.isNotEmpty;
}

// ── Provider ──────────────────────────────────────────────────────────────────

final psListProvider = StreamProvider<List<PsEntry>>((ref) {
  return FirebaseFirestore.instance
      .collection(AppConstants.colDeliveries)
      .orderBy('createdAt', descending: true)
      .limit(300)
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => PsEntry.fromFirestore(d.id, d.data()))
          .toList());
});

// ── Screen ────────────────────────────────────────────────────────────────────

class PsScreen extends ConsumerStatefulWidget {
  const PsScreen({super.key});

  @override
  ConsumerState<PsScreen> createState() => _PsScreenState();
}

class _PsScreenState extends ConsumerState<PsScreen>
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

  List<PsEntry> _filter(List<PsEntry> list, String tab) {
    switch (tab) {
      case 'czaplin':  return list.where((e) => !e.isKwg).toList();
      case 'rylex':    return list.where((e) => e.isKwg && e.kwgType == 'R').toList();
      case 'grojecka': return list.where((e) => e.isKwg && e.kwgType == 'G').toList();
      default:         return list;
    }
  }

  Widget _buildList(List<PsEntry> items) {
    if (items.isEmpty) {
      return const Center(
        child: Text('Brak wyników', style: TextStyle(color: AppTheme.textSecondary)),
      );
    }
    final grouped = <String, List<PsEntry>>{};
    for (final e in items) {
      final key = e.lot.replaceAll(RegExp(r'\d+$'), '');
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(e);
    }
    final keys = grouped.keys.toList();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
      itemCount: keys.length,
      itemBuilder: (ctx, i) => _PsGroup(baseLot: keys[i], entries: grouped[keys[i]]!),
    );
  }

  @override
  Widget build(BuildContext context) {
    final psAsync = ref.watch(psListProvider);

    return OfflineOverflowGuard(
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: const Text('PS — Parametry Surowca'),
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
              Tab(text: 'RYLEX'),
              Tab(text: 'Grójecka'),
            ],
          ),
        ),
        body: Column(
          children: [
            const OfflineBanner(),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Szukaj (LOT, odmiana, dostawca, nr dostawy...)',
                  prefixIcon: Icon(Icons.search, size: 20),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onChanged: (v) => setState(() => _search = v.toLowerCase()),
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: psAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => _ErrorView(message: e.toString()),
                data: (list) {
                  final searched = list.where((e) {
                    final q = _search;
                    if (q.isEmpty) return true;
                    return e.lot.toLowerCase().contains(q) ||
                        e.odmiana.toLowerCase().contains(q) ||
                        e.dostawca.toLowerCase().contains(q) ||
                        e.nrDostawy.contains(q) ||
                        e.owoc.toLowerCase().contains(q);
                  }).toList();

                  return TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _buildList(searched),
                      _buildList(_filter(searched, 'czaplin')),
                      _buildList(_filter(searched, 'rylex')),
                      _buildList(_filter(searched, 'grojecka')),
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

// ── Grupa dostaw ──────────────────────────────────────────────────────────────

class _PsGroup extends StatefulWidget {
  final String baseLot;
  final List<PsEntry> entries;
  const _PsGroup({required this.baseLot, required this.entries});

  @override
  State<_PsGroup> createState() => _PsGroupState();
}

class _PsGroupState extends State<_PsGroup> {
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
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.baseLot,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14,
                          color: AppTheme.primaryDark, fontFamily: 'monospace')),
                  const SizedBox(height: 3),
                  Text('${_cap(e0.owoc)}${odmiany.isNotEmpty ? "  •  ${odmiany.join(" / ")}" : ""}',
                      style: const TextStyle(fontSize: 13)),
                  Text('${e0.dostawca}  •  ${e0.data}  •  ${totalNetto.toStringAsFixed(0)} kg',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ])),
                Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppTheme.textSecondary),
              ]),
            ),
          ),
          if (_expanded)
            ...widget.entries.map((e) => Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
              ),
              child: _PsCard(entry: e),
            )),
        ],
      ),
    );
  }

  static String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ── Karta parametrów ──────────────────────────────────────────────────────────

class _PsCard extends StatelessWidget {
  final PsEntry entry;
  const _PsCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(entry.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Nagłówek — nr dostawy + data + status
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.primaryDark,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Dost. #${entry.nrDostawy}',
                style: const TextStyle(
                    color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
            Text(entry.data,
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            const Spacer(),
            if (entry.status.isNotEmpty)
              _StatusBadge(status: entry.status, color: statusColor),
          ]),
          const SizedBox(height: 8),

          // LOT
          Text(entry.lot,
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.primaryMid,
                  fontWeight: FontWeight.w600, fontFamily: 'monospace')),
          const SizedBox(height: 6),

          // Owoc + odmiana + dostawca
          _InfoLine(Icons.eco_outlined,
              '${_cap(entry.owoc)} • ${entry.przeznaczenie}'
                  '${entry.odmiana.isNotEmpty ? " • ${entry.odmiana}" : ""}'),
          _InfoLine(Icons.business_outlined, entry.dostawca),

          // Waga
          if (entry.wagaNetto.isNotEmpty) ...[
            const SizedBox(height: 4),
            _InfoLine(Icons.scale_outlined, '${entry.wagaNetto} kg netto'),
          ],

          // Parametry jakości
          if (entry.hasParams) ...[
            const Divider(height: 16),
            Wrap(spacing: 8, runSpacing: 6, children: [
              if (entry.brix.isNotEmpty)
                _ParamChip('BRIX', entry.brix, AppTheme.primaryMid),
              if (entry.odpad.isNotEmpty)
                _ParamChip('ODPAD', '${entry.odpad}%', AppTheme.warningOrange),
              if (entry.twardosc.isNotEmpty)
                _ParamChip('TWARD.', entry.twardosc, AppTheme.successGreen),
              if (entry.kaliber.isNotEmpty)
                _ParamChip('KALIB.', '${entry.kaliber}%', AppTheme.primaryLight),
              if (entry.zwrotPct.isNotEmpty)
                _ParamChip('ZWROT', '${entry.zwrotPct}%', AppTheme.errorRed),
            ]),
          ] else ...[
            const SizedBox(height: 4),
            const Text('Brak parametrów jakości',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary,
                    fontStyle: FontStyle.italic)),
          ],
        ]),
      ),
    );
  }

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  Color _statusColor(String s) => switch (s.toUpperCase()) {
    'PRZYJETO'   => AppTheme.warningOrange,
    'PRZESŁANO'  => AppTheme.accent,
    'ROZLICZONO' => AppTheme.textSecondary,
    _            => AppTheme.textSecondary,
  };
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final Color color;
  const _StatusBadge({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    final label = switch (status.toUpperCase()) {
      'PRZYJETO'   => 'Przyjęto',
      'PRZESŁANO'  => 'W stanach',
      'ROZLICZONO' => 'Rozliczono',
      _            => status,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _ParamChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _ParamChip(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withAlpha(15),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withAlpha(60)),
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: TextStyle(
          fontSize: 9, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.5)),
      Text(value, style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w700, color: color)),
    ]),
  );
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoLine(this.icon, this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Row(children: [
      Icon(icon, size: 13, color: AppTheme.textSecondary),
      const SizedBox(width: 6),
      Expanded(child: Text(text,
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
    ]),
  );
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) => Center(
    child: Text(message,
        style: const TextStyle(color: AppTheme.errorRed)),
  );
}
