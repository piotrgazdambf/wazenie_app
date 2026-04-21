import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/auth/pin_auth_service.dart';
import '../core/firebase/remote_config_service.dart';
import '../core/models/kw_data.dart';
import '../features/admin/catalog_screen.dart';
import '../features/admin/sync_screen.dart';
import '../features/admin/users_screen.dart';
import '../features/auth/pin_screen.dart';
import '../features/force_update/force_update_screen.dart';
import '../features/home/home_screen.dart';
import '../features/kw/kw_screen.dart';
import '../features/kwg/kwg_screen.dart';
import '../features/mcr/mcr_screen.dart';
import '../features/pls/pls_screen.dart';
import '../features/ps/ps_screen.dart';
import '../features/skrzynie/skrzynie_screen.dart';
import '../features/stany/stany_screen.dart';
import '../features/karty/karty_screen.dart';
import '../features/wsg/wsg_screen.dart';

// ── Notifier do odświeżania routera gdy zmienią się providery ────────────────

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(Ref ref) {
    ref.listen<AsyncValue<bool>>(forceUpdateProvider, (_, __) => notifyListeners());
    ref.listen<AuthSession?>(currentSessionProvider, (_, __) => notifyListeners());
  }
}

// ── Router ────────────────────────────────────────────────────────────────────

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: (context, state) {
      final path = state.matchedLocation;

      // Force update — sprawdź stan (synchronicznie, bez await)
      final forceUpdateAsync = ref.read(forceUpdateProvider);

      // Jeszcze ładuje → zostań na splash
      if (forceUpdateAsync.isLoading) {
        return path == '/splash' ? null : '/splash';
      }

      final forceUpdate = forceUpdateAsync.value ?? false;
      if (forceUpdate && path != '/force-update') return '/force-update';
      if (!forceUpdate && path == '/force-update') return '/login';

      // Auth
      final session = ref.read(currentSessionProvider);
      final isLoggedIn = session != null && !session.isExpired;
      final onAuthScreen = path == '/login' || path == '/splash';

      if (isLoggedIn && onAuthScreen) return '/home';
      if (!isLoggedIn && !onAuthScreen) return '/login';
      if (path == '/splash') return '/login';

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, __) => const _SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const PinScreen(),
      ),
      GoRoute(
        path: '/force-update',
        builder: (_, __) => const ForceUpdateScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (_, __) => const HomeScreen(),
      ),
      GoRoute(path: '/wsg/new', builder: (_, __) => const WsgScreen()),
      GoRoute(
        path: '/kw/new',
        builder: (_, state) {
          final data = state.extra as WsgInputData;
          return KwScreen(data: data);
        },
      ),
      GoRoute(
        path: '/kwg/new',
        builder: (_, state) {
          final data = state.extra as WsgInputData;
          return KwgScreen(data: data);
        },
      ),
      GoRoute(path: '/pls', builder: (_, __) => const PlsScreen()),
      GoRoute(path: '/stany', builder: (_, __) => const StanyScreen()),
      GoRoute(path: '/mcr', builder: (_, __) => const McrScreen()),
      GoRoute(path: '/skrzynie', builder: (_, __) => const SkrzynieScreen()),
      GoRoute(path: '/ps', builder: (_, __) => const PsScreen()),
      GoRoute(path: '/karty', builder: (_, __) => const KartyScreen()),
      GoRoute(path: '/admin/users', builder: (_, __) => const UsersScreen()),
      GoRoute(path: '/admin/sync', builder: (_, __) => const SyncScreen()),
      GoRoute(path: '/admin/catalog', builder: (_, __) => const CatalogScreen()),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Błąd: ${state.error}')),
    ),
  );
});

// ── Splash screen (inicjalizacja) ─────────────────────────────────────────────

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF1E3A5F),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.scale, color: Colors.white, size: 72),
            SizedBox(height: 20),
            Text(
              'System Ważenia',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 40),
            CircularProgressIndicator(color: Colors.white54),
          ],
        ),
      ),
    );
  }
}
