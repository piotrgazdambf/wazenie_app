import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
import '../../core/constants.dart';
import '../../shared/widgets/offline_banner.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class CrateState {
  final String id;          // = docId (lot z / zastąpione _)
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
    required this.id,
    required this.lot,
    required this.odmiana,
    required this.owoc,
    required this.dostawca,
    required this.przeznaczenie,
    required this.nrDostawy,
    required this.data,
    required this.drewTotal,
    required this.plastTotal,
    required this.drewRemaining,
    required this.plastRemaining,
    required this.drewWagaJedn,
    required this.plastWagaJedn,
    required this.kgTotal,
    required this.kgRemaining,
    required this.active,
    required this.isKwg,
  });

  factory CrateState.fromFirestore(String id, Map<String, dynamic> d) => CrateState(
    id:             id,
    lot:            d['lot'] as String? ?? '',
    odmiana:        d['odmiana'] as String? ?? '',
    owoc:           d['owoc'] as String? ?? '',
    dostawca:       d['dostawca'] as String? ?? '',
    przeznaczenie:  d['przeznaczenie'] as String? ?? '',
    nrDostawy:      d['nr_dostawy'] as String? ?? '',
    data:           d['data'] as String? ?? '',
    drewTotal:      (d['drew_total'] as num?)?.toInt() ?? 0,
    plastTotal:     (d['plast_total'] as num?)?.toInt() ?? 0,
    drewRemaining:  (d['drew_remaining'] as num?)?.toInt() ?? 0,
    plastRemaining: (d['plast_remaining'] as num?)?.toInt() ?? 0,
    drewWagaJedn:   (d['drew_waga_jedn'] as num?)?.toDouble() ?? 20.0,
    plastWagaJedn:  (d['plast_waga_jedn'] as num?)?.toDouble() ?? 10.0,
    kgTotal:        (d['kg_total'] as num?)?.toDouble() ?? 0,
    kgRemaining:    (d['kg_remaining'] as num?)?.toDouble() ?? 0,
    active:         d['active'] as bool? ?? true,
    isKwg:          d['is_kwg'] as bool? ?? false,
  );

  int get totalCratesRemaining => drewRemaining + plastRemaining;

  /// Kg na skrzynię — prosty średni przelicznik (model użytkownika)
  double get kgPerCrate {
    if (totalCratesRemaining == 0) return 0;
    return kgRemaining / totalCratesRemaining;
  }

  /// Kg obliczone dla N skrzyń drew + M plast (proporcjonalnie przez tarę)
  double kgForRemoval(int drew, int plast) {
    final totalTaraRemaining =
        drewRemaining * drewWagaJedn + plastRemaining * plastWagaJedn;
    if (totalTaraRemaining <= 0 || kgRemaining <= 0) return 0;
    final taraRemoved = drew * drewWagaJedn + plast * plastWagaJedn;
    return (kgRemaining * taraRemoved / totalTaraRemaining).clamp(0, kgRemaining);
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final crateStatesProvider = StreamProvider<List<CrateState>>((ref) {
  return FirebaseFirestore.instance
      .collection(AppConstants.colCrateStates)
      .where('active', isEqualTo: true)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => CrateState.fromFirestore(d.id, d.data()))
          .toList());
});

// ── Screen ────────────────────────────────────────────────────────────────────

class SkrzynieScreen extends ConsumerWidget {
  const SkrzynieScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cratesAsync = ref.watch(crateStatesProvider);

