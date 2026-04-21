import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
import '../../core/auth/pin_auth_service.dart';
import '../../core/constants.dart';

// ── Stany ekranu PIN ─────────────────────────────────────────────────────────

enum PinScreenStep { selectUser, enterPin }

class _PinState {
  final PinScreenStep step;
  final AppUser? selectedUser;
  final String enteredPin;
  final int failedAttempts;
  final DateTime? lockedUntil;
  final String? errorMessage;
  final bool isLoading;

  const _PinState({
    this.step = PinScreenStep.selectUser,
    this.selectedUser,
    this.enteredPin = '',
    this.failedAttempts = 0,
    this.lockedUntil,
    this.errorMessage,
    this.isLoading = false,
  });

  bool get isLocked =>
      lockedUntil != null && DateTime.now().isBefore(lockedUntil!);

  _PinState copyWith({
    PinScreenStep? step,
    AppUser? selectedUser,
    String? enteredPin,
    int? failedAttempts,
    DateTime? lockedUntil,
    String? errorMessage,
    bool clearError = false,
    bool? isLoading,
    bool clearLock = false,
  }) => _PinState(
    step: step ?? this.step,
    selectedUser: selectedUser ?? this.selectedUser,
    enteredPin: enteredPin ?? this.enteredPin,
    failedAttempts: failedAttempts ?? this.failedAttempts,
    lockedUntil: clearLock ? null : (lockedUntil ?? this.lockedUntil),
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    isLoading: isLoading ?? this.isLoading,
  );
}

// ── Ekran PIN ─────────────────────────────────────────────────────────────────

class PinScreen extends ConsumerStatefulWidget {
  const PinScreen({super.key});

