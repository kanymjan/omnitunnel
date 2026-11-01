import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../platform/installation_keys.dart';
import 'models.dart';
import 'omni_api.dart';

/// Настоящий клиент API раздела 1.7. Базовый путь /api/v1, JSON, UTC.
///
/// Заголовки доказательства владения даёт Kotlin ([InstallationKeys]).
/// Заголовок Idempotency-Key — допущение, сверить со схемой DRF.
/// В журнал ничего не пишется: ни тела, ни ключи, ни адреса.
class HttpOmniApi implements OmniApi {
  HttpOmniApi({
    required String base,
    required InstallationKeys keys,
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
  })  : _base = Uri.parse(base.endsWith('/') ? base : '$base/')
            .resolve('api/v1/'),
        _keys = keys,
        _client = client ?? http.Client();

  final Uri _base;
  final InstallationKeys _keys;
  final http.Client _client;
  final Duration timeout;

  Future<Object?> _send(
    String method,
    String path, {
    Map<String, Object?>? body,
    String? idempotencyKey,
    bool allowNotFound = false,
  }) async {
    final uri = _base.resolve(path);
    final encoded = body == null ? null : jsonEncode(body);
    final headers = <String, String>{
      'Accept': 'application/json',
      if (encoded != null) 'Content-Type': 'application/json',
      if (idempotencyKey != null) 'Idempotency-Key': idempotencyKey,
      ...await _keys.authHeaders(
          method: method, path: '/api/v1/$path', body: encoded),
    };
    final http.Response res;
    try {
      final req = http.Request(method, uri)..headers.addAll(headers);
      if (encoded != null) req.body = encoded;
      res = await http.Response.fromStream(
          await _client.send(req).timeout(timeout));
    } on SocketException {
      throw const ApiOffline();
    } on http.ClientException {
      throw const ApiOffline();
    } on TimeoutException {
      throw const ApiUnavailable();
    }
    if (allowNotFound && res.statusCode == 404) return null;
    if (res.statusCode >= 500) throw const ApiUnavailable();
    if (res.statusCode >= 400) {
      String? code;
      try {
        final j = jsonDecode(utf8.decode(res.bodyBytes));
        if (j is Map) code = j['code']?.toString();
      } on FormatException {
        code = null;
      }
      throw ApiRejected(res.statusCode, code);
    }
    if (res.bodyBytes.isEmpty) return null;
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  Map<String, Object?> _map(Object? o) => (o as Map).cast<String, Object?>();

  @override
  Future<void> registerInstallation({
    required String publicKey,
    required int consentVersion,
  }) async {
    await _send('POST', 'installations',
        body: {'public_key': publicKey, 'consent_version': consentVersion});
  }

  @override
  Future<List<NodeInfo>> getNodes() async {
    final j = await _send('GET', 'nodes');
    final list = j is Map ? (j['results'] ?? j['nodes']) : j;
    return [
      for (final e in (list as List? ?? const [])) NodeInfo.fromJson(_map(e)),
    ];
  }

  @override
  Future<TrialInfo> createTrial({required String idempotencyKey}) async =>
      TrialInfo.fromJson(
          _map(await _send('POST', 'trials', idempotencyKey: idempotencyKey)));

  @override
  Future<PeerInfo> createPeer({required String idempotencyKey}) async =>
      PeerInfo.fromJson(
          _map(await _send('POST', 'peers', idempotencyKey: idempotencyKey)));

  @override
  Future<TrialInfo?> getCurrentTrial() async {
    final j = await _send('GET', 'trials/current', allowNotFound: true);
    return j == null ? null : TrialInfo.fromJson(_map(j));
  }

  @override
  Future<void> deletePeer(String peerId) async {
    await _send('DELETE', 'peers/${Uri.encodeComponent(peerId)}',
        allowNotFound: true);
  }

  @override
  Future<void> deleteInstallation() async =>
      throw const ApiNotInContract('DELETE installation (PRI-401)');
}
