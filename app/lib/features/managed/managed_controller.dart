import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/settings.dart';
import '../../core/config.dart';
import '../../core/ids.dart';
import '../../data/api/models.dart';
import '../../data/api/omni_api.dart';
import '../../platform/vpn_channel.dart';
import '../../ui/failure_view.dart';

enum ManagedPhase {
  loading,
  registering,
  idle,
  preparing,
  connecting,
  connected,
  activeDisconnected,
  expired,
  failure,
}

class ManagedViewState {
  const ManagedViewState({
    required this.phase,
    this.failure,
    this.remaining,
    this.serverLabel,
    this.tunnelAddress,
    this.slow = false,
    this.busy = false,
    this.nodesAvailable = true,
  });

  final ManagedPhase phase;
  final FailureKind? failure;

  /// Остаток по часам сервера. null — выдачи ACTIVE нет.
  final Duration? remaining;
  final String? serverLabel;
  final String? tunnelAddress;

  /// PROVISIONING длится дольше обычного («агент задержался»).
  final bool slow;
  final bool busy;
  final bool nodesAvailable;
}

/// Управляемый режим (MOB-101, MOB-302, MOB-501).
///
/// Правила ТЗ, которые здесь соблюдены:
/// * таймер — только из GET /trials/current (deadline − server_time),
///   отсчёт между сверками идёт по монотонному Stopwatch, а не по часам телефона;
/// * Flutter не решает об истечении: на нуле он спрашивает сервер;
/// * «подключено» показывается только когда так говорит Kotlin.
class ManagedController extends AutoDisposeNotifier<ManagedViewState> {
  late OmniApi _api;
  late VpnChannel _vpn;
  late ManagedTiming _timing;

  bool _disposed = false;
  StreamSubscription<TunnelStatus>? _tunnelSub;
  Timer? _ticker;
  Timer? _resyncTimer;
  Timer? _delayTimer;
  Completer<void>? _delayDone;

  final Stopwatch _sinceSync = Stopwatch();
  final Stopwatch _sinceZeroSync = Stopwatch();
  Duration? _remainingAtSync;

  TrialInfo? _trial;
  PeerInfo? _peer;
  String? _serverLabel;
  bool _nodesAlive = true;
  TunnelStatus _tunnel = TunnelStatus.disconnected;

  FailureKind? _failure;
  bool _loaded = false;
  bool _registering = false;
  bool _waitingForTrial = false;
  bool _connectingPeer = false;
  bool _cancelWait = false;
  bool _slow = false;
  bool _busy = false;
  bool _zeroSyncRunning = false;

  String? _trialKey;
  String? _peerKey;

  @override
  ManagedViewState build() {
    _disposed = false;
    _api = ref.watch(omniApiProvider);
    _vpn = ref.watch(vpnChannelProvider);
    _timing = ref.watch(managedTimingProvider);
    ref.onDispose(_dispose);
    Future.microtask(_start);
    return const ManagedViewState(phase: ManagedPhase.loading);
  }

  void _dispose() {
    _disposed = true;
    _tunnelSub?.cancel();
    _stopTimers();
    _delayTimer?.cancel();
    final done = _delayDone;
    if (done != null && !done.isCompleted) done.complete();
    _sinceSync.stop();
    _sinceZeroSync.stop();
  }

  // ---------------------------------------------------------------- start

  Future<void> _start() async {
    if (_disposed) return;
    _failure = null;
    _render();
    try {
      if (!ref.read(settingsProvider).registered) {
        _registering = true;
        _render();
        final publicKey = await ref.read(installationKeysProvider).publicKey();
        if (_disposed) return;
        await _api.registerInstallation(
            publicKey: publicKey, consentVersion: kConsentVersion);
        if (_disposed) return;
        await ref.read(settingsProvider.notifier).markRegistered();
        _registering = false;
      }
      await _tunnelSub?.cancel();
      if (_disposed) return;
      _tunnelSub = _vpn.watchState().listen(_onTunnel);
      await _loadNodes();
      await _syncTrial();
      _loaded = true;
      _render();
    } on ApiFailure catch (e) {
      _registering = false;
      _fail(failureFromApi(e));
    }
  }

