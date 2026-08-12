import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:sync_core/sync_core.dart';

import '../../data/database/app_database.dart';
import '../storage/secure_vault.dart';
import 'hlc_service.dart';
import 'sync_endpoint.dart';
import 'sync_http_client.dart';
import 'sync_identity.dart';
import 'sync_merge.dart';

final class VaultSetupResult {
  const VaultSetupResult({required this.identity, required this.recoveryCode});

  final SyncIdentity identity;
  final String recoveryCode;
}

final class SyncRunResult {
  const SyncRunResult({required this.uploaded, required this.downloaded, required this.pending});

  final int uploaded;
  final int downloaded;
  final int pending;
}

final class SyncService {
  SyncService({
    required this.database,
    required this.deviceId,
    required this.secureVault,
    NylaSyncCrypto? crypto,
    SyncHttpClient? httpClient,
  })  : crypto = crypto ?? NylaSyncCrypto(),
        identityStore = SyncIdentityStore(secureVault),
        httpClient = httpClient ?? SyncHttpClient(baseUrl: SyncEndpoint.baseUrl, crypto: crypto ?? NylaSyncCrypto()),
        merge = SyncMergeEngine(database, HlcService(database, deviceId));

  static const _cursorKey = 'sync.cursor.v1';

  final AppDatabase database;
  final String deviceId;
  final SecureVault secureVault;
  final NylaSyncCrypto crypto;
  final SyncIdentityStore identityStore;
  final SyncHttpClient httpClient;
  final SyncMergeEngine merge;

  bool get endpointConfigured => SyncEndpoint.isConfigured;

  Future<SyncIdentity?> identity() => identityStore.read();

  Future<VaultSetupResult> createVault() async {
    if (!endpointConfigured) throw const SyncTransportException('sync_endpoint_not_configured');
    if (await identityStore.read() != null) throw const SyncTransportException('sync_already_configured');
    final identity = SyncIdentity.create(deviceId);
    await httpClient.bootstrap(identity);
    await identityStore.write(identity);
    await _writeCursor(0);
    final recoveryCode = await rotateRecoveryCode(identity);
    return VaultSetupResult(identity: identity, recoveryCode: recoveryCode);
  }

  Future<String?> pendingRecoveryCode() => secureVault.readPendingRecoveryCode();

  Future<void> confirmRecoveryCodeSaved() => secureVault.clearPendingRecoveryCode();

  Future<String> rotateRecoveryCode([SyncIdentity? suppliedIdentity]) async {
    final identity = suppliedIdentity ?? await identityStore.read();
    if (identity == null) throw const SyncTransportException('sync_not_configured');
    final code = RecoveryCode.generate(identity.vaultId);
    await secureVault.writePendingRecoveryCode(code.toString());
    final recoveryCrypto = NylaRecoveryCrypto();
    final envelope = await recoveryCrypto.wrapVaultKey(code: code, vaultKey: identity.vaultKey);
    await httpClient.authenticatedJson(
      identity: identity,
      method: 'PUT',
      path: '/recovery',
      body: {
        'recovery_id': envelope.recoveryId,
        'recovery_signing_public_key': base64UrlNoPadding(envelope.recoverySigningPublicKey),
        'wrap_nonce': base64UrlNoPadding(envelope.wrapNonce),
        'wrapped_vault_key': base64UrlNoPadding(envelope.wrappedVaultKey),
      },
    );
    return code.toString();
  }

