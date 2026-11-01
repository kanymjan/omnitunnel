import 'models.dart';

/// Ошибки API. Коды по разделу 1.7: 403 отказ, 409 конфликт
/// идемпотентности, 422 плохой ввод, 429 throttle.
sealed class ApiFailure implements Exception {
  const ApiFailure();
}

/// Нет сети на телефоне.
class ApiOffline extends ApiFailure {
  const ApiOffline();
}

/// Сервер не ответил вовремя или вернул 5xx.
class ApiUnavailable extends ApiFailure {
  const ApiUnavailable();
}

/// Сервер отказал: 403, 409, 422, 429. [code] — из каталога ошибок API (CODE.detail).
class ApiRejected extends ApiFailure {
  const ApiRejected(this.status, [this.code]);
  final int status;
  final String? code;
}

/// Путь ещё не описан в разделе 1.7. Не выдумываем конечные точки.
class ApiNotInContract extends ApiFailure {
  const ApiNotInContract(this.what);
  final String what;
}

/// Клиент API управляемого режима. В BYO его использовать нельзя:
/// маршрут BYO подменяет провайдер на запрет (см. lib/app/router.dart).
abstract interface class OmniApi {
  /// POST /installations — после согласия. Только открытый ключ.
  Future<void> registerInstallation({
    required String publicKey,
    required int consentVersion,
  });

  /// GET /nodes
  Future<List<NodeInfo>> getNodes();

  /// POST /trials — идемпотентно.
  Future<TrialInfo> createTrial({required String idempotencyKey});

  /// POST /peers — идемпотентно.
  Future<PeerInfo> createPeer({required String idempotencyKey});

  /// GET /trials/current. null — выдачи нет.
  Future<TrialInfo?> getCurrentTrial();

  /// DELETE /peers/{id} — идемпотентное отключение.
  Future<void> deletePeer(String peerId);

  /// Удаление установки (US-OT08, PRI-401). Пути в разделе 1.7 нет:
  /// настоящий клиент бросает [ApiNotInContract], пока Evgeniy его не добавит.
  Future<void> deleteInstallation();
}
