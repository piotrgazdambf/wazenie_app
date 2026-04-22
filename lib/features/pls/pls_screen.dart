import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
import '../../core/constants.dart';
import '../../core/offline/hive_buffer.dart';
import '../../core/offline/offline_entry.dart';
import '../../core/auth/pin_auth_service.dart';
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
    final isAdmin     = ref.watch(currentSessionProvider)?.user.isAdmin ?? false;
    final statusColor = _statusColor(entry.status);
    final statusLabel = _statusLabel(entry.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showDetail(context, isAdmin: isAdmin),
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

            // Akcje statusowe
            const SizedBox(height: 8),
            Row(
              children: [
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

  void _showDetail(BuildContext context, {required bool isAdmin}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PlsDetailSheet(entry: entry, isAdmin: isAdmin),
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

class _PlsDetailSheet extends StatefulWidget {
  final PlsEntry entry;
  final bool isAdmin;
  const _PlsDetailSheet({required this.entry, required this.isAdmin});

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
  late String _status;

  @override
  void initState() {
    super.initState();
    final e      = widget.entry;
    _brixCtrl    = TextEditingController(text: e.brix);
    _odpadCtrl   = TextEditingController(text: e.odpad);
    _twardCtrl   = TextEditingController(text: e.twardosc);
    _kaliberCtrl = TextEditingController(text: e.kaliber);
    _zwrotCtrl   = TextEditingController(text: e.zwrotPct);
    _wagaNettoCtrl = TextEditingController(text: e.wagaNetto);
    _status      = e.status;
  }

  @override
  void dispose() {
    for (final c in [_brixCtrl, _odpadCtrl, _twardCtrl, _kaliberCtrl, _zwrotCtrl, _wagaNettoCtrl]) c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection(AppConstants.colDeliveries)
          .doc(widget.entry.id)
          .update({
        'brix':       _brixCtrl.text.trim(),
        'odpad':      _odpadCtrl.text.trim(),
        'twardosc':   _twardCtrl.text.trim(),
        'kaliber':    _kaliberCtrl.text.trim(),
        'zwrot_pct':  _zwrotCtrl.text.trim(),
        'waga_netto': _wagaNettoCtrl.text.trim(),
        'status':     _status,
      });
      if (mounted) {
        setState(() { _editing = false; _saving = false; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Zapisano zmiany'), backgroundColor: AppTheme.successGreen));
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
                Text('${e.data}  •  Dostawa ${e.nrDostawy}',
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
              _DetailRow('Owoc', e.owoc),
              if (e.odmiana.isNotEmpty) _DetailRow('Odmiana', e.odmiana),
              _DetailRow('Przeznaczenie', e.przeznaczenie),
            ]),
            const SizedBox(height: 12),
            _DetailSection('WAGI', [
              if (e.wagaBrutto.isNotEmpty) _DetailRow('Brutto', '${e.wagaBrutto} kg'),
              _editing
                  ? _PlsEditRow('Netto', _wagaNettoCtrl, suffix: 'kg')
                  : _DetailRow('Netto', '${e.wagaNetto} kg', bold: true),
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
