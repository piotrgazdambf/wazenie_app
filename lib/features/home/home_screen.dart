import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
import '../../core/auth/pin_auth_service.dart';
import '../../shared/widgets/offline_banner.dart';
import '../../shared/widgets/crate_icon.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(currentSessionProvider);
    final user = session?.user;

    return OfflineOverflowGuard(
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: const Text('System Ważenia'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Wyloguj',
              onPressed: () => _logout(context, ref),
            ),
          ],
        ),
        body: Column(
          children: [
            const OfflineBanner(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Pozdrowienie
                  _WelcomeCard(user: user),
                  const SizedBox(height: 20),

                  // Moduły
                  _SectionLabel('Przyjęcie surowca'),
                  _ModuleCard(
                    icon: Icons.add_box_outlined,
                    title: 'Nowe przyjęcie (WSG)',
                    subtitle: 'Wypełnij kartę ważenia',
                    color: AppTheme.primaryMid,
                    onTap: () => context.go('/wsg/new'),
                  ),
                  _ModuleCard(
                    icon: Icons.list_alt,
                    title: 'Lista dostaw (PLS)',
                    subtitle: 'Przeglądaj i zarządzaj dostawami',
                    color: AppTheme.primaryDark,
                    onTap: () => context.go('/pls'),
                  ),
                  const SizedBox(height: 12),

                  _ModuleCard(
                    icon: Icons.description_outlined,
                    title: 'Karty Ważenia',
                    subtitle: 'Przeglądaj karty KW / KWG',
                    color: const Color(0xFF0F766E),
                    onTap: () => context.go('/karty'),
                  ),
                  const SizedBox(height: 12),

                  _SectionLabel('Magazyn'),
                  _ModuleCard(
                    icon: Icons.inventory_2_outlined,
                    title: 'Stany surowcowe',
                    subtitle: 'Aktualny stan magazynu',
                    color: const Color(0xFF059669),
                    onTap: () => context.go('/stany'),
                  ),
                  _ModuleCard(
                    customIcon: const CrateIcon(size: 26, color: Color(0xFF0891B2)),
                    title: 'Skrzynie',
                    subtitle: 'Stan skrzyń i przelicznik kg',
                    color: const Color(0xFF0891B2),
                    onTap: () => context.go('/skrzynie'),
                  ),
                  _ModuleCard(
                    icon: Icons.science_outlined,
                    title: 'PS — Parametry Surowca',
                    subtitle: 'BRIX, odpad, zwroty, twardość',
                    color: const Color(0xFF7C3AED),
                    onTap: () => context.go('/ps'),
                  ),
                  _ModuleCard(
                    icon: Icons.swap_horiz,
                    title: 'MCR — Raport Akcji',
                    subtitle: 'Kolejka zejść i przyjęć',
                    color: const Color(0xFF9333EA),
                    onTap: () => context.go('/mcr'),
                  ),
                  const SizedBox(height: 12),

                  // Admin only
                  if (user?.isAdmin == true) ...[
                    _SectionLabel('Administracja'),
                    _ModuleCard(
                      icon: Icons.manage_accounts_outlined,
                      title: 'Zarządzanie użytkownikami',
                      subtitle: 'PINy, role, dostępy',
                      color: const Color(0xFFD97706),
                      onTap: () => context.go('/admin/users'),
                    ),
                    _ModuleCard(
                      icon: Icons.cloud_sync_outlined,
                      title: 'Status synchronizacji',
                      subtitle: 'Bufor offline, synchronizacja',
                      color: const Color(0xFF0284C7),
                      onTap: () => context.go('/admin/sync'),
                    ),
                    _ModuleCard(
                      icon: Icons.store_outlined,
                      title: 'Katalog: dostawcy i owoce',
                      subtitle: 'Zarządzaj listami dostawców i owoców',
                      color: const Color(0xFF0F766E),
                      onTap: () => context.go('/admin/catalog'),
                    ),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Wylogowanie'),
        content: const Text('Czy na pewno chcesz się wylogować?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Anuluj')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Wyloguj')),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(pinAuthServiceProvider).clearSession();
      ref.read(currentSessionProvider.notifier).state = null;
      if (context.mounted) context.go('/login');
    }
  }
}

class _WelcomeCard extends StatelessWidget {
  final AppUser? user;
  const _WelcomeCard({this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryDark, AppTheme.primaryMid],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: Text(
              user?.name.substring(0, 1).toUpperCase() ?? '?',
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Witaj, ${user?.name ?? ''}',
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
                ),
                Text(
                  user?.isAdmin == true ? 'Administrator' : 'Operator',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4, left: 2),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final IconData? icon;
  final Widget? customIcon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ModuleCard({
    this.icon,
    this.customIcon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: customIcon ?? Icon(icon, color: color, size: 24),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
