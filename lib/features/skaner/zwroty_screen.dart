import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/auth/pin_auth_service.dart';
import '../../core/constants.dart';
import 'crate_flow.dart';
import 'skaner_entry_screen.dart';
import 'skaner_search_field.dart';

// ── Ekran cofania przypisanych zejść ("Zwroty") ───────────────────────────────
//
// Dyspozytor może cofnąć zejście przypisane do raportu wstępnego. Cofnięcie:
//   • delivery_assignment -> status='cofniety' (+cancelled_at/by) — wypada z mirrora Matiego
//   • usuwa skaner_zejscia (zejscie_id)
//   • przywraca pobrano_kg w deliveries (surowiec wraca na stan)
//   • wniosek -> status='zwrocony' (trafia na zakładkę "Zwrócone")
// Z "Zwrócone" można przywrócić wniosek do puli (status='oczekujacy') i przypisać na nowo.

final fmtKg = NumberFormat('#,##0', 'pl_PL');
final fmtDt = DateFormat('dd.MM.yyyy  HH:mm');

class ZwrotyScreen extends ConsumerWidget {
  const ZwrotyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: kSkanerBg,
        appBar: AppBar(
          backgroundColor: kSkanerCard,
          foregroundColor: Colors.white,
          leading: BackButton(onPressed: () => context.go('/skaner/dyspozytor')),
          title: const Text('Zwroty zejść',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          bottom: const TabBar(
            labelColor: kSkanerAccent,
            unselectedLabelColor: Colors.white60,
            indicatorColor: kSkanerAccent,
            tabs: [
              Tab(text: 'Przesłane'),
              Tab(text: 'Zwrócone'),
            ],
          ),
        ),
        body: const TabBarView(children: [
          _PrzeslaneTab(),
          _ZwroconeTab(),
        ]),
      ),
    );
  }
}

// ── Zakładka: przesłane (status przypisany) — można cofnąć ────────────────────

class _PrzeslaneTab extends ConsumerStatefulWidget {
  const _PrzeslaneTab();
  @override
  ConsumerState<_PrzeslaneTab> createState() => _PrzeslaneTabState();
}

class _PrzeslaneTabState extends ConsumerState<_PrzeslaneTab> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final userName = ref.watch(currentSessionProvider)?.user.name ?? '';
    final userId   = ref.watch(currentSessionProvider)?.user.id ?? '';
    return Column(children: [
      SkanerSearchField(onChanged: (q) => setState(() => _query = q)),
      Expanded(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection(AppConstants.colDeliveryAssign)
              .where('status', isEqualTo: 'przypisany')
              .snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: kSkanerAccent));
            }
            final docs = List.of(snap.data?.docs ?? [])
              ..sort((a, b) {
                final am = (a.data()['created_at'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                final bm = (b.data()['created_at'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                return bm.compareTo(am);
              });
            final shown = docs.where((d) => matchesQuery(_query, [
              d.data()['lot_dostawy'] as String?,
              d.data()['dostawca'] as String?,
              d.data()['odmiana'] as String?,
              d.data()['owoc'] as String?,
              d.data()['lot_produkcji'] as String?,
              dateTimeSearchBlob((d.data()['created_at'] as Timestamp?)?.toDate()),   // data przypisania
              dateTimeSearchBlob((d.data()['cancelled_at'] as Timestamp?)?.toDate()), // data cofnięcia
            ])).toList();
            if (shown.isEmpty) {
              return _Empty(_query.isEmpty
                  ? 'Brak przesłanych zejść do cofnięcia'
                  : 'Brak wyników wyszukiwania');
            }
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: shown.length,
              itemBuilder: (_, i) => _AssignmentCard(
                // Klucz per dokument — bez niego stan karty (spinner _busy)
                // przykleja się do następnej pozycji gdy wiersz znika z listy.
                key: ValueKey(shown[i].id),
                doc: shown[i],
                akcja: 'cofnij',
                userName: userName,
                userId: userId,
              ),
            );
          },
        ),
      ),
    ]);
  }
}

// ── Zakładka: zwrócone (status cofniety) — można przywrócić do puli ───────────

class _ZwroconeTab extends ConsumerStatefulWidget {
  const _ZwroconeTab();
  @override
  ConsumerState<_ZwroconeTab> createState() => _ZwroconeTabState();
}

