import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
import '../../core/constants.dart';
import '../../core/auth/pin_auth_service.dart';
import '../../shared/widgets/offline_banner.dart';
import '../../shared/widgets/crate_icon.dart';

// ── Model CrateState ─────────────────────────────────────────────────────────

class CrateState {
  final String id;
  final String lot;
  final String odmiana;
  final String owoc;
  final String dostawca;
  final String przeznaczenie;
  final String nrDostawy;
  final String data;
  final int drewTotal;
  final int plastTotal;
  final int drewRemaining;
  final int plastRemaining;
  final double drewWagaJedn;
  final double plastWagaJedn;
  final double kgTotal;
  final double kgRemaining;
  final bool active;
  final bool isKwg;

  const CrateState({
    required this.id, required this.lot, required this.odmiana,
    required this.owoc, required this.dostawca, required this.przeznaczenie,
    required this.nrDostawy, required this.data,
    required this.drewTotal, required this.plastTotal,
    required this.drewRemaining, required this.plastRemaining,
    required this.drewWagaJedn, required this.plastWagaJedn,
    required this.kgTotal, required this.kgRemaining,
    required this.active, required this.isKwg,
  });

  factory CrateState.fromFirestore(String id, Map<String, dynamic> d) => CrateState(
    id: id, lot: d['lot'] as String? ?? '',
    odmiana: d['odmiana'] as String? ?? '', owoc: d['owoc'] as String? ?? '',
    dostawca: d['dostawca'] as String? ?? '', przeznaczenie: d['przeznaczenie'] as String? ?? '',
    nrDostawy: d['nr_dostawy'] as String? ?? '', data: d['data'] as String? ?? '',
    drewTotal:      (d['drew_total']      as num?)?.toInt()    ?? 0,
    plastTotal:     (d['plast_total']     as num?)?.toInt()    ?? 0,
    drewRemaining:  (d['drew_remaining']  as num?)?.toInt()    ?? 0,
    plastRemaining: (d['plast_remaining'] as num?)?.toInt()    ?? 0,
    drewWagaJedn:   (d['drew_waga_jedn']  as num?)?.toDouble() ?? 20.0,
    plastWagaJedn:  (d['plast_waga_jedn'] as num?)?.toDouble() ?? 10.0,
    kgTotal:        (d['kg_total']        as num?)?.toDouble() ?? 0,
    kgRemaining:    (d['kg_remaining']    as num?)?.toDouble() ?? 0,
    active: d['active'] as bool? ?? true, isKwg: d['is_kwg'] as bool? ?? false,
  );

  int get totalCratesRemaining => drewRemaining + plastRemaining;
  double get kgPerCrate => totalCratesRemaining == 0 ? 0 : kgRemaining / totalCratesRemaining;

  double kgForRemoval(int drew, int plast) {
    final totalTara = drewRemaining * drewWagaJedn + plastRemaining * plastWagaJedn;
    if (totalTara <= 0 || kgRemaining <= 0) return 0;
    return (kgRemaining * (drew * drewWagaJedn + plast * plastWagaJedn) / totalTara)
        .clamp(0, kgRemaining);
  }
}

// ── Model CrateAction ─────────────────────────────────────────────────────────

class CrateAction {
  final String id;
  final String dostawca;
  final String lot;
  final String owoc;
  final String odmiana;
  final String przeznaczenie;
  final String nrDostawy;
  final String data;
  final String akcja;
  final int drewZdj;
  final int plastZdj;
  final DateTime? createdAt;

  const CrateAction({
    required this.id, required this.dostawca, required this.lot,
    required this.owoc, required this.odmiana, required this.przeznaczenie,
    required this.nrDostawy, required this.data, required this.akcja,
    required this.drewZdj, required this.plastZdj, this.createdAt,
  });

