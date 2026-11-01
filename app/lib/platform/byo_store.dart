import 'package:flutter/services.dart';

/// Что Flutter знает о сохранённом конфиге BYO: только endpoint и туннельный
/// адрес (MOB-202). Поля для закрытого ключа здесь нет и быть не должно.
class ByoSummary {
  const ByoSummary({required this.endpoint, required this.tunnelAddress});

  final String endpoint;
  final String tunnelAddress;
}

enum ByoRejectReason { invalid, tooLarge, cancelled }

sealed class ByoImportResult {
  const ByoImportResult();
}

class ByoImported extends ByoImportResult {
  const ByoImported(this.summary);
  final ByoSummary summary;
}

class ByoRejected extends ByoImportResult {
  const ByoRejected(this.reason);
  final ByoRejectReason reason;
}

/// Предварительная проверка размера до отправки в Kotlin.
/// Окончательный предел задаёт парсер Kotlin.
const int kByoMaxConfigChars = 16 * 1024;

/// Импорт, разбор, шифрование и хранение BYO делает Kotlin (MOB-202).
/// Этот интерфейс никогда не ходит в сеть.
///
/// Имена методов channel — допущение, согласовать с Sohipjon.
abstract interface class ByoConfigStore {
  Future<ByoSummary?> load();
  Future<ByoImportResult> importText(String text);
  Future<ByoImportResult> importFile();
  Future<ByoImportResult> importQr();
  Future<void> delete();
}

ByoImportResult parseByoResult(Map<String, Object?>? raw) {
  switch (raw?['status']) {
    case 'ok':
      return ByoImported(ByoSummary(
        endpoint: '${raw!['endpoint'] ?? ''}',
        tunnelAddress: '${raw['tunnelAddress'] ?? ''}',
      ));
    case 'too_large':
      return const ByoRejected(ByoRejectReason.tooLarge);
    case 'cancelled':
      return const ByoRejected(ByoRejectReason.cancelled);
    default:
      return const ByoRejected(ByoRejectReason.invalid);
  }
}

class MethodChannelByoStore implements ByoConfigStore {
  const MethodChannelByoStore([this._ch = const MethodChannel('omnitunnel/byo')]);

  final MethodChannel _ch;

  @override
  Future<ByoSummary?> load() async {
    final raw = await _ch.invokeMapMethod<String, Object?>('load');
    final res = parseByoResult(raw);
    return res is ByoImported ? res.summary : null;
  }

  @override
  Future<ByoImportResult> importText(String text) async {
    if (text.length > kByoMaxConfigChars) {
      return const ByoRejected(ByoRejectReason.tooLarge);
    }
    return parseByoResult(
        await _ch.invokeMapMethod<String, Object?>('importText', {'text': text}));
  }

  @override
  Future<ByoImportResult> importFile() async =>
      parseByoResult(await _ch.invokeMapMethod<String, Object?>('importFile'));

  @override
  Future<ByoImportResult> importQr() async =>
      parseByoResult(await _ch.invokeMapMethod<String, Object?>('importQr'));

  @override
  Future<void> delete() => _ch.invokeMethod<void>('delete');
}
