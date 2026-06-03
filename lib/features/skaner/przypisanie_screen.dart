import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/auth/pin_auth_service.dart';
import '../../core/constants.dart';
import '../../core/models/delivery_assignment.dart';
import '../../core/models/raport_wstepny.dart';
import 'skaner_entry_screen.dart';

// ── Ekran przypisywania dostaw do kart raportów wstępnych ─────────────────────
//
// Otwierany po wyborze typu produkcji w dyspozytorze.
// Split-screen: lewo = karty raportów wstępnych, prawo = oczekujące wnioski.
// Mechanizm: drag & drop LUB checkbox + przycisk "Przypisz zaznaczone".

class PrzypisanieScreen extends StatefulWidget {
  final TypProdukcji typProdukcji;
  final AppUser user;
  final String? initialWniosekId; // pre-zaznaczony po kliknięciu "Akceptuj"

  const PrzypisanieScreen({
    super.key,
    required this.typProdukcji,
    required this.user,
    this.initialWniosekId,
  });

  @override
  State<PrzypisanieScreen> createState() => _PrzypisanieScreenState();
}

class _PrzypisanieScreenState extends State<PrzypisanieScreen> {
  // wniosekId -> raportId (aktualne przypisania, jeszcze niezatwierdzone)
  final Map<String, String> _assignments = {};

  // Zaznaczone checkboxami (dla alternatywy do DnD)
  final Set<String> _checked = {};

  // Cache docs ze streamów (potrzebne w _wykonajPrzeslij)
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _wnioskiDocs = [];
  List<RaportWstepny> _raporty = [];