  factory CrateAction.fromFirestore(String id, Map<String, dynamic> d) {
    DateTime? parseTs(dynamic v) {
      if (v is Timestamp) return v.toDate();
      return null;
    }
    return CrateAction(
      id: id, dostawca: d['dostawca'] as String? ?? '',
      lot: d['lot'] as String? ?? '', owoc: d['owoc'] as String? ?? '',
      odmiana: d['odmiana'] as String? ?? '', przeznaczenie: d['przeznaczenie'] as String? ?? '',
      nrDostawy: d['nr_dostawy'] as String? ?? '', data: d['data'] as String? ?? '',
      akcja: d['akcja'] as String? ?? 'Zejście',
      drewZdj:  (d['drew_zdj']  as num?)?.toInt() ?? 0,
      plastZdj: (d['plast_zdj'] as num?)?.toInt() ?? 0,
      createdAt: parseTs(d['createdAt']),
    );
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final crateStatesProvider = StreamProvider<List<CrateState>>((ref) =>
  FirebaseFirestore.instance
      .collection(AppConstants.colCrateStates)
      .where('active', isEqualTo: true)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => CrateState.fromFirestore(d.id, d.data())).toList()));

final crateActionsProvider = StreamProvider<List<CrateAction>>((ref) =>
  FirebaseFirestore.instance
      .collection(AppConstants.colCrateActions)
      .orderBy('createdAt', descending: true)
      .limit(200)
      .snapshots()
      .map((s) => s.docs.map((d) => CrateAction.fromFirestore(d.id, d.data())).toList()));

// ── Screen ────────────────────────────────────────────────────────────────────

class SkrzynieScreen extends ConsumerWidget {
  const SkrzynieScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OfflineOverflowGuard(
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            title: const Text('Skrzynie'),
            leading: BackButton(onPressed: () => context.go('/home')),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  ref.invalidate(crateStatesProvider);
                  ref.invalidate(crateActionsProvider);
                },
              ),
            ],
            bottom: const TabBar(
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              tabs: [
                Tab(text: 'Stany skrzyń'),
                Tab(text: 'Akcje skrzyń'),
              ]),
          ),
          body: Column(children: [
            const OfflineBanner(),
            const Expanded(child: TabBarView(children: [
              _StanyTab(),
              _AkcjeTab(),
            ])),
          ]),
        ),
      ),
    );
  }
}

// ── TAB 1: STANY ──────────────────────────────────────────────────────────────

