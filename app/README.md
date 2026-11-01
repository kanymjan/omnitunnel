# OmniTunnel — Flutter UI (app/)

Экраны, навигация и тексты RU/KY для пилота OmniTunnel (только Android).
Исполнитель: Kanymjan. Стек по ТЗ: Flutter, Riverpod, русский и кыргызский.

> ⚠️ По ТЗ промышленный код начинается после подписи **G0-10**.
> Пока она не подписана, считать этот код прототипом.

## Что готово

| Тикет | Что сделано | Статус |
|---|---|---|
| MOB-101 | Два режима в отдельных стеках навигации; загрузка, отказ в разрешении, офлайн, ошибка; в BYO нет HTTP и таймера | готово на заглушках |
| MOB-202 (экраны) | Пусто, вставка, неверно, сохранено, подтверждение удаления, QR; только endpoint и туннельный адрес; ключ замазан | готово на заглушках |
| MOB-302 | Таймер из `GET /trials/current` (deadline − server_time), отсчёт по монотонным часам, на нуле — вопрос серверу | готово на заглушках |
| MOB-501 | Узел недоступен, нет мест, разрешение запрещено насовсем, офлайн, истекло, агент задержался | готово на заглушках |
| UX-402 | Нет «анонимности», «kill switch», обхода цензуры и покупки — проверяет тест | готово |
| US-OT08 | Экран удаления данных с подтверждением | ждёт путь API |
| STORE-601 | Снимки RU/KY для Play | после реального телефона |

Ещё нет: подключения к настоящему API и Kotlin (ждёт BE-101 и MOB-101 у
коллег), снимков с телефона, проверки на крупном шрифте на устройстве.

## Запуск

Нужен Flutter 3.32 или новее.

```bash
cd app
# один раз: создать папку android/ (существующие файлы не перезапишутся)
flutter create . --platforms=android --org kg.omnitunnel --project-name omnitunnel
flutter pub get
flutter gen-l10n
flutter analyze
flutter test
flutter run
```

По умолчанию приложение работает **на заглушках** (`lib/data/fakes.dart`):
они ведут себя по правилам ТЗ — ACTIVE только после «ACK узла», срок задаёт
«сервер», вторая выдача получает 403. Сценарии сбоев для показа:

```bash
flutter run --dart-define=OT_FAKE_SCENARIO=offline
# также: server_down, no_capacity, slow_agent, permission_denied,
#        permission_denied_permanently, expired
```

Настоящая сборка, когда будут API и Kotlin:

```bash
flutter run --dart-define=OT_FAKES=false --dart-define=OT_API_BASE=https://…
```

После `flutter create` владелец проекта ставит `targetSdk = 36` и тип
VPN foreground service в `android/app/build.gradle.kts` и манифесте
(раздел 1.13); это делают Sohipjon и владелец, не Flutter.

## Устройство кода

```
lib/
  app/        провайдеры, настройки, маршруты (два ShellRoute), MaterialApp
  core/       сборочные настройки, маскировка секретов, ключи идемпотентности
  data/api/   клиент API раздела 1.7 и модели
  data/fakes  заглушки API и Kotlin
  platform/   контракты method channel: vpn, keys, byo
  features/   onboarding, managed, byo, settings
  ui/         тема «стекло и свет», общие виджеты, экраны сбоев
  l10n/       app_ru.arb, app_ky.arb — все видимые строки
test/         widget-тесты и проверки правил ТЗ
docs/         CONTRACTS.md — что согласовать с Evgeniy и Sohipjon
```

Ключи строк — `screenElement` (раздел 3.4 просит `screen.element`, но ARB
требует имён без точек). Оба файла правятся в одном коммите.

## Что проверяют тесты

- RU и KY содержат одни и те же ключи; нет запрещённых слов и покупки.
- Код BYO не импортирует клиент API и HTTP; в BYO ноль запросов к OmniTunnel, нет таймера.
- Таймер берёт время сервера, а не телефона.
- «Подключено» показывается, только когда так говорит Kotlin.
- Закрытый ключ не появляется на экране; вместо него маркер.
- Экраны сбоев MOB-501 на русском и кыргызском.
- Сценарий A: приватность → согласие → регистрация; до согласия запросов нет.
- Удаление данных и смена языка.

## Шрифты

Onest и Unbounded из Google Fonts, лицензия SIL OFL (`assets/fonts/OFL-*.txt`).