  Future<VaultSetupResult> recoverVault(String encodedCode) async {
    if (!endpointConfigured) throw const SyncTransportException('sync_endpoint_not_configured');
    if (await identityStore.read() != null) throw const SyncTransportException('sync_already_configured');
    final code = RecoveryCode.parse(encodedCode);
    final recoveryCrypto = NylaRecoveryCrypto();
    final derived = await recoveryCrypto.derive(code);
    final envelopeResponse = await httpClient.unauthenticatedJson(
      vaultId: code.vaultId,
      method: 'GET',
      path: '/recovery/${derived.recoveryId}',
    );
    final recoveryId = envelopeResponse['recovery_id'];
    final wrapNonce = envelopeResponse['wrap_nonce'];
    final wrappedVaultKey = envelopeResponse['wrapped_vault_key'];
    if (recoveryId is! String || wrapNonce is! String || wrappedVaultKey is! String) {
      throw const SyncTransportException('invalid_recovery_envelope');
    }
    final vaultKey = await recoveryCrypto.unwrapVaultKey(
      code: code,
      recoveryId: recoveryId,
      nonce: decodeBase64UrlNoPadding(wrapNonce),
      wrappedVaultKey: decodeBase64UrlNoPadding(wrappedVaultKey),
    );

    var identity = SyncIdentity.create(deviceId).copyForVault(vaultId: code.vaultId, vaultKey: vaultKey, epoch: 1);
    final public = await crypto.publicIdentity(identity.keys);
    final signingPublic = base64UrlNoPadding(public.signingPublicKey);
    final exchangePublic = base64UrlNoPadding(public.exchangePublicKey);
    final timestamp = '${DateTime.now().millisecondsSinceEpoch}';
    final nonce = _randomId();
    final signature = await recoveryCrypto.signEnrollment(
      code: code,
      payload: recoveryEnrollmentPayload(
        vaultId: code.vaultId,
        recoveryId: recoveryId,
        deviceId: deviceId,
        signingPublicKey: signingPublic,
        exchangePublicKey: exchangePublic,
        timestamp: timestamp,
        nonce: nonce,
      ),
    );
    final enrolled = await httpClient.unauthenticatedJson(
      vaultId: code.vaultId,
      method: 'POST',
      path: '/recovery/$recoveryId/enroll',
      body: {
        'device_id': deviceId,
        'signing_public_key': signingPublic,
        'exchange_public_key': exchangePublic,
        'timestamp': timestamp,
        'nonce': nonce,
        'signature': base64UrlNoPadding(signature),
      },
    );
    final epoch = enrolled['epoch'];
    if (epoch is! int || epoch < 1) throw const SyncTransportException('invalid_recovery_epoch');
    identity = identity.copyWith(epoch: epoch);
    await identityStore.write(identity);
    await _writeCursor(0);

    // Rotate recovery immediately so a code used for recovery is one-time in practice.
    final newCode = await rotateRecoveryCode(identity);
    return VaultSetupResult(identity: identity, recoveryCode: newCode);
  }

  Future<SyncRunResult> syncNow() async {
    if (!endpointConfigured) throw const SyncTransportException('sync_endpoint_not_configured');
    final identity = await identityStore.read();
    if (identity == null) throw const SyncTransportException('sync_not_configured');

    final uploaded = await _pushAll(identity);
    final devices = await _deviceSigningKeys(identity);
    final downloaded = await _pullAll(identity, devices);
    return SyncRunResult(
      uploaded: uploaded,
      downloaded: downloaded,
      pending: await database.pendingMutationCount(),
    );
  }

  Future<int> _pushAll(SyncIdentity identity) async {
    var uploaded = 0;
    while (true) {
      final pending = await database.pendingMutations();
      if (pending.isEmpty) return uploaded;
      final envelopes = <SyncEnvelope>[];
      for (final mutation in pending) {
        envelopes.add(await crypto.encryptOperation(_plain(mutation), identity.keys));
      }
      final response = await httpClient.authenticatedJson(
        identity: identity,
        method: 'POST',
        path: '/operations',
        body: {'operations': envelopes.map((envelope) => envelope.uploadJson()).toList(growable: false)},
      );
      final accepted = _stringList(response['accepted']);
      final duplicate = _stringList(response['duplicate']);
      final completed = <String>{...accepted, ...duplicate};
      if (completed.isEmpty) throw const SyncTransportException('sync_upload_made_no_progress');
      await database.markMutationsUploaded(completed);
      uploaded += accepted.length;
    }
  }