class _StanyTab extends ConsumerWidget {
  const _StanyTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(crateStatesProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Błąd: $e')),
      data: (list) {
        if (list.isEmpty) return const _EmptyView();

        final totalDrew  = list.fold(0, (s, c) => s + c.drewRemaining);
        final totalPlast = list.fold(0, (s, c) => s + c.plastRemaining);

        // Agreguj per dostawca
        final Map<String, ({int drew, int plast, List<CrateState> lots})> byDostawca = {};
        for (final c in list) {
          final d = c.dostawca.trim().isEmpty ? '(nieznany)' : c.dostawca.trim();
          if (!byDostawca.containsKey(d)) {
            byDostawca[d] = (drew: 0, plast: 0, lots: []);
          }
          final prev = byDostawca[d]!;
          byDostawca[d] = (
            drew: prev.drew + c.drewRemaining,
            plast: prev.plast + c.plastRemaining,
            lots: [...prev.lots, c],
          );
        }

        final sorted = byDostawca.entries.toList()
          ..sort((a, b) => (b.value.drew + b.value.plast).compareTo(a.value.drew + a.value.plast));

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            // Nagłówek — bez kg
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryDark, AppTheme.primaryMid],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                const CrateIcon(size: 16, color: Colors.white70),
                const SizedBox(width: 8),
                const Text('STANY SKRZYŃ', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
                const Spacer(),
                _SumBadge('Drewniane', '$totalDrew szt.'),
                const SizedBox(width: 16),
                _SumBadge('Plastikowe', '$totalPlast szt.'),
              ]),
            ),
            const SizedBox(height: 10),

            // Tabela nagłówek
            Container(
              decoration: const BoxDecoration(
                color: AppTheme.primaryDark,
                borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(children: [
                const Expanded(child: Text('DOSTAWCA', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
                SizedBox(width: 80, child: Text('DREWNIANE', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700), textAlign: TextAlign.center)),
                SizedBox(width: 80, child: Text('PLASTIKOWE', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700), textAlign: TextAlign.center)),
              ]),
            ),

            // Wiersze
            Card(
              margin: EdgeInsets.zero,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(8))),
              child: Column(
                children: sorted.asMap().entries.map((entry) {
                  final i = entry.key;
                  final e = entry.value;
                  final isLast = i == sorted.length - 1;
                  final isAdmin = ref.watch(currentSessionProvider)?.user.isAdmin ?? false;
                  return InkWell(
                    onTap: () => _showDostawcaLots(context, e.key, e.value.lots),
                    child: Container(
                      decoration: BoxDecoration(
                        color: i.isEven ? Colors.white : AppTheme.background,
                        borderRadius: isLast
                            ? const BorderRadius.vertical(bottom: Radius.circular(8))
                            : null,
                        border: isLast ? null : const Border(bottom: BorderSide(color: AppTheme.borderLight, width: 0.5)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Row(children: [
                        Expanded(
                          child: Text(e.key,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                        ),
                        SizedBox(
                          width: 80,
                          child: Text(
                            e.value.drew > 0 ? '${e.value.drew}' : '—',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700,
                              color: e.value.drew > 0 ? AppTheme.primaryMid : AppTheme.textSecondary,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 80,
                          child: Text(
                            e.value.plast > 0 ? '${e.value.plast}' : '—',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700,
                              color: e.value.plast > 0 ? AppTheme.accent : AppTheme.textSecondary,
                            ),
                          ),
                        ),
                        if (isAdmin)
                          SizedBox(
                            width: 36,
                            child: IconButton(
                              icon: const Icon(Icons.settings, size: 16, color: AppTheme.textSecondary),
                              padding: EdgeInsets.zero,
                              tooltip: 'Korekta skrzyń',
                              onPressed: () => _showKorekta(context, e.key, e.value.lots),
                            ),
                          ),
                      ]),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showDostawcaLots(BuildContext context, String dostawca, List<CrateState> lots) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DostawcaLotsSheet(dostawca: dostawca, lots: lots),
    );
  }

  void _showKorekta(BuildContext context, String dostawca, List<CrateState> lots) {
    showDialog<void>(
      context: context,
      builder: (_) => _KorektaDialog(dostawca: dostawca, lots: lots),
    );
  }
}

class _SumBadge extends StatelessWidget {
  final String label;
  final String value;
  const _SumBadge(this.label, this.value);

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
    Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
    Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
  ]);
}

// ── Bottom sheet: loty dostawcy ───────────────────────────────────────────────

class _DostawcaLotsSheet extends StatelessWidget {
  final String dostawca;
  final List<CrateState> lots;
  const _DostawcaLotsSheet({required this.dostawca, required this.lots});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(children: [
          const SizedBox(height: 8),
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: AppTheme.borderLight, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(dostawca, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 8),
          const Divider(),
          Expanded(
            child: ListView.builder(
              controller: ctrl,
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
              itemCount: lots.length + 1,
              itemBuilder: (_, i) {
                // Pierwsza pozycja — WSZYSTKIE
                if (i == 0) {
                  final totalDrew  = lots.fold(0, (s, c) => s + c.drewRemaining);
                  final totalPlast = lots.fold(0, (s, c) => s + c.plastRemaining);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    color: AppTheme.primaryDark,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          const Expanded(child: Text('WSZYSTKIE',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white))),
                          Text('${totalDrew}D + ${totalPlast}P',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white70)),
                        ]),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: (totalDrew + totalPlast) > 0 ? () {
                              Navigator.of(context).pop();
                              showDialog<void>(
                                context: context,
                                builder: (_) => _ZdejmijWszystkieDialog(dostawca: dostawca, lots: lots),
                              );
                            } : null,
                            icon: const Icon(Icons.remove_circle_outline, size: 16),
                            label: const Text('Wydaj skrzynie'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              side: const BorderSide(color: Colors.white38),
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ]),
                    ),
                  );
                }

                final c = lots[i - 1];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(
                          c.odmiana.isNotEmpty ? c.odmiana : c.owoc,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        )),
                        Text('${c.drewRemaining}D + ${c.plastRemaining}P',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primaryMid)),
                      ]),
                      Text('${c.przeznaczenie}  •  Dost. ${c.nrDostawy}  •  ${c.data}',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      Text(c.lot, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: c.totalCratesRemaining > 0
                              ? () {
                                  Navigator.of(context).pop();
                                  showDialog<void>(
                                    context: context,
                                    builder: (_) => _ZdejmijDialog(state: c),
                                  );
                                }
                              : null,
                          icon: const Icon(Icons.remove_circle_outline, size: 16),
                          label: const Text('Wydaj skrzynie'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.errorRed,
                            side: const BorderSide(color: AppTheme.errorRed),
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            textStyle: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ]),
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

// ── TAB 2: AKCJE ─────────────────────────────────────────────────────────────

class _AkcjeTab extends ConsumerWidget {
  const _AkcjeTab();

  Future<void> _deleteAction(BuildContext context, String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Usuń akcję'),
        content: const Text('Na pewno usunąć tę akcję? Stany skrzyń nie zostaną automatycznie cofnięte.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Anuluj')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            child: const Text('Usuń', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await FirebaseFirestore.instance.collection(AppConstants.colCrateActions).doc(id).delete();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async   = ref.watch(crateActionsProvider);
    final isAdmin = ref.watch(currentSessionProvider)?.user.isAdmin ?? false;
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Błąd: $e')),
      data: (list) {
        if (list.isEmpty) return const Center(
          child: Text('Brak akcji skrzyń', style: TextStyle(color: AppTheme.textSecondary)),
        );

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: list.length,
          itemBuilder: (_, i) {
            final a = list[i];
            final dateStr = a.createdAt != null
                ? '${a.createdAt!.day.toString().padLeft(2,'0')}.${a.createdAt!.month.toString().padLeft(2,'0')}.${a.createdAt!.year}  ${a.createdAt!.hour.toString().padLeft(2,'0')}:${a.createdAt!.minute.toString().padLeft(2,'0')}'
                : a.data;

            final isPrzyjecie = a.akcja == 'Przyjęcie';
            final actionColor = isPrzyjecie ? AppTheme.successGreen : AppTheme.errorRed;
            final sign = isPrzyjecie ? '+' : '−';
            return Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: actionColor.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isPrzyjecie ? Icons.add_circle_outline : Icons.remove_circle_outline,
                      size: 18, color: actionColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(
                        child: Text(a.dostawca.isNotEmpty ? a.dostawca : '—',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: actionColor.withAlpha(20),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(a.akcja,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: actionColor)),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    // Opis ilości skrzyń
                    if (a.drewZdj > 0 || a.plastZdj > 0) ...[
                      if (a.drewZdj > 0)
                        Text(
                          '${isPrzyjecie ? "Przyjęto" : "Wydano"} ${a.drewZdj} skrzyń drewnianych',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: actionColor),
                        ),
                      if (a.plastZdj > 0)
                        Text(
                          '${isPrzyjecie ? "Przyjęto" : "Wydano"} ${a.plastZdj} skrzyń plastikowych',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: actionColor),
                        ),
                      const SizedBox(height: 2),
                    ],
                    if (a.nrDostawy.isNotEmpty || a.owoc.isNotEmpty)
                      Text(
                        '${a.nrDostawy.isNotEmpty ? "Dost. ${a.nrDostawy}  •  " : ""}'
                        '${a.owoc.isNotEmpty ? "${a.owoc}${a.odmiana.isNotEmpty ? " • ${a.odmiana}" : ""}" : ""}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                    Text(dateStr, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  ])),
                  if (isAdmin)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.errorRed),
                      onPressed: () => _deleteAction(context, a.id),
                      tooltip: 'Usuń akcję',
                    ),
                ]),
              ),
            );
          },
        );
      },
    );
  }
}

