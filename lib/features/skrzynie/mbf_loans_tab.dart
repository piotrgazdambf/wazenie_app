import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme.dart';
import '../../core/constants.dart';
import '../../core/auth/pin_auth_service.dart';

// ── Wypożyczenia skrzyń MBF dostawcom (saldo) ─────────────────────────────────
//
// Osobny ledger od pustych skrzyń (crateStates). Każdy dokument crate_loans to
// jedna operacja: wydanie skrzyń MBF dostawcy (saldo w dół) lub zwrot (w górę).
//
//   saldo = suma delta;  wydanie => delta -ilosc,  zwrot => delta +ilosc
//   saldo ujemne = dostawca ma nam tyle skrzyń do oddania.

const List<String> kMbfTypy = ['metal', 'drewno', 'plastik'];
const List<String> kMbfLokalizacje = ['Czaplin', 'Grójecka'];

String mbfTypLabel(String t) {
  switch (t) {
    case 'metal':   return 'Metalowe';
    case 'drewno':  return 'Drewniane';
    case 'plastik': return 'Plastikowe';
    default:        return t;
  }
}

// ── Model operacji ────────────────────────────────────────────────────────────

class CrateLoan {
  final String id;
  final String dostawcaId;
  final String dostawcaNazwa;
  final String typ;          // metal | drewno | plastik
  final String kierunek;     // wydanie | zwrot
  final int    ilosc;        // zawsze dodatnia
  final int    delta;        // wydanie: -ilosc, zwrot: +ilosc
  final String lokalizacja;  // Czaplin | Grójecka
  final String userName;
  final String notatka;
  final DateTime? createdAt;

  const CrateLoan({
    required this.id, required this.dostawcaId, required this.dostawcaNazwa,
    required this.typ, required this.kierunek, required this.ilosc,
    required this.delta, required this.lokalizacja, required this.userName,
    required this.notatka, this.createdAt,
  });

  factory CrateLoan.fromFirestore(String id, Map<String, dynamic> d) => CrateLoan(
    id: id,
    dostawcaId:    d['dostawca_id']    as String? ?? '',
    dostawcaNazwa: d['dostawca_nazwa'] as String? ?? '',
    typ:           d['typ']            as String? ?? '',
    kierunek:      d['kierunek']       as String? ?? 'wydanie',
    ilosc:         (d['ilosc'] as num?)?.toInt() ?? 0,
    delta:         (d['delta'] as num?)?.toInt() ?? 0,
    lokalizacja:   d['lokalizacja']    as String? ?? '',
    userName:      d['user_name']      as String? ?? '',
    notatka:       d['notatka']        as String? ?? '',
    createdAt:     (d['createdAt'] as Timestamp?)?.toDate(),
  );
}

final crateLoansProvider = StreamProvider<List<CrateLoan>>((ref) =>
  FirebaseFirestore.instance
      .collection(AppConstants.colCrateLoans)
      .orderBy('createdAt', descending: true)
      .limit(500)
      .snapshots()
      .map((s) => s.docs.map((d) => CrateLoan.fromFirestore(d.id, d.data())).toList()));

// Saldo dostawcy per typ (z listy operacji)
class SaldoDostawcy {
  final String nazwa;
  final Map<String, int> perTyp; // typ -> saldo (suma delta)
  const SaldoDostawcy(this.nazwa, this.perTyp);

  int get total => perTyp.values.fold(0, (s, v) => s + v);
  int saldo(String typ) => perTyp[typ] ?? 0;
  bool get maDoOddania => perTyp.values.any((v) => v < 0);
}

Map<String, SaldoDostawcy> agregujSaldo(List<CrateLoan> ops) {
  final map = <String, Map<String, int>>{};
  for (final o in ops) {
    final key = o.dostawcaNazwa.trim().isEmpty ? '(nieznany)' : o.dostawcaNazwa.trim();
    map.putIfAbsent(key, () => {});
    map[key]![o.typ] = (map[key]![o.typ] ?? 0) + o.delta;
  }
  return { for (final e in map.entries) e.key: SaldoDostawcy(e.key, e.value) };
}

// ── TAB ───────────────────────────────────────────────────────────────────────

class MbfLoansTab extends ConsumerWidget {
  const MbfLoansTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(crateLoansProvider);
    final userName = ref.watch(currentSessionProvider)?.user.name ?? '';