    return OfflineOverflowGuard(
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: const Text('Stany skrzyń'),
          leading: BackButton(onPressed: () => context.go('/home')),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.invalidate(crateStatesProvider),
            ),
          ],
        ),
        body: Column(
          children: [
            const OfflineBanner(),
            Expanded(
              child: cratesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => _ErrorView(message: e.toString()),
                data: (list) {
                  if (list.isEmpty) return const _EmptyView();

                  // Suma łączna kg
                  final totalKg = list.fold(0.0, (s, c) => s + c.kgRemaining);
                  final totalDrew = list.fold(0, (s, c) => s + c.drewRemaining);
                  final totalPlast = list.fold(0, (s, c) => s + c.plastRemaining);

                  return ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      // Summary card
                      _SummaryCard(
                        totalKg: totalKg,
                        totalDrew: totalDrew,
                        totalPlast: totalPlast,
                        count: list.length,
                      ),
                      const SizedBox(height: 12),
                      // Individual crate cards
                      ...list.map((c) => _CrateCard(
                        state: c,
                        onZdejmij: () => _showZdejmijDialog(context, c),
                      )),
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

  Future<void> _showZdejmijDialog(BuildContext context, CrateState state) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _ZdejmijDialog(state: state),
    );
  }
}

// ── Podsumowanie ──────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final double totalKg;
  final int totalDrew;
  final int totalPlast;
  final int count;
  const _SummaryCard({
    required this.totalKg, required this.totalDrew,
    required this.totalPlast, required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryDark, AppTheme.primaryMid],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.inventory_2_outlined, color: Colors.white70, size: 18),
          const SizedBox(width: 8),
          Text('STANY SKRZYŃ — $count aktywnych LOT-ów',
              style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _SumTile('Łącznie kg', '${totalKg.toStringAsFixed(0)} kg')),
          Expanded(child: _SumTile('Skrz. drew.', '$totalDrew szt.')),
          Expanded(child: _SumTile('Skrz. plast.', '$totalPlast szt.')),
        ]),
      ]),
    );
  }
}

class _SumTile extends StatelessWidget {
  final String label;
  final String value;
  const _SumTile(this.label, this.value);

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
      const SizedBox(height: 2),
      Text(value, style: const TextStyle(
          color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
    ],
  );
}

// ── Karta skrzyni ─────────────────────────────────────────────────────────────

class _CrateCard extends StatelessWidget {
  final CrateState state;
  final VoidCallback onZdejmij;
  const _CrateCard({required this.state, required this.onZdejmij});

