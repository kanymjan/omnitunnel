import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../platform/byo_store.dart';
import '../../platform/vpn_channel.dart';
import '../../ui/failure_view.dart';

// ВАЖНО: код BYO не импортирует клиент API OmniTunnel и HTTP (US-OT06).
// Это проверяет test/architecture_test.dart.

class ByoViewState {
  const ByoViewState({
    this.loading = true,
    this.summary,
    this.tunnel = TunnelStatus.disconnected,
    this.busy = false,
    this.failure,
  });

  final bool loading;
  final ByoSummary? summary;
  final TunnelStatus tunnel;
  final bool busy;
  final FailureKind? failure;

  ByoViewState copyWith({
    bool? loading,
    ByoSummary? summary,
    bool clearSummary = false,
    TunnelStatus? tunnel,
    bool? busy,
    FailureKind? failure,
    bool clearFailure = false,
  }) =>
      ByoViewState(
        loading: loading ?? this.loading,
        summary: clearSummary ? null : summary ?? this.summary,
        tunnel: tunnel ?? this.tunnel,
        busy: busy ?? this.busy,
        failure: clearFailure ? null : failure ?? this.failure,
      );
}

/// BYO: импорт, подключение и удаление локального конфига. Нет таймера,
/// нет аккаунта, нет запросов к OmniTunnel (сценарий D).
class ByoController extends AutoDisposeNotifier<ByoViewState> {
  late ByoConfigStore _store;
  late VpnChannel _vpn;
  StreamSubscription<TunnelStatus>? _sub;
  bool _disposed = false;

  @override
  ByoViewState build() {
    _disposed = false;
    _store = ref.watch(byoStoreProvider);
    _vpn = ref.watch(vpnChannelProvider);
    ref.onDispose(() {
      _disposed = true;
      _sub?.cancel();
    });
    Future.microtask(_load);
    return const ByoViewState();
  }

  Future<void> _load() async {
    if (_disposed) return;
    final saved = await _store.load();
    if (_disposed) return;
    await _sub?.cancel();
    _sub = _vpn.watchState().listen((t) {
      if (!_disposed) state = state.copyWith(tunnel: t);
    });
    state = state.copyWith(loading: false, summary: saved, clearSummary: saved == null);
  }

  ByoImportResult _apply(ByoImportResult r) {
    if (!_disposed && r is ByoImported) {
      state = state.copyWith(summary: r.summary, clearFailure: true);
    }
    return r;
  }

  Future<ByoImportResult> importText(String text) async =>
      _apply(await _store.importText(text));

  Future<ByoImportResult> importFile() async => _apply(await _store.importFile());

  Future<ByoImportResult> importQr() async => _apply(await _store.importQr());

  Future<void> connect() async {
    if (state.busy) return;
    state = state.copyWith(busy: true, clearFailure: true);
    try {
      final perm = await _vpn.prepareVpn();
      if (_disposed) return;
      if (perm != VpnPermission.granted) {
        state = state.copyWith(
          failure: perm == VpnPermission.deniedPermanently
              ? FailureKind.permissionDeniedPermanently
              : FailureKind.permissionDenied,
        );
        return;
      }
      await _vpn.connect(TunnelRequest.byo());
    } finally {
      if (!_disposed) state = state.copyWith(busy: false);
    }
  }

  Future<void> disconnect() => _vpn.disconnect();

  Future<void> delete() async {
    if (state.tunnel != TunnelStatus.disconnected) await _vpn.disconnect();
    await _store.delete();
    if (!_disposed) state = state.copyWith(clearSummary: true);
  }

  void clearFailure() => state = state.copyWith(clearFailure: true);
}

final byoControllerProvider =
    NotifierProvider.autoDispose<ByoController, ByoViewState>(ByoController.new);