    return Column(children: [
      // Przycisk nowej operacji
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => NowaOperacjaMbfDialog(userName: userName),
            ),
            icon: const Icon(Icons.swap_horiz, size: 18),
            label: const Text('Nowa operacja (wydanie / zwrot)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryMid,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ),
      Expanded(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Błąd: $e')),
          data: (ops) {
            final saldoMap = agregujSaldo(ops);
            // tylko dostawcy z niezerowym saldem, najbardziej zadłużeni u góry
            final lista = saldoMap.values.where((s) => s.total != 0).toList()
              ..sort((a, b) => a.total.compareTo(b.total));

            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _SaldoHeader(ops: ops),
                const SizedBox(height: 10),
                if (lista.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: Text(
                      'Brak otwartych sald.\nWszystkie skrzynie MBF rozliczone.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 14))),
                  )
                else
                  ...lista.map((s) => _SaldoCard(
                        saldo: s,
                        ops: ops.where((o) => o.dostawcaNazwa.trim() == s.nazwa).toList(),
                      )),
              ],
            );
          },
        ),
      ),
    ]);
  }
}

class _SaldoHeader extends StatelessWidget {
  final List<CrateLoan> ops;
  const _SaldoHeader({required this.ops});

  @override
  Widget build(BuildContext context) {
    // łączne saldo per typ (po wszystkich dostawcach)
    final perTyp = <String, int>{ for (final t in kMbfTypy) t: 0 };
    for (final o in ops) {
      perTyp[o.typ] = (perTyp[o.typ] ?? 0) + o.delta;
    }
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryDark, AppTheme.primaryMid],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('SKRZYNIE MBF U DOSTAWCÓW',
            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        const Text('Ujemne saldo = ilość do oddania przez dostawcę',
            style: TextStyle(color: Colors.white60, fontSize: 11)),
        const SizedBox(height: 10),
        Row(children: kMbfTypy.map((t) {
          final v = perTyp[t] ?? 0;
          return Expanded(child: Column(children: [
            Text(mbfTypLabel(t),
                style: const TextStyle(color: Colors.white60, fontSize: 10)),
            Text(v == 0 ? '0' : '$v',
                style: TextStyle(
                    color: v < 0 ? const Color(0xFFFCA5A5) : Colors.white,
                    fontSize: 18, fontWeight: FontWeight.w800)),
          ]));
        }).toList()),
      ]),
    );
  }
}

class _SaldoCard extends StatelessWidget {
  final SaldoDostawcy saldo;
  final List<CrateLoan> ops;
  const _SaldoCard({required this.saldo, required this.ops});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _HistoriaSheet(nazwa: saldo.nazwa, ops: ops),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(
              child: Text(saldo.nazwa,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            ),
            ...kMbfTypy.map((t) {
              final v = saldo.saldo(t);
              return SizedBox(
                width: 58,
                child: Column(children: [
                  Text(mbfTypLabel(t).substring(0, 1),
                      style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
                  Text(v == 0 ? '—' : '$v',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800,
                          color: v < 0 ? AppTheme.errorRed
                              : (v > 0 ? AppTheme.warningOrange : AppTheme.textSecondary))),
                ]),
              );
            }),
            const Icon(Icons.chevron_right, color: AppTheme.textSecondary, size: 20),
          ]),
        ),
      ),
    );
  }
}

// ── Historia operacji dostawcy ────────────────────────────────────────────────

