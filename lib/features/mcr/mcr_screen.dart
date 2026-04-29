import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
import '../../core/auth/pin_auth_service.dart';
import '../../core/constants.dart';
import '../../shared/widgets/offline_banner.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class McrEntry {
  final String id;
  final String lot;
  final String czas;
  final String akcja;
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

  bool get isZejscie =>
      akcja.toLowerCase().contains('zejscie') ||
      akcja.toLowerCase().contains('zejście');
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
  String _filter = 'all';
  final Set<String> _selected = {};
  bool _deleteMode = false;
  bool _deleting = false;

  bool get _selectionMode => _selected.isNotEmpty;

  void _toggleDeleteMode() => setState(() {
        _deleteMode = !_deleteMode;
        _selected.clear();
      });

  void _toggleSelect(String id) =>
      setState(() => _selected.contains(id) ? _selected.remove(id) : _selected.add(id));

  void _selectAll(List<McrEntry> filtered) =>
      setState(() => _selected
        ..clear()
        ..addAll(filtered.map((e) => e.id)));

  void _clearSelection() => setState(() {
        _selected.clear();
        _deleteMode = false;
      });

  Future<void> _deleteSelected() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Usuń zaznaczone'),
        content: Text('Usunąć ${_selected.length} wpisów MCR? Tej operacji nie można cofnąć.'),
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

    setState(() => _deleting = true);
    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      for (final id in _selected) {
        batch.delete(db.collection(AppConstants.colMcrQueue).doc(id));
      }
      await batch.commit();
      if (mounted) setState(() { _selected.clear(); _deleting = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd: $e'), backgroundColor: AppTheme.errorRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mcrAsync = ref.watch(mcrListProvider);
    final isAdmin  = ref.watch(currentSessionProvider)?.user.isAdmin ?? false;

    return OfflineOverflowGuard(
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: _deleteMode && isAdmin
              ? Text(_selectionMode ? 'Zaznaczono: ${_selected.length}' : 'Tryb usuwania')
              : const Text('MCR — Raport Akcji'),
          leading: _deleteMode && isAdmin
              ? IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _clearSelection,
                )
              : BackButton(onPressed: () => context.go('/home')),
          actions: [
            if (isAdmin) ...[
              if (_deleteMode) ...[
                if (_deleting)
                  const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                  )
                else if (_selectionMode)
                  TextButton.icon(
                    icon: const Icon(Icons.delete_outline, color: Colors.white, size: 18),
                    label: Text('Usuń (${_selected.length})',
                        style: const TextStyle(color: Colors.white)),
                    onPressed: _deleteSelected,
                  ),
              ] else
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Tryb usuwania',
                  onPressed: _toggleDeleteMode,
                ),
            ],
          ],
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
                onSelectionChanged: (s) => setState(() {
                  _filter = s.first;
                  _selected.clear();
                }),
                style: ButtonStyle(
                  textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12)),
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

                      // pasek "Zaznacz wszystkie" gdy admin w trybie usuwania
                      if (isAdmin && _deleteMode)
                        Container(
                          color: AppTheme.primaryMid.withAlpha(15),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          child: Row(
                            children: [
                              Text('${_selected.length} z ${filtered.length} zaznaczonych',
                                  style: const TextStyle(fontSize: 12, color: AppTheme.primaryDark)),
                              const Spacer(),
                              TextButton(
                                onPressed: () => _selectAll(filtered),
                                child: const Text('Zaznacz wszystkie', style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                        ),

                      Expanded(
                        child: filtered.isEmpty
                            ? const _EmptyView()
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                                itemCount: filtered.length,
                                itemBuilder: (ctx, i) {
                                  final e = filtered[i];
                                  return _McrCard(
                                    entry: e,
                                    isAdmin: isAdmin && _deleteMode,
                                    isSelected: _selected.contains(e.id),
                                    onToggle: () => _toggleSelect(e.id),
                                  );
                                },
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
                style: const TextStyle(
                    color: AppTheme.warningOrange,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

// ── Karta MCR ─────────────────────────────────────────────────────────────────

class _McrCard extends StatelessWidget {
  final McrEntry entry;
  final bool isAdmin;
  final bool isSelected;
  final VoidCallback onToggle;

  const _McrCard({
    required this.entry,
    required this.isAdmin,
    required this.isSelected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isZejscie   = entry.isZejscie;
    final isZmiana    = entry.akcja.toLowerCase().contains('zmiana');
    final isCzastkowe = entry.akcja.toLowerCase().contains('cząst') ||
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
      color: isSelected ? AppTheme.errorRed.withAlpha(12) : null,
      shape: isSelected
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: AppTheme.errorRed.withAlpha(80), width: 1.5),
            )
          : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isAdmin ? onToggle : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Checkbox (admin) lub ikona (user)
              if (isAdmin)
                Padding(
                  padding: const EdgeInsets.only(right: 10, top: 2),
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (_) => onToggle(),
                    activeColor: AppTheme.errorRed,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                )
              else
                Container(
                  width: 44, height: 44,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: akcjaColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(akcjaIcon, color: akcjaColor, size: 22),
                ),

              if (isAdmin)
                Container(
                  width: 40, height: 40,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: akcjaColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(akcjaIcon, color: akcjaColor, size: 20),
                ),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(akcjaLabel,
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: akcjaColor)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withAlpha(20),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(_statusLabel(entry.status),
                              style: TextStyle(
                                  fontSize: 10,
                                  color: statusColor,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    if (entry.lot.isNotEmpty)
                      Text(entry.lot,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                              fontFamily: 'monospace')),
                    Text(
                      [
                        if (entry.owoc.isNotEmpty)
                          entry.owoc[0].toUpperCase() + entry.owoc.substring(1),
                        if (entry.odmiana.isNotEmpty) entry.odmiana,
                        if (entry.przeznaczenie.isNotEmpty) entry.przeznaczenie,
                      ].join(' • '),
                      style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                    ),
                    if (entry.czas.isNotEmpty)
                      Text(entry.czas,
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.textSecondary)),
                  ],
                ),
              ),

              if (entry.wagaNetto.isNotEmpty)
                Text('${entry.wagaNetto} kg',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: akcjaColor)),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(String s) => switch (s) {
        'pending' => AppTheme.warningOrange,
        'done'    => AppTheme.successGreen,
        'failed'  => AppTheme.errorRed,
        _         => AppTheme.textSecondary,
      };

  String _statusLabel(String s) => switch (s) {
        'pending' => 'Oczekuje',
        'done'    => 'Wysłano',
        'failed'  => 'Błąd',
        _         => s,
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
            Icon(Icons.swap_horiz, size: 64, color: AppTheme.borderLight),
            SizedBox(height: 12),
            Text('Brak wpisów MCR',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
            SizedBox(height: 4),
            Text('Wpisy pojawiają się po przesłaniu dostaw do Stanów',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                textAlign: TextAlign.center),
          ],
        ),
      );
}
