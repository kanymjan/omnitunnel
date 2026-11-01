import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnitunnel/app/app.dart';
import 'package:omnitunnel/app/providers.dart';
import 'package:omnitunnel/app/router.dart';
import 'package:omnitunnel/app/settings.dart';
import 'package:omnitunnel/core/config.dart';
import 'package:omnitunnel/data/fakes.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Быстрые заглушки: без задержек сети и туннеля.
FakeOmniApi fastApi({
  FakeScenario scenario = FakeScenario.ok,
  DateTime Function()? serverNow,
  Duration provisioningTime = Duration.zero,
}) =>
    FakeOmniApi(
      scenario: scenario,
      latency: Duration.zero,
      provisioningTime: provisioningTime,
      serverNow: serverNow,
    );

FakeVpnChannel fastVpn({
  FakeScenario scenario = FakeScenario.ok,
  Duration? connectDelay = Duration.zero,
}) =>
    FakeVpnChannel(scenario: scenario, connectDelay: connectDelay);

const testTiming = ManagedTiming(
  poll: Duration(milliseconds: 10),
  slowAfter: Duration(seconds: 30),
  resync: Duration(seconds: 30),
  tick: Duration(milliseconds: 200),
);

/// Кадры без pumpAndSettle: на экранах есть бесконечные индикаторы.
Future<void> settle(WidgetTester tester, [int frames = 12]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  required FakeOmniApi api,
  required FakeVpnChannel vpn,
  FakeByoStore? byo,
  String? lang = 'ru',
  bool consent = true,
  bool registered = true,
  String? location,
  ManagedTiming timing = testTiming,
}) async {
  tester.view.physicalSize = const Size(1236, 2700);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({
    if (lang != null) SettingsController.kLang: lang,
    if (consent) SettingsController.kConsent: kConsentVersion,
    if (registered) SettingsController.kRegistered: true,
  });
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        omniApiProvider.overrideWithValue(api),
        vpnChannelProvider.overrideWithValue(vpn),
        installationKeysProvider.overrideWithValue(FakeInstallationKeys()),
        byoStoreProvider
            .overrideWithValue(byo ?? FakeByoStore(latency: Duration.zero)),
        reduceMotionProvider.overrideWithValue(true),
        managedTimingProvider.overrideWithValue(timing),
      ],
      child: const OmniTunnelApp(),
    ),
  );
  await settle(tester);
  final container =
      ProviderScope.containerOf(tester.element(find.byType(OmniTunnelApp)));
  if (location != null) {
    container.read(routerProvider).push(location);
    await settle(tester);
  }
  return container;
}
