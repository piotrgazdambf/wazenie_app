import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../constants.dart';
import 'offline_entry.dart';

/// Lokalny bufor operacji offline — persystowany przez Hive.
/// Przechowuje obiekty jako JSON string (nie wymaga generowania adapterów).
class HiveBuffer {
  static late Box<String> _box;

  static Future<void> openBoxes() async {
    _box = await Hive.openBox<String>(AppConstants.hiveBoxOffline);
  }

  // ── Zapis ────────────────────────────────────────────────────────────────────

  Future<void> enqueue(OfflineEntry entry) async {
    await _box.put(entry.id, jsonEncode(entry.toMap()));
  }

  // ── Odczyt ───────────────────────────────────────────────────────────────────

  List<OfflineEntry> getPending() {
    return _box.values
        .map((s) => OfflineEntry.fromMap(jsonDecode(s) as Map<String, dynamic>))
        .where((e) => e.status == 'pending' || e.status == 'failed')
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  int get pendingCount => getPending().length;

  // ── Aktualizacja statusu ──────────────────────────────────────────────────────

  Future<void> markSent(String id) async {
    await _box.delete(id);
  }

  Future<void> markFailed(String id, {int? retryCount}) async {
    final raw = _box.get(id);
    if (raw == null) return;
    final entry = OfflineEntry.fromMap(jsonDecode(raw) as Map<String, dynamic>);
    entry.status = 'failed';
    if (retryCount != null) entry.retryCount = retryCount;
    await _box.put(id, jsonEncode(entry.toMap()));
  }

  // ── Strumień zmian ────────────────────────────────────────────────────────────

  Stream<int> get pendingCountStream =>
      _box.watch().map((_) => pendingCount).distinct();

  // ── Czyszczenie ───────────────────────────────────────────────────────────────

  Future<void> clear() => _box.clear();
}

final hiveBufferProvider = Provider<HiveBuffer>((ref) => HiveBuffer());

/// Stream liczby oczekujących operacji offline.
final pendingCountProvider = StreamProvider<int>((ref) {
  final buffer = ref.watch(hiveBufferProvider);
  return Stream.value(buffer.pendingCount).asyncExpand((_) async* {
    yield buffer.pendingCount;
    yield* buffer.pendingCountStream;
  });
});
