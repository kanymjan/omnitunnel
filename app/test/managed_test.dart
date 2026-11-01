import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnitunnel/app/providers.dart';
import 'package:omnitunnel/data/api/models.dart';
import 'package:omnitunnel/data/fakes.dart';
import 'package:omnitunnel/platform/vpn_channel.dart';

import 'helpers.dart';

String _countdown(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('countdown-text'))).data!;

void main() {
  testWidgets('MOB-302: таймер считает по времени сервера, не телефона',
      (tester) async {
    // Часы «сервера» далеко от часов телефона.
    final serverNow = DateTime.utc(2026, 1, 1, 12);
    final api = FakeOmniApi(
      latency: Duration.zero,
      serverNow: () => serverNow,
      initialTrial: TrialInfo(
        id: 't',
        state: TrialState.active,
        serverTime: serverNow,
        deadline: serverNow.add(const Duration(minutes: 24, seconds: 13)),
      ),
    );
    await pumpApp(tester,
        api: api,
        vpn: FakeVpnChannel(initial: TunnelStatus.connected),
        location: '/managed');

    expect(find.text('Подключено'), findsOneWidget);
    // По часам телефона срок давно прошёл бы (00:00). По серверу — 24:1x.
    expect(_countdown(tester), startsWith('24:1'));
    expect(api.calls, contains('GET /trials/current'));
  });

  testWidgets('US-OT05: «Подключено» только когда так говорит Kotlin',
      (tester) async {
    final api = fastApi();
    final vpn = fastVpn(connectDelay: null); // Kotlin застрял в connecting
    await pumpApp(tester, api: api, vpn: vpn, location: '/managed');

    await tester.tap(find.byKey(const Key('access-orb')));
    await settle(tester);

    expect(api.calls, containsAllInOrder(['POST /trials', 'POST /peers']));
    expect(vpn.calls, contains('connect:managed'));
    expect(find.text('Подключение…'), findsOneWidget);
    expect(find.text('Подключено'), findsNothing);
  });

  testWidgets('обычная выдача: подключено, адрес туннеля, таймер ≈ 30 минут',
      (tester) async {
    await pumpApp(tester,
        api: fastApi(), vpn: fastVpn(), location: '/managed');
    await tester.tap(find.byKey(const Key('access-orb')));
    await settle(tester);

    expect(find.text('Подключено'), findsOneWidget);
    expect(find.text('10.8.0.12'), findsOneWidget);
    expect(_countdown(tester), anyOf('30:00', startsWith('29:5')));
  });

  testWidgets('отключение: пир удаляется, туннель опущен', (tester) async {
    final api = fastApi();
    final vpn = fastVpn();
    await pumpApp(tester, api: api, vpn: vpn, location: '/managed');
    await tester.tap(find.byKey(const Key('access-orb')));
    await settle(tester);

    await tester.tap(find.text('Отключить'));
    await settle(tester);

    expect(vpn.calls.last, 'disconnect');
    expect(api.calls.last, startsWith('DELETE /peers/'));
    expect(find.text('Подключено'), findsNothing);
    expect(find.text('Подключить'), findsOneWidget);
  });

  testWidgets('истечение по решению сервера', (tester) async {
    await pumpApp(tester,
        api: fastApi(scenario: FakeScenario.expired),
        vpn: fastVpn(),
        location: '/managed');
    expect(find.text('Время доступа закончилось'), findsOneWidget);
    expect(find.textContaining('VPN отключён'), findsOneWidget);
  });

  group('MOB-501: экраны сбоев', () {
    testWidgets('нет интернета (RU и KY)', (tester) async {
      await pumpApp(tester,
          api: fastApi(scenario: FakeScenario.offline),
          vpn: fastVpn(),
          location: '/managed');
      expect(find.text('Нет подключения к интернету'), findsOneWidget);
      expect(find.text('Повторить'), findsOneWidget);
    });

    testWidgets('нет интернета на кыргызском', (tester) async {
      await pumpApp(tester,
          api: fastApi(scenario: FakeScenario.offline),
          vpn: fastVpn(),
          lang: 'ky',
          location: '/managed');
      expect(find.text('Интернет байланышы жок'), findsOneWidget);
    });

    testWidgets('сервер недоступен', (tester) async {
      await pumpApp(tester,
          api: fastApi(scenario: FakeScenario.serverDown),
          vpn: fastVpn(),
          location: '/managed');
      expect(find.text('Сервер сейчас недоступен'), findsOneWidget);
    });

    testWidgets('нет свободных мест', (tester) async {
      await pumpApp(tester,
          api: fastApi(scenario: FakeScenario.noCapacity),
          vpn: fastVpn(),
          location: '/managed');
      await tester.tap(find.byKey(const Key('access-orb')));
      await settle(tester);
      expect(find.text('Сейчас нет свободных мест'), findsOneWidget);
    });

    testWidgets('разрешение VPN запрещено насовсем', (tester) async {
      await pumpApp(tester,
          api: fastApi(),
          vpn: fastVpn(scenario: FakeScenario.permissionDeniedPermanently),
          location: '/managed');
      await tester.tap(find.byKey(const Key('access-orb')));
      await settle(tester);
      expect(find.text('Разрешите VPN в настройках телефона'), findsOneWidget);
    });

    testWidgets('агент узла задержался', (tester) async {
      await pumpApp(
        tester,
        api: fastApi(scenario: FakeScenario.slowAgent),
        vpn: fastVpn(),
        location: '/managed',
        timing: const ManagedTiming(
          poll: Duration(milliseconds: 10),
          slowAfter: Duration.zero,
          resync: Duration(seconds: 30),
          tick: Duration(milliseconds: 200),
        ),
      );
      await tester.tap(find.byKey(const Key('access-orb')));
      await settle(tester);
      expect(find.text('Сервер отвечает дольше обычного'), findsOneWidget);
      expect(find.text('Подключено'), findsNothing);
    });
  });
}
