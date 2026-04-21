import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../app/theme.dart';
import '../../core/offline/hive_buffer.dart';
import '../../core/offline/offline_entry.dart';
import '../../core/offline/sync_manager.dart';
import '../../shared/widgets/offline_banner.dart';

// ── Ekran ─────────────────────────────────────────────────────────────────────

class SyncScreen extends ConsumerWidget {
  const SyncScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingCountProvider);
    final connectivityAsync = ref.watch(connectivityProvider);

    return OfflineOverflowGuard(
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: const Text('Status synchronizacji'),
          leading: BackButton(onPressed: () => context.go('/home')),
        ),
        body: Column(
          children: [
            const OfflineBanner(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Status połączenia
                  _ConnectivityCard(connectivityAsync: connectivityAsync),
                  const SizedBox(height: 12),
                  // Licznik offline
                  _PendingCard(pendingAsync: pendingAsync),
                  const SizedBox(height: 12),
                  // Ręczna synchronizacja
                  _SyncButton(),
                  const SizedBox(height: 20),
                  // Lista oczekujących wpisów
                  _PendingList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Karta połączenia ──────────────────────────────────────────────────────────

class _ConnectivityCard extends StatelessWidget {
  final AsyncValue<bool> connectivityAsync;
  const _ConnectivityCard({required this.connectivityAsync});

  @override
  Widget build(BuildContext context) {
    final isOnline = connectivityAsync.value ?? false;
    final color = isOnline ? AppTheme.successGreen : AppTheme.errorRed;
    final label = isOnline ? 'Online' : 'Offline';
    final icon = isOnline ? Icons.wifi : Icons.wifi_off;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Połączenie z internetem',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                Text(label,
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700, color: color)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Karta oczekujących ────────────────────────────────────────────────────────

class _PendingCard extends StatelessWidget {
  final AsyncValue<int> pendingAsync;
  const _PendingCard({required this.pendingAsync});

  @override
  Widget build(BuildContext context) {
    final count = pendingAsync.value ?? 0;
    final color = count == 0 ? AppTheme.successGreen : AppTheme.warningOrange;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.pending_outlined, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Oczekujące operacje offline',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                Text(
                  count == 0 ? 'Wszystko zsynchronizowane' : '$count do wysłania',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700, color: color),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Przycisk synchronizacji ───────────────────────────────────────────────────

class _SyncButton extends ConsumerStatefulWidget {
  @override
  ConsumerState<_SyncButton> createState() => _SyncButtonState();
}

class _SyncButtonState extends ConsumerState<_SyncButton> {
  bool _syncing = false;

  Future<void> _sync() async {
    setState(() => _syncing = true);
    try {
      await ref.read(syncManagerProvider).flushPending();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Synchronizacja zakończona'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd sync: $e'), backgroundColor: AppTheme.errorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: _syncing ? null : _sync,
      icon: _syncing
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : const Icon(Icons.cloud_sync_outlined),
      label: Text(_syncing ? 'Synchronizowanie...' : 'Synchronizuj teraz'),
    );
  }
}

// ── Lista oczekujących wpisów ─────────────────────────────────────────────────

class _PendingList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buffer = ref.read(hiveBufferProvider);
    final pending = buffer.getPending();

    if (pending.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline, size: 48, color: AppTheme.successGreen),
              SizedBox(height: 12),
              Text('Bufor offline jest pusty',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'BUFOR OFFLINE',
          style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700,
            letterSpacing: 1.2, color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        ...pending.map((e) => _OfflineEntryCard(entry: e)),
      ],
    );
  }
}

class _OfflineEntryCard extends StatelessWidget {
  final OfflineEntry entry;
  const _OfflineEntryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd.MM HH:mm', 'pl');
    final statusColor = entry.status == 'failed' ? AppTheme.errorRed : AppTheme.warningOrange;
    final typeLabel = _typeLabel(entry.type);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.pending_outlined, color: statusColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(typeLabel,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(
                    df.format(entry.createdAt),
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                  if (entry.retryCount > 0)
                    Text('Próby: ${entry.retryCount}',
                        style: TextStyle(fontSize: 11, color: statusColor)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                entry.status == 'failed' ? 'Błąd' : 'Oczekuje',
                style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _typeLabel(String type) => switch (type) {
    'delivery_create' => 'Nowe przyjęcie WSG',
    'pls_update' => 'Aktualizacja PLS',
    'mcr_zejscie' => 'Akcja MCR',
    _ => type,
  };
}
