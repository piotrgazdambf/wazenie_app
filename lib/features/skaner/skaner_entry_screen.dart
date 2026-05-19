import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/pin_auth_service.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              const Text(
                'Wybierz tryb pracy',
                style: TextStyle(color: kSkanerTextSec, fontSize: 14),
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
              // Wróć
              TextButton.icon(
                onPressed: () => context.go('/login'),
                icon: const Icon(Icons.arrow_back_ios, color: kSkanerTextSec, size: 14),
                label: const Text(
                  'Wróć do logowania',
                  style: TextStyle(color: kSkanerTextSec, fontSize: 13),
                ),
              ),
            ],
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
