import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
import '../../core/auth/pin_auth_service.dart';
import '../../core/constants.dart';
import '../../shared/widgets/offline_banner.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

final _adminUsersProvider = StreamProvider<List<AppUser>>((ref) {
  return FirebaseFirestore.instance
      .collection(AppConstants.colUsers)
      .snapshots()
      .map((snap) {
    final list = snap.docs
        .map((d) => AppUser.fromFirestore(d.id, d.data()))
        .toList()
      ..sort((a, b) {
        if (a.isAdmin && !b.isAdmin) return -1;
        if (!a.isAdmin && b.isAdmin) return 1;
        return a.name.compareTo(b.name);
      });
    return list;
  });
});

// ── Ekran ─────────────────────────────────────────────────────────────────────

class UsersScreen extends ConsumerWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(_adminUsersProvider);
    final session = ref.watch(currentSessionProvider);

    return OfflineOverflowGuard(
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: const Text('Zarządzanie użytkownikami'),
          leading: BackButton(onPressed: () => context.go('/home')),
        ),
        body: Column(
          children: [
            const OfflineBanner(),
            Expanded(
              child: usersAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => _ErrorView(message: e.toString()),
                data: (users) => ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    _InfoBanner(),
                    const SizedBox(height: 8),
                    ...users.map((u) => _UserCard(
                          user: u,
                          isCurrentUser: u.id == session?.user.id,
                        )),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Info banner ───────────────────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: AppTheme.primaryDark.withAlpha(10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.primaryMid.withAlpha(60)),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, size: 16, color: AppTheme.primaryMid),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Jako admin możesz zmienić PIN każdego użytkownika.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ),
          ],
        ),
      );
}

// ── Karta użytkownika ─────────────────────────────────────────────────────────

class _UserCard extends StatelessWidget {
  final AppUser user;
  final bool isCurrentUser;
  const _UserCard({required this.user, required this.isCurrentUser});

  @override
  Widget build(BuildContext context) {
    final roleColor = user.isAdmin ? AppTheme.warningOrange : AppTheme.primaryMid;
    final roleLabel = user.isAdmin ? 'Admin' : 'Operator';
    final initial = user.name.isNotEmpty ? user.name[0].toUpperCase() : '?';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: roleColor.withAlpha(25),
              child: Text(initial,
                  style: TextStyle(color: roleColor, fontWeight: FontWeight.w700, fontSize: 18)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(user.name,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      if (isCurrentUser) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.successGreen.withAlpha(25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('Ty', style: TextStyle(fontSize: 10, color: AppTheme.successGreen)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: roleColor.withAlpha(20),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(roleLabel,
                            style: TextStyle(fontSize: 11, color: roleColor, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 6),
                      Text('ID: ${user.id}',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.lock_reset, color: AppTheme.primaryMid),
              tooltip: 'Zmień PIN',
              onPressed: () => _showChangePinDialog(context, user),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePinDialog(BuildContext context, AppUser user) {
    showDialog(
      context: context,
      builder: (_) => _ChangePinDialog(user: user),
    );
  }
}

// ── Dialog zmiany PIN ─────────────────────────────────────────────────────────

class _ChangePinDialog extends ConsumerStatefulWidget {
  final AppUser user;
  const _ChangePinDialog({required this.user});

  @override
  ConsumerState<_ChangePinDialog> createState() => _ChangePinDialogState();
}

class _ChangePinDialogState extends ConsumerState<_ChangePinDialog> {
  final _pinCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _pinCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final pin = _pinCtrl.text;
    final confirm = _confirmCtrl.text;

    if (pin.length != AppConstants.pinLength) {
      setState(() => _error = 'PIN musi mieć ${AppConstants.pinLength} cyfry');
      return;
    }
    if (pin != confirm) {
      setState(() => _error = 'PINy nie są identyczne');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref.read(pinAuthServiceProvider).changePin(widget.user.id, pin);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PIN użytkownika ${widget.user.name} został zmieniony'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      setState(() => _error = 'Błąd: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Zmień PIN — ${widget.user.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _pinCtrl,
            decoration: const InputDecoration(
              labelText: 'Nowy PIN',
              prefixIcon: Icon(Icons.lock_outlined),
            ),
            keyboardType: TextInputType.number,
            maxLength: AppConstants.pinLength,
            obscureText: true,
            onChanged: (_) => setState(() => _error = null),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _confirmCtrl,
            decoration: const InputDecoration(
              labelText: 'Powtórz PIN',
              prefixIcon: Icon(Icons.lock_outlined),
            ),
            keyboardType: TextInputType.number,
            maxLength: AppConstants.pinLength,
            obscureText: true,
            onChanged: (_) => setState(() => _error = null),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!,
                  style: const TextStyle(color: AppTheme.errorRed, fontSize: 13)),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Anuluj'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Zapisywanie...' : 'Zmień PIN'),
        ),
      ],
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppTheme.errorRed),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      );
}
