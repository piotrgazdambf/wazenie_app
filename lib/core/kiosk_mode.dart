import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kKioskCode    = 'SKANER';
const _kKioskPrefKey = 'kiosk_mode_active';

// ── Provider trwałego stanu kiosku ────────────────────────────────────────────

class KioskModeNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kKioskPrefKey) ?? false;
  }

  Future<void> activate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kKioskPrefKey, true);
    state = const AsyncData(true);
  }

  Future<void> deactivate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kKioskPrefKey, false);
    state = const AsyncData(false);
  }
}

final kioskModeProvider = AsyncNotifierProvider<KioskModeNotifier, bool>(
  KioskModeNotifier.new,
);
