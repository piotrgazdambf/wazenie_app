import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';

const _seededSuppliers = <Map<String, String>>[
  {'kod': '000', 'nazwa': 'MBF'},
  {'kod': '001', 'nazwa': 'Budziński Mariusz'},
  {'kod': '002', 'nazwa': 'Fijka Roman'},
  {'kod': '003', 'nazwa': 'Trade Trap Traczyk Marianna'},
  {'kod': '004', 'nazwa': 'Świątek Piotr'},
  {'kod': '005', 'nazwa': 'Łozowski Adam'},
  {'kod': '006', 'nazwa': 'Kurant Grzegorz'},
  {'kod': '007', 'nazwa': 'Rog Sad'},
  {'kod': '008', 'nazwa': 'Mazur Piotr'},
  {'kod': '009', 'nazwa': 'Pawlica Monika'},
  {'kod': '010', 'nazwa': 'Łozowski Artur'},
  {'kod': '011', 'nazwa': 'Jabłońska Barbara'},
  {'kod': '012', 'nazwa': 'Sortpak'},
  {'kod': '013', 'nazwa': 'Sobiepanek Krzysztof'},
  {'kod': '014', 'nazwa': 'Krawczak Marzanna'},
  {'kod': '015', 'nazwa': 'Tompex'},
  {'kod': '016', 'nazwa': 'Bąk Wojciech'},
  {'kod': '017', 'nazwa': 'Fijka Teresa'},
  {'kod': '018', 'nazwa': 'Regulski Rogsad'},
  {'kod': '019', 'nazwa': 'Konrad Zwierzyński'},
  {'kod': '020', 'nazwa': 'Kochanowska Violetta'},
  {'kod': '021', 'nazwa': 'Naduk Monika'},
  {'kod': '022', 'nazwa': 'Sung Pol'},
  {'kod': '023', 'nazwa': 'Ciżdziel Elżbieta'},
  {'kod': '024', 'nazwa': 'Łukawski Sylwester'},
  {'kod': '025', 'nazwa': 'Paprocki'},
  {'kod': '026', 'nazwa': 'Ryl Pol'},
  {'kod': '027', 'nazwa': 'Szynkiewicz Jan'},
  {'kod': '028', 'nazwa': 'Gulba Waldemar MBF'},
  {'kod': '029', 'nazwa': 'Oliwia'},
  {'kod': '030', 'nazwa': 'Jakubczyk'},
  {'kod': '031', 'nazwa': 'Mroziak Ula'},
  {'kod': '032', 'nazwa': 'Jakubowski Henryk'},
  {'kod': '033', 'nazwa': 'Szynkiewicz Jacek'},
  {'kod': '034', 'nazwa': 'Wróbel Dariusz'},
  {'kod': '050', 'nazwa': 'Wieczorek Kamil'},
  {'kod': '062', 'nazwa': 'Budyta Sławomir'},
  {'kod': '070', 'nazwa': 'Twój Owoc'},
  {'kod': '079', 'nazwa': 'Mariańczyk Zbigniew'},
  {'kod': '197', 'nazwa': 'Van Rossum'},
  {'kod': '218', 'nazwa': 'Luczak Ignacy'},
  {'kod': '265', 'nazwa': 'Ysław'},
  {'kod': '266', 'nazwa': 'Ornysiak Grzegorz'},
  {'id': '266_osinski_roman', 'kod': '266', 'nazwa': 'Osiński Roman'},
  {'kod': '267', 'nazwa': 'Żórawska Anna'},
  {'kod': '268', 'nazwa': 'Retman Krzysztof'},
  {'kod': '269', 'nazwa': 'Kalińska'},
  {'kod': '270', 'nazwa': 'Dominiak Łukasz EKO'},
  {'kod': '271', 'nazwa': 'Widłak Piotr'},
  {'kod': '272', 'nazwa': 'Pilacka Agnieszka'},
  {'kod': '273', 'nazwa': 'Rosłoń Andrzej'},
  {'kod': '274', 'nazwa': 'Wasilewski Grzegorz'},
  {'kod': '275', 'nazwa': 'Żólcik Jarosław'},
  {'kod': '276', 'nazwa': 'Kocyk Marcin'},
  {'kod': '277', 'nazwa': 'Szymański Rafał'},
  {'kod': '278', 'nazwa': 'Glinka Paweł'},
  {'kod': '279', 'nazwa': 'Morawski Rafał'},
  {'kod': '280', 'nazwa': 'Żurawski'},
  {'kod': '281', 'nazwa': 'Szymaniak Piotr'},
  {'kod': '282', 'nazwa': 'Wasilewski Piotr'},
  {'kod': '283', 'nazwa': 'Arczewski'},
  {'kod': '284', 'nazwa': 'Zadorski'},
  {'kod': '285', 'nazwa': 'Łowiecki Zbigniew'},
  {'kod': '292', 'nazwa': 'Olborski Waldemar'},
  {'kod': '294', 'nazwa': 'Kępka Piotr'},
  {'kod': '317', 'nazwa': 'Movena'},
  {'kod': '404', 'nazwa': 'Kuklk'},
  {'kod': '405', 'nazwa': 'Jaworski'},
  {'kod': '406', 'nazwa': 'Wilga Fruit'},
  {'kod': '407', 'nazwa': 'Dobrzyński Marcin'},
  {'kod': '408', 'nazwa': 'Hoffman'},
  {'kod': '409', 'nazwa': 'Chryn Dariusz'},
  {'kod': '410', 'nazwa': 'Warzybok Jacek JABTAR'},
  {'kod': '412', 'nazwa': 'Plny Farm Flasińska'},
  {'kod': '414', 'nazwa': 'Kępka Mariusz EKO'},
  {'kod': '415', 'nazwa': 'Stasiak'},
  {'kod': '416', 'nazwa': 'Stolarski Mariusz'},
  {'kod': '417', 'nazwa': 'Fudecki'},
  {'kod': '418', 'nazwa': 'Ślarzyński Przemysław'},
  {'kod': '419', 'nazwa': 'Paradowska Agnieszka'},
  {'kod': '420', 'nazwa': 'Smaga'},
  {'kod': '421', 'nazwa': 'Mir-Pol'},
  {'kod': '422', 'nazwa': 'Paniec Paweł'},
  {'kod': '423', 'nazwa': 'Jaradys Łukasz'},
  {'kod': '424', 'nazwa': 'Pawelec Paweł'},
  {'kod': '425', 'nazwa': 'Rowalczyk Piotr'},
  {'kod': '426', 'nazwa': 'Multismak'},
  {'kod': '427', 'nazwa': 'Sad-Fruit'},
  {'kod': '428', 'nazwa': 'Lewandowski Adrian'},
  {'kod': '429', 'nazwa': 'Pietrzak Waldemar'},
  {'kod': '430', 'nazwa': 'Pro-Agro'},
  {'kod': '431', 'nazwa': 'ZYSR'},
  {'kod': '432', 'nazwa': 'Pil Paw'},
  {'kod': '433', 'nazwa': 'Rechnio Małgorzata'},
  {'kod': '434', 'nazwa': 'Urbański Janusz'},
  {'kod': '435', 'nazwa': 'Nowak Wojciech'},
  {'kod': '436', 'nazwa': 'Zgieta Bogdan'},
  {'kod': '437', 'nazwa': 'Przychodzeń Mariusz'},
  {'kod': '438', 'nazwa': 'Przychodzeń Sławomir'},
  {'kod': '998', 'nazwa': 'RYLEX'},
  {'kod': '999', 'nazwa': 'GRÓJECKA MBF'},
];

