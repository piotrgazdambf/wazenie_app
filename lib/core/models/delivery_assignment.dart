import 'package:cloud_firestore/cloud_firestore.dart';
import 'raport_wstepny.dart';

// ── Model przypisania dostawy do karty raportu wstępnego ──────────────────────
//
// INTEGRACJA z Raporty końcowe:
//   Kolekcja: 'delivery_assignments' w projekcie Firebase Ważenia.
//   Raporty końcowe inicjalizują secondary FirebaseApp z konfiguracją projektu
//   Ważenia i czytają tę kolekcję filtrując po status == 'przypisany'.
//   Po powiązaniu z raportem końcowym ustawiają status na 'zatwierdzony'.

class DeliveryAssignment {
  final String? id;
  final String wniosekId;
  final String lotDostawy;
  final String raportWstepnyId;
  final String lotProdukcji;
  final TypProdukcji typProdukcji;
  final double kgZejscia;
  final String dostawca;
  final String owoc;
  final String odmiana;
  final String dyspozytorId;
  final String dyspozytorName;
  final String? zejscieId;
  final String? operonPreliminaryDocId; // ID dokumentu w Raporty produkcyjne (mbf-raporty)
  final String status; // przypisany | zatwierdzony

  const DeliveryAssignment({
    this.id,
    required this.wniosekId,
    required this.lotDostawy,
    required this.raportWstepnyId,
    required this.lotProdukcji,
    required this.typProdukcji,
    required this.kgZejscia,
    required this.dostawca,
    required this.owoc,
    required this.odmiana,
    required this.dyspozytorId,
    required this.dyspozytorName,
    this.zejscieId,
    this.operonPreliminaryDocId,
    this.status = 'przypisany',
  });

  Map<String, dynamic> toMap() => {
    'wniosek_id':        wniosekId,
    'lot_dostawy':       lotDostawy,
    'raport_wstepny_id': raportWstepnyId,
    'lot_produkcji':     lotProdukcji,
    'typ_produkcji':     typProdukcji.firestoreValue,
    'kg_zejscia':        kgZejscia,
    'dostawca':          dostawca,
    'owoc':              owoc,
    'odmiana':           odmiana,
    'dyspozytor_id':     dyspozytorId,
    'dyspozytor_name':   dyspozytorName,
    if (zejscieId              != null) 'zejscie_id':                zejscieId,
    if (operonPreliminaryDocId != null) 'operon_preliminary_doc_id': operonPreliminaryDocId,
    'status':            status,
    'created_at':        FieldValue.serverTimestamp(),
    'source_app':        'wazenie',
  };
}
