# Контракты, которые нужно согласовать

ТЗ (редакция 1.2) называет пути API и методы channel, но не описывает
точный формат. Ниже — что Flutter сейчас ожидает. Всё помечено как
**допущение**: при расхождении правится один файл, экраны не трогаются.

## 1. API Django — с Evgeniy (BE-101, BE-201, BE-202, BE-301)

Файл: `lib/data/api/http_omni_api.dart`, модели — `lib/data/api/models.dart`.
Базовый путь `/api/v1`, JSON, время в UTC.

| Запрос | Что шлёт Flutter | Что ждёт в ответ |
|---|---|---|
| `POST /installations` | `{"public_key": "...", "consent_version": 1}` | любой 2xx |
| `GET /nodes` | — | список или `{"results": [...]}`; элемент `{"id", "label", "alive"}` |
| `POST /trials` | заголовок `Idempotency-Key` | `{"id", "state", "server_time", "deadline"}` |
| `GET /trials/current` | — | то же; **404 = выдачи нет** |
| `POST /peers` | заголовок `Idempotency-Key` | `{"id", "tunnel_address", "server_config": {...}}` |
| `DELETE /peers/{id}` | — | 2xx или 404 |

Ошибки: тело `{"code": "..."}`. Flutter различает коды:
`TRIAL_EXISTS` (403, вторая выдача), `NO_CAPACITY` (403, нет мест), 429 — throttle.

Состояния выдачи: `NEW`, `PROVISIONING`, `ACTIVE`, `EXPIRED`, `CANCELLED`.

**Удаление установки (US-OT08, PRI-401)** — пути в разделе 1.7 нет.
Клиент сейчас бросает `ApiNotInContract`, экран показывает
«Удаление станет доступно, когда сервер его поддержит». Конечную точку
не выдумываем: ждём, когда Evgeniy добавит её в раздел 1.7.

## 2. Kotlin method channel — с Sohipjon (MOB-101, MOB-102, MOB-202, MOB-301)

### `omnitunnel/vpn` — из ТЗ (раздел 1.8)

| Метод | Аргументы | Ответ |
|---|---|---|
| `prepareVpn` | — | `"granted"`, `"denied"`, `"denied_permanently"` |
| `connect` | `{"mode": "managed", "peerId", "tunnelAddress", "serverConfig"}` или `{"mode": "byo"}` | — |
| `disconnect` | — | — |
| `getState` | — | `"connecting"`, `"connected"`, `"disconnected"` |

Неизвестное значение Flutter считает `disconnected`: «подключено» не
показывается, пока Kotlin не сказал этого явно. Состояние опрашивается
раз в секунду; если появится EventChannel, меняется только `watchState()`.

### `omnitunnel/keys` — допущение (MOB-102)

| Метод | Ответ |
|---|---|
| `getPublicKey` | открытый ключ установки (строка) |
| `signRequest` `{"method", "path", "body"}` | заголовки доказательства владения `{"...": "..."}` |
| `reset` | — |

Схема подписи не описана в ТЗ — нужна договорённость Evgeniy + Sohipjon.

### `omnitunnel/byo` — допущение (MOB-202)

Методы `load`, `importText {"text"}`, `importFile`, `importQr`, `delete`.
Ответ: `{"status": "ok", "endpoint", "tunnelAddress"}` или
`{"status": "invalid" | "too_large" | "cancelled"}`.

**Закрытый ключ в ответе не нужен и Flutter его не читает.**
Камеру для QR и выбор файла открывает Kotlin.
