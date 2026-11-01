import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _load(String path) =>
    (jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>)
      ..removeWhere((k, _) => k.startsWith('@'));

/// UX-402 и раздел 3.4: оба каталога в одном изменении,
/// без обещаний анонимности, kill switch и обхода цензуры, без покупки.
void main() {
  final ru = _load('lib/l10n/app_ru.arb');
  final ky = _load('lib/l10n/app_ky.arb');

  test('RU и KY содержат одни и те же ключи', () {
    expect(ky.keys.toSet(), ru.keys.toSet());
  });

  test('ни одной пустой строки', () {
    for (final e in [...ru.entries, ...ky.entries]) {
      expect('${e.value}'.trim(), isNotEmpty, reason: e.key);
    }
  });

  test('ключи вида screen + Element', () {
    final re = RegExp(
        r'^(app|common|language|mode|privacy|consent|managed|byo|fail|settings)[A-Z]');
    for (final k in ru.keys) {
      expect(re.hasMatch(k), isTrue, reason: k);
    }
  });

  test('нет запрещённых заявлений и покупки', () {
    const banned = [
      'аноним',
      'kill switch',
      'killswitch',
      'обход',
      'цензур',
      'купить',
      'оплат',
      'подписк',
      'сатып ал',
      'төлөм',
      'жазылуу',
      'paywall',
    ];
    for (final e in [...ru.entries, ...ky.entries]) {
      final v = '${e.value}'.toLowerCase();
      for (final b in banned) {
        expect(v.contains(b), isFalse, reason: '${e.key}: «$b»');
      }
    }
  });

  test('текст о приватности говорит, что оператор видит метаданные', () {
    expect('${ru['privacyOperatorSees']}', contains('видят'));
    expect('${ky['privacyOperatorSees']}', contains('көрө алат'));
  });
}
