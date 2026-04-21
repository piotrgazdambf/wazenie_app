import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants.dart';

class Supplier {
  final String kod;
  final String nazwa;

  const Supplier({required this.kod, required this.nazwa});

  factory Supplier.fromFirestore(Map<String, dynamic> d) => Supplier(
        kod: d['kod'] as String? ?? '',
        nazwa: d['nazwa'] as String? ?? '',
      );

  String get pelnaNazwa => '$kod - $nazwa';

  @override
  String toString() => pelnaNazwa;
}

final suppliersProvider = FutureProvider<List<Supplier>>((ref) async {
  final snap = await FirebaseFirestore.instance
      .collection(AppConstants.colSuppliers)
      .orderBy('kod')
      .get();
  return snap.docs.map((d) => Supplier.fromFirestore(d.data())).toList();
});
