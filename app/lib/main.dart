import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'core/config.dart';
import 'data/fakes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        if (AppConfig.useFakes)
          ...fakeOverrides(FakeScenario.parse(AppConfig.fakeScenario)),
      ],
      child: const OmniTunnelApp(),
    ),
  );
}