  @override
  ConsumerState<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends ConsumerState<PinScreen> {
  _PinState _state = const _PinState();
  Timer? _lockTimer;

  @override
  void dispose() {
    _lockTimer?.cancel();
    super.dispose();
  }

  void _selectUser(AppUser user) {
    setState(() => _state = _state.copyWith(
      step: PinScreenStep.enterPin,
      selectedUser: user,
      enteredPin: '',
      clearError: true,
      clearLock: true,
      failedAttempts: 0,
    ));
  }

  void _appendDigit(String digit) {
    if (_state.isLocked) return;
    if (_state.enteredPin.length >= AppConstants.pinLength) return;
    final newPin = _state.enteredPin + digit;
    setState(() => _state = _state.copyWith(enteredPin: newPin, clearError: true));
    if (newPin.length == AppConstants.pinLength) {
      _validatePin(newPin);
    }
  }

  void _backspace() {
    if (_state.enteredPin.isEmpty) return;
    setState(() => _state = _state.copyWith(
      enteredPin: _state.enteredPin.substring(0, _state.enteredPin.length - 1),
      clearError: true,
    ));
  }

  Future<void> _validatePin(String pin) async {
    if (_state.selectedUser == null) return;

    setState(() => _state = _state.copyWith(isLoading: true));

    try {
      final service = ref.read(pinAuthServiceProvider);
      final ok = await service.verifyPin(_state.selectedUser!.id, pin);

      if (ok) {
        await service.saveSession(_state.selectedUser!);
        ref.read(currentSessionProvider.notifier).state = AuthSession(
          user: _state.selectedUser!,
          expiresAt: DateTime.now().add(const Duration(hours: AppConstants.sessionHours)),
        );
        if (mounted) context.go('/home');
      } else {
        final newFails = _state.failedAttempts + 1;
        DateTime? lockUntil;
        String error;

        if (newFails >= AppConstants.maxPinAttempts) {
          lockUntil = DateTime.now().add(
            Duration(seconds: AppConstants.lockoutSeconds),
          );
          error = 'Zablokowano na ${AppConstants.lockoutSeconds}s';
          _startLockTimer(lockUntil);
        } else {
          error = 'Błędny PIN. Pozostało prób: ${AppConstants.maxPinAttempts - newFails}';
        }

        setState(() => _state = _state.copyWith(
          enteredPin: '',
          failedAttempts: newFails,
          lockedUntil: lockUntil,
          errorMessage: error,
          isLoading: false,
        ));
      }
    } catch (e) {
      setState(() => _state = _state.copyWith(
        enteredPin: '',
        errorMessage: 'Błąd połączenia. Sprawdź internet.',
        isLoading: false,
      ));
    }
  }

  void _startLockTimer(DateTime until) {
    _lockTimer?.cancel();
    _lockTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (DateTime.now().isAfter(until)) {
        t.cancel();
        setState(() => _state = _state.copyWith(
          clearLock: true,
          failedAttempts: 0,
          clearError: true,
        ));
      } else {
        setState(() {}); // odśwież licznik
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      body: SafeArea(
        child: _state.step == PinScreenStep.selectUser
            ? _buildSelectUser()
            : _buildEnterPin(),
      ),
    );
  }

  // ── Wybór użytkownika ────────────────────────────────────────────────────────

  Widget _buildSelectUser() {
    final usersAsync = ref.watch(usersListProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.scale, color: Colors.white, size: 56),
          const SizedBox(height: 12),
          const Text(
            'System Ważenia',
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Wybierz użytkownika',
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
          ),
          const SizedBox(height: 40),
          usersAsync.when(
            loading: () => const CircularProgressIndicator(color: Colors.white),
            error: (e, _) => Text('Błąd: $e', style: const TextStyle(color: Colors.red)),
            data: (users) => Column(
              children: users.map((u) => _UserTile(user: u, onTap: () => _selectUser(u))).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Wprowadzanie PIN ─────────────────────────────────────────────────────────

  Widget _buildEnterPin() {
    final remaining = _state.lockedUntil != null
        ? _state.lockedUntil!.difference(DateTime.now()).inSeconds
        : 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // Wstecz
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _state = const _PinState()),
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 16),
              label: const Text('Zmień użytkownika', style: TextStyle(color: Colors.white)),
            ),
          ),
          const Spacer(),
          // Awatar + imię
          CircleAvatar(
            radius: 36,
            backgroundColor: Colors.white.withOpacity(0.15),
            child: Text(
              _state.selectedUser?.name.substring(0, 1).toUpperCase() ?? '?',
              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _state.selectedUser?.name ?? '',
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          if (_state.selectedUser?.isAdmin == true)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.25),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('ADMIN', style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
            ),
          const SizedBox(height: 32),
          // Kropki PIN
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(AppConstants.pinLength, (i) {
              final filled = i < _state.enteredPin.length;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: filled ? Colors.white : Colors.transparent,
                  border: Border.all(color: Colors.white.withOpacity(0.6), width: 2),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          // Błąd / blokada
          if (_state.isLocked)
            Text(
              'Zablokowano na ${remaining}s',
              style: const TextStyle(color: Colors.orangeAccent, fontSize: 13),
            )
          else if (_state.errorMessage != null)
            Text(
              _state.errorMessage!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
          const Spacer(),
          // Numpad
          if (_state.isLoading)
            const CircularProgressIndicator(color: Colors.white)
          else
            _Numpad(
              onDigit: _state.isLocked ? null : _appendDigit,
              onBackspace: _backspace,
            ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ── Widget: kafelek użytkownika ───────────────────────────────────────────────

class _UserTile extends StatelessWidget {
  final AppUser user;
  final VoidCallback onTap;

  const _UserTile({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  child: Text(
                    user.name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                      if (user.isAdmin)
                        const Text('Administrator', style: TextStyle(color: Colors.amber, fontSize: 12)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white54),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Widget: klawiatura PIN ────────────────────────────────────────────────────

class _Numpad extends StatelessWidget {
  final void Function(String digit)? onDigit;
  final VoidCallback onBackspace;

  const _Numpad({required this.onDigit, required this.onBackspace});

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
    ];

    return Column(
      children: [
        ...rows.map((row) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: row.map((d) => _NumKey(label: d, onTap: onDigit == null ? null : () => onDigit!(d))).toList(),
          ),
        )),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const SizedBox(width: 76),
            _NumKey(label: '0', onTap: onDigit == null ? null : () => onDigit!('0')),
            _BackspaceKey(onTap: onBackspace),
          ],
        ),
      ],
    );
  }
}

class _NumKey extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _NumKey({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      height: 76,
      child: Material(
        color: onTap == null
            ? Colors.white.withOpacity(0.05)
            : Colors.white.withOpacity(0.12),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: onTap == null ? Colors.white38 : Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BackspaceKey extends StatelessWidget {
  final VoidCallback onTap;

  const _BackspaceKey({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      height: 76,
      child: Material(
        color: Colors.white.withOpacity(0.08),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: const Center(
            child: Icon(Icons.backspace_outlined, color: Colors.white70, size: 26),
          ),
        ),
      ),
    );
  }
}
