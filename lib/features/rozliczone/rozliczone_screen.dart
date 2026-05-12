import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../app/theme.dart';
import '../../core/auth/pin_auth_service.dart';
import '../../shared/widgets/offline_banner.dart';
import '../pls/pls_screen.dart';

// ── Stałe ─────────────────────────────────────────────────────────────────────

const _kColRozliczone = 'rozliczone';
const _kNaCo = ['Obieranie', 'Sok', 'Gruszka', 'Rylex', 'Grójecka', 'Odpad', 'Burak'];

// ── Model ─────────────────────────────────────────────────────────────────────

class RozliczoneEntry {
  final String id;
  final String naCo;
  final String data;
  final String lot;
  final String odmiana;
  final double kg;
  final int skrzyny;
  final DateTime? createdAt;
  final String createdByName;

  const RozliczoneEntry({
    required this.id,
    required this.naCo,
    required this.data,
    required this.lot,
    required this.odmiana,
    required this.kg,
    required this.skrzyny,
    this.createdAt,
    required this.createdByName,
  });

  factory RozliczoneEntry.fromFirestore(String id, Map<String, dynamic> d) =>
      RozliczoneEntry(
        id:            id,
        naCo:          d['na_co']           as String? ?? '',
        data:          d['data']            as String? ?? '',
        lot:           d['lot']             as String? ?? '',
        odmiana:       d['odmiana']         as String? ?? '',
        kg:            (d['kg']      as num?)?.toDouble() ?? 0,
        skrzyny:       (d['skrzyny'] as num?)?.toInt()    ?? 0,
        createdAt:     (d['created_at'] as Timestamp?)?.toDate(),
        createdByName: d['created_by_name'] as String? ?? '',
      );
}

// ── Provider ──────────────────────────────────────────────────────────────────

final rozliczoneListProvider = StreamProvider<List<RozliczoneEntry>>((ref) {
  return FirebaseFirestore.instance
      .collection(_kColRozliczone)
      .orderBy('created_at', descending: true)
      .snapshots()
      .map((s) => s.docs
          .map((d) => RozliczoneEntry.fromFirestore(d.id, d.data()))
          .toList());
});

// ── Screen ────────────────────────────────────────────────────────────────────

class RozliczoneScreen extends ConsumerStatefulWidget {
  const RozliczoneScreen({super.key});

  @override
  ConsumerState<RozliczoneScreen> createState() => _RozliczoneScreenState();
}

