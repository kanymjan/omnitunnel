import 'package:flutter_test/flutter_test.dart';
import 'package:omnitunnel/app/settings.dart';

import 'helpers.dart';

void main() {
  testWidgets('US-OT08: удаление данных с подтверждением', (tester) async {
    final api = fastApi();
    final container =
        await pumpApp(tester, api: api, vpn: fastVpn(), location: '/settings');

    await tester.tap(find.text('Удалить мои данные'));
    await settle(tester);
    expect(find.text('Удалить ваши данные?'), findsOneWidget);

    await tester.tap(find.text('Удалить данные'));
    await settle(tester);

    expect(find.text('Данные удалены'), findsOneWidget);
    expect(api.calls, contains('DELETE installation'));
    final s = container.read(settingsProvider);
    expect(s.registered, isFalse);
    expect(s.consentVersion, isNull);
    expect(s.languageCode, 'ru');
  });

  testWidgets('смена языка в настройках', (tester) async {
    await pumpApp(tester, api: fastApi(), vpn: fastVpn(), location: '/settings');
    await tester.tap(find.text('Кыргызча'));
    await settle(tester);
    expect(find.text('Жөндөөлөр'), findsOneWidget);
  });
}