  Future<void> _loadNodes() async {
    final nodes = await _api.getNodes();
    if (_disposed) return;
    final alive = nodes.where((n) => n.alive).toList();
    _nodesAlive = alive.isNotEmpty;
    _serverLabel = alive.isEmpty ? null : alive.first.label;
  }

  // ---------------------------------------------------------- server time

  Future<void> _syncTrial() async {
    final t = await _api.getCurrentTrial();
    if (_disposed) return;
    _trial = t;
    final left = t != null && t.state == TrialState.active
        ? t.remainingAtServer
        : null;
    if (left != null) {
      _remainingAtSync = left;
      _sinceSync
        ..reset()
        ..start();
      _ensureTimers();
    } else {
      _remainingAtSync = null;
      _stopTimers();
    }
    final ended = t == null ||
        t.state == TrialState.expired ||
        t.state == TrialState.cancelled;
    if (ended) {
      _peer = null;
      // Срок закончил сервер, узел снимает пир. Здесь только убираем
      // мёртвый туннель на телефоне, чтобы текст «VPN отключён» был правдой.
      if (t != null && _tunnel != TunnelStatus.disconnected) {
        unawaited(_vpn.disconnect());
      }
    }
    _render();
  }

  Duration? get _remaining {
    final base = _remainingAtSync;
    if (base == null) return null;
    final left = base - _sinceSync.elapsed;
    return left.isNegative ? Duration.zero : left;
  }

  void _ensureTimers() {
    _ticker ??= Timer.periodic(_timing.tick, (_) => _onTick());
    _resyncTimer ??= Timer.periodic(_timing.resync, (_) => _safeSync());
  }

  void _stopTimers() {
    _ticker?.cancel();
    _ticker = null;
    _resyncTimer?.cancel();
    _resyncTimer = null;
  }

  void _onTick() {
    if (_disposed) return;
    final left = _remaining;
    if (left == Duration.zero && !_zeroSyncRunning) {
      final firstTime = !_sinceZeroSync.isRunning;
      if (firstTime || _sinceZeroSync.elapsed >= const Duration(seconds: 3)) {
        _zeroSyncRunning = true;
        _sinceZeroSync
          ..reset()
          ..start();
        _safeSync().whenComplete(() => _zeroSyncRunning = false);
      }
    }
    _render();
  }

  Future<void> _safeSync() async {
    try {
      await _syncTrial();
    } on ApiFailure {
      // Сверка не удалась: показываем последнее известное время сервера.
      // Решение об истечении всё равно за сервером и узлом.
    }
  }

  void _onTunnel(TunnelStatus s) {
    _tunnel = s;
    _render();
  }

  // -------------------------------------------------------------- actions

  Future<void> requestAccess() async {
    if (_busy) return;
    _busy = true;
    _failure = null;
    _slow = false;
    _cancelWait = false;
    _render();
    try {
      final perm = await _vpn.prepareVpn();
      if (_disposed) return;
      if (perm != VpnPermission.granted) {
        _fail(perm == VpnPermission.deniedPermanently
            ? FailureKind.permissionDeniedPermanently
            : FailureKind.permissionDenied);
        return;
      }
      _trialKey ??= newIdempotencyKey();
      try {
        await _api.createTrial(idempotencyKey: _trialKey!);
      } on ApiRejected catch (e) {
        // Выдача уже есть: сервер вернул 403. Берём её состояние, вторую не просим.
        if (e.code != 'TRIAL_EXISTS') rethrow;
      }
      if (_disposed) return;
      _waitingForTrial = true;
      _render();
      final waited = Stopwatch()..start();
      await _syncTrial();
      while (!_disposed && !_cancelWait && _isProvisioning) {
        if (!_slow && waited.elapsed >= _timing.slowAfter) {
          _slow = true;
          _render();
        }
        await _delay(_timing.poll);
        if (_disposed || _cancelWait) break;
        await _syncTrial();
      }
      _waitingForTrial = false;
      _slow = false;
      _trialKey = null;
      if (_disposed || _cancelWait) return;
      if (_trial?.state == TrialState.active) await _connectPeer();
    } on ApiFailure catch (e) {
      _waitingForTrial = false;
      _fail(failureFromApi(e));
    } finally {
      _busy = false;
      _render();
    }
  }