class _RozliczoneScreenState extends ConsumerState<RozliczoneScreen>
    with SingleTickerProviderStateMixin {
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

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(currentSessionProvider);
    final isAdmin = session?.user?.isAdmin ?? false;

    return OfflineOverflowGuard(
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: const Text('Rozliczone'),
          bottom: TabBar(
            controller: _tabCtrl,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: AppTheme.accent,
            tabs: const [
              Tab(text: 'Wpisy'),
              Tab(text: 'Dostawy'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showAddDialog(context),
          icon: const Icon(Icons.add),
          label: const Text('Dodaj wpis'),
          backgroundColor: AppTheme.accent,
          foregroundColor: Colors.white,
        ),
        body: TabBarView(
          controller: _tabCtrl,
          children: [
            _WpisyTab(isAdmin: isAdmin),
            const _DostawyTab(),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddDialog(BuildContext context) async {
    final pls = ref.read(plsListProvider).value ?? [];
    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (_) => _AddDialog(plsEntries: pls, ref: ref),
    );
  }
}

// ── Wpisy tab ─────────────────────────────────────────────────────────────────

class _WpisyTab extends ConsumerWidget {
  final bool isAdmin;
  const _WpisyTab({required this.isAdmin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(rozliczoneListProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Błąd: $e')),
      data: (entries) {
        if (entries.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.receipt_long_outlined, size: 64, color: AppTheme.textSecondary),
                SizedBox(height: 12),
                Text('Brak wpisów', style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
          itemCount: entries.length,
          itemBuilder: (_, i) => _EntryTile(entry: entries[i], isAdmin: isAdmin),
        );
      },
    );
  }
}

class _EntryTile extends StatelessWidget {
  final RozliczoneEntry entry;
  final bool isAdmin;
  const _EntryTile({required this.entry, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'pl_PL');
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                entry.data,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F766E)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.naCo,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                  const SizedBox(height: 2),
                  Text(
                    entry.lot + (entry.odmiana.isNotEmpty ? ' · ${entry.odmiana}' : ''),
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${fmt.format(entry.kg)} kg',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                if (entry.skrzyny > 0)
                  Text('${entry.skrzyny} skrz.',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
            if (isAdmin) ...[
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppTheme.errorRed, size: 20),
                onPressed: () => _delete(context, entry.id),
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context, String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Usuń wpis'),
        content: const Text('Czy na pewno chcesz usunąć ten wpis?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Anuluj')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await FirebaseFirestore.instance.collection(_kColRozliczone).doc(id).delete();
    }
  }
}

// ── Dostawy tab ───────────────────────────────────────────────────────────────

class _DostawyTab extends ConsumerWidget {
  const _DostawyTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rozlAsync = ref.watch(rozliczoneListProvider);
    final plsAsync  = ref.watch(plsListProvider);

    if (rozlAsync.isLoading || plsAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final rozl = rozlAsync.value ?? [];
    final pls  = plsAsync.value  ?? [];

    // Grupuj rozliczone po LOT
    final Map<String, List<RozliczoneEntry>> byLot = {};
    for (final e in rozl) {
      if (e.lot.isEmpty) continue;
      byLot.putIfAbsent(e.lot, () => []).add(e);
    }

    // Zlicz wagę netto z PLS per LOT
    final Map<String, _PlsInfo> plsInfo = {};
    for (final p in pls) {
      if (p.lot.isEmpty) continue;
      final kg = double.tryParse(
              p.wagaNetto.replaceAll(',', '.').replaceAll(RegExp(r'[^0-9.]'), '')) ??
          0;
      final info = plsInfo.putIfAbsent(p.lot, () => _PlsInfo());
      info.wagaNettoSum += kg;
      if (p.odmiana.isNotEmpty && !info.odmiany.contains(p.odmiana)) {
        info.odmiany.add(p.odmiana);
      }
    }

    if (byLot.isEmpty) {
      return const Center(
          child: Text('Brak danych', style: TextStyle(color: AppTheme.textSecondary)));
    }

    // Sortuj LOT-y po dacie ostatniego wpisu (najnowszy na górze)
    final lots = byLot.keys.toList()
      ..sort((a, b) {
        final aLast = byLot[a]!
            .map((e) => e.createdAt ?? DateTime(2000))
            .reduce((x, y) => x.isAfter(y) ? x : y);
        final bLast = byLot[b]!
            .map((e) => e.createdAt ?? DateTime(2000))
            .reduce((x, y) => x.isAfter(y) ? x : y);
        return bLast.compareTo(aLast);
      });

    final fmt = NumberFormat('#,##0', 'pl_PL');

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: lots.length,
      itemBuilder: (_, i) {
        final lot      = lots[i];
        final entries  = byLot[lot]!;
        final info     = plsInfo[lot];
        final sumRozl  = entries.fold(0.0, (s, e) => s + e.kg);
        final wagaN    = info?.wagaNettoSum ?? 0;
        final pozostalo = wagaN > 0 ? wagaN - sumRozl : null;

        return _DostawaCard(
          lot: lot,
          entries: entries,
          odmiany: info?.odmiany ?? [],
          wagaNetto: wagaN,
          sumRozliczone: sumRozl,
          pozostalo: pozostalo,
          fmt: fmt,
        );
      },
    );
  }
}

class _PlsInfo {
  double wagaNettoSum = 0;
  final List<String> odmiany = [];
}

class _DostawaCard extends StatefulWidget {
  final String lot;
  final List<RozliczoneEntry> entries;
  final List<String> odmiany;
  final double wagaNetto;
  final double sumRozliczone;
  final double? pozostalo;
  final NumberFormat fmt;

  const _DostawaCard({
    required this.lot,
    required this.entries,
    required this.odmiany,
    required this.wagaNetto,
    required this.sumRozliczone,
    required this.pozostalo,
    required this.fmt,
  });

  @override
  State<_DostawaCard> createState() => _DostawaCardState();
}

class _DostawaCardState extends State<_DostawaCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final pozostalo = widget.pozostalo;
    final poColor = pozostalo == null
        ? AppTheme.textSecondary
        : pozostalo > 0
            ? AppTheme.successGreen
            : AppTheme.errorRed;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.lot,
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary),
                            ),
                            if (widget.odmiany.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                widget.odmiany.join(', '),
                                style: const TextStyle(
                                    fontSize: 12, color: AppTheme.textSecondary),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        color: AppTheme.textSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (widget.wagaNetto > 0) ...[
                        _StatChip(
                          label: 'Waga netto',
                          value: '${widget.fmt.format(widget.wagaNetto)} kg',
                          color: AppTheme.primaryLight,
                        ),
                        const SizedBox(width: 6),
                      ],
                      _StatChip(
                        label: 'Rozliczono',
                        value: '${widget.fmt.format(widget.sumRozliczone)} kg',
                        color: const Color(0xFF0F766E),
                      ),
                      const SizedBox(width: 6),
                      _StatChip(
                        label: 'Pozostało',
                        value: pozostalo != null
                            ? '${widget.fmt.format(pozostalo)} kg'
                            : '—',
                        color: poColor,
                      ),
                    ],
                  ),
                  if (widget.wagaNetto > 0) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (widget.sumRozliczone / widget.wagaNetto).clamp(0.0, 1.0),
                        minHeight: 5,
                        backgroundColor: Colors.grey.shade200,
                        valueColor:
                            const AlwaysStoppedAnimation(Color(0xFF0F766E)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            ...widget.entries.map(
              (e) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                child: Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text(e.data,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                              fontFeatures: [FontFeature.tabularFigures()])),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        e.naCo +
                            (e.odmiana.isNotEmpty ? ' · ${e.odmiana}' : ''),
                        style: const TextStyle(
                            fontSize: 13, color: AppTheme.textPrimary),
                      ),
                    ),
                    Text(
                      '${widget.fmt.format(e.kg)} kg',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary),
                    ),
                    if (e.skrzyny > 0) ...[
                      const SizedBox(width: 6),
                      Text('(${e.skrzyny} skrz.)',
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.textSecondary)),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style:
                    TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(value,
                style:
                    TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

// ── Dialog dodawania wpisu ────────────────────────────────────────────────────

class _AddDialog extends StatefulWidget {
  final List<PlsEntry> plsEntries;
  final WidgetRef ref;
  const _AddDialog({required this.plsEntries, required this.ref});

  @override
  State<_AddDialog> createState() => _AddDialogState();
}

class _AddDialogState extends State<_AddDialog> {
  final _formKey = GlobalKey<FormState>();
  final _naCoCtrl    = TextEditingController();
  final _kgCtrl      = TextEditingController();
  final _skrzynyCtrl = TextEditingController();
  final _odmianaCtrl = TextEditingController();
  String _lot = '';
  DateTime _data = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _naCoCtrl.dispose();
    _kgCtrl.dispose();
    _skrzynyCtrl.dispose();
    _odmianaCtrl.dispose();
    super.dispose();
  }

  void _onLotSelected(String lot) {
    setState(() => _lot = lot);
    final match =
        widget.plsEntries.where((e) => e.lot == lot).toList();
    if (match.isNotEmpty && _odmianaCtrl.text.isEmpty) {
      setState(() => _odmianaCtrl.text = match.first.odmiana);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('pl'),
    );
    if (picked != null) setState(() => _data = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_lot.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Podaj LOT / nr dostawy')));
      return;
    }
    setState(() => _saving = true);
    final session = widget.ref.read(currentSessionProvider);
    final kg = double.tryParse(_kgCtrl.text.replaceAll(',', '.')) ?? 0;
    final skrzyny = int.tryParse(_skrzynyCtrl.text) ?? 0;

    await FirebaseFirestore.instance.collection(_kColRozliczone).add({
      'na_co':           _naCoCtrl.text.trim(),
      'data':            DateFormat('dd.MM.yyyy').format(_data),
      'lot':             _lot.trim(),
      'odmiana':         _odmianaCtrl.text.trim(),
      'kg':              kg,
      'skrzyny':         skrzyny,
      'created_at':      FieldValue.serverTimestamp(),
      'created_by_name': session?.user?.name ?? '',
    });

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final lots = widget.plsEntries
        .map((e) => e.lot)
        .where((l) => l.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final dateFmt = DateFormat('dd.MM.yyyy');

    return AlertDialog(
      title: const Text('Dodaj wpis rozliczenia'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Na co
                const Text('Na co',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _kNaCo
                      .map((s) => ActionChip(
                            label: Text(s, style: const TextStyle(fontSize: 12)),
                            onPressed: () =>
                                setState(() => _naCoCtrl.text = s),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _naCoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Na co (np. obieranie, sok)',
                    isDense: true,
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Wymagane' : null,
                ),
                const SizedBox(height: 14),

                // LOT autocomplete
                Autocomplete<String>(
                  optionsBuilder: (text) {
                    if (text.text.isEmpty) return lots.take(20);
                    return lots
                        .where((l) => l
                            .toLowerCase()
                            .contains(text.text.toLowerCase()))
                        .take(20);
                  },
                  onSelected: _onLotSelected,
                  fieldViewBuilder: (ctx, ctrl, fn, onSubmit) {
                    return TextFormField(
                      controller: ctrl,
                      focusNode: fn,
                      onChanged: (v) => _lot = v,
                      decoration: const InputDecoration(
                        labelText: 'LOT / Nr dostawy',
                        isDense: true,
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Wymagane' : null,
                    );
                  },
                ),
                const SizedBox(height: 14),

                // Data
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(10),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Data',
                      isDense: true,
                      suffixIcon: Icon(Icons.calendar_today, size: 18),
                    ),
                    child: Text(dateFmt.format(_data)),
                  ),
                ),
                const SizedBox(height: 14),

                // Kg
                TextFormField(
                  controller: _kgCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Kg',
                    isDense: true,
                    suffixText: 'kg',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Wymagane';
                    if ((double.tryParse(v.replaceAll(',', '.')) ?? 0) <= 0) {
                      return 'Podaj wartość > 0';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Skrzyny opcjonalne
                TextFormField(
                  controller: _skrzynyCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Skrzynie (opcjonalnie)',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 14),

                // Odmiana (auto-uzupełniana)
                TextFormField(
                  controller: _odmianaCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Odmiana (opcjonalnie)',
                    isDense: true,
                    helperText: 'Auto-uzupełniane po wybraniu LOT',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Anuluj'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Zapisz'),
        ),
      ],
    );
  }
}
