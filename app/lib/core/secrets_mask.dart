/// Маркер, которым на экране заменяется любой секрет.
const String kSecretMarker = '••••••••';

final RegExp _secretLine = RegExp(
  r'^(\s*(?:PrivateKey|PresharedKey)\s*=\s*)(.*)$',
  multiLine: true,
  caseSensitive: false,
);

/// Возвращает текст конфига, в котором значения PrivateKey и PresharedKey
/// заменены маркером. Это только маскировка для показа, не разбор:
/// разбирает конфиг Kotlin (MOB-202). Исходный текст на экран не попадает.
String maskSecrets(String config) =>
    config.replaceAllMapped(_secretLine, (m) => '${m[1]}$kSecretMarker');
