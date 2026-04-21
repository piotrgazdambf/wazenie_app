import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/theme.dart';
import '../../core/firebase/remote_config_service.dart';

/// Fullscreen overlay blokujący aplikację gdy wymagana aktualizacja.
/// Użytkownik NIE może ominąć tego ekranu.
class ForceUpdateScreen extends ConsumerWidget {
  const ForceUpdateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rc = ref.read(remoteConfigServiceProvider);

    return PopScope(
      canPop: false, // blokuje przycisk wstecz
      child: Scaffold(
        backgroundColor: AppTheme.primaryDark,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.system_update_alt, color: Colors.white, size: 52),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Wymagana aktualizacja',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Dostępna jest nowa wersja aplikacji.\nAby kontynuować pracę, pobierz aktualizację.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _openStore(context, rc),
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('Aktualizuj teraz'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.primaryDark,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 60),
                  Text(
                    'System Ważenia',
                    style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openStore(BuildContext context, RemoteConfigService rc) async {
    // Rozróżnij platformę — na web/Android użyj android URL
    final urlStr = rc.androidStoreUrl;
    final uri = Uri.tryParse(urlStr);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nie można otworzyć sklepu')),
        );
      }
    }
  }
}