  Future<Map<String, List<int>>> _deviceSigningKeys(SyncIdentity identity) async {
    final response = await httpClient.authenticatedJson(identity: identity, method: 'GET', path: '/devices');
    final rows = response['devices'];
    if (rows is! List) throw const SyncTransportException('invalid_device_list');
    final result = <String, List<int>>{};
    for (final raw in rows) {
      if (raw is! Map<String, dynamic>) continue;
      final id = raw['device_id'];
      final publicKey = raw['signing_public_key'];
      if (id is String && publicKey is String) result[id] = decodeBase64UrlNoPadding(publicKey);
    }
    if (!result.containsKey(identity.deviceId)) throw const SyncTransportException('self_missing_from_device_list');
    return result;
  }

  Future<int> _pullAll(SyncIdentity identity, Map<String, List<int>> deviceKeys) async {
    var cursor = await _readCursor();
    var downloaded = 0;
    while (true) {
      final response = await httpClient.authenticatedJson(
        identity: identity,
        method: 'GET',
        path: '/operations',
        query: {'since': '$cursor', 'limit': '100'},
      );
      final epoch = response['epoch'];
      if (epoch != identity.epoch) throw const SyncTransportException('vault_key_epoch_changed');
      final operations = response['operations'];
      final nextCursor = response['next_cursor'];
      final hasMore = response['has_more'];
      if (operations is! List || nextCursor is! int || hasMore is! bool) {
        throw const SyncTransportException('invalid_sync_page');
      }

      for (final raw in operations) {
        if (raw is! Map<String, dynamic>) throw const SyncTransportException('invalid_remote_operation');
        final sender = raw['device_id'];
        final opId = raw['op_id'];
        final opEpoch = raw['epoch'];
        final nonce = raw['nonce'];
        final ciphertext = raw['ciphertext'];
        final signature = raw['signature'];
        if (sender is! String ||
            opId is! String ||
            opEpoch is! int ||
            nonce is! String ||
            ciphertext is! String ||
            signature is! String) {
          throw const SyncTransportException('invalid_remote_operation');
        }
        final senderKey = deviceKeys[sender];
        if (senderKey == null) throw const SyncTransportException('unknown_remote_device');
        final envelope = SyncEnvelope(
          vaultId: identity.vaultId,
          deviceId: sender,
          epoch: opEpoch,
          opId: opId,
          nonce: decodeBase64UrlNoPadding(nonce),
          ciphertextAndMac: decodeBase64UrlNoPadding(ciphertext),
          signature: decodeBase64UrlNoPadding(signature),
        );
        final operation = await crypto.decryptAndVerify(
          envelope: envelope,
          keys: identity.keys,
          senderSigningPublicKey: senderKey,
        );
        if (await merge.apply(operation)) downloaded += 1;
      }

      await _writeCursor(nextCursor);
      cursor = nextCursor;
      if (!hasMore) return downloaded;
    }
  }

  SyncPlainOperation _plain(LocalMutationEntry mutation) {
    Object? value;
    if (mutation.valueJson != null) value = jsonDecode(mutation.valueJson!);
    return SyncPlainOperation(
      opId: mutation.opId,
      entityId: mutation.entityId,
      entityType: mutation.entityType,
      field: mutation.field,
      hlc: mutation.hlc,
      kind: mutation.kind,
      value: value,
    );
  }

  List<String> _stringList(Object? raw) {
    if (raw is! List) throw const SyncTransportException('invalid_operation_ack');
    final result = <String>[];
    for (final value in raw) {
      if (value is! String) throw const SyncTransportException('invalid_operation_ack');
      result.add(value);
    }
    return result;
  }

  String _randomId() {
    final random = Random.secure();
    return base64UrlNoPadding(List<int>.generate(16, (_) => random.nextInt(256), growable: false));
  }

  Future<int> _readCursor() async {
    final row = await (database.select(database.syncState)..where((entry) => entry.key.equals(_cursorKey)))
        .getSingleOrNull();
    if (row == null) return 0;
    return int.tryParse(row.value) ?? 0;
  }

  Future<void> _writeCursor(int cursor) => database.into(database.syncState).insertOnConflictUpdate(
        SyncStateCompanion.insert(key: _cursorKey, value: '$cursor'),
      );
}