class _HistoriaSheet extends StatelessWidget {
  final String nazwa;
  final List<CrateLoan> ops;
  const _HistoriaSheet({required this.nazwa, required this.ops});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6, maxChildSize: 0.9, minChildSize: 0.3,
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
            child: Row(children: [
              Expanded(child: Text(nazwa,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
            ]),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              controller: ctrl,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              itemCount: ops.length,
              itemBuilder: (_, i) {
                final o = ops[i];
                final wyd = o.kierunek == 'wydanie';
                final col = wyd ? AppTheme.errorRed : AppTheme.successGreen;
                final dt = o.createdAt;
                final dstr = dt != null
                    ? '${dt.day.toString().padLeft(2,'0')}.${dt.month.toString().padLeft(2,'0')}.${dt.year}  ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}'
                    : '';
                return Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(children: [
                      Icon(wyd ? Icons.north_east : Icons.south_west, color: col, size: 18),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${wyd ? "Wydano" : "Zwrot"}: ${o.ilosc} szt. ${mbfTypLabel(o.typ).toLowerCase()}',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: col)),
                        Text('${o.lokalizacja}${o.notatka.isNotEmpty ? "  •  ${o.notatka}" : ""}',
                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                        Row(children: [
                          Text(dstr, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                          if (o.userName.isNotEmpty) ...[
                            const Text('  •  ', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                            Text(o.userName, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                          ],
                        ]),
                      ])),
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

// ── TAB: Historia MBF (pełny log wszystkich operacji) ─────────────────────────

class MbfHistoryTab extends ConsumerStatefulWidget {
  const MbfHistoryTab({super.key});
  @override
  ConsumerState<MbfHistoryTab> createState() => _MbfHistoryTabState();
}

class _MbfHistoryTabState extends ConsumerState<MbfHistoryTab> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Usuń operację'),
        content: const Text('Usunąć tę operację? Saldo dostawcy zostanie przeliczone bez niej.'),
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
    if (ok != true) return;
    await FirebaseFirestore.instance.collection(AppConstants.colCrateLoans).doc(id).delete();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(crateLoansProvider);
    final isAdmin = ref.watch(currentSessionProvider)?.user.isAdmin ?? false;
    final q = _searchCtrl.text.trim().toLowerCase();

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: TextField(
          controller: _searchCtrl,
          decoration: const InputDecoration(
            hintText: 'Szukaj po dostawcy…',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (_) => setState(() {}),
        ),
      ),
      Expanded(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Błąd: $e')),
          data: (ops) {
            final list = q.isEmpty ? ops
                : ops.where((o) => o.dostawcaNazwa.toLowerCase().contains(q)).toList();
            if (list.isEmpty) {
              return const Center(child: Text('Brak operacji MBF',
                  style: TextStyle(color: AppTheme.textSecondary)));
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              itemCount: list.length,
              itemBuilder: (_, i) {
                final o = list[i];
                final wyd = o.kierunek == 'wydanie';
                final col = wyd ? AppTheme.errorRed : AppTheme.successGreen;
                final dt = o.createdAt;
                final dstr = dt != null
                    ? '${dt.day.toString().padLeft(2,'0')}.${dt.month.toString().padLeft(2,'0')}.${dt.year}  ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}'
                    : '';
                return Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                    child: Row(children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(color: col.withAlpha(20), borderRadius: BorderRadius.circular(8)),
                        child: Icon(wyd ? Icons.north_east : Icons.south_west, size: 18, color: col),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text(o.dostawcaNazwa.isNotEmpty ? o.dostawcaNazwa : '—',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: col.withAlpha(20), borderRadius: BorderRadius.circular(6)),
                            child: Text(wyd ? 'Wydanie' : 'Zwrot',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: col)),
                          ),
                        ]),
                        const SizedBox(height: 2),
                        Text('${o.ilosc} szt. ${mbfTypLabel(o.typ).toLowerCase()}  •  ${o.lokalizacja}',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: col)),
                        if (o.notatka.isNotEmpty)
                          Text(o.notatka, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                        Row(children: [
                          Text(dstr, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                          if (o.userName.isNotEmpty) ...[
                            const Text('  •  ', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                            Text(o.userName, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                          ],
                        ]),
                      ])),
                      if (isAdmin)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.errorRed),
                          onPressed: () => _delete(o.id),
                          tooltip: 'Usuń operację',
                        ),
                    ]),
                  ),
                );
              },
            );
          },
        ),
      ),
    ]);
  }
}

// ── Dialog nowej operacji ─────────────────────────────────────────────────────

class NowaOperacjaMbfDialog extends StatefulWidget {
  final String userName;
  const NowaOperacjaMbfDialog({super.key, required this.userName});

  @override
  State<NowaOperacjaMbfDialog> createState() => _NowaOperacjaMbfDialogState();
}

class _NowaOperacjaMbfDialogState extends State<NowaOperacjaMbfDialog> {
  String? _dostawcaId;
  String  _dostawcaNazwa = '';
  String  _typ = 'plastik';
  String  _kierunek = 'wydanie';
  String  _lokalizacja = 'Czaplin';
  final _iloscCtrl = TextEditingController();
  final _notatkaCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() { _iloscCtrl.dispose(); _notatkaCtrl.dispose(); super.dispose(); }

  int get _ilosc => int.tryParse(_iloscCtrl.text.trim()) ?? 0;
  bool get _valid => _dostawcaId != null && _ilosc > 0;

