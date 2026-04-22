import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
import '../../core/constants.dart';
import '../../core/offline/hive_buffer.dart';
import '../../core/offline/offline_entry.dart';
import 'package:printing/printing.dart';
import '../kw/kw_pdf_generator.dart';
import '../../shared/widgets/offline_banner.dart';

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
  final String owoc;
  final String status;
  final bool isKwg;
  final String brix;
  final String odpad;
  final String twardosc;
  final String kaliber;
  final String zwrotPct;
  final String stanOpak;
  final String stanAuto;

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
    required this.owoc,
    required this.status,
    this.isKwg = false,
    this.brix = '',
    this.odpad = '',
    this.twardosc = '',
    this.kaliber = '',
    this.zwrotPct = '',
    this.stanOpak = '',
    this.stanAuto = '',
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
        wagaBrutto:   (d['waga_brutto'] != null)
            ? d['waga_brutto'].toString()
            : '',
        owoc:         d['owoc'] as String? ?? '',
        status:       d['status'] as String? ?? '',
        isKwg:        d['is_kwg'] as bool? ?? false,
        brix:         d['brix'] as String? ?? '',
        odpad:        d['odpad'] as String? ?? '',
        twardosc:     d['twardosc'] as String? ?? '',
        kaliber:      d['kaliber'] as String? ?? '',
        zwrotPct:     d['zwrot_pct'] as String? ?? '',
        stanOpak:     d['stan_opakowania'] as String? ?? '',
        stanAuto:     d['stan_samochodu'] as String? ?? '',
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

class _PlsScreenState extends ConsumerState<PlsScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final plsAsync = ref.watch(plsListProvider);

    return OfflineOverflowGuard(
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: const Text('Lista dostaw (PLS)'),
          leading: BackButton(onPressed: () => context.go('/home')),
        ),
        body: Column(
          children: [
            const OfflineBanner(),
            // Pasek wyszukiwania
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
                  final filtered = _search.isEmpty
                      ? list
                      : list.where((e) =>
                          e.lot.toLowerCase().contains(_search) ||
                          e.odmiana.toLowerCase().contains(_search) ||
                          e.dostawca.toLowerCase().contains(_search) ||
                          e.owoc.toLowerCase().contains(_search)).toList();

                  if (filtered.isEmpty) return const _EmptyView();

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) => _PlsCard(entry: filtered[i]),
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

// ── Karta dostawy ─────────────────────────────────────────────────────────────

class _PlsCard extends ConsumerWidget {
  final PlsEntry entry;
  const _PlsCard({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = _statusColor(entry.status);
    final statusLabel = _statusLabel(entry.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showDetail(context),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            if (entry.data.isNotEmpty)
              _InfoRow(Icons.calendar_today_outlined, '${entry.data}  •  Dostawa ${entry.nrDostawy}'),

            // Skrzynie + waga
            if (entry.skrzynie.isNotEmpty || entry.wagaNetto.isNotEmpty)
              _InfoRow(
                Icons.inventory_2_outlined,
                [
                  if (entry.skrzynie.isNotEmpty) 'Skrz: ${entry.skrzynie}',
                  if (entry.wagaNetto.isNotEmpty) 'Netto: ${entry.wagaNetto} kg',
                  if (entry.wagaBrutto.isNotEmpty) 'Brutto: ${entry.wagaBrutto} kg',
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
                  if (entry.zwrotPct.isNotEmpty) _QualityChip('ZWROT', '${entry.zwrotPct}%'),
                ],
              ),
            ],

            // Akcje
            const SizedBox(height: 8),
            Row(
              children: [
                // Podgląd + Drukuj
                IconButton(
                  icon: const Icon(Icons.visibility_outlined, size: 20),
                  tooltip: 'Podgląd karty ważenia',
                  color: AppTheme.textSecondary,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _podglad(context),
                ),
                IconButton(
                  icon: const Icon(Icons.print_outlined, size: 20),
                  tooltip: 'Drukuj kartę',
                  color: AppTheme.textSecondary,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _drukuj(context),
                ),
                const Spacer(),
                if (entry.status == 'PRZYJETO')
                  TextButton.icon(
                    onPressed: () => _przeslijDoStanow(context, ref),
                    icon: const Icon(Icons.send_outlined, size: 16),
                    label: const Text('Prześlij do Stanów'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primaryMid,
                      textStyle:
                          const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                if (entry.status == 'PRZESŁANO')
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

  void _showDetail(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PlsDetailSheet(entry: entry),
    );
  }

  Future<void> _podglad(BuildContext context) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection(AppConstants.colDeliveries)
          .doc(entry.id)
          .get();
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
          SnackBar(content: Text('Błąd podglądu: $e'), backgroundColor: AppTheme.errorRed),
        );
      }
    }
  }

  Future<void> _drukuj(BuildContext context) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection(AppConstants.colDeliveries)
          .doc(entry.id)
          .get();
      if (!snap.exists) return;
      final pdfData = KwPdfData.fromFirestoreMap(snap.data()!);
      await Printing.layoutPdf(
        name: 'KW_${snap.id}',
        onLayout: (_) => KwPdfGenerator.generate(pdfData),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd druku: $e'), backgroundColor: AppTheme.errorRed),
        );
      }
    }
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rozliczenie dostawy'),
        content: Text(
            'Czy rozliczyć LOT ${entry.lot}?\n'
            'Zostanie dodane Zejście do MCR i status zmieni się na ROZLICZONO.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Anuluj')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Rozlicz')),
        ],
      ),
    );
    if (confirm != true) return;

    final buffer = ref.read(hiveBufferProvider);
    try {
      await FirebaseFirestore.instance
          .collection(AppConstants.colDeliveries)
          .doc(entry.id)
          .update({'status': 'ROZLICZONO'});

      final now    = DateTime.now();
      final mcrId  = 'mcr_zejscie_${now.millisecondsSinceEpoch}';
      final mcrData = {
        'id':           mcrId,
        'lot':          entry.lot,
        'czas':         '${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}',
        'akcja':        'Zejscie',
        'waga_netto':   entry.wagaNetto,
        'owoc':         entry.owoc,
        'odmiana':      entry.odmiana,
        'przeznaczenie':entry.przeznaczenie,
        'status':       'pending',
        'createdAt':    now.toIso8601String(),
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
          SnackBar(
              content: Text('Błąd: $e'),
              backgroundColor: AppTheme.errorRed),
        );
      }
      return;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rozliczono + Zejście do MCR'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    }
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

