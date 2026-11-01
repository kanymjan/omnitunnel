import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

/// Локальные настройки. Здесь нет ни ключей, ни конфигов, ни адресов:
/// ключи — в Keystore (Kotlin), конфиг BYO — в зашифрованном хранилище Kotlin.
class AppSettings {
  const AppSettings({
    this.languageCode,
    this.consentVersion,
    this.registered = false,
  });

  /// 'ru' или 'ky'. null — язык ещё не выбран (первый запуск).
  final String? languageCode;

  /// Версия принятого согласия. null — согласия нет.
  final int? consentVersion;

  /// Установка зарегистрирована на сервере (POST /installations прошёл).
  final bool registered;

  AppSettings copyWith({
    String? languageCode,
    int? consentVersion,
    bool clearConsent = false,
    bool? registered,
  }) =>
      AppSettings(
        languageCode: languageCode ?? this.languageCode,
        consentVersion: clearConsent ? null : consentVersion ?? this.consentVersion,
        registered: registered ?? this.registered,
      );
}

class SettingsController extends Notifier<AppSettings> {
  static const kLang = 'ot.lang';
  static const kConsent = 'ot.consent_version';
  static const kRegistered = 'ot.registered';

  @override
  AppSettings build() {
    final p = ref.watch(sharedPrefsProvider);
    return AppSettings(
      languageCode: p.getString(kLang),
      consentVersion: p.getInt(kConsent),
      registered: p.getBool(kRegistered) ?? false,
    );
  }

  Future<void> setLanguage(String code) async {
    await ref.read(sharedPrefsProvider).setString(kLang, code);
    state = state.copyWith(languageCode: code);
  }

  Future<void> acceptConsent(int version) async {
    await ref.read(sharedPrefsProvider).setInt(kConsent, version);
    state = state.copyWith(consentVersion: version);
  }

  Future<void> markRegistered() async {
    await ref.read(sharedPrefsProvider).setBool(kRegistered, true);
    state = state.copyWith(registered: true);
  }

  /// После удаления данных: согласие и регистрация сбрасываются, язык остаётся.
  Future<void> resetInstallation() async {
    final p = ref.read(sharedPrefsProvider);
    await p.remove(kConsent);
    await p.remove(kRegistered);
    state = state.copyWith(clearConsent: true, registered: false);
  }
}

final settingsProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);