// ── Dialog zdejmowania skrzyń ─────────────────────────────────────────────────

class _ZdejmijDialog extends StatefulWidget {
  final CrateState state;
  const _ZdejmijDialog({required this.state});

  @override
  State<_ZdejmijDialog> createState() => _ZdejmijDialogState();
}

class _ZdejmijDialogState extends State<_ZdejmijDialog> {
  final _drewCtrl  = TextEditingController(text: '0');
  final _plastCtrl = TextEditingController(text: '0');
  bool _saving = false;

  @override
  void dispose() { _drewCtrl.dispose(); _plastCtrl.dispose(); super.dispose(); }

  int get _drewN  => int.tryParse(_drewCtrl.text.trim()) ?? 0;
  int get _plastN => int.tryParse(_plastCtrl.text.trim()) ?? 0;
  double get _kgDoZdjecia => widget.state.kgForRemoval(_drewN, _plastN);
  bool get _valid =>
      (_drewN + _plastN) > 0 &&
      _drewN <= widget.state.drewRemaining &&
      _plastN <= widget.state.plastRemaining;

  Future<void> _confirm() async {
    if (!_valid) return;
    setState(() => _saving = true);
    final s = widget.state;
    final kg = _kgDoZdjecia;

    try {
      final db  = FirebaseFirestore.instance;
      final now = DateTime.now();

      await db.collection(AppConstants.colCrateStates).doc(s.id).update({
        'drew_remaining':  s.drewRemaining - _drewN,
        'plast_remaining': s.plastRemaining - _plastN,
        'kg_remaining':    (s.kgRemaining - kg).clamp(0.0, s.kgTotal),
        'active':          ((s.drewRemaining - _drewN) + (s.plastRemaining - _plastN)) > 0,
        'updatedAt':       FieldValue.serverTimestamp(),
      });

      await db.collection(AppConstants.colCrateActions).add({
        'lot': s.lot, 'dostawca': s.dostawca,
        'owoc': s.owoc, 'odmiana': s.odmiana,
        'przeznaczenie': s.przeznaczenie,
        'nr_dostawy': s.nrDostawy, 'data': s.data,
        'akcja': 'Zejście',
        'drew_zdj': _drewN, 'plast_zdj': _plastN,
        'createdAt': FieldValue.serverTimestamp(),
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

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return AlertDialog(
      title: Text('Wydaj skrzynie\n${s.odmiana.isNotEmpty ? s.odmiana : s.lot}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.accent.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.accent.withAlpha(60)),
            ),
            child: Text(
              'Stan: ${s.drewRemaining}D + ${s.plastRemaining}P\n'
              '~${s.kgPerCrate.toStringAsFixed(1)} kg/skrzynię',
              style: const TextStyle(fontSize: 12, color: AppTheme.primaryDark),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.select_all, size: 16),
              label: const Text('Wydaj wszystkie'),
              onPressed: () => setState(() {
                _drewCtrl.text  = s.drewRemaining.toString();
                _plastCtrl.text = s.plastRemaining.toString();
              }),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.errorRed,
                side: const BorderSide(color: AppTheme.errorRed),
                padding: const EdgeInsets.symmetric(vertical: 8),
                textStyle: const TextStyle(fontSize: 13),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextFormField(
              controller: _drewCtrl,
              decoration: InputDecoration(labelText: 'Drewn. (max ${s.drewRemaining})'),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
            )),
            const SizedBox(width: 10),
            Expanded(child: TextFormField(
              controller: _plastCtrl,
              decoration: InputDecoration(labelText: 'Plast. (max ${s.plastRemaining})'),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
            )),
          ]),
          if (_drewN + _plastN > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _valid ? AppTheme.errorRed.withAlpha(15) : AppTheme.warningOrange.withAlpha(15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _valid ? AppTheme.errorRed.withAlpha(60) : AppTheme.warningOrange.withAlpha(60)),
              ),
              child: Column(children: [
                _Row2('Skrzynie', '${_drewN}D + ${_plastN}P'),
                _Row2('Kg do odjęcia', '−${_kgDoZdjecia.toStringAsFixed(2)} kg'),
                if (!_valid) const Text('Przekroczono dostępną liczbę!',
                    style: TextStyle(color: AppTheme.errorRed, fontSize: 12)),
              ]),
            ),
          ],
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Anuluj')),
        ElevatedButton(
          onPressed: (_valid && !_saving) ? _confirm : null,
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
          child: _saving
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Wydaj'),
        ),
      ],
    );
  }
}