  bool get _isProvisioning =>
      _trial?.state == TrialState.provisioning ||
      _trial?.state == TrialState.newState;

  Future<void> reconnect() async {
    if (_busy) return;
    _busy = true;
    _failure = null;
    _render();
    try {
      final perm = await _vpn.prepareVpn();
      if (_disposed) return;
      if (perm != VpnPermission.granted) {
        _fail(perm == VpnPermission.deniedPermanently
            ? FailureKind.permissionDeniedPermanently
            : FailureKind.permissionDenied);
        return;
      }
      await _connectPeer();
    } on ApiFailure catch (e) {
      _fail(failureFromApi(e));
    } finally {
      _busy = false;
      _render();
    }
  }

  Future<void> _connectPeer() async {
    _connectingPeer = true;
    _render();
    try {
      _peerKey ??= newIdempotencyKey();
      final peer = await _api.createPeer(idempotencyKey: _peerKey!);
      if (_disposed) return;
      _peer = peer;
      _peerKey = null;
      await _vpn.connect(TunnelRequest.managed(
        peerId: peer.id,
        tunnelAddress: peer.tunnelAddress,
        serverConfig: peer.serverConfig,
      ));
    } finally {
      _connectingPeer = false;
    }
  }

  /// Отмена ожидания выдачи или подключения.
  Future<void> cancel() async {
    _cancelWait = true;
    final done = _delayDone;
    if (done != null && !done.isCompleted) done.complete();
    if (_tunnel != TunnelStatus.disconnected || _connectingPeer) {
      await disconnect();
    }
    _render();
  }

  Future<void> disconnect() async {
    final peer = _peer;
    try {
      await _vpn.disconnect();
      if (peer != null) {
        try {
          await _api.deletePeer(peer.id);
        } on ApiFailure {
          // Узел всё равно снимет пир по своему deadline.
        }
      }
      _peer = null;
    } finally {
      _render();
    }
  }

  Future<void> retry() async {
    _failure = null;
    await _start();
  }

  // -------------------------------------------------------------- helpers

  Future<void> _delay(Duration d) {
    final done = Completer<void>();
    _delayDone = done;
    _delayTimer = Timer(d, () {
      if (!done.isCompleted) done.complete();
    });
    return done.future;
  }

  void _fail(FailureKind kind) {
    _failure = kind;
    _render();
  }

  ManagedPhase _phase() {
    final t = _trial;
    if (_failure != null) return ManagedPhase.failure;
    if (_registering) return ManagedPhase.registering;
    if (!_loaded && t == null) return ManagedPhase.loading;
    if (_waitingForTrial ||
        (t != null && (t.state == TrialState.provisioning ||
            t.state == TrialState.newState))) {
      return ManagedPhase.preparing;
    }
    if (t == null) return ManagedPhase.idle;
    if (t.state == TrialState.active) {
      return switch (_tunnel) {
        TunnelStatus.connected => ManagedPhase.connected,
        TunnelStatus.connecting => ManagedPhase.connecting,
        TunnelStatus.disconnected => _connectingPeer
            ? ManagedPhase.connecting
            : ManagedPhase.activeDisconnected,
      };
    }
    return ManagedPhase.expired;
  }

  void _render() {
    if (_disposed) return;
    state = ManagedViewState(
      phase: _phase(),
      failure: _failure,
      remaining: _remaining,
      serverLabel: _serverLabel,
      tunnelAddress: _peer?.tunnelAddress,
      slow: _slow,
      busy: _busy,
      nodesAvailable: _nodesAlive,
    );
  }
}

final managedControllerProvider =
    NotifierProvider.autoDispose<ManagedController, ManagedViewState>(
        ManagedController.new);
