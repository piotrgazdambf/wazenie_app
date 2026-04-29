import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
import '../../core/constants.dart';
import '../../shared/widgets/offline_banner.dart';
import '../../shared/widgets/crate_icon.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class StanOdmiany {
  final String id;
  final String lot;
  final String odmiana;
  final String wagaNetto;
  final String dostawca;
  final String dostawcaKod;
  final String owoc;
  final String przeznaczenie;
  final String nrDostawy;
  final String data;
  final DateTime? createdAt;

  const StanOdmiany({
    required this.id,
    required this.lot,
    required this.odmiana,
    required this.wagaNetto,
    required this.dostawca,
    this.dostawcaKod = '',
    required this.owoc,
    required this.przeznaczenie,
    required this.nrDostawy,
    required this.data,
    this.createdAt,
  });

  factory StanOdmiany.fromFirestore(String id, Map<String, dynamic> d) {
    DateTime? parseDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    return StanOdmiany(
      id:            id,
      lot:           d['lot'] as String? ?? '',
      odmiana:       d['odmiana'] as String? ?? '',
      wagaNetto:     d['waga_netto'] as String? ?? '',
      dostawca:      d['dostawca'] as String? ?? '',
      dostawcaKod:   d['dostawca_kod'] as String? ?? '',
      owoc:          d['owoc'] as String? ?? '',
      przeznaczenie: d['przeznaczenie'] as String? ?? '',
      nrDostawy:     d['nr_dostawy'] as String? ?? '',
      data:          d['data'] as String? ?? '',
      createdAt:     parseDate(d['createdAt']),
    );
  }

  double get kgValue =>
      double.tryParse(wagaNetto.replaceAll(',', '.').replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
}

// ── Dane skrzyń per lot ────────────────────────────────────────────────────────

class _CrateInfo {
  final double kgRemaining;
  final int drewRemaining;
  final int plastRemaining;
  _CrateInfo(this.kgRemaining, this.drewRemaining, this.plastRemaining);

  int get total => drewRemaining + plastRemaining;
  double get kgPerCrate => total == 0 ? 0 : kgRemaining / total;
}

class _StockAgg {
  final String owoc;
  final String odmiana;
  final double kg;
  final int deliveries;

  const _StockAgg({
    required this.owoc,
    required this.odmiana,
    required this.kg,
    required this.deliveries,
  });

  String get label => odmiana.isEmpty ? owoc : '$owoc • $odmiana';
}

final crateInfoMapProvider = StreamProvider<Map<String, _CrateInfo>>((ref) {
  return FirebaseFirestore.instance
      .collection(AppConstants.colCrateStates)
      .where('active', isEqualTo: true)
      .snapshots()
      .map((snap) {
    final map = <String, _CrateInfo>{};
    for (final doc in snap.docs) {
      final d = doc.data();
      map[doc.id] = _CrateInfo(
        (d['kg_remaining'] as num?)?.toDouble() ?? 0,
        (d['drew_remaining'] as num?)?.toInt() ?? 0,
        (d['plast_remaining'] as num?)?.toInt() ?? 0,
      );
    }
    return map;
  });
});

// ── Provider ──────────────────────────────────────────────────────────────────

final stanyProvider = StreamProvider<List<StanOdmiany>>((ref) {
  return FirebaseFirestore.instance
      .collection(AppConstants.colDeliveries)
      .where('status', isEqualTo: 'PRZESŁANO')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => StanOdmiany.fromFirestore(d.id, d.data()))
          .toList());
});

// ── Definicja przeznaczeń ─────────────────────────────────────────────────────

const _przeznaczenia = [
  (name: 'Przecier',  kod: 'P', color: Color(0xFFF59E0B)),
  (name: 'Sok',       kod: 'S', color: Color(0xFF0284C7)),
  (name: 'Obieranie', kod: 'O', color: Color(0xFF16A34A)),
  (name: 'Świeże',    kod: 'F', color: Color(0xFF059669)),
];

Color _przeznaczenieColor(String p) {
  final pu = p.toUpperCase();
  for (final pr in _przeznaczenia) {
    if (pu == pr.name.toUpperCase() || pu == pr.kod.toUpperCase()) return pr.color;
    if (pr.name.length >= 2 && pu.startsWith(pr.name.substring(0, 2).toUpperCase())) return pr.color;
  }
  return AppTheme.primaryMid;
}

