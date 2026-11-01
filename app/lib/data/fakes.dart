import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../platform/byo_store.dart';
import '../platform/installation_keys.dart';
import '../platform/vpn_channel.dart';
import 'api/models.dart';
import 'api/omni_api.dart';

/// Заглушки для работы без API Django и без Kotlin channel.
/// Ведут себя по правилам ТЗ: ACTIVE только после «ACK узла»,
/// срок задаёт «сервер», вторая выдача — 403.
/// В промышленной сборке не используются (OT_FAKES=false).
enum FakeScenario {
  ok,
  offline,
  serverDown,
  noCapacity,
  slowAgent,
  permissionDenied,
  permissionDeniedPermanently,
  expired;

  static FakeScenario parse(String raw) => switch (raw) {
        'offline' => offline,
        'server_down' => serverDown,
        'no_capacity' => noCapacity,
        'slow_agent' => slowAgent,
        'permission_denied' => permissionDenied,
        'permission_denied_permanently' => permissionDeniedPermanently,
        'expired' => expired,
        _ => ok,
      };
}

Future<void> _wait(Duration d) =>
    d > Duration.zero ? Future<void>.delayed(d) : Future<void>.value();

class FakeOmniApi implements OmniApi {
  FakeOmniApi({
    this.scenario = FakeScenario.ok,
    this.latency = const Duration(milliseconds: 400),
    this.provisioningTime = const Duration(seconds: 2),
    DateTime Function()? serverNow,
    TrialInfo? initialTrial,
    PeerInfo? initialPeer,
  })  : _serverNow = serverNow ??
            // Часы «сервера» нарочно сдвинуты от часов телефона:
            // таймер обязан показывать время сервера.
            (() => DateTime.now().toUtc().subtract(const Duration(minutes: 2))),
        _trial = initialTrial,
        _peer = initialPeer {
    if (scenario == FakeScenario.expired) {
      final now = _serverNow();
      _trial = TrialInfo(
        id: 'trial-1',
        state: TrialState.active,
        serverTime: now,
        deadline: now.subtract(const Duration(seconds: 1)),
      );
    }
  }

  final FakeScenario scenario;
  final Duration latency;
  final Duration provisioningTime;
  final DateTime Function() _serverNow;

  /// Журнал вызовов — для тестов «ноль запросов в BYO».
  final List<String> calls = [];

  TrialInfo? _trial;
  PeerInfo? _peer;
  DateTime? _requestedAt;

  Future<void> _net(String call) async {
    calls.add(call);
    await _wait(latency);
    if (scenario == FakeScenario.offline) throw const ApiOffline();
    if (scenario == FakeScenario.serverDown) throw const ApiUnavailable();
  }

  TrialInfo _advance() {
    final now = _serverNow();
    var t = _trial!;
    if (t.state == TrialState.provisioning &&
        scenario != FakeScenario.slowAgent &&
        now.difference(_requestedAt ?? now) >= provisioningTime) {
      // ACK узла получен: срок считается от этого момента.
      t = TrialInfo(
          id: t.id,
          state: TrialState.active,
          serverTime: now,
          deadline: now.add(const Duration(minutes: 30)));
    }
    if (t.state == TrialState.active && !now.isBefore(t.deadline!)) {
      t = TrialInfo(
          id: t.id,
          state: TrialState.expired,
          serverTime: now,
          deadline: t.deadline);
      _peer = null;
    }
    _trial = t;
    return TrialInfo(
        id: t.id, state: t.state, serverTime: now, deadline: t.deadline);
  }

  @override
  Future<void> registerInstallation({
    required String publicKey,
    required int consentVersion,
  }) =>
      _net('POST /installations');

  @override
  Future<List<NodeInfo>> getNodes() async {
    await _net('GET /nodes');
    return const [NodeInfo(id: 'ala-1', label: 'Алматы', alive: true)];
  }

  @override
  Future<TrialInfo> createTrial({required String idempotencyKey}) async {
    await _net('POST /trials');
    if (scenario == FakeScenario.noCapacity) {
      throw const ApiRejected(403, 'NO_CAPACITY');
    }
    if (_trial != null) {
      final t = _advance();
      if (t.state == TrialState.active ||
          t.state == TrialState.provisioning ||
          t.state == TrialState.expired) {
        throw const ApiRejected(403, 'TRIAL_EXISTS');
      }
    }
    _requestedAt = _serverNow();
    _trial = TrialInfo(
        id: 'trial-1', state: TrialState.provisioning, serverTime: _requestedAt!);
    return _trial!;
  }

  @override
  Future<TrialInfo?> getCurrentTrial() async {
    await _net('GET /trials/current');
    if (_trial == null) return null;
    return _advance();
  }

  @override
  Future<PeerInfo> createPeer({required String idempotencyKey}) async {
    await _net('POST /peers');
    if (_trial == null || _advance().state != TrialState.active) {
      throw const ApiRejected(403, 'NO_ACTIVE_TRIAL');
    }
    return _peer ??= const PeerInfo(
      id: 'peer-1',
      tunnelAddress: '10.8.0.12',
      serverConfig: {
        'endpoint': 'ala-1.example.invalid:51820',
        'public_key': 'SERVER_PUBLIC_KEY',
      },
    );
  }

