import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/byo/byo_home_screen.dart';
import '../features/byo/byo_paste_screen.dart';
import '../features/byo/byo_qr_screen.dart';
import '../features/managed/managed_screen.dart';
import '../features/onboarding/language_screen.dart';
import '../features/onboarding/mode_screen.dart';
import '../features/onboarding/privacy_screen.dart';
import '../features/settings/settings_screen.dart';
import 'settings.dart';

abstract final class Routes {
  static const language = '/language';
  static const home = '/home';
  static const managed = '/managed';
  static const byo = '/byo';
  static const byoPaste = '/byo/paste';
  static const byoQr = '/byo/qr';
  static const settings = '/settings';
  static const settingsPrivacy = '/settings/privacy';
}

/// Управляемый режим и BYO — два отдельных ShellRoute, у каждого свой
/// Navigator (раздел 3.3: «разные стеки навигации»).
///
/// Код BYO (lib/features/byo/) не импортирует клиент API и HTTP.
/// Это проверяет test/architecture_test.dart, а
/// test/byo_test.dart проверяет, что в BYO ноль запросов к OmniTunnel.
final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: Routes.home,
    redirect: (context, state) {
      final lang = ref.read(settingsProvider).languageCode;
      final loc = state.matchedLocation;
      if (lang == null && loc != Routes.language) return Routes.language;
      if (loc == '/') return Routes.home;
      return null;
    },
    routes: [
      GoRoute(path: '/', redirect: (context, state) => Routes.home),
      GoRoute(
        path: Routes.language,
        builder: (context, state) => const LanguageScreen(),
      ),
      GoRoute(
        path: Routes.home,
        builder: (context, state) => const ModeScreen(),
      ),
      GoRoute(
        path: Routes.settings,
        builder: (context, state) => const SettingsScreen(),
        routes: [
          GoRoute(
            path: 'privacy',
            builder: (context, state) => const PrivacyScreen(),
          ),
        ],
      ),
      ShellRoute(
        builder: (context, state, child) => child,
        routes: [
          GoRoute(
            path: Routes.managed,
            builder: (context, state) => const ManagedScreen(),
          ),
        ],
      ),
      ShellRoute(
        builder: (context, state, child) => child,
        routes: [
          GoRoute(
            path: Routes.byo,
            builder: (context, state) => const ByoHomeScreen(),
            routes: [
              GoRoute(
                path: 'paste',
                builder: (context, state) => const ByoPasteScreen(),
              ),
              GoRoute(
                path: 'qr',
                builder: (context, state) => const ByoQrScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
