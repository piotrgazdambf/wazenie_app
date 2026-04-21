import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme.dart';
import '../../core/constants.dart';
import '../../core/offline/hive_buffer.dart';
import '../../core/offline/sync_manager.dart';

/// Pasek informacyjny o stanie połączenia i buforze offline.
/// Pokazuje się na górze ekranu gdy brak internetu lub są pending operacje.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connAsync = ref.watch(connectivityProvider);
    final pendingAsync = ref.watch(pendingCountProvider);

    final isOnline = connAsync.value ?? true;
    final pending = pendingAsync.value ?? 0;

    if (isOnline && pending == 0) return const SizedBox.shrink();

    return Material(
      color: isOnline ? AppTheme.warningOrange : AppTheme.errorRed,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                isOnline ? Icons.sync : Icons.wifi_off_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isOnline
                      ? 'Synchronizacja... ($pending operacji oczekuje)'
                      : 'Brak połączenia — tryb offline ($pending w buforze)',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
              if (isOnline && pending > 0)
                GestureDetector(
                  onTap: () => ref.read(syncManagerProvider).flushPending(),
                  child: const Text('WYŚLIJ', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700, decoration: TextDecoration.underline, decorationColor: Colors.white)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Popup blokujący gdy w buforze jest więcej niż [AppConstants.offlineWarningThreshold] wpisów.
class OfflineOverflowGuard extends ConsumerWidget {
  final Widget child;
  const OfflineOverflowGuard({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingCountProvider);
    final pending = pendingAsync.value ?? 0;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (pending > AppConstants.offlineWarningThreshold) {
        _showOverflowDialog(context, pending, ref);
      }
    });

    return child;
  }

  void _showOverflowDialog(BuildContext context, int count, WidgetRef ref) {
    if (!context.mounted) return;
    // Nie pokazuj jeśli dialog już otwarty
    final nav = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.warning_rounded, color: AppTheme.errorRed, size: 48),
        title: const Text('Bufor offline przepełniony!', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.errorRed, fontWeight: FontWeight.w700)),
        content: Text(
          'W buforze offline jest $count niezapisanych operacji.\n\nPołącz urządzenie z internetem aby wysłać dane.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            onPressed: () {
              nav.pop();
              ref.read(syncManagerProvider).flushPending();
            },
            child: const Text('Wyślij teraz', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: nav.pop,
            child: const Text('Kontynuuj offline'),
          ),
        ],
      ),
    );
  }
}