bool _matchesFilter(String przeznaczenie, String filter) {
  if (filter == 'Wszystkie') return true;
  final pu = przeznaczenie.toUpperCase();
  final fu = filter.toUpperCase();
  for (final pr in _przeznaczenia) {
    if (pr.name.toUpperCase() == fu || pr.kod.toUpperCase() == fu) {
      if (pu == pr.name.toUpperCase() || pu == pr.kod.toUpperCase()) return true;
      if (pr.name.length >= 2 && pu.startsWith(pr.name.substring(0, 2).toUpperCase())) return true;
    }
  }
  return false;
}

// ── Ekran ─────────────────────────────────────────────────────────────────────

class StanyScreen extends ConsumerStatefulWidget {
  const StanyScreen({super.key});

  @override
  ConsumerState<StanyScreen> createState() => _StanyScreenState();
}

class _StanyScreenState extends ConsumerState<StanyScreen>
    with SingleTickerProviderStateMixin {
  String _filter = 'Wszystkie';
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

  static const _filters = ['Wszystkie', 'Przecier', 'Sok', 'Obieranie', 'Świeże'];

  List<Widget> _buildCards(
    List<StanOdmiany> entries,
    Map<String, _CrateInfo> crateMap,
    WidgetRef ref,
  ) {
    return entries.map((a) => _LotCard(
            entry: a,
            przeznaczenieColor: _przeznaczenieColor(a.przeznaczenie),
            crateInfo: crateMap[a.id],
            onPrzeznaczenieChanged: () {
              ref.invalidate(stanyProvider);
              ref.invalidate(crateInfoMapProvider);
            },
          )).toList();
  }

  @override
  Widget build(BuildContext context) {
    final stanyAsync    = ref.watch(stanyProvider);
    final crateMapAsync = ref.watch(crateInfoMapProvider);
    final crateMap      = crateMapAsync.value ?? {};

    return OfflineOverflowGuard(
      child: Scaffold(
        backgroundColor: AppTheme.background,
        floatingActionButton: stanyAsync.maybeWhen(
          data: (entries) => entries.isNotEmpty ? FloatingActionButton.extended(
            icon: const Icon(Icons.arrow_downward),
            label: const Text('Ściągnij ze stanów'),
            backgroundColor: AppTheme.primaryMid,
            foregroundColor: Colors.white,
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => _SciagnijDialog(entries: entries),
            ),
          ) : null,
          orElse: () => null,
        ),
        appBar: AppBar(
          title: const Text('Stany surowcowe'),
          leading: BackButton(onPressed: () => context.go('/home')),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                ref.invalidate(stanyProvider);
                ref.invalidate(crateInfoMapProvider);
              },
            ),
          ],
          bottom: TabBar(
            controller: _tabCtrl,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: const [Tab(text: 'Stany'), Tab(text: 'Dostawcy')],
          ),
        ),
        body: Column(
          children: [
            const OfflineBanner(),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  // ── Tab 1: Stany ──────────────────────────────────────
                  Column(children: [
                    SizedBox(
                      height: 48,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        children: _filters.map((f) {
                          final sel = _filter == f;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(f),
                              selected: sel,
                              onSelected: (_) => setState(() => _filter = f),
                              selectedColor: AppTheme.primaryMid.withAlpha(30),
                              checkmarkColor: AppTheme.primaryMid,
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                                color: sel ? AppTheme.primaryMid : AppTheme.textSecondary,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    Expanded(
                      child: stanyAsync.when(
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, _) => _ErrorView(message: e.toString()),
                        data: (allEntries) {
                          final filtered = allEntries
                              .where((e) => _matchesFilter(e.przeznaczenie, _filter))
                              .toList();
                          if (filtered.isEmpty && allEntries.isEmpty) return const _EmptyView();
                          return ListView(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
                            children: [
                              _MagazynSummaryCard(entries: filtered),
                              const SizedBox(height: 10),
                              if (filtered.isEmpty) const _EmptyView()
                              else ..._buildCards(filtered, crateMap, ref),
                            ],
                          );
                        },
                      ),
                    ),
                  ]),
                  // ── Tab 2: Dostawcy ───────────────────────────────────
                  stanyAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => _ErrorView(message: e.toString()),
                    data: (allEntries) => _DostawcyView(entries: allEntries),
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

// ── Karta podsumowania magazynu ────────────────────────────────────────────────

class _MagazynSummaryCard extends StatelessWidget {
  final List<StanOdmiany> entries;

  const _MagazynSummaryCard({required this.entries});

  static const _columns = [
    (kod: 'P', label: 'PRZECIER',  color: Color(0xFF2E7D32)),
    (kod: 'S', label: 'SOK',       color: Color(0xFFE65100)),
    (kod: 'O', label: 'OBIERANIE', color: Color(0xFF6A1B9A)),
    (kod: 'F', label: 'ŚWIEŻE',    color: Color(0xFF0277BD)),
  ];

  @override
  Widget build(BuildContext context) {
    final Map<String, Map<String, double>> jablkoByKod  = {for (final c in _columns) c.kod: {}};
    final Map<String, Map<String, double>> gruszkaByKod = {for (final c in _columns) c.kod: {}};
    final Map<String, Map<String, double>> inneByKod    = {for (final c in _columns) c.kod: {}};

    for (final e in entries) {
      final przKod = _extractKod(e.przeznaczenie);
      if (!jablkoByKod.containsKey(przKod)) continue;
      final owoc    = e.owoc.trim().toLowerCase();
      final odmiana = e.odmiana.trim().isEmpty ? e.owoc : e.odmiana.trim();
      if (owoc == 'jabłko' || owoc.contains('jab')) {
        jablkoByKod[przKod]![odmiana]  = (jablkoByKod[przKod]![odmiana]  ?? 0) + e.kgValue;
      } else if (owoc == 'gruszka' || owoc.contains('gruszk')) {
        gruszkaByKod[przKod]![odmiana] = (gruszkaByKod[przKod]![odmiana] ?? 0) + e.kgValue;
      } else {
        inneByKod[przKod]![odmiana]    = (inneByKod[przKod]![odmiana]    ?? 0) + e.kgValue;
      }
    }

    final totalAll = entries.fold(0.0, (a, e) => a + e.kgValue);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nagłówek
            Row(children: [
              const Text('PODSUMOWANIE MAGAZYNU',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
              const Spacer(),
              Text('${_fmt(totalAll)} kg',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primaryMid)),
            ]),
            const SizedBox(height: 8),

            // Szybkie chipsaty per przeznaczenie
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: _columns.map((col) {
                final total = (jablkoByKod[col.kod]?.values.fold<double>(0.0, (a, v) => a + v) ?? 0.0) +
                              (gruszkaByKod[col.kod]?.values.fold<double>(0.0, (a, v) => a + v) ?? 0.0) +
                              (inneByKod[col.kod]?.values.fold<double>(0.0, (a, v) => a + v) ?? 0.0);
                if (total == 0) return const SizedBox.shrink();
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: col.color.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: col.color.withAlpha(80)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(color: col.color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(col.label,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: col.color)),
                    const SizedBox(width: 6),
                    Text('${_fmt(total)} kg',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: col.color)),
                  ]),
                );
              }).toList(),
            ),

            const SizedBox(height: 10),

            // Sekcje wertykalne per przeznaczenie
            ..._columns.map((col) {
              final jMap   = jablkoByKod[col.kod]!;
              final gMap   = gruszkaByKod[col.kod]!;
              final iMap   = inneByKod[col.kod]!;
              final jTotal = jMap.values.fold(0.0, (a, v) => a + v);
              final gTotal = gMap.values.fold(0.0, (a, v) => a + v);
              final iTotal = iMap.values.fold(0.0, (a, v) => a + v);
              final total  = jTotal + gTotal + iTotal;
              if (total == 0) return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Nagłówek sekcji
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        color: col.color,
                        child: Row(children: [
                          Text(col.label,
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                          const Spacer(),
                          Text('${_fmt(total)} kg',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                      if (jTotal > 0) ...[
                        _FruitGroupHeader('Jabłko', jTotal, col.color),
                        ..._sortedEntries(jMap).map((od) =>
                            _OdmianaRow(odmiana: od.key, kg: od.value, color: col.color, indent: true)),
                      ],
                      if (gTotal > 0) ...[
                        _FruitGroupHeader('Gruszka', gTotal, col.color),
                        ..._sortedEntries(gMap).map((od) =>
                            _OdmianaRow(odmiana: od.key, kg: od.value, color: col.color, indent: true)),
                      ],
                      ..._sortedEntries(iMap).map((od) =>
                          _OdmianaRow(odmiana: od.key, kg: od.value, color: col.color)),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  static String _extractKod(String przeznaczenie) {
    final p = przeznaczenie.trim().toUpperCase();
    if (p.startsWith('P')) return 'P';
    if (p.startsWith('S')) return 'S';
    if (p.startsWith('O')) return 'O';
    if (p.startsWith('F') || p.startsWith('Ś')) return 'F';
    return p.isNotEmpty ? p[0] : '';
  }

  static List<MapEntry<String, double>> _sortedEntries(Map<String, double> map) {
    final list = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return list;
  }

  static String _fmt(double v) => v.toStringAsFixed(0);
}

// ── Zakładka Dostawcy ─────────────────────────────────────────────────────────

class _DostawcyView extends StatelessWidget {
  final List<StanOdmiany> entries;
  const _DostawcyView({required this.entries});

  @override
  Widget build(BuildContext context) {
    final Map<String, Map<String, double>> byOwocKey = {};
    final Map<String, String> keyLabel = {};

    for (final e in entries) {
      final owoc = e.owoc.trim().isEmpty ? '—' : _cap(e.owoc.trim());
      byOwocKey.putIfAbsent(owoc, () => {});
      final odmLabel = e.odmiana.trim().isEmpty ? e.owoc : e.odmiana.trim();
      final key = '${odmLabel}__${e.dostawcaKod}__${e.dostawca}';
      keyLabel[key] = '${_cap(odmLabel)}   ${e.dostawcaKod.isNotEmpty ? e.dostawcaKod : ''}  —  ${e.dostawca}';
      byOwocKey[owoc]![key] = (byOwocKey[owoc]![key] ?? 0) + e.kgValue;
    }

    if (byOwocKey.isEmpty) return const _EmptyView();

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
      children: byOwocKey.entries.map((owocEntry) {
        final owoc = owocEntry.key;
        final rows = owocEntry.value.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final total = rows.fold(0.0, (s, r) => s + r.value);
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ExpansionTile(
            initiallyExpanded: true,
            title: Text(owoc, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            subtitle: Text('${total.toStringAsFixed(0)} kg łącznie',
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            children: rows.map((r) {
              final label = keyLabel[r.key] ?? r.key;
              return ListTile(
                dense: true,
                title: Text(label, style: const TextStyle(fontSize: 13)),
                trailing: Text(
                  '${r.value.toStringAsFixed(0)} kg',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();
}

// ─────────────────────────────────────────────────────────────────────────────

class _FruitGroupHeader extends StatelessWidget {
  final String owoc;
  final double kg;
  final Color color;
  const _FruitGroupHeader(this.owoc, this.kg, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(10, 5, 10, 4),
    decoration: BoxDecoration(color: color.withAlpha(15)),
    child: Row(children: [
      Expanded(child: Text(owoc.toUpperCase(),
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color))),
      Text('${kg.toStringAsFixed(0)} kg',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    ]),
  );
}

class _OdmianaRow extends StatelessWidget {
  final String odmiana;
  final double kg;
  final Color color;
  final bool indent;

  const _OdmianaRow({
    required this.odmiana,
    required this.kg,
    required this.color,
    this.indent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(indent ? 20 : 10, 6, 10, 6),
      decoration: BoxDecoration(
        color: indent ? color.withAlpha(5) : Colors.transparent,
        border: Border(bottom: BorderSide(color: color.withAlpha(20), width: 0.5)),
      ),
      child: Row(children: [
        Expanded(
          child: Text(
            odmiana,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: indent ? AppTheme.textSecondary : AppTheme.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${kg.toStringAsFixed(0)} kg',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
        ),
      ]),
    );
  }
}

// ── Karta lotu ─────────────────────────────────────────────────────────────────

class _LotCard extends StatelessWidget {
  final StanOdmiany entry;
  final Color przeznaczenieColor;
  final _CrateInfo? crateInfo;
  final VoidCallback onPrzeznaczenieChanged;

  const _LotCard({
    required this.entry,
    required this.przeznaczenieColor,
    required this.onPrzeznaczenieChanged,
    this.crateInfo,
  });

  @override
  Widget build(BuildContext context) {
    final color = przeznaczenieColor;
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Wiersz 1: numer dostawy + przeznaczenie + data + kg
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primaryDark,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text('Dost. #${entry.nrDostawy}',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: color.withAlpha(80)),
                ),
                child: Text(entry.przeznaczenie,
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color)),
              ),
              const SizedBox(width: 6),
              Text(entry.data,
                  style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: color.withAlpha(80)),
                ),
                child: Text('${entry.kgValue.toStringAsFixed(0)} kg',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
              ),
            ]),
            const SizedBox(height: 4),
            // Wiersz 2: LOT
            Text(entry.lot,
                style: const TextStyle(fontSize: 11, color: AppTheme.primaryMid, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            // Wiersz 3: owoc + odmiana + dostawca
            Row(children: [
              Icon(Icons.eco_outlined, size: 11, color: AppTheme.textSecondary),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  '${_cap(entry.owoc)}${entry.odmiana.isNotEmpty ? " • ${entry.odmiana}" : ""}  •  ${entry.dostawca}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                ),
              ),
            ]),
            if (crateInfo != null && crateInfo!.total > 0) ...[
              const SizedBox(height: 4),
              Row(children: [
                _CrateBadge(
                  icon: Icons.inventory_outlined,
                  label: _crateLabel(crateInfo!),
                  color: AppTheme.primaryMid,
                ),
                const SizedBox(width: 8),
                _CrateBadge(
                  icon: Icons.scale_outlined,
                  label: _kgPerCrateLabel(crateInfo!),
                  color: AppTheme.accent,
                ),
              ]),
            ],
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.swap_horiz, size: 14),
                label: const Text('Zmień przeznaczenie'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  textStyle: const TextStyle(fontSize: 11),
                  minimumSize: const Size(0, 28),
                ),
                onPressed: () => _showZmianaDialog(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showZmianaDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => _ZmianaDialog(
        entry: entry,
        onChanged: onPrzeznaczenieChanged,
      ),
    );
  }

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  String _crateLabel(_CrateInfo c) {
    if (c.drewRemaining > 0 && c.plastRemaining > 0) return '${c.drewRemaining}D + ${c.plastRemaining}P';
    if (c.drewRemaining > 0) return '${c.drewRemaining}D';
    return '${c.plastRemaining}P';
  }

  String _kgPerCrateLabel(_CrateInfo c) {
    final avg = c.total > 0 ? (c.kgRemaining / c.total) : 0.0;
    if (c.drewRemaining > 0 && c.plastRemaining > 0) {
      return '~${avg.toStringAsFixed(0)} kg/D  ~${avg.toStringAsFixed(0)} kg/P';
    }
    if (c.drewRemaining > 0) return '~${avg.toStringAsFixed(0)} kg/D';
    return '~${avg.toStringAsFixed(0)} kg/P';
  }
}

class _CrateBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _CrateBadge({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 12, color: color),
      const SizedBox(width: 3),
      Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    ],
  );
}

// ── Dialog zmiany przeznaczenia ────────────────────────────────────────────────

class _ZmianaDialog extends StatefulWidget {
  final StanOdmiany entry;
  final VoidCallback onChanged;

  const _ZmianaDialog({required this.entry, required this.onChanged});

  @override
  State<_ZmianaDialog> createState() => _ZmianaDialogState();
}

class _ZmianaDialogState extends State<_ZmianaDialog> {
  String? _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.entry.przeznaczenie;
  }

  Future<void> _save() async {
    if (_selected == null || _selected == widget.entry.przeznaczenie) {
      Navigator.pop(context);
      return;
    }

    setState(() => _saving = true);
    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      final selectedPrzezn = _przeznaczenia.firstWhere(
        (p) => p.name == _selected,
        orElse: () => _przeznaczenia.first,
      );

      final delivRef = db.collection(AppConstants.colDeliveries).doc(widget.entry.id);
      batch.update(delivRef, {
        'przeznaczenie':     selectedPrzezn.name,
        'przeznaczenie_kod': selectedPrzezn.kod,
      });

      final crateRef = db.collection(AppConstants.colCrateStates).doc(widget.entry.id);
      final crateSnap = await crateRef.get();
      if (crateSnap.exists) {
        batch.update(crateRef, {'przeznaczenie': selectedPrzezn.name});
      }

      final mcrRef = db.collection(AppConstants.colMcrQueue).doc();
      batch.set(mcrRef, {
        'lot':          widget.entry.lot,
        'czas':         DateTime.now().toIso8601String(),
        'akcja':        'Zmiana przeznaczenia',
        'waga_netto':   widget.entry.wagaNetto,
        'owoc':         widget.entry.owoc,
        'odmiana':      widget.entry.odmiana,
        'przeznaczenie':selectedPrzezn.name,
        'poprzednie_przeznaczenie': widget.entry.przeznaczenie,
        'status':       'done',
        'createdAt':    FieldValue.serverTimestamp(),
      });

      await batch.commit().timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('Przekroczono czas. Sprawdź połączenie.'),
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onChanged();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd: $e'), backgroundColor: AppTheme.errorRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Zmień przeznaczenie'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.entry.lot,
            style: const TextStyle(
                fontSize: 12,
                color: AppTheme.primaryMid,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            '${_cap(widget.entry.owoc)} • ${widget.entry.odmiana}',
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          ..._przeznaczenia.map((p) => _PrzeznaczenieOption(
                name: p.name,
                color: p.color,
                selected: _selected == p.name,
                current: widget.entry.przeznaczenie == p.name,
                onTap: () => setState(() => _selected = p.name),
              )),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Anuluj'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Zatwierdź'),
        ),
      ],
    );
  }

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _PrzeznaczenieOption extends StatelessWidget {
  final String name;
  final Color color;
  final bool selected;
  final bool current;
  final VoidCallback onTap;

  const _PrzeznaczenieOption({
    required this.name,
    required this.color,
    required this.selected,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? color.withAlpha(30) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? color : AppTheme.borderLight,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: selected ? color : AppTheme.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                      color: selected ? color : AppTheme.textPrimary,
                      fontSize: 14),
                ),
              ),
              if (current)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.textSecondary.withAlpha(20),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('aktualnie',
                      style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppTheme.errorRed),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      );
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CrateIcon(size: 64, color: AppTheme.borderLight),
            SizedBox(height: 12),
            Text('Brak przesłanych dostaw',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
            SizedBox(height: 4),
            Text(
              'Przesyłaj dostawy przez PLS → "Prześlij do Stanów"',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
}

// ── Ściągnij ze stanów (do MCR) ───────────────────────────────────────────────

class _SciagnijDialog extends StatefulWidget {
  final List<StanOdmiany> entries;
  const _SciagnijDialog({required this.entries});

  @override
  State<_SciagnijDialog> createState() => _SciagnijDialogState();
}

class _SciagnijDialogState extends State<_SciagnijDialog> {
  String? _owoc;
  String? _lot;
  bool _useWaga = true;
  final _wagaCtrl = TextEditingController();
  final _drewCtrl = TextEditingController();
  final _plastCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _wagaCtrl.dispose();
    _drewCtrl.dispose();
    _plastCtrl.dispose();
    super.dispose();
  }

  List<String> get _owoce => widget.entries
      .map((e) => e.owoc.trim().isEmpty ? '—' : e.owoc.trim())
      .toSet().toList()..sort();

  List<StanOdmiany> get _odmiany => _owoc == null ? [] :
      widget.entries.where((e) => e.owoc.trim() == _owoc).toList();

  Future<void> _save() async {
    if (_lot == null) return;
    final entry = widget.entries.firstWhere((e) => e.id == _lot);
    final wagaKg = double.tryParse(_wagaCtrl.text.replaceAll(',', '.')) ?? 0;
    final drewZdj = int.tryParse(_drewCtrl.text) ?? 0;
    final plastZdj = int.tryParse(_plastCtrl.text) ?? 0;
    if (_useWaga && wagaKg <= 0) return;
    if (!_useWaga && drewZdj == 0 && plastZdj == 0) return;

    setState(() => _saving = true);
    final db  = FirebaseFirestore.instance;
    final now = DateTime.now();
    try {
      final batch = db.batch();
      final mcrRef = db.collection(AppConstants.colMcrQueue).doc();
      batch.set(mcrRef, {
        'lot':          entry.lot,
        'czas':         now.toIso8601String(),
        'akcja':        'Zejście',
        'waga_netto':   _useWaga ? wagaKg.toStringAsFixed(2) : '0',
        'owoc':         entry.owoc,
        'odmiana':      entry.odmiana,
        'przeznaczenie':entry.przeznaczenie,
        'drew_zdj':     _useWaga ? 0 : drewZdj,
        'plast_zdj':    _useWaga ? 0 : plastZdj,
        'status':       'done',
        'createdAt':    FieldValue.serverTimestamp(),
      });
      if (!_useWaga) {
        final crateSnap = await db.collection(AppConstants.colCrateStates).doc(entry.id).get();
        if (crateSnap.exists) {
          final d = crateSnap.data()!;
          final newDrew  = ((d['drew_remaining']  as num?)?.toInt() ?? 0) - drewZdj;
          final newPlast = ((d['plast_remaining'] as num?)?.toInt() ?? 0) - plastZdj;
          batch.update(crateSnap.reference, {
            'drew_remaining':  newDrew.clamp(0, 9999),
            'plast_remaining': newPlast.clamp(0, 9999),
            'active': (newDrew + newPlast) > 0,
          });
        }
      }
      final delivKg = entry.kgValue;
      if (_useWaga && wagaKg >= delivKg * 0.99) {
        batch.update(db.collection(AppConstants.colDeliveries).doc(entry.id), {'status': 'ROZLICZONO'});
      }
      await batch.commit();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd: $e'), backgroundColor: Colors.red),
        );
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ściągnij ze stanów'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'Owoc / Surowiec'),
            value: _owoc,
            items: _owoce.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
            onChanged: (v) => setState(() { _owoc = v; _lot = null; }),
          ),
          const SizedBox(height: 10),
          if (_owoc != null)
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Odmiana / LOT'),
              value: _lot,
              items: _odmiany.map((e) => DropdownMenuItem(
                value: e.id,
                child: Text('${e.odmiana.isNotEmpty ? e.odmiana : e.owoc}  (${e.wagaNetto} kg)'),
              )).toList(),
              onChanged: (v) => setState(() => _lot = v),
            ),
          const SizedBox(height: 12),
          if (_lot != null) ...[
            Row(children: [
              Expanded(child: RadioListTile<bool>(
                title: const Text('Waga [kg]', style: TextStyle(fontSize: 13)),
                value: true, groupValue: _useWaga,
                onChanged: (v) => setState(() => _useWaga = v!),
                contentPadding: EdgeInsets.zero,
              )),
              Expanded(child: RadioListTile<bool>(
                title: const Text('Skrzynie', style: TextStyle(fontSize: 13)),
                value: false, groupValue: _useWaga,
                onChanged: (v) => setState(() => _useWaga = v!),
                contentPadding: EdgeInsets.zero,
              )),
            ]),
            if (_useWaga)
              TextFormField(
                controller: _wagaCtrl,
                decoration: const InputDecoration(labelText: 'Waga zejścia [kg]'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              )
            else
              Row(children: [
                Expanded(child: TextFormField(
                  controller: _drewCtrl,
                  decoration: const InputDecoration(labelText: 'Drew.'),
                  keyboardType: TextInputType.number,
                )),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(
                  controller: _plastCtrl,
                  decoration: const InputDecoration(labelText: 'Plast.'),
                  keyboardType: TextInputType.number,
                )),
              ]),
          ],
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Anuluj')),
        FilledButton(
          onPressed: (_saving || _lot == null) ? null : _save,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Zapisz zejście'),
        ),
      ],
    );
  }
}
