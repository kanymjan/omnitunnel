import 'dart:async';

import 'package:flutter/services.dart';

/// Состояние туннеля. Источник истины — только Kotlin (US-OT05).
/// Flutter не решает, подключён ли туннель и истекла ли выдача.
enum TunnelStatus { disconnected, connecting, connected }

enum VpnPermission { granted, denied, deniedPermanently }

/// Что передать Kotlin при connect. Состав полей — допущение,
/// его нужно согласовать с Sohipjon (MOB-101 / MOB-301).
class TunnelRequest {
  const TunnelRequest._(this.mode, this.params);

  /// Управляемая выдача: публичный конфиг сервера и туннельный адрес из POST /peers.
  /// Закрытый ключ клиента Flutter не видит: он в Keystore.
  factory TunnelRequest.managed({
    required String peerId,
    required String tunnelAddress,
    required Map<String, Object?> serverConfig,
  }) =>
      TunnelRequest._('managed', {
        'peerId': peerId,
        'tunnelAddress': tunnelAddress,
        'serverConfig': serverConfig,
      });

  /// BYO: Kotlin сам берёт сохранённый зашифрованный конфиг.
  factory TunnelRequest.byo() => const TunnelRequest._('byo', {});

  final String mode;
  final Map<String, Object?> params;

  Map<String, Object?> toMap() => {'mode': mode, ...params};
}

/// Контракт method channel со стороны Kotlin (раздел 1.8):
/// prepareVpn, connect, disconnect, getState.
abstract interface class VpnChannel {
  Future<VpnPermission> prepareVpn();
  Future<void> connect(TunnelRequest request);
  Future<void> disconnect();
  Future<TunnelStatus> getState();

  /// Поток состояний. Первым приходит текущее состояние.
  Stream<TunnelStatus> watchState();
}

/// Неизвестное значение — всегда disconnected: нельзя показать
/// «подключено», пока Kotlin этого явно не сказал.
TunnelStatus parseTunnelStatus(String? raw) => switch (raw) {
      'connecting' => TunnelStatus.connecting,
      'connected' => TunnelStatus.connected,
      _ => TunnelStatus.disconnected,
    };

VpnPermission parsePermission(String? raw) => switch (raw) {
      'granted' => VpnPermission.granted,
      'denied_permanently' => VpnPermission.deniedPermanently,
      _ => VpnPermission.denied,
    };

class MethodChannelVpn implements VpnChannel {
  MethodChannelVpn({
    MethodChannel channel = const MethodChannel('omnitunnel/vpn'),
    this.pollInterval = const Duration(seconds: 1),
  }) : _ch = channel;

  final MethodChannel _ch;
  final Duration pollInterval;

  @override
  Future<VpnPermission> prepareVpn() async =>
      parsePermission(await _ch.invokeMethod<String>('prepareVpn'));

  @override
  Future<void> connect(TunnelRequest request) =>
      _ch.invokeMethod<void>('connect', request.toMap());

  @override
  Future<void> disconnect() => _ch.invokeMethod<void>('disconnect');

  @override
  Future<TunnelStatus> getState() async =>
      parseTunnelStatus(await _ch.invokeMethod<String>('getState'));

  /// Контракт называет только getState, поэтому состояние опрашивается.
  /// Если Kotlin добавит EventChannel, меняется только этот метод.
  @override
  Stream<TunnelStatus> watchState() async* {
    TunnelStatus? last;
    while (true) {
      TunnelStatus now;
      try {
        now = await getState();
      } on PlatformException {
        now = TunnelStatus.disconnected;
      }
      if (now != last) {
        last = now;
        yield now;
      }
      await Future<void>.delayed(pollInterval);
    }
  }
}