  @override
  Widget build(BuildContext context) {
    final kgPer = state.kgPerCrate;
    final pct   = state.kgTotal > 0
        ? (state.kgRemaining / state.kgTotal).clamp(0.0, 1.0)
        : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Nagłówek
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  state.odmiana.isNotEmpty ? state.odmiana : '—',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15,
                      color: AppTheme.primaryDark),
                ),
                Text(
                  '${state.owoc.isNotEmpty ? state.owoc[0].toUpperCase() + state.owoc.substring(1) : ''}'
                  ' • ${state.przeznaczenie}'
                  ' • Dost. ${state.nrDostawy}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ]),
            ),
            if (state.isKwg)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.warningOrange.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.warningOrange.withAlpha(80)),
                ),
                child: const Text('KWG', style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.warningOrange)),
              ),
          ]),
          const SizedBox(height: 10),

          // Progress bar kg
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: AppTheme.borderLight,
              color: pct > 0.5
                  ? AppTheme.accent
                  : pct > 0.2
                      ? AppTheme.warningOrange
                      : AppTheme.errorRed,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),

          // Statystyki
          Row(children: [
            _StatChip(Icons.scale_outlined, '${state.kgRemaining.toStringAsFixed(1)} kg',
                AppTheme.primaryMid),
            const SizedBox(width: 8),
            _StatChip(Icons.aspect_ratio_outlined,
                '${kgPer.toStringAsFixed(1)} kg/skrz.', AppTheme.accent),
            const SizedBox(width: 8),
            _StatChip(Icons.inventory_outlined,
                '${state.drewRemaining}D + ${state.plastRemaining}P',
                AppTheme.textSecondary),
          ]),

          const SizedBox(height: 10),

          // LOT tekst
          Text(state.lot,
              style: const TextStyle(
                  fontSize: 11, color: AppTheme.textSecondary, fontFamily: 'monospace')),

          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // Przycisk
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: state.totalCratesRemaining > 0 ? onZdejmij : null,
              icon: const Icon(Icons.remove_circle_outline, size: 18),
              label: const Text('Zdejmij skrzynie'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.errorRed,
                side: const BorderSide(color: AppTheme.errorRed, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _StatChip(this.icon, this.text, this.color);

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 4),
      Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    ],
  );
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
  void dispose() {
    _drewCtrl.dispose();
    _plastCtrl.dispose();
    super.dispose();
  }

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

    final s     = widget.state;
    final kg    = _kgDoZdjecia;
    final newDr = s.drewRemaining - _drewN;
    final newPl = s.plastRemaining - _plastN;
    final newKg = (s.kgRemaining - kg).clamp(0.0, s.kgTotal);

    try {
      final db  = FirebaseFirestore.instance;
      final now = DateTime.now();

      // Aktualizuj crateState
      await db.collection(AppConstants.colCrateStates).doc(s.id).update({
        'drew_remaining':  newDr,
        'plast_remaining': newPl,
        'kg_remaining':    newKg,
        'active':          (newDr + newPl) > 0 && newKg > 0,
        'updatedAt':       FieldValue.serverTimestamp(),
      });

      // Utwórz wpis MCR — Zejście
      await db.collection(AppConstants.colMcrQueue).add({
        'lot':          s.lot,
        'czas':         '${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}',
        'akcja':        'Zejście cząstkowe',
        'waga_netto':   kg.toStringAsFixed(2),
        'owoc':         s.owoc,
        'odmiana':      s.odmiana,
        'przeznaczenie':s.przeznaczenie,
        'drew_zdj':     _drewN,
        'plast_zdj':    _plastN,
        'status':       'done',
        'createdAt':    FieldValue.serverTimestamp(),
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
    final s   = widget.state;
    final kgP = s.kgPerCrate;

    return AlertDialog(
      title: Text('Zdejmij skrzynie\n${s.odmiana.isNotEmpty ? s.odmiana : s.lot}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Info przelicznik
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.accent.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.accent.withAlpha(60)),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline, size: 16, color: AppTheme.accentDark),
              const SizedBox(width: 8),
              Expanded(child: Text(
                'Przelicznik: ~${kgP.toStringAsFixed(1)} kg/skrzynię\n'
                'Stan: ${s.drewRemaining}D + ${s.plastRemaining}P = ${s.kgRemaining.toStringAsFixed(1)} kg',
                style: const TextStyle(fontSize: 12, color: AppTheme.primaryDark),
              )),
            ]),
          ),
          const SizedBox(height: 16),

          // Pola wejściowe
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: _drewCtrl,
                decoration: InputDecoration(
                  labelText: 'Skrz. drewn. (max ${s.drewRemaining})',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _plastCtrl,
                decoration: InputDecoration(
                  labelText: 'Skrz. plast. (max ${s.plastRemaining})',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
              ),
            ),
          ]),
          const SizedBox(height: 16),

          // Podgląd wyniku
          if (_drewN + _plastN > 0)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _valid
                    ? AppTheme.errorRed.withAlpha(15)
                    : AppTheme.warningOrange.withAlpha(15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _valid
                      ? AppTheme.errorRed.withAlpha(60)
                      : AppTheme.warningOrange.withAlpha(60),
                ),
              ),
              child: Column(children: [
                _ResultRow('Skrzynie do zdjęcia', '${_drewN}D + ${_plastN}P'),
                _ResultRow('Kg do odjęcia', '−${_kgDoZdjecia.toStringAsFixed(2)} kg'),
                if (!_valid)
                  const Text('Przekroczono dostępną liczbę skrzyń!',
                      style: TextStyle(color: AppTheme.errorRed, fontSize: 12)),
              ]),
            ),
        ]),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Anuluj'),
        ),
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

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;
  const _ResultRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      ],
    ),
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
      SizedBox(height: 4),
      Text('Skrzynie pojawiają się po zapisaniu karty KW/KWG',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          textAlign: TextAlign.center),
    ]),
  );
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline, size: 48, color: AppTheme.errorRed),
      const SizedBox(height: 12),
      Text(message, textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.textSecondary)),
    ]),
  );
}
