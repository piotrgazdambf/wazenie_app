import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../constants.dart';

class RemoteConfigService {
  final FirebaseRemoteConfig _rc;

  RemoteConfigService(this._rc);

  Future<void> init() async {
    await _rc.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 15),
      minimumFetchInterval: const Duration(hours: 1),
    ));

    // Domyślne wartości — fallback gdy brak internetu
    await _rc.setDefaults({
      AppConstants.rcMinVersion:      '1.0.0',
      AppConstants.rcMaintenanceMode: false,
      AppConstants.rcAndroidStoreUrl: 'https://play.google.com/store',
      AppConstants.rcIosStoreUrl:     'https://apps.apple.com',
    });

    try {
      await _rc.fetchAndActivate();
    } catch (_) {
      // Offline — używamy domyślnych wartości
    }
  }

  String get minVersion     => _rc.getString(AppConstants.rcMinVersion);
  bool   get maintenanceMode => _rc.getBool(AppConstants.rcMaintenanceMode);
  String get androidStoreUrl => _rc.getString(AppConstants.rcAndroidStoreUrl);
  String get iosStoreUrl     => _rc.getString(AppConstants.rcIosStoreUrl);

  /// Zwraca true gdy wymagana aktualizacja.
  Future<bool> isUpdateRequired() async {
    final info = await PackageInfo.fromPlatform();
    final current = _parseVersion(info.version);
    final required = _parseVersion(minVersion);
    return _versionCompare(current, required) < 0;
  }

  List<int> _parseVersion(String v) {
    return v.split('.').map((s) => int.tryParse(s) ?? 0).toList();
  }

  int _versionCompare(List<int> a, List<int> b) {
    final len = a.length > b.length ? a.length : b.length;
    for (int i = 0; i < len; i++) {
      final ai = i < a.length ? a[i] : 0;
      final bi = i < b.length ? b[i] : 0;
      if (ai != bi) return ai.compareTo(bi);
    }
    return 0;
  }
}

final remoteConfigServiceProvider = Provider<RemoteConfigService>((ref) {
  throw UnimplementedError('Override in ProviderScope');
});

final forceUpdateProvider = FutureProvider<bool>((ref) async {
  // Na web force-update nie ma sensu (brak sklepów)
  if (kIsWeb) return false;
  try {
    final rc = ref.read(remoteConfigServiceProvider);
    await rc.init().timeout(const Duration(seconds: 10));
    if (rc.maintenanceMode) return true;
    return await rc.isUpdateRequired().timeout(const Duration(seconds: 5));
  } catch (_) {
    return false;
  }
});