class _ZwroconeTabState extends ConsumerState<_ZwroconeTab> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      SkanerSearchField(onChanged: (q) => setState(() => _query = q)),
      Expanded(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection(AppConstants.colDeliveryAssign)
              .where('status', isEqualTo: 'cofniety')
              .snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: kSkanerAccent));
            }
            final docs = List.of(snap.data?.docs ?? [])
              ..sort((a, b) {
                final am = (a.data()['cancelled_at'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                final bm = (b.data()['cancelled_at'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                return bm.compareTo(am);
              });
            final shown = docs.where((d) => matchesQuery(_query, [
              d.data()['lot_dostawy'] as String?,
              d.data()['dostawca'] as String?,
              d.data()['odmiana'] as String?,
              d.data()['owoc'] as String?,
              d.data()['lot_produkcji'] as String?,
              dateTimeSearchBlob((d.data()['created_at'] as Timestamp?)?.toDate()),   // data przypisania
              dateTimeSearchBlob((d.data()['cancelled_at'] as Timestamp?)?.toDate()), // data cofnięcia
            ])).toList();
            if (shown.isEmpty) {
              return _Empty(_query.isEmpty
                  ? 'Brak zwróconych zejść'
                  : 'Brak wyników wyszukiwania');
            }
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: shown.length,
              itemBuilder: (_, i) => _AssignmentCard(
                key: ValueKey(shown[i].id),
                doc: shown[i],
                akcja: 'przywroc',
                userName: '',
                userId: '',
              ),
            );
          },
        ),
      ),
    ]);
  }
}

// ── Karta pojedynczego przypisania ────────────────────────────────────────────

class _AssignmentCard extends StatefulWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final String akcja; // 'cofnij' | 'przywroc'
  final String userName;
  final String userId;
  const _AssignmentCard({
    super.key,
    required this.doc, required this.akcja,
    required this.userName, required this.userId,
  });

  @override
  State<_AssignmentCard> createState() => _AssignmentCardState();
}

class _AssignmentCardState extends State<_AssignmentCard> {
  bool _busy = false;

  Map<String, dynamic> get d => widget.doc.data();