class _PlsDetailSheet extends StatelessWidget {
  final PlsEntry entry;
  const _PlsDetailSheet({required this.entry});

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (entry.status.toUpperCase()) {
      'PRZYJETO'   => AppTheme.warningOrange,
      'PRZESŁANO'  => AppTheme.successGreen,
      'ROZLICZONO' => AppTheme.textSecondary,
      _            => AppTheme.textSecondary,
    };
    final statusLabel = switch (entry.status.toUpperCase()) {
      'PRZYJETO'   => 'Przyjęto',
      'PRZESŁANO'  => 'Przesłano',
      'ROZLICZONO' => 'Rozliczono',
      _            => entry.status,
    };

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, ctrl) => ListView(
        controller: ctrl,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppTheme.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Nagłówek — LOT + status
          Row(children: [
            Expanded(
              child: Text(
                entry.lot.isNotEmpty ? entry.lot : entry.id,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800,
                    color: AppTheme.primaryDark, fontFamily: 'monospace'),
              ),
            ),
            if (entry.status.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: statusColor.withAlpha(80)),
                ),
                child: Text(statusLabel,
                    style: TextStyle(color: statusColor, fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
          ]),
          const SizedBox(height: 16),

          // Dane dostawy
          _DetailSection('DANE DOSTAWY', [
            _DetailRow('Nr dostawy', entry.nrDostawy),
            _DetailRow('Data', entry.data),
            _DetailRow('Dostawca', entry.dostawca),
            _DetailRow('Owoc', _cap(entry.owoc)),
            if (entry.odmiana.isNotEmpty) _DetailRow('Odmiana', entry.odmiana),
            _DetailRow('Przeznaczenie', entry.przeznaczenie),
          ]),
          const SizedBox(height: 12),

          // Skrzynie + waga
          _DetailSection('SKRZYNIE & WAGA', [
            if (entry.skrzynie.isNotEmpty) _DetailRow('Skrzynie (drew/plast)', entry.skrzynie),
            if (entry.wagaNetto.isNotEmpty) _DetailRow('Waga netto', '${entry.wagaNetto} kg', bold: true),
          ]),

          // Parametry jakości
          if (entry.brix.isNotEmpty || entry.odpad.isNotEmpty ||
              entry.twardosc.isNotEmpty || entry.kaliber.isNotEmpty) ...[
            const SizedBox(height: 12),
            _DetailSection('PARAMETRY JAKOŚCI', [
              if (entry.brix.isNotEmpty) _DetailRow('BRIX', entry.brix),
              if (entry.odpad.isNotEmpty) _DetailRow('Odpad', '${entry.odpad}%'),
              if (entry.twardosc.isNotEmpty) _DetailRow('Twardość', entry.twardosc),
              if (entry.kaliber.isNotEmpty) _DetailRow('Kaliber', '${entry.kaliber}%'),
            ]),
          ],

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Podgląd karty KW'),
                  onPressed: () async {
                    try {
                      final snap = await FirebaseFirestore.instance
                          .collection(AppConstants.colDeliveries)
                          .doc(entry.id)
                          .get();
                      if (!snap.exists || !context.mounted) return;
                      final pdfData = KwPdfData.fromFirestoreMap(snap.data()!);
                      Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => Scaffold(
                          appBar: AppBar(title: Text('Podgląd KW: ${entry.lot}')),
                          body: PdfPreview(
                            pdfFileName: 'KW_${entry.id}',
                            build: (_) => KwPdfGenerator.generate(pdfData),
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
                              backgroundColor: AppTheme.errorRed),
                        );
                      }
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('Drukuj kartę KW'),
                  onPressed: () async {
                    try {
                      final snap = await FirebaseFirestore.instance
                          .collection(AppConstants.colDeliveries)
                          .doc(entry.id)
                          .get();
                      if (snap.exists && context.mounted) {
                        final pdfData = KwPdfData.fromFirestoreMap(snap.data()!);
                        await Printing.layoutPdf(
                          name: 'KW_${snap.id}',
                          onLayout: (_) => KwPdfGenerator.generate(pdfData),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Błąd druku: $e'),
                              backgroundColor: AppTheme.errorRed),
                        );
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
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
