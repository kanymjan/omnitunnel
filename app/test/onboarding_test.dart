import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  testWidgets('первый запуск: выбор языка на двух языках', (tester) async {
    await pumpApp(tester, api: fastApi(), vpn: fastVpn(), lang: null);
    expect(find.text('Выберите язык'), findsOneWidget);
    expect(find.text('Тилди тандаңыз'), findsOneWidget);

    await tester.tap(find.text('Кыргызча'));
    await settle(tester);
    await tester.tap(find.text('Кийинки'));
    await settle(tester);

    expect(find.text('Режимди тандаңыз'), findsOneWidget);
    expect(find.text('OmniTunnel аркылуу кирүү'), findsOneWidget);
    expect(find.text('Өз конфигиңиз'), findsOneWidget);
  });

  testWidgets('домашний экран: два режима (RU)', (tester) async {
    await pumpApp(tester, api: fastApi(), vpn: fastVpn());
    expect(find.text('Выберите режим'), findsOneWidget);
    expect(find.byKey(const Key('mode-managed')), findsOneWidget);
    expect(find.byKey(const Key('mode-byo')), findsOneWidget);
  });

  testWidgets('сценарий A: приватность, согласие, затем регистрация',
      (tester) async {
    final api = fastApi();
    await pumpApp(tester,
        api: api, vpn: fastVpn(), consent: false, registered: false);
    await tester.tap(find.byKey(const Key('mode-managed')));
    await settle(tester);

    expect(find.text('Как работает OmniTunnel'), findsOneWidget);
    expect(api.calls, isEmpty, reason: 'до согласия запросов нет');

    await tester.tap(find.text('Понятно'));
    await settle(tester);
    expect(find.text('Согласие'), findsOneWidget);

    // Без галочки «Продолжить» не работает.
    await tester.tap(find.text('Продолжить'));
    await settle(tester);
    expect(api.calls, isEmpty);

    await tester.tap(find.byKey(const Key('consent-checkbox')));
    await settle(tester);
    await tester.tap(find.text('Продолжить'));
    await settle(tester);

    expect(api.calls.first, 'POST /installations');
    expect(find.text('Не подключено'), findsOneWidget);
  });
}