class _Row2 extends StatelessWidget {
  final String label;
  final String value;
  const _Row2(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
    ]),
  );
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      CrateIcon(size: 64, color: AppTheme.borderLight),
      SizedBox(height: 12),
      Text('Brak aktywnych skrzyń', style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
    ]),
  );
}

// ── Dialog wydania WSZYSTKICH skrzyń dostawcy ─────────────────────────────────

class _ZdejmijWszystkieDialog extends StatefulWidget {
  final String dostawca;
  final List<CrateState> lots;
  const _ZdejmijWszystkieDialog({required this.dostawca, required this.lots});

  @override
  State<_ZdejmijWszystkieDialog> createState() => _ZdejmijWszystkieDialogState();
}

class _ZdejmijWszystkieDialogState extends State<_ZdejmijWszystkieDialog> {
  final _drewCtrl  = TextEditingController(text: '0');
  final _plastCtrl = TextEditingController(text: '0');
  bool _saving = false;

  @override
  void dispose() { _drewCtrl.dispose(); _plastCtrl.dispose(); super.dispose(); }

  int get _drewN  => int.tryParse(_drewCtrl.text.trim()) ?? 0;
  int get _plastN => int.tryParse(_plastCtrl.text.trim()) ?? 0;

  int get _totalDrew  => widget.lots.fold(0, (s, c) => s + c.drewRemaining);
  int get _totalPlast => widget.lots.fold(0, (s, c) => s + c.plastRemaining);

