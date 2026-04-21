import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'core/auth/pin_auth_service.dart';
import 'core/firebase/remote_config_service.dart';
import 'core/offline/hive_buffer.dart';
import 'core/offline/sync_manager.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Firebase ────────────────────────────────────────────────────────────────
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Firestore offline persistence
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // ── Hive ─────────────────────────────────────────────────────────────────────
  await Hive.initFlutter();
  await HiveBuffer.openBoxes();

  // ── SharedPreferences ────────────────────────────────────────────────────────
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        // Wstrzyknięcie serwisów z prawdziwymi zależnościami
        pinAuthServiceProvider.overrideWithValue(
          PinAuthService(FirebaseFirestore.instance, prefs),
        ),
        remoteConfigServiceProvider.overrideWithValue(
          RemoteConfigService(FirebaseRemoteConfig.instance),
        ),
      ],
      child: const _AppInit(),
    ),
  );
}

/// Inicjalizacja po uruchomieniu ProviderScope.
class _AppInit extends ConsumerStatefulWidget {
  const _AppInit();

  @override
  ConsumerState<_AppInit> createState() => _AppInitState();
}

class _AppInitState extends ConsumerState<_AppInit> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Seed użytkowników jeśli pierwsza instalacja
    await ref.read(pinAuthServiceProvider).seedUsersIfNeeded();

    // Seed dostawców jeśli pierwsza instalacja
    await ref.read(pinAuthServiceProvider).seedSuppliersIfNeeded();

    // Wczytaj sesję z pamięci lokalnej
    final session = ref.read(pinAuthServiceProvider).loadSession();
    ref.read(currentSessionProvider.notifier).state = session;

    // Uruchom sync manager
    ref.read(syncManagerProvider).start();

    setState(() => _initialized = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const MaterialApp(
        home: Scaffold(
          backgroundColor: Color(0xFF1E3A5F),
          body: Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
      );
    }

    return const WazenieApp();
  }
}

class WazenieApp extends ConsumerWidget {
  const WazenieApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'System Ważenia',
      theme: AppTheme.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pl', 'PL'),
        Locale('en', 'US'),
      ],
    );
  }
}