// ── Model użytkownika ────────────────────────────────────────────────────────

class AppUser {
  final String id;
  final String name;
  final UserRole role;

  const AppUser({required this.id, required this.name, required this.role});

  factory AppUser.fromFirestore(String id, Map<String, dynamic> data) {
    return AppUser(
      id: id,
      name: data['name'] as String? ?? '',
      role: data['role'] == 'admin' ? UserRole.admin : UserRole.user,
    );
  }

  bool get isAdmin => role == UserRole.admin;
}

// ── Stan sesji ───────────────────────────────────────────────────────────────

class AuthSession {
  final AppUser user;
  final DateTime expiresAt;

  const AuthSession({required this.user, required this.expiresAt});

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

// ── PIN Auth Service ─────────────────────────────────────────────────────────

class PinAuthService {
  final FirebaseFirestore _db;
  final SharedPreferences _prefs;

  PinAuthService(this._db, this._prefs);

  static String hashPin(String pin) {
    final bytes = utf8.encode(pin);
    return sha256.convert(bytes).toString();
  }

  // ── Inicjalizacja: seed domyślnych użytkowników ──────────────────────────────
  Future<void> seedUsersIfNeeded() async {
    try {
      await _seedInternal().timeout(const Duration(seconds: 15));
    } catch (_) {
      // timeout lub brak połączenia - pomiń seed
    }
  }

