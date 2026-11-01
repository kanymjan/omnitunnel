// Этот файл нужен ещё и затем, чтобы `flutter create .` не положил сюда
// стандартный тест со счётчиком, который не соберётся.
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  testWidgets('приложение запускается на заглушках', (tester) async {
    await pumpApp(tester, api: fastApi(), vpn: fastVpn());
    expect(find.text('Выберите режим'), findsOneWidget);
  });
}
