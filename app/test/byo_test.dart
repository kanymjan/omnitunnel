import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnitunnel/data/fakes.dart';
import 'package:omnitunnel/platform/byo_store.dart';

import 'helpers.dart';

const _config = '[Interface]\n'
    'PrivateKey = SECRET_PRIVATE_KEY_123=\n'
    'Address = 10.9.0.2/32\n'
    'DNS = 1.1.1.1\n'
    '\n'
    '[Peer]\n'
    'PublicKey = SERVER_PUBLIC\n'
    'Endpoint = vpn.test:51820\n'
    'AllowedIPs = 0.0.0.0/0\n';

void main() {
  testWidgets('US-OT06/07: в BYO ноль запросов к OmniTunnel и нет таймера',
      (tester) async {
    final api = fastApi();
    await pumpApp(tester, api: api, vpn: fastVpn(), location: '/byo');

    expect(find.text('Нет сохранённых конфигов'), findsOneWidget);
    expect(find.text('Осталось'), findsNothing);
    expect(api.calls, isEmpty);
  });

  testWidgets('MOB-202: вставка — ключ замазан, сохраняется только адрес',
      (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async =>
          call.method == 'Clipboard.getData' ? {'text': _config} : null,
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    final api = fastApi();
    await pumpApp(tester, api: api, vpn: fastVpn(), location: '/byo');

    await tester.tap(find.text('Вставить'));
    await settle(tester);
    await tester.tap(find.byKey(const Key('byo-paste-from-clipboard')));
    await settle(tester);

    expect(find.byKey(const Key('byo-masked-preview')), findsOneWidget);
    expect(find.textContaining('SECRET_PRIVATE_KEY_123'), findsNothing);
    expect(find.textContaining('PrivateKey = ••••••••'), findsOneWidget);

    await tester.tap(find.text('Сохранить'));
    await settle(tester);

    expect(find.text('Мой конфиг'), findsOneWidget);
    expect(find.text('vpn.test:51820'), findsOneWidget);
    expect(find.text('10.9.0.2/32'), findsOneWidget);
    expect(find.byKey(const Key('byo-key-mask')), findsOneWidget);
    expect(find.textContaining('SECRET_PRIVATE_KEY_123'), findsNothing);
    expect(find.text('Осталось'), findsNothing);
    expect(api.calls, isEmpty);
  });

  testWidgets('MOB-202: неверный конфиг отвергнут', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => call.method == 'Clipboard.getData'
          ? {'text': 'просто текст'}
          : null,
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    await pumpApp(tester, api: fastApi(), vpn: fastVpn(), location: '/byo');
    await tester.tap(find.text('Вставить'));
    await settle(tester);
    await tester.tap(find.byKey(const Key('byo-paste-from-clipboard')));
    await settle(tester);
    await tester.tap(find.text('Сохранить'));
    await settle(tester);

    expect(find.text('Конфиг не распознан. Проверьте, что это файл WireGuard.'),
        findsOneWidget);
  });

  testWidgets('BYO подключается без API', (tester) async {
    final api = fastApi();
    final vpn = fastVpn();
    await pumpApp(
      tester,
      api: api,
      vpn: vpn,
      byo: FakeByoStore(
        latency: Duration.zero,
        initial: const ByoSummary(
            endpoint: 'vpn.test:51820', tunnelAddress: '10.9.0.2/32'),
      ),
      location: '/byo',
    );

    await tester.tap(find.text('Подключить'));
    await settle(tester);

    expect(vpn.calls, containsAllInOrder(['prepareVpn', 'connect:byo']));
    expect(find.text('Подключено'), findsOneWidget);
    expect(find.text('Осталось'), findsNothing);
    expect(api.calls, isEmpty);
  });

  testWidgets('удаление конфига с подтверждением', (tester) async {
    await pumpApp(
      tester,
      api: fastApi(),
      vpn: fastVpn(),
      byo: FakeByoStore(
        latency: Duration.zero,
        initial: const ByoSummary(
            endpoint: 'vpn.test:51820', tunnelAddress: '10.9.0.2/32'),
      ),
      location: '/byo',
    );

    await tester.tap(find.text('Удалить конфиг'));
    await settle(tester);
    expect(find.text('Удалить конфиг?'), findsOneWidget);

    await tester.tap(find.text('Удалить'));
    await settle(tester);
    expect(find.text('Нет сохранённых конфигов'), findsOneWidget);
  });
}