  bool get _valid => (_drewN + _plastN) > 0 && _drewN <= _totalDrew && _plastN <= _totalPlast;

  Future<void> _confirm() async {
    if (!_valid) return;
    setState(() => _saving = true);
    try {
      final db  = FirebaseFirestore.instance;
      int drewLeft  = _drewN;
      int plastLeft = _plastN;

      final batch = db.batch();

      // Zdejmuj kolejno z lotów (od pierwszego)
      for (final c in widget.lots) {
        if (drewLeft <= 0 && plastLeft <= 0) break;
        final dZdj = drewLeft.clamp(0, c.drewRemaining);
        final pZdj = plastLeft.clamp(0, c.plastRemaining);
        if (dZdj + pZdj == 0) continue;

        final newDrew  = c.drewRemaining - dZdj;
        final newPlast = c.plastRemaining - pZdj;
        batch.update(db.collection(AppConstants.colCrateStates).doc(c.id), {
          'drew_remaining':  newDrew,
          'plast_remaining': newPlast,
          'active':          (newDrew + newPlast) > 0,
          'updatedAt':       FieldValue.serverTimestamp(),
        });
        drewLeft  -= dZdj;
        plastLeft -= pZdj;
      }

      // Jedna akcja zbiorcza
      batch.set(db.collection(AppConstants.colCrateActions).doc(), {
        'lot':          '',
        'dostawca':     widget.dostawca,
        'owoc':         '',
        'odmiana':      '',
        'przeznaczenie':'',
        'nr_dostawy':   '',
        'data':         '',
        'akcja':        'Zejście',
        'drew_zdj':     _drewN,
        'plast_zdj':    _plastN,
        'createdAt':    FieldValue.serverTimestamp(),
      });

      await batch.commit();
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Wydaj skrzynie\n${widget.dostawca}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.accent.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.accent.withAlpha(60)),
            ),
            child: Text(
              'Łącznie u dostawcy: ${_totalDrew}D + ${_totalPlast}P',
              style: const TextStyle(fontSize: 12, color: AppTheme.primaryDark),
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: TextFormField(
              controller: _drewCtrl,
              decoration: InputDecoration(labelText: 'Drewn. (max $_totalDrew)'),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
            )),
            const SizedBox(width: 10),
            Expanded(child: TextFormField(
              controller: _plastCtrl,
              decoration: InputDecoration(labelText: 'Plast. (max $_totalPlast)'),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
            )),
          ]),
          if (!_valid && (_drewN + _plastN) > 0) ...[
            const SizedBox(height: 8),
            const Text('Przekroczono dostępną ilość!',
                style: TextStyle(fontSize: 11, color: AppTheme.errorRed)),
          ],
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Anuluj')),
        ElevatedButton(
          onPressed: _valid && !_saving ? _confirm : null,
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
          child: _saving
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Wydaj', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

// ── Korekta skrzyń (admin) ────────────────────────────────────────────────────

class _KorektaDialog extends StatefulWidget {
  final String dostawca;
  final List<CrateState> lots;
  const _KorektaDialog({required this.dostawca, required this.lots});

  @override
  State<_KorektaDialog> createState() => _KorektaDialogState();
}

class _KorektaDialogState extends State<_KorektaDialog> {
  final _drewCtrl  = TextEditingController();
  final _plastCtrl = TextEditingController();
  final _noteCtrl  = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _drewCtrl.dispose();
    _plastCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final drewDelta  = int.tryParse(_drewCtrl.text.trim()) ?? 0;
    final plastDelta = int.tryParse(_plastCtrl.text.trim()) ?? 0;
    if (drewDelta == 0 && plastDelta == 0) return;

    setState(() => _saving = true);
    final db   = FirebaseFirestore.instance;
    final now  = DateTime.now();
    final date = '${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}';

    try {
      // Aktualizuj pierwszą aktywną skrzynię dostawcy
      if (widget.lots.isNotEmpty) {
        final docId = widget.lots.first.id;
        final snap  = await db.collection(AppConstants.colCrateStates).doc(docId).get();
        if (snap.exists) {
          final d     = snap.data()!;
          final drew  = ((d['drew_remaining'] as num?)?.toInt() ?? 0) + drewDelta;
          final plast = ((d['plast_remaining'] as num?)?.toInt() ?? 0) + plastDelta;
          await db.collection(AppConstants.colCrateStates).doc(docId).update({
            'drew_remaining':  drew.clamp(0, 9999),
            'plast_remaining': plast.clamp(0, 9999),
          });
        }
      }
      // Zapisz akcję korekty
      await db.collection(AppConstants.colCrateActions).add({
        'lot':         'KOREKTA',
        'dostawca':    widget.dostawca,
        'dostawca_kod':'—',
        'nr_dostawy':  '—',
        'data':        date,
        'akcja':       'Korekta',
        'drew_delta':  drewDelta,
        'plast_delta': plastDelta,
        'notatka':     _noteCtrl.text.trim(),
        'createdAt':   FieldValue.serverTimestamp(),
      });

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Korekta skrzyń\n${widget.dostawca}',
          style: const TextStyle(fontSize: 15)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Wpisz zmianę (np. +5 lub -3).',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextFormField(
              controller: _drewCtrl,
              decoration: const InputDecoration(labelText: 'Drewniane (Δ)', hintText: 'np. -3'),
              keyboardType: const TextInputType.numberWithOptions(signed: true),
            )),
            const SizedBox(width: 12),
            Expanded(child: TextFormField(
              controller: _plastCtrl,
              decoration: const InputDecoration(labelText: 'Plastikowe (Δ)', hintText: 'np. +10'),
              keyboardType: const TextInputType.numberWithOptions(signed: true),
            )),
          ]),
          const SizedBox(height: 10),
          TextFormField(
            controller: _noteCtrl,
            decoration: const InputDecoration(labelText: 'Notatka (opcjonalna)'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Anuluj')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Zapisz korektę'),
        ),
      ],
    );
  }
}