  @override
  Future<void> deletePeer(String peerId) async {
    await _net('DELETE /peers/$peerId');
    _peer = null;
  }

  @override
  Future<void> deleteInstallation() async {
    await _net('DELETE installation');
    _trial = null;
    _peer = null;
  }
}

class FakeVpnChannel implements VpnChannel {
  FakeVpnChannel({
    this.scenario = FakeScenario.ok,
    this.connectDelay = const Duration(milliseconds: 1200),
    TunnelStatus initial = TunnelStatus.disconnected,
  }) : _status = initial;

  final FakeScenario scenario;

  /// null — туннель навсегда остаётся в connecting (для теста честного состояния).
  final Duration? connectDelay;

  final List<String> calls = [];
  final StreamController<TunnelStatus> _ctrl = StreamController.broadcast();
  TunnelStatus _status;
  int _attempt = 0;

  void _emit(TunnelStatus s) {
    _status = s;
    _ctrl.add(s);
  }

  @override
  Future<VpnPermission> prepareVpn() async {
    calls.add('prepareVpn');
    return switch (scenario) {
      FakeScenario.permissionDenied => VpnPermission.denied,
      FakeScenario.permissionDeniedPermanently =>
        VpnPermission.deniedPermanently,
      _ => VpnPermission.granted,
    };
  }

  @override
  Future<void> connect(TunnelRequest request) async {
    calls.add('connect:${request.mode}');
    final attempt = ++_attempt;
    _emit(TunnelStatus.connecting);
    final d = connectDelay;
    if (d == null) return;
    await _wait(d);
    if (attempt == _attempt && _status == TunnelStatus.connecting) {
      _emit(TunnelStatus.connected);
    }
  }

  @override
  Future<void> disconnect() async {
    calls.add('disconnect');
    _attempt++;
    _emit(TunnelStatus.disconnected);
  }

  @override
  Future<TunnelStatus> getState() async => _status;

  @override
  Stream<TunnelStatus> watchState() async* {
    yield _status;
    yield* _ctrl.stream;
  }
}

class FakeInstallationKeys implements InstallationKeys {
  @override
  Future<String> publicKey() async => 'FAKE_PUBLIC_KEY';

  @override
  Future<Map<String, String>> authHeaders({
    required String method,
    required String path,
    String? body,
  }) async =>
      const {};

  @override
  Future<void> reset() async {}
}

/// Разбор в заглушке — только для показа экранов. Настоящий разбор,
/// шифрование и хранение делает Kotlin (MOB-202). Ключ здесь не хранится.
class FakeByoStore implements ByoConfigStore {
  FakeByoStore({ByoSummary? initial, this.latency = const Duration(milliseconds: 300)})
      : _saved = initial;

  final Duration latency;
  ByoSummary? _saved;

  static const _sample = ByoSummary(
      endpoint: 'vpn.example.com:51820', tunnelAddress: '10.0.0.2/32');

  @override
  Future<ByoSummary?> load() async {
    await _wait(latency);
    return _saved;
  }

  @override
  Future<ByoImportResult> importText(String text) async {
    await _wait(latency);
    if (text.length > kByoMaxConfigChars) {
      return const ByoRejected(ByoRejectReason.tooLarge);
    }
    String? field(String name) {
      final m = RegExp('^\\s*$name\\s*=\\s*(.+)\$',
              multiLine: true, caseSensitive: false)
          .firstMatch(text);
      return m?.group(1)?.trim();
    }

    final hasSections = text.contains('[Interface]') && text.contains('[Peer]');
    final endpoint = field('Endpoint');
    final address = field('Address');
    if (!hasSections ||
        field('PrivateKey') == null ||
        endpoint == null ||
        address == null) {
      return const ByoRejected(ByoRejectReason.invalid);
    }
    _saved = ByoSummary(endpoint: endpoint, tunnelAddress: address);
    return ByoImported(_saved!);
  }

  @override
  Future<ByoImportResult> importFile() async {
    await _wait(latency);
    _saved = _sample;
    return const ByoImported(_sample);
  }

  @override
  Future<ByoImportResult> importQr() async {
    await _wait(latency);
    _saved = _sample;
    return const ByoImported(_sample);
  }

  @override
  Future<void> delete() async {
    await _wait(latency);
    _saved = null;
  }
}

/// Подмены провайдеров для сборки на заглушках.
List<Override> fakeOverrides(FakeScenario scenario) => [
      omniApiProvider.overrideWithValue(FakeOmniApi(scenario: scenario)),
      vpnChannelProvider.overrideWithValue(FakeVpnChannel(scenario: scenario)),
      installationKeysProvider.overrideWithValue(FakeInstallationKeys()),
      byoStoreProvider.overrideWithValue(FakeByoStore()),
    ];
