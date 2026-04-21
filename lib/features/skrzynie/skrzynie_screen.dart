import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
import '../../core/constants.dart';
import '../../shared/widgets/offline_banner.dart';

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
      .collection(AppConstants.colMcrQueue)
      .where('akcja', isEqualTo: 'Zejście cząstkowe')
      .orderBy('createdAt', descending: true)
      .limit(100)
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
            bottom: const TabBar(tabs: [
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
                const Icon(Icons.inventory_2_outlined, color: Colors.white70, size: 16),
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
              itemCount: lots.length,
              itemBuilder: (_, i) {
                final c = lots[i];
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
                          label: const Text('Zdejmij skrzynie'),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(crateActionsProvider);
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

            return Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.errorRed.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.remove_circle_outline, size: 18, color: AppTheme.errorRed),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(a.dostawca.isNotEmpty ? a.dostawca : '—',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    Text(
                      '${a.nrDostawy.isNotEmpty ? "Dost. ${a.nrDostawy}  •  " : ""}'
                      '${a.owoc.isNotEmpty ? "${a.owoc}${a.odmiana.isNotEmpty ? " • ${a.odmiana}" : ""}  •  " : ""}'
                      '${a.przeznaczenie}',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                    Text(dateStr, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    if (a.drewZdj > 0)
                      Text('−${a.drewZdj}D', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primaryMid)),
                    if (a.plastZdj > 0)
                      Text('−${a.plastZdj}P', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.accent)),
                  ]),
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

      await db.collection(AppConstants.colMcrQueue).add({
        'lot': s.lot, 'dostawca': s.dostawca,
        'czas': '${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}',
        'akcja': 'Zejście cząstkowe',
        'waga_netto': kg.toStringAsFixed(2),
        'owoc': s.owoc, 'odmiana': s.odmiana,
        'przeznaczenie': s.przeznaczenie,
        'nr_dostawy': s.nrDostawy, 'data': s.data,
        'drew_zdj': _drewN, 'plast_zdj': _plastN,
        'status': 'done', 'createdAt': FieldValue.serverTimestamp(),
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
      title: Text('Zdejmij skrzynie\n${s.odmiana.isNotEmpty ? s.odmiana : s.lot}',
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
          const SizedBox(height: 16),
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
              : const Text('Zdejmij'),
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
      Icon(Icons.inventory_2_outlined, size: 64, color: AppTheme.borderLight),
      SizedBox(height: 12),
      Text('Brak aktywnych skrzyń', style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
    ]),
  );
}
