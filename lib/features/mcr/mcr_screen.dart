import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
import '../../core/constants.dart';
import '../../shared/widgets/offline_banner.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class McrEntry {
  final String id;
  final String lot;
  final String czas;
  final String akcja; // 'Zejscie' | 'Przyjecie'
  final String wagaNetto;
  final String owoc;
  final String odmiana;
  final String przeznaczenie;
  final String status;
  final DateTime? createdAt;

  const McrEntry({
    required this.id,
    required this.lot,
    required this.czas,
    required this.akcja,
    required this.wagaNetto,
    required this.owoc,
    required this.odmiana,
    required this.przeznaczenie,
    required this.status,
    this.createdAt,
  });

  factory McrEntry.fromFirestore(String id, Map<String, dynamic> d) {
    DateTime? parseDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    return McrEntry(
      id: id,
      lot: d['lot'] as String? ?? '',
      czas: d['czas'] as String? ?? '',
      akcja: d['akcja'] as String? ?? '',
      wagaNetto: d['waga_netto'] as String? ?? '',
      owoc: d['owoc'] as String? ?? '',
      odmiana: d['odmiana'] as String? ?? '',
      przeznaczenie: d['przeznaczenie'] as String? ?? '',
      status: d['status'] as String? ?? 'pending',
      createdAt: parseDate(d['createdAt']),
    );
  }

  bool get isZejscie => akcja.toLowerCase().contains('zejscie') || akcja.toLowerCase().contains('zejście');
}

// ── Provider ──────────────────────────────────────────────────────────────────

final mcrListProvider = StreamProvider<List<McrEntry>>((ref) {
  return FirebaseFirestore.instance
      .collection(AppConstants.colMcrQueue)
      .orderBy('createdAt', descending: true)
      .limit(200)
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => McrEntry.fromFirestore(d.id, d.data()))
          .toList());
});

// ── Ekran ─────────────────────────────────────────────────────────────────────

class McrScreen extends ConsumerStatefulWidget {
  const McrScreen({super.key});

  @override
  ConsumerState<McrScreen> createState() => _McrScreenState();
}

class _McrScreenState extends ConsumerState<McrScreen> {
  String _filter = 'all'; // 'all', 'zejscie', 'przyjecie'

  @override
  Widget build(BuildContext context) {
    final mcrAsync = ref.watch(mcrListProvider);

    return OfflineOverflowGuard(
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: const Text('MCR — Raport Akcji'),
          leading: BackButton(onPressed: () => context.go('/home')),
        ),
        body: Column(
          children: [
            const OfflineBanner(),

            // Filtr
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'all', label: Text('Wszystkie')),
                  ButtonSegment(value: 'zejscie',
                      label: Text('Zejścia'), icon: Icon(Icons.arrow_upward, size: 14)),
                  ButtonSegment(value: 'przyjecie',
                      label: Text('Przyjęcia'), icon: Icon(Icons.arrow_downward, size: 14)),
                ],
                selected: {_filter},
                onSelectionChanged: (s) => setState(() => _filter = s.first),
                style: ButtonStyle(
                  textStyle: WidgetStateProperty.all(
                    const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),

            Expanded(
              child: mcrAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => _ErrorView(message: e.toString()),
                data: (list) {
                  final filtered = list.where((e) {
                    if (_filter == 'zejscie') return e.isZejscie;
                    if (_filter == 'przyjecie') return !e.isZejscie;
                    return true;
                  }).toList();

                  final pending = list.where((e) => e.status == 'pending').length;

                  return Column(
                    children: [
                      if (pending > 0) _PendingBanner(count: pending),
                      Expanded(
                        child: filtered.isEmpty
                            ? const _EmptyView()
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                                itemCount: filtered.length,
                                itemBuilder: (ctx, i) => _McrCard(entry: filtered[i]),
                              ),
                      ),
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

// ── Banner ────────────────────────────────────────────────────────────────────

class _PendingBanner extends StatelessWidget {
  final int count;
  const _PendingBanner({required this.count});

  @override
  Widget build(BuildContext context) => Container(
        color: AppTheme.warningOrange.withAlpha(20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.pending_outlined, color: AppTheme.warningOrange, size: 16),
            const SizedBox(width: 8),
            Text('$count oczekujących do synchronizacji',
                style: const TextStyle(color: AppTheme.warningOrange, fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

// ── Karta MCR ─────────────────────────────────────────────────────────────────

class _McrCard extends StatelessWidget {
  final McrEntry entry;
  const _McrCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isZejscie    = entry.isZejscie;
    final isZmiana     = entry.akcja.toLowerCase().contains('zmiana');
    final isCzastkowe  = entry.akcja.toLowerCase().contains('cząst') ||
                         entry.akcja.toLowerCase().contains('czast');
    final akcjaColor = isZmiana
        ? const Color(0xFF0891B2)
        : isZejscie
            ? const Color(0xFF7C3AED)
            : AppTheme.successGreen;
    final akcjaLabel = isZmiana
        ? 'Zmiana przezn.'
        : isCzastkowe
            ? 'Zejście cząstkowe'
            : isZejscie
                ? 'Zejście'
                : 'Przyjęcie';
    final akcjaIcon = isZmiana
        ? Icons.swap_horiz
        : isZejscie
            ? Icons.arrow_upward
            : Icons.arrow_downward;
    final statusColor = _statusColor(entry.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: akcjaColor.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(akcjaIcon, color: akcjaColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(akcjaLabel,
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14,
                              color: akcjaColor)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(_statusLabel(entry.status),
                            style: TextStyle(fontSize: 10, color: statusColor,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  // LOT
                  if (entry.lot.isNotEmpty)
                    Text(entry.lot,
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary,
                            fontFamily: 'monospace')),
                  // Owoc + odmiana
                  Text(
                    [
                      if (entry.owoc.isNotEmpty)
                        entry.owoc[0].toUpperCase() + entry.owoc.substring(1),
                      if (entry.odmiana.isNotEmpty) entry.odmiana,
                      if (entry.przeznaczenie.isNotEmpty) entry.przeznaczenie,
                    ].join(' • '),
                    style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                  ),
                  // Czas
                  if (entry.czas.isNotEmpty)
                    Text(entry.czas,
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            // Waga
            if (entry.wagaNetto.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${entry.wagaNetto} kg',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700, color: akcjaColor)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String s) => switch (s) {
    'pending' => AppTheme.warningOrange,
    'done' => AppTheme.successGreen,
    'failed' => AppTheme.errorRed,
    _ => AppTheme.textSecondary,
  };

  String _statusLabel(String s) => switch (s) {
    'pending' => 'Oczekuje',
    'done' => 'Wysłano',
    'failed' => 'Błąd',
    _ => s,
  };
}

// ── Helpers ───────────────────────────────────────────────────────────────────

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
            Text(message, textAlign: TextAlign.center,
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
            Icon(Icons.swap_horiz, size: 64, color: AppTheme.borderLight),
            SizedBox(height: 12),
            Text('Brak wpisów MCR', style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
            SizedBox(height: 4),
            Text('Wpisy pojawiają się po przesłaniu dostaw do Stanów',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                textAlign: TextAlign.center),
          ],
        ),
      );
}