  Future<void> _pickDostawca() async {
    final wynik = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _DostawcaPickerSheet(),
    );
    if (wynik != null) {
      setState(() {
        _dostawcaId = wynik['id'];
        _dostawcaNazwa = wynik['nazwa'] ?? '';
      });
    }
  }

  Future<void> _zapisz() async {
    if (!_valid) return;
    setState(() => _saving = true);
    final wyd = _kierunek == 'wydanie';
    try {
      await FirebaseFirestore.instance.collection(AppConstants.colCrateLoans).add({
        'dostawca_id':    _dostawcaId,
        'dostawca_nazwa': _dostawcaNazwa,
        'typ':            _typ,
        'kierunek':       _kierunek,
        'ilosc':          _ilosc,
        'delta':          wyd ? -_ilosc : _ilosc,
        'lokalizacja':    _lokalizacja,
        'notatka':        _notatkaCtrl.text.trim(),
        'user_name':      widget.userName,
        'createdAt':      FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd: $e'), backgroundColor: AppTheme.errorRed));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final wyd = _kierunek == 'wydanie';
    return AlertDialog(
      title: const Text('Operacja skrzyń MBF', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Kierunek
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'wydanie', label: Text('Wydanie'), icon: Icon(Icons.north_east, size: 16)),
              ButtonSegment(value: 'zwrot',   label: Text('Zwrot'),   icon: Icon(Icons.south_west, size: 16)),
            ],
            selected: {_kierunek},
            onSelectionChanged: (s) => setState(() => _kierunek = s.first),
          ),
          const SizedBox(height: 14),

          // Dostawca
          const Text('Dostawca', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: _pickDostawca,
            icon: const Icon(Icons.person_search, size: 18),
            label: Text(_dostawcaId == null ? 'Wybierz dostawcę' : _dostawcaNazwa,
                overflow: TextOverflow.ellipsis),
            style: OutlinedButton.styleFrom(
              alignment: Alignment.centerLeft,
              minimumSize: const Size(double.infinity, 44),
            ),
          ),
          const SizedBox(height: 14),

          // Typ skrzyni
          const Text('Rodzaj skrzyni', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, children: kMbfTypy.map((t) => ChoiceChip(
            label: Text(mbfTypLabel(t)),
            selected: _typ == t,
            onSelected: (_) => setState(() => _typ = t),
          )).toList()),
          const SizedBox(height: 14),

          // Lokalizacja
          const Text('Lokalizacja', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, children: kMbfLokalizacje.map((l) => ChoiceChip(
            label: Text(l),
            selected: _lokalizacja == l,
            onSelected: (_) => setState(() => _lokalizacja = l),
          )).toList()),
          const SizedBox(height: 14),

          // Ilość
          TextField(
            controller: _iloscCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Ilość skrzyń', border: OutlineInputBorder()),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _notatkaCtrl,
            decoration: const InputDecoration(labelText: 'Notatka (opcjonalna)', border: OutlineInputBorder()),
          ),

          if (_valid) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (wyd ? AppTheme.errorRed : AppTheme.successGreen).withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                wyd
                    ? '$_dostawcaNazwa weźmie $_ilosc szt. (${mbfTypLabel(_typ).toLowerCase()}). Saldo zmieni się o −$_ilosc.'
                    : '$_dostawcaNazwa oddaje $_ilosc szt. (${mbfTypLabel(_typ).toLowerCase()}). Saldo zmieni się o +$_ilosc.',
                style: const TextStyle(fontSize: 12, color: AppTheme.primaryDark),
              ),
            ),
          ],
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Anuluj')),
        ElevatedButton(
          onPressed: (_valid && !_saving) ? _zapisz : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: wyd ? AppTheme.errorRed : AppTheme.successGreen,
            foregroundColor: Colors.white),
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(wyd ? 'Wydaj' : 'Przyjmij zwrot'),
        ),
      ],
    );
  }
}

// ── Picker dostawcy (z wyszukiwarką) ──────────────────────────────────────────

class _DostawcaPickerSheet extends StatefulWidget {
  const _DostawcaPickerSheet();
  @override
  State<_DostawcaPickerSheet> createState() => _DostawcaPickerSheetState();
}

class _DostawcaPickerSheetState extends State<_DostawcaPickerSheet> {
  final _searchCtrl = TextEditingController();
  List<Map<String, String>> _all = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final snap = await FirebaseFirestore.instance.collection(AppConstants.colSuppliers).get();
      final list = snap.docs.map((d) {
        final data = d.data();
        return {'id': d.id, 'nazwa': (data['nazwa'] as String?) ?? d.id};
      }).toList()
        ..sort((a, b) => a['nazwa']!.compareTo(b['nazwa']!));
      setState(() { _all = list; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _searchCtrl.text.trim().toLowerCase();
    final filtered = q.isEmpty ? _all
        : _all.where((s) => s['nazwa']!.toLowerCase().contains(q)).toList();
    return DraggableScrollableSheet(
      initialChildSize: 0.7, maxChildSize: 0.95, minChildSize: 0.4,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(children: [
          const SizedBox(height: 8),
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: AppTheme.borderLight, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Szukaj dostawcy…',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: ctrl,
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => ListTile(
                      title: Text(filtered[i]['nazwa']!),
                      onTap: () => Navigator.of(context).pop(filtered[i]),
                    ),
                  ),
          ),
        ]),
      ),
    );
  }
}
