import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/pin_auth_service.dart';
import '../../core/kiosk_mode.dart';

// ── Paleta kolorów modułu skanera ─────────────────────────────────────────────

const kSkanerBg      = Color(0xFF0A1B12);
const kSkanerCard    = Color(0xFF122A1C);
const kSkanerPrimary = Color(0xFF2D6A4F);
const kSkanerAccent  = Color(0xFF52B788);
const kSkanerTextSec = Color(0xFF8FB5A0);

// ── Ekran wejścia skanera ─────────────────────────────────────────────────────

class SkanerEntryScreen extends ConsumerStatefulWidget {
  const SkanerEntryScreen({super.key});

  @override
  ConsumerState<SkanerEntryScreen> createState() => _SkanerEntryScreenState();
}

class _SkanerEntryScreenState extends ConsumerState<SkanerEntryScreen> {
  @override
  void initState() {
    super.initState();
    // Upewnij się że Olaf istnieje w Firestore
    ref.read(pinAuthServiceProvider).seedOlafIfNeeded();
  }

  Future<void> _deactivateKiosk(BuildContext context) async {
    final ctrl = TextEditingController();
    String? error;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: const Color(0xFF0A1B12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.lock_open, color: Colors.orangeAccent, size: 22),
              SizedBox(width: 10),
              Text('Wyjście z trybu Skanera',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Wpisz kod aby wrócić do menu głównego.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 4),
                textAlign: TextAlign.center,
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) => setS(() => error = null),
                onSubmitted: (_) {
                  if (ctrl.text.trim().toUpperCase() == kKioskCode) {
                    Navigator.pop(ctx, true);
                  } else {
                    setS(() => error = 'Nieprawidłowy kod');
                  }
                },
                decoration: InputDecoration(
                  hintText: 'KOD',
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.08),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  errorText: error,
                  errorStyle: const TextStyle(color: Colors.orangeAccent),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Anuluj', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                if (ctrl.text.trim().toUpperCase() == kKioskCode) {
                  Navigator.pop(ctx, true);
                } else {
                  setS(() => error = 'Nieprawidłowy kod');
                }
              },
              child: const Text('Odblokuj', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );

    ctrl.dispose();
    if (ok == true && mounted) {
      await ref.read(kioskModeProvider.notifier).deactivate();
      if (mounted) context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final kioskAsync = ref.watch(kioskModeProvider);
    final kioskMode  = kioskAsync.value ?? false;

    return PopScope(
      canPop: !kioskMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && kioskMode) _deactivateKiosk(context);
      },
      child: Scaffold(
        backgroundColor: kSkanerBg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 16),
                // Logo / nagłówek
                const Icon(Icons.qr_code_scanner, color: kSkanerAccent, size: 52),
                const SizedBox(height: 12),
                const Text(
                  'Skaner',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  kioskMode ? 'Tryb kiosku — urządzenie zablokowane' : 'Wybierz tryb pracy',
                  style: TextStyle(
                    color: kioskMode ? Colors.orangeAccent : kSkanerTextSec,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 48),
                // Kafelek — Wózkowy
                _ModeTile(
                  label: 'Wózkowy',
                  subtitle: 'Skanowanie dostaw',
                  icon: Icons.forklift,
                  iconColor: const Color(0xFF74C69D),
                  bgColor: const Color(0xFF1B4332),
                  borderColor: const Color(0xFF2D6A4F),
                  onTap: () => context.go('/skaner/wozkowy'),
                ),
                const SizedBox(height: 20),
                // Kafelek — Dyspozytor
                _ModeTile(
                  label: 'Dyspozytor',
                  subtitle: 'Zarządzanie zleceniami',
                  icon: Icons.manage_accounts_outlined,
                  iconColor: const Color(0xFF95D5B2),
                  bgColor: const Color(0xFF1A3A28),
                  borderColor: const Color(0xFF40916C),
                  onTap: () => context.go('/skaner/dyspozytor'),
                ),
                const Spacer(),
                // Wróć / Wyjście z kiosku
                if (kioskMode)
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orangeAccent,
                        side: const BorderSide(color: Colors.orangeAccent),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => _deactivateKiosk(context),
                      icon: const Icon(Icons.lock_open, size: 20),
                      label: const Text(
                        'Wyjście (wpisz kod)',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                  )
                else
                  TextButton.icon(
                    onPressed: () => context.go('/login'),
                    icon: const Icon(Icons.arrow_back_ios, color: kSkanerTextSec, size: 14),
                    label: const Text(
                      'Wróć do logowania',
                      style: TextStyle(color: kSkanerTextSec, fontSize: 13),
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final Color borderColor;
  final VoidCallback onTap;

  const _ModeTile({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: borderColor.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 36),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: kSkanerTextSec,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: kSkanerTextSec, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}
