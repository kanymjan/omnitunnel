/// Сборочные настройки. Меняются через --dart-define, без правки кода.
///
/// Пока нет API Django (BE-101) и Kotlin channel (MOB-101), приложение
/// по умолчанию работает на заглушках из lib/data/fakes.dart.
/// Настоящая сборка: --dart-define=OT_FAKES=false --dart-define=OT_API_BASE=https://…
abstract final class AppConfig {
  static const bool useFakes =
      bool.fromEnvironment('OT_FAKES', defaultValue: true);

  /// Базовый адрес API без /api/v1. Задаёт владелец; в Git не хранится.
  static const String apiBase =
      String.fromEnvironment('OT_API_BASE', defaultValue: '');

  /// Сценарий заглушек для показа и ручной проверки экранов:
  /// ok, offline, server_down, no_capacity, slow_agent,
  /// permission_denied, permission_denied_permanently, expired.
  static const String fakeScenario =
      String.fromEnvironment('OT_FAKE_SCENARIO', defaultValue: 'ok');
}

/// Версия текста согласия. Сервер хранит её в ConsentReceipt.
const int kConsentVersion = 1;

/// Длительность одной выдачи. Только для рисования кольца таймера:
/// сам срок задаёт сервер (deadline), Flutter его не считает.
const Duration kTrialLength = Duration(minutes: 30);
