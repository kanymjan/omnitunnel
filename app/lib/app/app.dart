import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../ui/theme.dart';
import 'router.dart';
import 'settings.dart';

class OmniTunnelApp extends ConsumerWidget {
  const OmniTunnelApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final lang = ref.watch(settingsProvider.select((s) => s.languageCode));
    return MaterialApp.router(
      title: 'OmniTunnel',
      debugShowCheckedModeBanner: false,
      theme: buildOtTheme(),
      locale: lang == null ? null : Locale(lang),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      // До выбора языка: кыргызский, если он у телефона, иначе русский.
      localeResolutionCallback: (device, supported) =>
          device?.languageCode == 'ky' ? const Locale('ky') : const Locale('ru'),
      routerConfig: router,
    );
  }
}