  bool _sending = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialWniosekId != null) {
      _checked.add(widget.initialWniosekId!);
    }
  }

  // ── Logika przypisania ────────────────────────────────────────────────────

  void _assign(String wniosekId, String raportId) {
    setState(() => _assignments[wniosekId] = raportId);
  }

  void _unassign(String wniosekId) {
    setState(() => _assignments.remove(wniosekId));
  }

  void _assignCheckedTo(String raportId) {
    if (_checked.isEmpty) return;
    setState(() {
      for (final id in _checked) {
        _assignments[id] = raportId;
      }
      _checked.clear();
    });
  }

  // ── Wykonaj zejście i zapisz przypisanie ──────────────────────────────────

  Future<void> _wykonajPrzeslij() async {
    if (_assignments.isEmpty) return;
    setState(() => _sending = true);

    final db     = FirebaseFirestore.instance;
    final fmt    = NumberFormat('#,##0', 'pl_PL');
    int    ok    = 0;
    final errors = <String>[];

    for (final entry in _assignments.entries) {
      final wniosekId = entry.key;
      final raportId  = entry.value;

      final wniosekDoc = _wnioskiDocs.cast<QueryDocumentSnapshot<Map<String, dynamic>>?>()
          .firstWhere((d) => d?.id == wniosekId, orElse: () => null);
      if (wniosekDoc == null) continue;

      final d   = wniosekDoc.data();
      final lot = d['lot'] as String? ?? '';
      final kg  = (d['kg_szacunek'] as num?)?.toDouble() ?? 0.0;

      final raport = _raporty.cast<RaportWstepny?>()
          .firstWhere((r) => r?.id == raportId, orElse: () => null);
      if (raport == null) continue;

      try {
        // 1. Pobierz dokument dostawy
        double  limit      = 0.0;
        String? delivDocId;

        final docId = lot.replaceAll('/', '_');
        var delivDoc = await db.collection(AppConstants.colDeliveries).doc(docId).get();
        if (!delivDoc.exists) {
          final q = await db.collection(AppConstants.colDeliveries)
              .where('lot', isEqualTo: lot).limit(1).get();
          if (q.docs.isNotEmpty) {
            delivDoc = q.docs.first as DocumentSnapshot<Map<String, dynamic>>;
          }
        }
        if (delivDoc.exists && delivDoc.data() != null) {
          delivDocId = delivDoc.id;
          final raw  = (delivDoc.data()!['waga_netto'] ?? '').toString()
              .replaceAll(',', '.').replaceAll(RegExp(r'[^0-9.]'), '');
          limit = double.tryParse(raw) ?? 0.0;
        }

        // 2. Suma już pobranych kg
        double pobrano = 0.0;
        final zejsSnap = await db.collection('skaner_zejscia')
            .where('lot', isEqualTo: lot).get();
        pobrano = zejsSnap.docs.fold(
            0.0, (s, x) => s + ((x.data()['waga_zejscia'] as num?)?.toDouble() ?? 0.0));

        // 3. Walidacja limitu
        if (limit > 0 && kg > 0 && kg > (limit - pobrano) + 0.1) {
          errors.add('$lot: za dużo (pozostało ~${fmt.format((limit - pobrano).clamp(0, double.infinity))} kg)');
          continue;
        }

        final wagaPo = pobrano + kg;

        // 4. Zapisz zejście
        String? zejscieId;
        if (kg > 0) {
          final zejRef = await db.collection('skaner_zejscia').add({
            'lot':             lot,
            'owoc':            d['owoc']    ?? '',
            'odmiana':         d['odmiana'] ?? '',
            'dostawca':        d['dostawca'] ?? '',
            'waga_limit':      limit,
            'waga_zejscia':    kg,
            'waga_przed':      pobrano,
            'waga_po':         wagaPo,
            'metoda':          'skrzynie',
            'skrzynie_ilosc':  d['skrzynie_ilosc'] ?? 0,
            'dyspozytor_id':   widget.user.id,
            'dyspozytor_name': widget.user.name,
            'wniosek_id':      wniosekId,
            'raport_wstepny_id': raportId,
            'created_at':      FieldValue.serverTimestamp(),
          });
          zejscieId = zejRef.id;

          // 5. Zaktualizuj pobrano_kg w deliveries (zejście ze stanów)
          if (delivDocId != null) {
            await db.collection(AppConstants.colDeliveries)
                .doc(delivDocId).update({'pobrano_kg': FieldValue.increment(kg)});
          }

          // 6. MCR queue
          final now   = DateTime.now();
          final mcrId = 'mcr_skaner_${now.millisecondsSinceEpoch}';
          await db.collection(AppConstants.colMcrQueue).doc(mcrId).set({
            'id':            mcrId,
            'lot':           lot,
            'czas':          '${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}',
            'akcja':         'Zejście',
            'waga_netto':    kg.toStringAsFixed(2),
            'owoc':          d['owoc']          ?? '',
            'odmiana':       d['odmiana']        ?? '',
            'przeznaczenie': d['przeznaczenie']  ?? '',
            'status':        'done',
            'createdAt':     FieldValue.serverTimestamp(),
          });
        }

        // 7. Pobierz operon_preliminary_doc_id z dokumentu raportu wstępnego
        String? operonPreliminaryDocId;
        try {
          final raportDoc = await db
              .collection(AppConstants.colRaportyWstepne)
              .doc(raportId)
              .get();
          operonPreliminaryDocId =
              raportDoc.data()?['operon_preliminary_doc_id'] as String?;
        } catch (_) {}

        // 8. Zapisz przypisanie
        await db.collection(AppConstants.colDeliveryAssign).add(
          DeliveryAssignment(
            wniosekId:             wniosekId,
            lotDostawy:            lot,
            raportWstepnyId:       raportId,
            lotProdukcji:          raport.lotProdukcji,
            typProdukcji:          widget.typProdukcji,
            kgZejscia:             kg,
            dostawca:              d['dostawca'] as String? ?? '',
            owoc:                  d['owoc']     as String? ?? '',
            odmiana:               d['odmiana']  as String? ?? '',
            dyspozytorId:          widget.user.id,
            dyspozytorName:        widget.user.name,
            zejscieId:             zejscieId,
            operonPreliminaryDocId: operonPreliminaryDocId,
          ).toMap(),
        );

        // 8. Zaktualizuj status wniosku
        await db.collection('skaner_wnioski').doc(wniosekId).update({
          'status':            'zaakceptowany',
          'dyspozytor_id':     widget.user.id,
          'dyspozytor_name':   widget.user.name,
          'raport_wstepny_id': raportId,
          'updated_at':        FieldValue.serverTimestamp(),
        });

        ok++;
      } catch (e) {
        errors.add('$lot: błąd ($e)');
      }
    }

    setState(() => _sending = false);

    if (!mounted) return;

    if (errors.isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Częściowy błąd',
              style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (ok > 0)
                Text('Przesłano pomyślnie: $ok',
                    style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              ...errors.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• $e',
                    style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
              )),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(_),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }

    if (ok > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Przesłano $ok ${ok == 1 ? "dostawę" : "dostawy"} pomyślnie'),
        backgroundColor: const Color(0xFF2D6A4F),
      ));
      Navigator.pop(context);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final typ = widget.typProdukcji;

    return Scaffold(
      backgroundColor: kSkanerBg,
      appBar: AppBar(
        backgroundColor: kSkanerCard,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            const Text('Przypisanie dostaw',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(width: 12),
            _TypChip(typ: typ),
          ],
        ),
        actions: [
          if (_assignments.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: kSkanerAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kSkanerAccent.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    'Przypisano: ${_assignments.length}',
                    style: const TextStyle(
                        color: kSkanerAccent, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _assignments.isEmpty ? kSkanerPrimary : kSkanerAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              onPressed: (_assignments.isEmpty || _sending) ? null : _wykonajPrzeslij,
              icon: _sending
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send, size: 16),
              label: const Text('Prześlij', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── LEWA: karty raportów wstępnych ────────────────────────────
          Expanded(
            flex: 5,
            child: _LeftPanel(
              typProdukcji:   widget.typProdukcji,
              assignments:    _assignments,
              checked:        _checked,
              onRaportyLoaded: (list) => setState(() => _raporty = list),
              onAssignChecked: _assignCheckedTo,
              onUnassign:     (wniosekId) => _unassign(wniosekId),
              onDrop:         (wniosekId, raportId) => _assign(wniosekId, raportId),
              wnioskiDocs:    _wnioskiDocs,
              raporty:        _raporty,
            ),
          ),
          // Separator
          Container(
            width: 1,
            color: kSkanerPrimary.withValues(alpha: 0.4),
          ),
          // ── PRAWA: oczekujące wnioski ─────────────────────────────────
          Expanded(
            flex: 4,
            child: _RightPanel(
              assignments:      _assignments,
              checked:          _checked,
              initialWniosekId: widget.initialWniosekId,
              raporty:          _raporty,
              onDocsLoaded:     (docs) => setState(() => _wnioskiDocs = docs),
              onToggleCheck: (id) => setState(() {
                if (_checked.contains(id)) {
                  _checked.remove(id);
                } else {
                  _checked.add(id);
                }
              }),
              onUnassign: _unassign,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Lewa strona: pula kart raportów wstępnych ─────────────────────────────────

class _LeftPanel extends StatelessWidget {
  final TypProdukcji typProdukcji;
  final Map<String, String> assignments;
  final Set<String> checked;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> wnioskiDocs;
  final List<RaportWstepny> raporty;
  final void Function(List<RaportWstepny>) onRaportyLoaded;
  final void Function(String raportId) onAssignChecked;
  final void Function(String wniosekId) onUnassign;
  final void Function(String wniosekId, String raportId) onDrop;

  const _LeftPanel({
    required this.typProdukcji,
    required this.assignments,
    required this.checked,
    required this.wnioskiDocs,
    required this.raporty,
    required this.onRaportyLoaded,
    required this.onAssignChecked,
    required this.onUnassign,
    required this.onDrop,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PanelHeader(
          icon: typProdukcji.icon,
          label: 'Karty raportów wstępnych',
          subtitle: typProdukcji.label,
          color: typProdukcji.color,
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection(AppConstants.colRaportyWstepne)
                .where('typ_produkcji', isEqualTo: typProdukcji.firestoreValue)
                .where('status', isEqualTo: 'otwarty')
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: kSkanerAccent));
              }

              final docs = snap.data?.docs ?? [];
              final items = docs
                  .map((d) => RaportWstepny.fromFirestore(
                      d as DocumentSnapshot<Map<String, dynamic>>))
                  .toList();

              // Aktualizuj cache w rodzicu (jeden raz po zmianie)
              WidgetsBinding.instance.addPostFrameCallback((_) {
                onRaportyLoaded(items);
              });

              if (items.isEmpty) {
                return _EmptyRaportyPlaceholder(typ: typProdukcji);
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: items.length,
                itemBuilder: (_, i) => _RaportKartaCard(
                  raport:       items[i],
                  assignments:  assignments,
                  checked:      checked,
                  wnioskiDocs:  wnioskiDocs,
                  onDrop:       onDrop,
                  onAssignChecked: onAssignChecked,
                  onUnassign:   onUnassign,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Prawa strona: oczekujące wnioski ──────────────────────────────────────────

class _RightPanel extends StatelessWidget {
  final Map<String, String> assignments;
  final Set<String> checked;
  final String? initialWniosekId;
  final List<RaportWstepny> raporty;
  final void Function(List<QueryDocumentSnapshot<Map<String, dynamic>>>) onDocsLoaded;
  final void Function(String wniosekId) onToggleCheck;
  final void Function(String wniosekId) onUnassign;

  const _RightPanel({
    required this.assignments,
    required this.checked,
    required this.initialWniosekId,
    required this.raporty,
    required this.onDocsLoaded,
    required this.onToggleCheck,
    required this.onUnassign,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _PanelHeader(
          icon: Icons.hourglass_top,
          label: 'Oczekujące dostawy',
          subtitle: 'Przeciągnij lub zaznacz i przypisz',
          color: kSkanerAccent,
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('skaner_wnioski')
                .where('status', isEqualTo: 'oczekujacy')
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: kSkanerAccent));
              }

              final docs = (snap.data?.docs
                  .cast<QueryDocumentSnapshot<Map<String, dynamic>>>() ?? []);

              WidgetsBinding.instance.addPostFrameCallback((_) {
                onDocsLoaded(docs);
              });

              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_outline,
                          color: kSkanerAccent, size: 48),
                      const SizedBox(height: 12),
                      const Text('Brak oczekujących dostaw',
                          style: TextStyle(color: kSkanerTextSec, fontSize: 15)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final doc = docs[i];
                  return _WniosekDragTile(
                    doc:        doc,
                    isChecked:  checked.contains(doc.id),
                    assignment: assignments[doc.id],
                    raporty:    raporty,
                    onToggle:   () => onToggleCheck(doc.id),
                    onUnassign: () => onUnassign(doc.id),
                    isInitial:  doc.id == initialWniosekId,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Karta raportu wstępnego (DragTarget) ──────────────────────────────────────

class _RaportKartaCard extends StatefulWidget {
  final RaportWstepny raport;
  final Map<String, String> assignments;
  final Set<String> checked;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> wnioskiDocs;
  final void Function(String wniosekId, String raportId) onDrop;
  final void Function(String raportId) onAssignChecked;
  final void Function(String wniosekId) onUnassign;

  const _RaportKartaCard({
    required this.raport,
    required this.assignments,
    required this.checked,
    required this.wnioskiDocs,
    required this.onDrop,
    required this.onAssignChecked,
    required this.onUnassign,
  });

  @override
  State<_RaportKartaCard> createState() => _RaportKartaCardState();
}

class _RaportKartaCardState extends State<_RaportKartaCard> {
  bool _hovering = false;

  List<String> get _assignedWniosekIds => widget.assignments.entries
      .where((e) => e.value == widget.raport.id)
      .map((e) => e.key)
      .toList();

  @override
  Widget build(BuildContext context) {
    final raport = widget.raport;
    final fmt    = NumberFormat('#,##0', 'pl_PL');
    final color  = raport.typProdukcji.color;
    final assigned = _assignedWniosekIds;

    // Suma kg przypisanych wniosków
    double sumKg = 0;
    for (final wid in assigned) {
      final doc = widget.wnioskiDocs.cast<QueryDocumentSnapshot<Map<String, dynamic>>?>()
          .firstWhere((d) => d?.id == wid, orElse: () => null);
      if (doc != null) {
        sumKg += (doc.data()['kg_szacunek'] as num?)?.toDouble() ?? 0.0;
      }
    }

    return DragTarget<String>(
      onWillAcceptWithDetails: (_) {
        setState(() => _hovering = true);
        return true;
      },
      onLeave: (_) => setState(() => _hovering = false),
      onAcceptWithDetails: (details) {
        setState(() => _hovering = false);
        widget.onDrop(details.data, raport.id);
      },
      builder: (context, candidateData, _) {
        final isDragOver = _hovering || candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isDragOver
                ? color.withValues(alpha: 0.12)
                : kSkanerCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDragOver ? color : (assigned.isNotEmpty ? color.withValues(alpha: 0.5) : kSkanerPrimary),
              width: isDragOver ? 2 : 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nagłówek karty
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: color.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        raport.lotProdukcji,
                        style: TextStyle(
                            color: color,
                            fontSize: 13,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        raport.owoc,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                // Parametry
                if (raport.brix != null || raport.witaminaC != null || raport.uzyskPct != null) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (raport.brix != null)
                        _ParamChip('BRIX: ${raport.brix!.toStringAsFixed(1)}', color),
                      if (raport.witaminaC != null)
                        _ParamChip('Wit.C: ${raport.witaminaC!.toStringAsFixed(1)}', color),
                      if (raport.uzyskPct != null)
                        _ParamChip('Uzysk: ${raport.uzyskPct!.toStringAsFixed(1)}%', color),
                    ],
                  ),
                ],
                // Strefa upuszczania
                const SizedBox(height: 10),
                if (assigned.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: isDragOver
                          ? color.withValues(alpha: 0.08)
                          : kSkanerPrimary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDragOver ? color : kSkanerPrimary,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          isDragOver ? Icons.add_circle : Icons.drag_indicator,
                          color: isDragOver ? color : kSkanerTextSec,
                          size: 22,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isDragOver ? 'Upuść tutaj' : 'Przeciągnij dostawę lub użyj przycisku poniżej',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDragOver ? color : kSkanerTextSec,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  // Lista przypisanych wniosków
                  ...assigned.map((wid) {
                    final doc = widget.wnioskiDocs.cast<QueryDocumentSnapshot<Map<String, dynamic>>?>()
                        .firstWhere((d) => d?.id == wid, orElse: () => null);
                    final lot = doc?.data()['lot'] as String? ?? wid;
                    final kg  = (doc?.data()['kg_szacunek'] as num?)?.toDouble() ?? 0.0;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: color.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: color, size: 14),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(lot,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontFamily: 'monospace')),
                          ),
                          if (kg > 0)
                            Text('~${fmt.format(kg)} kg',
                                style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () => widget.onUnassign(wid),
                            child: const Icon(Icons.close, size: 14, color: Colors.redAccent),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (sumKg > 0) ...[
                    const SizedBox(height: 4),
                    Text('Łącznie: ~${fmt.format(sumKg)} kg',
                        style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ],
                ],
                // Przycisk "Przypisz zaznaczone"
                if (widget.checked.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: color,
                        side: BorderSide(color: color),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      icon: const Icon(Icons.arrow_back, size: 14),
                      label: Text(
                        'Przypisz zaznaczone (${widget.checked.length})',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      onPressed: () => widget.onAssignChecked(raport.id),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Kafelek wniosku (Draggable) ───────────────────────────────────────────────

class _WniosekDragTile extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final bool isChecked;
  final String? assignment; // raportId jeśli przypisany
  final List<RaportWstepny> raporty;
  final VoidCallback onToggle;
  final VoidCallback onUnassign;
  final bool isInitial;

  const _WniosekDragTile({
    required this.doc,
    required this.isChecked,
    required this.assignment,
    required this.raporty,
    required this.onToggle,
    required this.onUnassign,
    this.isInitial = false,
  });

  @override
  Widget build(BuildContext context) {
    final d        = doc.data();
    final lot      = d['lot']      as String? ?? '';
    final owoc     = d['owoc']     as String? ?? '';
    final odmiana  = d['odmiana']  as String? ?? '';
    final dostawca = d['dostawca'] as String? ?? '';
    final ilosc    = d['skrzynie_ilosc'] as int? ?? 0;
    final kg       = (d['kg_szacunek'] as num?)?.toDouble() ?? 0.0;
    final ts       = (d['created_at'] as Timestamp?)?.toDate();
    final fmt      = NumberFormat('#,##0', 'pl_PL');
    final timeFmt  = DateFormat('dd.MM HH:mm');

    final assigned = assignment != null;
    final raport   = assigned
        ? raporty.cast<RaportWstepny?>()
            .firstWhere((r) => r?.id == assignment, orElse: () => null)
        : null;

    final cardContent = Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: assigned
            ? (raport?.typProdukcji.color ?? kSkanerAccent).withValues(alpha: 0.06)
            : (isInitial ? kSkanerAccent.withValues(alpha: 0.08) : kSkanerCard),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: assigned
              ? (raport?.typProdukcji.color ?? kSkanerAccent).withValues(alpha: 0.4)
              : (isChecked ? kSkanerAccent : kSkanerPrimary),
          width: (assigned || isChecked || isInitial) ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Checkbox
            Checkbox(
              value: isChecked,
              onChanged: (_) => onToggle(),
              activeColor: kSkanerAccent,
              side: const BorderSide(color: kSkanerTextSec),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Owoc + LOT
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          '$owoc${odmiana.isNotEmpty ? " · $odmiana" : ""}',
                          style: const TextStyle(
                              color: kSkanerAccent,
                              fontSize: 13,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: kSkanerPrimary.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(lot,
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontFamily: 'monospace')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Dostawca + czas
                  Row(
                    children: [
                      Text(dostawca,
                          style: const TextStyle(color: kSkanerTextSec, fontSize: 11)),
                      const Spacer(),
                      if (ts != null)
                        Text(timeFmt.format(ts),
                            style: const TextStyle(color: kSkanerTextSec, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Skrzynie + kg
                  Row(
                    children: [
                      _SmallChip('$ilosc skrz.', kSkanerPrimary),
                      const SizedBox(width: 6),
                      if (kg > 0) _SmallChip('~${fmt.format(kg)} kg', const Color(0xFF2D6A4F)),
                      const Spacer(),
                      // Badge przypisania
                      if (assigned && raport != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: raport.typProdukcji.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: raport.typProdukcji.color.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.link, size: 10, color: raport.typProdukcji.color),
                              const SizedBox(width: 3),
                              Text(
                                raport.lotProdukcji,
                                style: TextStyle(
                                    color: raport.typProdukcji.color,
                                    fontSize: 10,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(width: 4),
                              InkWell(
                                onTap: onUnassign,
                                child: const Icon(Icons.close, size: 10, color: Colors.redAccent),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            // Uchwyt do przeciągania
            if (!assigned)
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 4),
                child: Icon(Icons.drag_indicator, color: kSkanerTextSec.withValues(alpha: 0.5), size: 18),
              ),
          ],
        ),
      ),
    );

    if (assigned) return cardContent;

    return Draggable<String>(
      data: doc.id,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: 0.85,
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.3,
            child: cardContent,
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: cardContent),
      child: cardContent,
    );
  }
}

// ── Pomocnicze widgety ─────────────────────────────────────────────────────────

class _PanelHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;

  const _PanelHeader({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: kSkanerCard,
        border: Border(bottom: BorderSide(color: color.withValues(alpha: 0.3))),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
              Text(subtitle,
                  style: TextStyle(color: color, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _TypChip extends StatelessWidget {
  final TypProdukcji typ;
  const _TypChip({required this.typ});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: typ.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: typ.color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(typ.icon, color: typ.color, size: 13),
          const SizedBox(width: 5),
          Text(typ.label,
              style: TextStyle(
                  color: typ.color, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _ParamChip extends StatelessWidget {
  final String label;
  final Color color;
  const _ParamChip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _SmallChip extends StatelessWidget {
  final String label;
  final Color color;
  const _SmallChip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _EmptyRaportyPlaceholder extends StatelessWidget {
  final TypProdukcji typ;
  const _EmptyRaportyPlaceholder({required this.typ});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(typ.icon, color: kSkanerTextSec, size: 52),
            const SizedBox(height: 16),
            Text(
              'Brak kart dla "${typ.label}"',
              style: const TextStyle(
                  color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Dodaj karty przez panel admina\n(przycisk "Seed raporty wstępne")\nlub poczekaj aż Generator LOT je utworzy.',
              textAlign: TextAlign.center,
              style: TextStyle(color: kSkanerTextSec, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