  // ── Cofnij: pełne odwrócenie zejścia + przywrócenie stanu ──────────────────
  Future<void> _cofnij() async {
    final lot   = d['lot_dostawy'] as String? ?? '';
    final kg    = (d['kg_zejscia'] as num?)?.toDouble() ?? 0.0;
    final ok = await _potwierdz(
      'Cofnąć zejście?',
      'LOT $lot — ~${fmtKg.format(kg)} kg wróci na stan, a wniosek trafi do „Zwrócone".\n'
      'Wpis zniknie z raportu wstępnego.',
      'Cofnij',
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      // 1. delivery_assignment -> cofniety (+ audyt)
      batch.update(widget.doc.reference, {
        'status':       'cofniety',
        'cancelled_at': FieldValue.serverTimestamp(),
        'cancelled_by': widget.userName,
        'cancelled_by_id': widget.userId,
      });

      // 2. usuń zejście (najpierw odczytaj liczbę skrzyń, by cofnąć opróżnienie)
      final zejscieId = d['zejscie_id'] as String?;
      int skrzynieIlosc = 0;
      if (zejscieId != null && zejscieId.isNotEmpty) {
        final zejRef = db.collection('skaner_zejscia').doc(zejscieId);
        final zejSnap = await zejRef.get();
        if (zejSnap.exists) {
          skrzynieIlosc = (zejSnap.data()?['skrzynie_ilosc'] as num?)?.toInt() ?? 0;
        }
        batch.delete(zejRef);
      }

      // 3. przywróć stan (pobrano_kg -= kg)
      if (kg > 0 && lot.isNotEmpty) {
        final docId = lot.replaceAll('/', '_');
        final delivRef = db.collection(AppConstants.colDeliveries).doc(docId);
        final delivSnap = await delivRef.get();
        if (delivSnap.exists) {
          batch.update(delivRef, {'pobrano_kg': FieldValue.increment(-kg)});
        }
      }

      // 4. wniosek -> zwrocony
      final wniosekId = d['wniosek_id'] as String?;
      if (wniosekId != null && wniosekId.isNotEmpty) {
        batch.update(db.collection('skaner_wnioski').doc(wniosekId), {
          'status':            'zwrocony',
          'raport_wstepny_id': FieldValue.delete(),
          'updated_at':        FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      // Cofnij opróżnienie skrzyń: PUSTE → PEŁNE (z produktem)
      await cofnijOproznienieSkrzynie(lot, skrzynieIlosc);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Zejście cofnięte — surowiec wrócił na stan'),
          backgroundColor: kSkanerPrimary));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Błąd: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  // ── Przywróć do puli: wniosek z powrotem do oczekujących ───────────────────
  Future<void> _przywroc() async {
    final lot = d['lot_dostawy'] as String? ?? '';
    final ok = await _potwierdz(
      'Przywrócić do puli?',
      'LOT $lot wróci do listy oczekujących i będzie można przypisać go na nowo.',
      'Przywróć',
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      final db = FirebaseFirestore.instance;
      final wniosekId = d['wniosek_id'] as String?;
      if (wniosekId != null && wniosekId.isNotEmpty) {
        await db.collection('skaner_wnioski').doc(wniosekId).update({
          'status':     'oczekujacy',
          'updated_at': FieldValue.serverTimestamp(),
        });
      }
      // oznacz cofnięty wpis jako rozliczony (żeby nie wisiał w "Zwrócone")
      await widget.doc.reference.update({'status': 'cofniety_przywrocony'});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Wniosek wrócił do puli oczekujących'),
          backgroundColor: kSkanerPrimary));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Błąd: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  Future<bool?> _potwierdz(String tytul, String tresc, String akcja) {
    final czerwony = akcja == 'Cofnij';
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kSkanerCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(tytul, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text(tresc, style: const TextStyle(color: kSkanerTextSec, fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Anuluj', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: czerwony ? Colors.redAccent : kSkanerAccent,
              foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: Text(akcja),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lot      = d['lot_dostawy'] as String? ?? '';
    final owoc     = d['owoc'] as String? ?? '';
    final odmiana  = d['odmiana'] as String? ?? '';
    final dostawca = d['dostawca'] as String? ?? '';
    final kg       = (d['kg_zejscia'] as num?)?.toDouble() ?? 0.0;
    final lotProd  = d['lot_produkcji'] as String? ?? '';
    final cofnij   = widget.akcja == 'cofnij';
    final ts       = (d['created_at'] as Timestamp?)?.toDate();
    final cancTs   = (d['cancelled_at'] as Timestamp?)?.toDate();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: kSkanerCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kSkanerPrimary, width: 1),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(
            '$owoc${odmiana.isNotEmpty ? " · $odmiana" : ""}',
            style: const TextStyle(color: kSkanerAccent, fontSize: 15, fontWeight: FontWeight.w700),
          )),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: kSkanerPrimary.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: kSkanerAccent.withValues(alpha: 0.4)),
            ),
            child: Text(lot, style: const TextStyle(
                color: Colors.white, fontSize: 13, fontFamily: 'monospace', fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 6),
        Text('$dostawca  ·  ~${fmtKg.format(kg)} kg',
            style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
        if (lotProd.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text('Raport: $lotProd',
                style: const TextStyle(color: kSkanerTextSec, fontSize: 12)),
          ),
        Text(
          cofnij
              ? (ts != null ? 'Przypisano: ${fmtDt.format(ts)}' : '')
              : (cancTs != null ? 'Cofnięto: ${fmtDt.format(cancTs)}'
                  '${(d['cancelled_by'] as String?)?.isNotEmpty == true ? "  ·  ${d['cancelled_by']}" : ""}' : ''),
          style: const TextStyle(color: kSkanerTextSec, fontSize: 11),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: cofnij
              ? OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                  ),
                  icon: _busy
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.redAccent))
                      : const Icon(Icons.undo, size: 16),
                  label: const Text('Cofnij zejście'),
                  onPressed: _busy ? null : _cofnij,
                )
              : ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kSkanerAccent, foregroundColor: Colors.white),
                  icon: _busy
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.replay, size: 16),
                  label: const Text('Przywróć do puli'),
                  onPressed: _busy ? null : _przywroc,
                ),
        ),
      ]),
    );
  }
}

class _Empty extends StatelessWidget {
  final String text;
  const _Empty(this.text);
  @override
  Widget build(BuildContext context) => Center(
    child: Text(text, style: const TextStyle(color: kSkanerTextSec, fontSize: 14)),
  );
}
