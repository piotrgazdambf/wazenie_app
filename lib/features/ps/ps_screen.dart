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

class _PsScreenState extends ConsumerState<PsScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final psAsync = ref.watch(psListProvider);

    return OfflineOverflowGuard(
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: const Text('PS — Parametry Surowca'),
          leading: BackButton(onPressed: () => context.go('/home')),
        ),
        body: Column(
          children: [
            const OfflineBanner(),

            // Pasek wyszukiwania
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
                  final filtered = list.where((e) {
                    final q = _search;
                    if (q.isEmpty) return true;
                    return e.lot.toLowerCase().contains(q) ||
                        e.odmiana.toLowerCase().contains(q) ||
                        e.dostawca.toLowerCase().contains(q) ||
                        e.nrDostawy.contains(q) ||
                        e.owoc.toLowerCase().contains(q);
                  }).toList();

                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text('Brak wyników',
                          style: TextStyle(color: AppTheme.textSecondary)),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) => _PsCard(entry: filtered[i]),
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
