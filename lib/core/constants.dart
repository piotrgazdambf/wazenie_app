/// Globalne stałe projektu.
class AppConstants {
  AppConstants._();

  // ── Wersja ──────────────────────────────────────────────────────────────────
  static const String appVersion = '1.0.0';

  // ── Firestore kolekcje ───────────────────────────────────────────────────────
  static const String colUsers       = 'users';
  static const String colDeliveries  = 'deliveries';
  static const String colPls         = 'pls';
  static const String colMcrQueue    = 'mcrQueue';
  static const String colInventory   = 'inventory';
  static const String colSuppliers   = 'suppliers';
  static const String colCrateActions = 'crateActions';
  static const String colCrateStates  = 'crateStates';
  static const String colKwDocs      = 'kwDocs';
  static const String colAppConfig   = 'appConfig';

  // ── Firebase Remote Config klucze ───────────────────────────────────────────
  static const String rcMinVersion        = 'min_version';
  static const String rcMaintenanceMode   = 'maintenance_mode';
  static const String rcAndroidStoreUrl   = 'android_store_url';
  static const String rcIosStoreUrl       = 'ios_store_url';

  // ── Hive boxy ────────────────────────────────────────────────────────────────
  static const String hiveBoxOffline  = 'offline_queue';
  static const String hiveBoxSession  = 'session';

  // ── Auth ─────────────────────────────────────────────────────────────────────
  static const int pinLength         = 4;
  static const int maxPinAttempts    = 3;
  static const int lockoutSeconds    = 30;
  static const int sessionHours      = 8;

  // ── Offline buffer ────────────────────────────────────────────────────────────
  static const int offlineWarningThreshold = 10;

}

/// Role użytkowników.
enum UserRole { admin, user }

extension UserRoleX on UserRole {
  String get name => this == UserRole.admin ? 'admin' : 'user';
  static UserRole fromString(String s) =>
      s == 'admin' ? UserRole.admin : UserRole.user;
}
