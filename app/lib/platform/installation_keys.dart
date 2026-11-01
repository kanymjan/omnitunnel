import 'package:flutter/services.dart';

/// Ключ установки живёт в Keystore (MOB-102, Sohipjon).
/// Flutter получает только открытый ключ и готовые заголовки доказательства
/// владения. Закрытый ключ сюда не приходит.
///
/// Имена методов channel — допущение, согласовать с Sohipjon и Evgeniy:
/// схема подписи запроса ещё не описана в DRF (BE-101).
abstract interface class InstallationKeys {
  /// Создаёт пару ключей при первом вызове. Возвращает открытый ключ.
  Future<String> publicKey();

  /// Заголовки, доказывающие владение ключом установки, для одного запроса.
  Future<Map<String, String>> authHeaders({
    required String method,
    required String path,
    String? body,
  });

  /// Стирает ключ установки (сброс или удаление данных).
  Future<void> reset();
}

class MethodChannelInstallationKeys implements InstallationKeys {
  const MethodChannelInstallationKeys(
      [this._ch = const MethodChannel('omnitunnel/keys')]);

  final MethodChannel _ch;

  @override
  Future<String> publicKey() async =>
      (await _ch.invokeMethod<String>('getPublicKey'))!;

  @override
  Future<Map<String, String>> authHeaders({
    required String method,
    required String path,
    String? body,
  }) async {
    final raw = await _ch.invokeMapMethod<String, String>(
      'signRequest',
      {'method': method, 'path': path, 'body': body},
    );
    return raw ?? const {};
  }

  @override
  Future<void> reset() => _ch.invokeMethod<void>('reset');
}