  Future<void> _seedInternal() async {
    final col = _db.collection(AppConstants.colUsers);
    final snap = await col.limit(1).get();
    if (snap.docs.isNotEmpty) return; // już istnieją

    // Dane startowe użytkowników aplikacji
    final users = [
      {
        'id': 'piotr_gazda',
        'name': 'Piotr Gazda',
        'pin': hashPin('3344'),
        'role': 'admin',
        'active': true,
      },
      {
        'id': 'daryna_milinchuk',
        'name': 'Daryna Milinchuk',
        'pin': hashPin('0080'),
        'role': 'user',
        'active': true,
      },
      {
        'id': 'mariia_rymar',
        'name': 'Mariia Rymar',
        'pin': hashPin('5221'),
        'role': 'user',
        'active': true,
      },
    ];

    final batch = _db.batch();
    for (final u in users) {
      final id = u['id'] as String;
      batch.set(col.doc(id), u..remove('id'));
    }
    await batch.commit();
  }

  // ── Seed dostawców ───────────────────────────────────────────────────────────
  Future<void> seedSuppliersIfNeeded() async {
    try {
      await _seedSuppliersInternal().timeout(const Duration(seconds: 20));
    } catch (_) {}
  }

  Future<void> _seedSuppliersInternal() async {
    final col = _db.collection(AppConstants.colSuppliers);
    final existingSnap = await col.get();
    final existing = <String, Map<String, dynamic>>{
      for (final d in existingSnap.docs) d.id: d.data(),
    };

    final batch = _db.batch();
    var changes = 0;
    for (final s in _seededSuppliers) {
      final id = s['id'] ?? s['kod']!;
      final current = existing[id];
      final shouldWrite = current == null ||
          current['kod'] != s['kod'] ||
          current['nazwa'] != s['nazwa'];
      if (!shouldWrite) continue;

      batch.set(
        col.doc(id),
        {
          'kod': s['kod'],
          'nazwa': s['nazwa'],
        },
        SetOptions(merge: true),
      );
      changes++;
    }

    if (changes > 0) {
      await batch.commit();
    }
  }

  // ── Pobierz listę aktywnych użytkowników ─────────────────────────────────────
  Future<List<AppUser>> fetchUsers() async {
    final snap = await _db
        .collection(AppConstants.colUsers)
        .where('active', isEqualTo: true)
        .get();
    return snap.docs
        .map((d) => AppUser.fromFirestore(d.id, d.data()))
        .toList()
      ..sort((a, b) {
        // Admin zawsze pierwszy
        if (a.isAdmin && !b.isAdmin) return -1;
        if (!a.isAdmin && b.isAdmin) return 1;
        return a.name.compareTo(b.name);
      });
  }

  // ── Weryfikacja PIN ───────────────────────────────────────────────────────────
  Future<bool> verifyPin(String userId, String pin) async {
    final doc = await _db.collection(AppConstants.colUsers).doc(userId).get();
    if (!doc.exists) return false;
    final data = doc.data()!;
    if (data['active'] != true) return false;
    return data['pin'] == hashPin(pin);
  }

  // ── Zmiana PIN przez admina ───────────────────────────────────────────────────
  Future<void> changePin(String userId, String newPin) async {
    await _db.collection(AppConstants.colUsers).doc(userId).update({
      'pin': hashPin(newPin),
      'pinChangedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Zarządzanie sesją (SharedPreferences) ────────────────────────────────────
  Future<void> saveSession(AppUser user) async {
    final expiry = DateTime.now().add(
      const Duration(hours: AppConstants.sessionHours),
    );
    await _prefs.setString('session_user_id', user.id);
    await _prefs.setString('session_user_name', user.name);
    await _prefs.setString('session_user_role', user.role.name);
    await _prefs.setString('session_expires', expiry.toIso8601String());
  }

  AuthSession? loadSession() {
    final id      = _prefs.getString('session_user_id');
    final name    = _prefs.getString('session_user_name');
    final role    = _prefs.getString('session_user_role');
    final expires = _prefs.getString('session_expires');

    if (id == null || name == null || role == null || expires == null) return null;

    final expiresAt = DateTime.tryParse(expires);
    if (expiresAt == null) return null;

    final user = AppUser(
      id: id,
      name: name,
      role: role == 'admin' ? UserRole.admin : UserRole.user,
    );
    final session = AuthSession(user: user, expiresAt: expiresAt);
    if (session.isExpired) {
      clearSession();
      return null;
    }
    return session;
  }

  Future<void> clearSession() async {
    await _prefs.remove('session_user_id');
    await _prefs.remove('session_user_name');
    await _prefs.remove('session_user_role');
    await _prefs.remove('session_expires');
  }
}

// ── Providers ────────────────────────────────────────────────────────────────

final pinAuthServiceProvider = Provider<PinAuthService>((ref) {
  throw UnimplementedError('Override in ProviderScope');
});

final currentSessionProvider = StateProvider<AuthSession?>((ref) => null);

final usersListProvider = FutureProvider<List<AppUser>>((ref) async {
  return ref.read(pinAuthServiceProvider).fetchUsers();
});
