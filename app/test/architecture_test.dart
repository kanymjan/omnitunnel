import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:omnitunnel/core/secrets_mask.dart';
import 'package:omnitunnel/features/managed/managed_widgets.dart';

void main() {
  test('код BYO не импортирует клиент API и HTTP (US-OT06)', () {
    final files = Directory('lib/features/byo')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();
    expect(files, isNotEmpty);
    for (final f in files) {
      final imports = f
          .readAsLinesSync()
          .where((line) => line.trimLeft().startsWith('import '))
          .join('\n');
      for (final banned in ['data/api', 'package:http', 'omni_api', 'dart:io']) {
        expect(imports.contains(banned), isFalse,
            reason: '${f.path} импортирует $banned');
      }
    }
  });

  test('в модели BYO нет поля для закрытого ключа', () {
    final src = File('lib/platform/byo_store.dart').readAsStringSync();
    expect(
      RegExp(r'final\s+\S+\s+\w*private\w*', caseSensitive: false).hasMatch(src),
      isFalse,
    );
  });

  test('нет оплаты и покупок в зависимостях', () {
    final pubspec = File('pubspec.yaml').readAsStringSync().toLowerCase();
    for (final banned in ['purchase', 'billing', 'revenuecat', 'stripe']) {
      expect(pubspec.contains(banned), isFalse, reason: banned);
    }
  });

  group('maskSecrets', () {
    test('замазывает PrivateKey и PresharedKey', () {
      const cfg = '[Interface]\n'
          'PrivateKey = SECRET_PRIVATE_123=\n'
          'Address = 10.0.0.2/32\n'
          '[Peer]\n'
          'PublicKey = SERVER_PUB\n'
          'PresharedKey = SECRET_PSK_456=\n'
          'Endpoint = vpn.example.com:51820\n';
      final masked = maskSecrets(cfg);
      expect(masked, isNot(contains('SECRET_PRIVATE_123')));
      expect(masked, isNot(contains('SECRET_PSK_456')));
      expect(masked, contains('PrivateKey = $kSecretMarker'));
      expect(masked, contains('PublicKey = SERVER_PUB'));
      expect(masked, contains('Endpoint = vpn.example.com:51820'));
    });

    test('без учёта регистра и пробелов', () {
      expect(maskSecrets('  privatekey=abc'), isNot(contains('abc')));
    });
  });

  group('formatRemaining', () {
    test('округляет вверх до секунды', () {
      expect(
          formatRemaining(const Duration(minutes: 24, seconds: 12, milliseconds: 400)),
          '24:13');
      expect(formatRemaining(Duration.zero), '00:00');
      expect(formatRemaining(const Duration(minutes: 30)), '30:00');
    });
  });
}
