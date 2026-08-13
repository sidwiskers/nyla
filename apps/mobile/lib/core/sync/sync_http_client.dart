import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:sync_core/sync_core.dart';

import 'sync_identity.dart';

final class SyncHttpClient {
  SyncHttpClient({required this.baseUrl, http.Client? client, NylaSyncCrypto? crypto})
      : _client = client ?? http.Client(),
        _crypto = crypto ?? NylaSyncCrypto();

  static const _requestTimeout = Duration(seconds: 20);

  final String baseUrl;
  final http.Client _client;
  final NylaSyncCrypto _crypto;

  Future<Map<String, dynamic>> bootstrap(SyncIdentity identity) async {
    final public = await _crypto.publicIdentity(identity.keys);
    final signingPublic = base64UrlNoPadding(public.signingPublicKey);
    final exchangePublic = base64UrlNoPadding(public.exchangePublicKey);
    final timestamp = '${DateTime.now().millisecondsSinceEpoch}';
    final nonce = _randomId();
    final signature = await _crypto.sign(
      bootstrapPayload(
        vaultId: identity.vaultId,
        deviceId: identity.deviceId,
        signingPublicKey: signingPublic,
        exchangePublicKey: exchangePublic,
        timestamp: timestamp,
        nonce: nonce,
      ),
      identity.keys,
    );
    return _requestJson(
      identity: identity,
      method: 'POST',
      path: '/bootstrap',
      authenticated: false,
      body: {
        'device_id': identity.deviceId,
        'signing_public_key': signingPublic,
        'exchange_public_key': exchangePublic,
        'timestamp': timestamp,
        'nonce': nonce,
        'signature': base64UrlNoPadding(signature),
      },
    );
  }

  Future<Map<String, dynamic>> unauthenticatedJson({
    required String vaultId,
    required String method,
    required String path,
    Object? body,
  }) =>
      _requestJsonForVault(
        vaultId: vaultId,
        identity: null,
        method: method,
        path: path,
        authenticated: false,
        body: body,
      );

  Future<Map<String, dynamic>> authenticatedJson({
    required SyncIdentity identity,
    required String method,
    required String path,
    Map<String, String>? query,
    Object? body,
  }) =>
      _requestJson(
        identity: identity,
        method: method,
        path: path,
        query: query,
        authenticated: true,
        body: body,
      );

  Future<Map<String, dynamic>> _requestJson({
    required SyncIdentity identity,
    required String method,
    required String path,
    required bool authenticated,
    Map<String, String>? query,
    Object? body,
  }) =>
      _requestJsonForVault(
        vaultId: identity.vaultId,
        identity: identity,
        method: method,
        path: path,
        authenticated: authenticated,
        query: query,
        body: body,
      );

  Future<Map<String, dynamic>> _requestJsonForVault({
    required String vaultId,
    required SyncIdentity? identity,
    required String method,
    required String path,
    required bool authenticated,
    Map<String, String>? query,
    Object? body,
  }) async {
    if (!baseUrl.startsWith('https://')) throw const SyncTransportException('Sync endpoint must use HTTPS.');
    if (authenticated && identity == null) throw const SyncTransportException('Authenticated request lacks identity.');
    final canonical = Uri(path: '/v1/vaults/$vaultId$path', queryParameters: query).toString();
    final endpoint = Uri.parse(baseUrl).resolve(canonical);
    final bodyBytes = body == null ? const <int>[] : utf8.encode(jsonEncode(body));
    final request = http.Request(method, endpoint)
      ..headers['accept'] = 'application/json'
      ..headers['cache-control'] = 'no-store';
    if (body != null) {
      request.headers['content-type'] = 'application/json; charset=utf-8';
      request.bodyBytes = bodyBytes;
    }

    if (authenticated) {
      final authIdentity = identity!;
      final timestamp = '${DateTime.now().millisecondsSinceEpoch}';
      final nonce = _randomId();
      final bodyHash = await _crypto.sha256Base64Url(bodyBytes);
      final signature = await _crypto.sign(
        httpAuthPayload(
          method: method,
          canonicalPath: canonical,
          timestamp: timestamp,
          nonce: nonce,
          bodyHash: bodyHash,
        ),
        authIdentity.keys,
      );
      request.headers['x-nyla-device'] = authIdentity.deviceId;
      request.headers['x-nyla-timestamp'] = timestamp;
      request.headers['x-nyla-nonce'] = nonce;
      request.headers['x-nyla-signature'] = base64UrlNoPadding(signature);
    }

    final streamed = await _client.send(request).timeout(_requestTimeout);
    final bytes = await streamed.stream.toBytes().timeout(_requestTimeout);
    Object? decoded;
    if (bytes.isNotEmpty) {
      try {
        decoded = jsonDecode(utf8.decode(bytes));
      } catch (_) {
        throw SyncTransportException(
          'Sync service returned unreadable data (${streamed.statusCode}).',
          statusCode: streamed.statusCode,
        );
      }
    }
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      final code = decoded is Map<String, dynamic> ? decoded['error'] : null;
      throw SyncTransportException(
        code is String ? code : 'HTTP ${streamed.statusCode}',
        statusCode: streamed.statusCode,
      );
    }
    if (decoded is! Map<String, dynamic>) throw const SyncTransportException('Sync service returned invalid JSON.');
    return decoded;
  }

  String _randomId() {
    final random = Random.secure();
    return base64UrlNoPadding(List<int>.generate(16, (_) => random.nextInt(256), growable: false));
  }
}

final class SyncTransportException implements Exception {
  const SyncTransportException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'SyncTransportException: $message';
}
