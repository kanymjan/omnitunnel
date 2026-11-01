import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config.dart';
import '../data/api/http_omni_api.dart';
import '../data/api/omni_api.dart';
import '../platform/byo_store.dart';
import '../platform/installation_keys.dart';
import '../platform/vpn_channel.dart';

/// Подменяется в main() уже открытым SharedPreferences.
final sharedPrefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPrefsProvider: override in main()'),
);

final installationKeysProvider = Provider<InstallationKeys>(
  (ref) => const MethodChannelInstallationKeys(),
);

/// Клиент API. Только для управляемого режима: внутри маршрута BYO
/// этот провайдер подменён запретом (lib/app/router.dart).
final omniApiProvider = Provider<OmniApi>(
  (ref) => HttpOmniApi(
    base: AppConfig.apiBase,
    keys: ref.watch(installationKeysProvider),
  ),
);

final vpnChannelProvider = Provider<VpnChannel>((ref) => MethodChannelVpn());

final byoStoreProvider =
    Provider<ByoConfigStore>((ref) => const MethodChannelByoStore());

/// Убрать фоновые анимации (тесты, настройки доступности).
final reduceMotionProvider = Provider<bool>((ref) => false);

/// Интервалы управляемого режима. В тестах подменяются на короткие.
class ManagedTiming {
  const ManagedTiming({
    this.poll = const Duration(seconds: 2),
    this.slowAfter = const Duration(seconds: 20),
    this.resync = const Duration(seconds: 30),
    this.tick = const Duration(seconds: 1),
  });

  /// Как часто спрашивать GET /trials/current, пока идёт PROVISIONING.
  final Duration poll;

  /// Через сколько показать «Сервер отвечает дольше обычного».
  final Duration slowAfter;

  /// Как часто сверять таймер с сервером, пока выдача ACTIVE.
  final Duration resync;

  /// Шаг перерисовки обратного отсчёта.
  final Duration tick;
}

final managedTimingProvider =
    Provider<ManagedTiming>((ref) => const ManagedTiming());
