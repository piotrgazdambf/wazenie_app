import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants.dart';
import 'hive_buffer.dart';
import 'offline_entry.dart';

/// Zarządza synchronizacją: wykrywa połączenie i flushuje bufor Hive → Firestore.
class SyncManager {
  final HiveBuffer _buffer;
  final FirebaseFirestore _db;
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  bool _isFlushing = false;

  SyncManager(this._buffer, this._db);

  void start() {
    _connSub = Connectivity().onConnectivityChanged.listen((results) {
      final hasNet = results.any((r) => r != ConnectivityResult.none);
      if (hasNet && !_isFlushing) {
        flushPending();
      }
    });
  }

  void stop() {
    _connSub?.cancel();
  }

  /// Wysyła wszystkie pending operacje do Firestore.
  Future<void> flushPending() async {
    if (_isFlushing) return;
    _isFlushing = true;
    try {
      final pending = _buffer.getPending();
      for (final entry in pending) {
        try {
          await _processEntry(entry);
          await _buffer.markSent(entry.id);
        } catch (e) {
          await _buffer.markFailed(
            entry.id,
            retryCount: entry.retryCount + 1,
          );
        }
      }
    } finally {
      _isFlushing = false;
    }
  }

  Future<void> _processEntry(OfflineEntry entry) async {
    switch (entry.type) {
      case 'mcr_zejscie':
        await _db.collection(AppConstants.colMcrQueue).doc(entry.id).set({
          ...entry.data,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });
        break;

      case 'pls_update':
        final id = entry.data['id'] as String;
        await _db.collection(AppConstants.colPls).doc(id).update(entry.data);
        break;

      case 'delivery_create':
        final id = entry.data['id'] as String;
        await _db.collection(AppConstants.colDeliveries).doc(id).set(
          entry.data,
          SetOptions(merge: true),
        );
        break;

      default:
        // Nieznany typ — zapisz do ogólnej kolekcji fallback
        await _db.collection('offline_fallback').doc(entry.id).set({
          ...entry.data,
          '_type': entry.type,
          '_createdAt': entry.createdAt.toIso8601String(),
        });
    }
  }
}

final syncManagerProvider = Provider<SyncManager>((ref) {
  final buffer = ref.watch(hiveBufferProvider);
  final db = FirebaseFirestore.instance;
  final mgr = SyncManager(buffer, db);
  ref.onDispose(mgr.stop);
  return mgr;
});

/// Stan połączenia sieciowego.
final connectivityProvider = StreamProvider<bool>((ref) {
  return Connectivity().onConnectivityChanged.map(
    (results) => results.any((r) => r != ConnectivityResult.none),
  );
});
