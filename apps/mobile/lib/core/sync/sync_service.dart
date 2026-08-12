import 'dart:convert';
import 'dart:math';

import 'package:sync_core/sync_core.dart';

import '../../data/database/app_database.dart';
import '../storage/secure_vault.dart';
import 'hlc_service.dart';
import 'sync_checkpoint.dart';
import 'sync_endpoint.dart';
import 'sync_http_client.dart';
import 'sync_identity.dart';
import 'sync_merge.dart';
import 'sync_order.dart';

final class VaultSetupResult {
  const VaultSetupResult({required this.identity, required this.recoveryCode});

  final SyncIdentity identity;
  final String recoveryCode;
}

final class PairingInviteStatus {
  const PairingInviteStatus({required this.joined, required this.authorized, required this.consumed});

  final bool joined;
  final bool authorized;
  final bool consumed;
}

final class PairingJoinState {
  const PairingJoinState({required this.code, required this.identity});

  final PairingCode code;
  final SyncIdentity identity;
}

final class SyncRunResult {
  const SyncRunResult({required this.uploaded, required this.downloaded, required this.pending});

  final int uploaded;
  final int downloaded;
  final int pending;
}

final class SyncDevice {
  const SyncDevice({
    required this.deviceId,
    required this.exchangePublicKey,
    required this.addedMs,
    required this.activatedMs,
    required this.revokedMs,
    required this.isCurrent,
  });

  final String deviceId;
  final List<int> exchangePublicKey;
  final int? addedMs;
  final int? activatedMs;
  final int? revokedMs;
  final bool isCurrent;

  bool get active => activatedMs != null && revokedMs == null;
}

final class _DeviceDirectory {
  const _DeviceDirectory({required this.epoch, required this.devices});

  final int epoch;
  final List<SyncDevice> devices;
}

final class _PendingRotation {
  const _PendingRotation({
    required this.rotationId,
    required this.expectedEpoch,
    required this.previousRecoveryCode,
  });

  final String rotationId;
  final int expectedEpoch;
  final String? previousRecoveryCode;

  String encode() => jsonEncode(<String, Object?>{
        'v': 1,
        'rotation_id': rotationId,
        'expected_epoch': expectedEpoch,
        'previous_recovery_code': previousRecoveryCode,
      });

  static _PendingRotation? decode(String raw) {
    try {
      final value = jsonDecode(raw);
      if (value is! Map<String, dynamic> || value['v'] != 1) return null;
      final rotationId = value['rotation_id'];
      final expectedEpoch = value['expected_epoch'];
      final previous = value['previous_recovery_code'];
      if (rotationId is! String || expectedEpoch is! int || expectedEpoch < 2 || (previous != null && previous is! String)) {
        return null;
      }
      return _PendingRotation(
        rotationId: rotationId,
        expectedEpoch: expectedEpoch,
        previousRecoveryCode: previous as String?,
      );
    } catch (_) {
      return null;
    }
  }
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

  Future<void> deleteRemoteVault() async {
    if (!endpointConfigured) throw const SyncTransportException('sync_endpoint_not_configured');
    var stored = await identityStore.read();
    if (stored == null) throw const SyncTransportException('sync_not_configured');
    stored = await _prepareRemoteState(stored);
    final response = await httpClient.authenticatedJson(
      identity: stored,
      method: 'DELETE',
      path: '/vault',
    );
    if (response['deleted'] != true) throw const SyncTransportException('invalid_delete_ack');
  }

  Future<List<SyncDevice>> devices() async {
    final stored = await identityStore.read();
    if (stored == null) throw const SyncTransportException('sync_not_configured');
    final identity = await _prepareRemoteState(stored);
    return (await _deviceDirectory(identity)).devices;
  }

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
    var identity = suppliedIdentity ?? await identityStore.read();
    if (identity == null) throw const SyncTransportException('sync_not_configured');
    if (suppliedIdentity == null) identity = await _prepareRemoteState(identity);
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

    // A used recovery code is replaced immediately. At rotated epochs the
    // recovered key is already the current key; the checkpoint is applied by
    // the normal sync preflight before any old history is pulled.
    final newCode = await rotateRecoveryCode(identity);
    return VaultSetupResult(identity: identity, recoveryCode: newCode);
  }

  Future<PairingCode> createPairingInvite() async {
    var identity = await identityStore.read();
    if (identity == null) throw const SyncTransportException('sync_not_configured');
    identity = await _prepareRemoteState(identity);
    final code = PairingCode.generate(identity.vaultId);
    final tokenHash = await NylaPairingCrypto().tokenHash(code);
    await httpClient.authenticatedJson(
      identity: identity,
      method: 'POST',
      path: '/pairing-invites',
      body: {'pairing_id': code.pairingId, 'token_hash': tokenHash},
    );
    return code;
  }

  Future<PairingInviteStatus> progressPairingInvite(PairingCode code) async {
    var identity = await identityStore.read();
    if (identity == null || identity.vaultId != code.vaultId) {
      throw const SyncTransportException('sync_not_configured');
    }
    identity = await _prepareRemoteState(identity);
    final status = await httpClient.unauthenticatedJson(
      vaultId: code.vaultId,
      method: 'GET',
      path: '/pairing-invites/${code.pairingId}',
    );
    final joined = status['target_device_id'] is String;
    final authorized = status['authorized_ms'] is int;
    final consumed = status['consumed_ms'] is int;
    if (joined && !authorized) {
      final package = await NylaPairingCrypto().wrap(
        code: code,
        vaultKey: identity.vaultKey,
        epoch: identity.epoch,
      );
      await httpClient.authenticatedJson(
        identity: identity,
        method: 'POST',
        path: '/pairing-invites/${code.pairingId}/authorize',
        body: {
          'package_nonce': base64UrlNoPadding(package.nonce),
          'package_ciphertext': base64UrlNoPadding(package.ciphertextAndMac),
        },
      );
      return const PairingInviteStatus(joined: true, authorized: true, consumed: false);
    }
    return PairingInviteStatus(joined: joined, authorized: authorized, consumed: consumed);
  }

  Future<PairingJoinState> joinPairing(String encodedCode) async {
    if (!endpointConfigured) throw const SyncTransportException('sync_endpoint_not_configured');
    if (await identityStore.read() != null) throw const SyncTransportException('sync_already_configured');
    final code = PairingCode.parse(encodedCode);
    final identity = SyncIdentity.pendingForVault(deviceId: deviceId, vaultId: code.vaultId);
    final public = await crypto.publicIdentity(identity.keys);
    final signingPublic = base64UrlNoPadding(public.signingPublicKey);
    final exchangePublic = base64UrlNoPadding(public.exchangePublicKey);
    final tokenHash = await NylaPairingCrypto().tokenHash(code);
    final timestamp = '${DateTime.now().millisecondsSinceEpoch}';
    final nonce = _randomId();
    final signature = await crypto.sign(
      pairingJoinPayload(
        vaultId: code.vaultId,
        pairingId: code.pairingId,
        tokenHash: tokenHash,
        deviceId: deviceId,
        signingPublicKey: signingPublic,
        exchangePublicKey: exchangePublic,
        timestamp: timestamp,
        nonce: nonce,
      ),
      identity.keys,
    );
    await httpClient.unauthenticatedJson(
      vaultId: code.vaultId,
      method: 'POST',
      path: '/pairing-invites/${code.pairingId}/join',
      body: {
        'token_hash': tokenHash,
        'target_device_id': deviceId,
        'signing_public_key': signingPublic,
        'exchange_public_key': exchangePublic,
        'timestamp': timestamp,
        'nonce': nonce,
        'signature': base64UrlNoPadding(signature),
      },
    );
    return PairingJoinState(code: code, identity: identity);
  }

  Future<bool> completePairing(PairingJoinState state) async {
    final response = await httpClient.unauthenticatedJson(
      vaultId: state.code.vaultId,
      method: 'GET',
      path: '/pairing-invites/${state.code.pairingId}',
    );
    final nonce = response['package_nonce'];
    final ciphertext = response['package_ciphertext'];
    if (nonce == null || ciphertext == null) return false;
    if (nonce is! String || ciphertext is! String) throw const SyncTransportException('invalid_pairing_package');
    final paired = await NylaPairingCrypto().unwrap(
      code: state.code,
      package: PairingPackage(
        nonce: decodeBase64UrlNoPadding(nonce),
        ciphertextAndMac: decodeBase64UrlNoPadding(ciphertext),
      ),
    );
    final identity = state.identity.copyForVault(
      vaultId: state.code.vaultId,
      vaultKey: paired.vaultKey,
      epoch: paired.epoch,
    );
    await identityStore.write(identity);
    await _writeCursor(0);
    try {
      await httpClient.authenticatedJson(
        identity: identity,
        method: 'POST',
        path: '/pairing-invites/${state.code.pairingId}/consume',
        body: const <String, Object>{},
      );
    } catch (_) {
      await identityStore.delete();
      rethrow;
    }
    return true;
  }

  Future<SyncRunResult> syncNow() async {
    if (!endpointConfigured) throw const SyncTransportException('sync_endpoint_not_configured');
    for (var attempt = 0; attempt < 3; attempt++) {
      final stored = await identityStore.read();
      if (stored == null) throw const SyncTransportException('sync_not_configured');
      try {
        final identity = await _prepareRemoteState(stored);
        final uploaded = await _pushAll(identity);
        final devices = await _deviceSigningKeys(identity);
        final downloaded = await _pullAll(identity, devices);
        return SyncRunResult(
          uploaded: uploaded,
          downloaded: downloaded,
          pending: await database.pendingMutationCount(),
        );
      } on SyncTransportException catch (error) {
        if (error.message != 'vault_key_epoch_changed' || attempt == 2) rethrow;
      }
    }
    throw const SyncTransportException('sync_epoch_retry_exhausted');
  }

  Future<VaultSetupResult> rotateAndRevoke(String targetDeviceId) async {
    if (targetDeviceId == deviceId) throw const SyncTransportException('cannot_revoke_current_device');
    if (!endpointConfigured) throw const SyncTransportException('sync_endpoint_not_configured');

    for (var attempt = 0; attempt < 3; attempt++) {
      await syncNow();
      final identity = await identityStore.read();
      if (identity == null) throw const SyncTransportException('sync_not_configured');
      final directory = await _deviceDirectory(identity);
      if (directory.epoch != identity.epoch) continue;

      SyncDevice? target;
      for (final candidate in directory.devices) {
        if (candidate.deviceId == targetDeviceId) {
          target = candidate;
          break;
        }
      }
      if (target == null || !target.active) throw const SyncTransportException('device_not_found');
      final retained = directory.devices.where((entry) => entry.active && entry.deviceId != targetDeviceId).toList();
      if (retained.isEmpty || !retained.any((entry) => entry.deviceId == identity.deviceId)) {
        throw const SyncTransportException('rotation_has_no_current_device');
      }

      final baseCursor = await _readCursor();
      final checkpointBytes = await SyncCheckpointCodec(database, merge).encode(baseCursor: baseCursor);
      final newVaultKey = _randomBytes(32);
      final newEpoch = identity.epoch + 1;
      final rotationId = _randomId();
      final rotationCrypto = NylaRotationCrypto();
      final packages = <Map<String, Object>>[];
      for (final device in retained) {
        final package = await rotationCrypto.wrapVaultKey(
          vaultId: identity.vaultId,
          sourceDeviceId: identity.deviceId,
          targetDeviceId: device.deviceId,
          targetExchangePublicKey: device.exchangePublicKey,
          newEpoch: newEpoch,
          newVaultKey: newVaultKey,
        );
        packages.add(<String, Object>{
          'target_device_id': device.deviceId,
          'ephemeral_public_key': base64UrlNoPadding(package.ephemeralPublicKey),
          'package_nonce': base64UrlNoPadding(package.nonce),
          'package_ciphertext': base64UrlNoPadding(package.ciphertextAndMac),
        });
      }
      final checkpoint = await rotationCrypto.encryptCheckpoint(
        vaultId: identity.vaultId,
        epoch: newEpoch,
        baseCursor: baseCursor,
        vaultKey: newVaultKey,
        cleartext: checkpointBytes,
      );

      final recoveryCode = RecoveryCode.generate(identity.vaultId);
      final recoveryCrypto = NylaRecoveryCrypto();
      final recoveryEnvelope = await recoveryCrypto.wrapVaultKey(code: recoveryCode, vaultKey: newVaultKey);
      final previousPendingCode = await secureVault.readPendingRecoveryCode();
      final pendingRotation = _PendingRotation(
        rotationId: rotationId,
        expectedEpoch: newEpoch,
        previousRecoveryCode: previousPendingCode,
      );
      await secureVault.writePendingRecoveryCode(recoveryCode.toString());
      await secureVault.writePendingRotation(pendingRotation.encode());

      final body = <String, Object>{
        'rotation_id': rotationId,
        'new_epoch': newEpoch,
        'base_cursor': baseCursor,
        'revoke_device_ids': <String>[targetDeviceId],
        'packages': packages,
        'checkpoint': <String, Object>{
          'nonce': base64UrlNoPadding(checkpoint.nonce),
          'ciphertext': base64UrlNoPadding(checkpoint.ciphertextAndMac),
        },
        'recovery': <String, Object>{
          'recovery_id': recoveryEnvelope.recoveryId,
          'recovery_signing_public_key': base64UrlNoPadding(recoveryEnvelope.recoverySigningPublicKey),
          'wrap_nonce': base64UrlNoPadding(recoveryEnvelope.wrapNonce),
          'wrapped_vault_key': base64UrlNoPadding(recoveryEnvelope.wrappedVaultKey),
        },
      };

      try {
        final response = await httpClient.authenticatedJson(
          identity: identity,
          method: 'POST',
          path: '/rotate',
          body: body,
        );
        if (response['rotation_id'] != rotationId || response['epoch'] != newEpoch || response['base_cursor'] != baseCursor) {
          throw const SyncTransportException('invalid_rotation_ack');
        }
        final rotated = identity.copyWith(epoch: newEpoch, vaultKey: newVaultKey);
        await identityStore.write(rotated);
        await _writeCursor(baseCursor);
        await secureVault.clearPendingRotation();
        return VaultSetupResult(identity: rotated, recoveryCode: recoveryCode.toString());
      } on SyncTransportException catch (error) {
        if (_definitelyRejectedRotation(error.message)) {
          await _restorePendingRecoveryCode(previousPendingCode);
          await secureVault.clearPendingRotation();
          if ((error.message == 'rotation_stale_cursor' || error.message == 'invalid_epoch') && attempt < 2) {
            continue;
          }
        }
        rethrow;
      }
    }
    throw const SyncTransportException('rotation_retry_exhausted');
  }

  Future<SyncIdentity> _prepareRemoteState(SyncIdentity identity) async {
    final cursor = await _readCursor();
    final state = await httpClient.authenticatedJson(
      identity: identity,
      method: 'GET',
      path: '/state',
      query: {'known_epoch': '${identity.epoch}', 'cursor': '$cursor'},
    );
    final remoteEpoch = state['epoch'];
    final currentRotationId = state['rotation_id'];
    if (remoteEpoch is! int || remoteEpoch < 1 || remoteEpoch < identity.epoch) {
      throw const SyncTransportException('invalid_remote_epoch');
    }
    if (remoteEpoch >= 2 && currentRotationId is! String) {
      throw const SyncTransportException('invalid_remote_rotation');
    }

    var prepared = identity;
    if (remoteEpoch > identity.epoch) {
      final raw = await httpClient.authenticatedJson(
        identity: identity,
        method: 'GET',
        path: '/rotations/$remoteEpoch',
      );
      final source = raw['source_device_id'];
      final target = raw['target_device_id'];
      final epoch = raw['epoch'];
      final ephemeral = raw['ephemeral_public_key'];
      final nonce = raw['package_nonce'];
      final ciphertext = raw['package_ciphertext'];
      if (source is! String ||
          target != identity.deviceId ||
          epoch != remoteEpoch ||
          ephemeral is! String ||
          nonce is! String ||
          ciphertext is! String) {
        throw const SyncTransportException('invalid_rotation_package');
      }
      final rotated = await NylaRotationCrypto().unwrapVaultKey(
        vaultId: identity.vaultId,
        targetExchangeSeed: identity.exchangeSeed,
        package: RotationPackage(
          sourceDeviceId: source,
          targetDeviceId: identity.deviceId,
          epoch: remoteEpoch,
          ephemeralPublicKey: decodeBase64UrlNoPadding(ephemeral),
          nonce: decodeBase64UrlNoPadding(nonce),
          ciphertextAndMac: decodeBase64UrlNoPadding(ciphertext),
        ),
      );
      prepared = identity.copyWith(epoch: rotated.epoch, vaultKey: rotated.vaultKey);
    }

    final rawCheckpoint = state['checkpoint'];
    if (rawCheckpoint == null) {
      if (prepared.epoch != identity.epoch) throw const SyncTransportException('rotation_checkpoint_missing');
      await _reconcilePendingRotation(remoteEpoch, currentRotationId as String?);
      return prepared;
    }
    if (rawCheckpoint is! Map<String, dynamic>) throw const SyncTransportException('invalid_rotation_checkpoint');
    final checkpointEpoch = rawCheckpoint['epoch'];
    final checkpointRotationId = rawCheckpoint['rotation_id'];
    final baseCursor = rawCheckpoint['base_cursor'];
    final nonce = rawCheckpoint['nonce'];
    final ciphertext = rawCheckpoint['ciphertext'];
    if (checkpointEpoch != remoteEpoch ||
        checkpointRotationId != currentRotationId ||
        baseCursor is! int ||
        baseCursor < 0 ||
        nonce is! String ||
        ciphertext is! String) {
      throw const SyncTransportException('invalid_rotation_checkpoint');
    }

    final clear = await NylaRotationCrypto().decryptCheckpoint(
      vaultId: identity.vaultId,
      epoch: remoteEpoch,
      baseCursor: baseCursor,
      vaultKey: prepared.vaultKey,
      envelope: RotationCheckpointEnvelope(
        nonce: decodeBase64UrlNoPadding(nonce),
        ciphertextAndMac: decodeBase64UrlNoPadding(ciphertext),
      ),
    );

    // Persist the new key first. If the process dies before checkpoint merge or
    // cursor advancement, the next launch requests and idempotently reapplies
    // the same checkpoint with the already-current key.
    if (prepared.epoch != identity.epoch) await identityStore.write(prepared);
    await SyncCheckpointCodec(database, merge).apply(compressed: clear, expectedBaseCursor: baseCursor);
    await _writeCursor(baseCursor);
    await _reconcilePendingRotation(remoteEpoch, currentRotationId as String?);
    return prepared;
  }

  Future<void> _reconcilePendingRotation(int remoteEpoch, String? currentRotationId) async {
    final raw = await secureVault.readPendingRotation();
    if (raw == null) return;
    final pending = _PendingRotation.decode(raw);
    if (pending == null) {
      await secureVault.clearPendingRotation();
      return;
    }
    if (remoteEpoch < pending.expectedEpoch) {
      await _restorePendingRecoveryCode(pending.previousRecoveryCode);
      await secureVault.clearPendingRotation();
      return;
    }
    if (remoteEpoch == pending.expectedEpoch && currentRotationId == pending.rotationId) {
      // The candidate recovery code stored before the request is the recovery
      // code atomically committed with this exact rotation.
      await secureVault.clearPendingRotation();
      return;
    }

    // A different/newer rotation won. Neither our candidate nor the recovery
    // code it replaced can be assumed current anymore.
    await secureVault.clearPendingRecoveryCode();
    await secureVault.clearPendingRotation();
  }

  Future<_DeviceDirectory> _deviceDirectory(SyncIdentity identity) async {
    final response = await httpClient.authenticatedJson(identity: identity, method: 'GET', path: '/devices');
    final epoch = response['epoch'];
    final rows = response['devices'];
    if (epoch is! int || epoch < 1 || rows is! List) throw const SyncTransportException('invalid_device_list');
    final result = <SyncDevice>[];
    for (final raw in rows) {
      if (raw is! Map<String, dynamic>) throw const SyncTransportException('invalid_device_list');
      final id = raw['device_id'];
      final exchange = raw['exchange_public_key'];
      final added = raw['added_ms'];
      final activated = raw['activated_ms'];
      final revoked = raw['revoked_ms'];
      if (id is! String ||
          exchange is! String ||
          (added != null && added is! int) ||
          (activated != null && activated is! int) ||
          (revoked != null && revoked is! int)) {
        throw const SyncTransportException('invalid_device_list');
      }
      final exchangeBytes = decodeBase64UrlNoPadding(exchange);
      if (exchangeBytes.length != 32) throw const SyncTransportException('invalid_device_list');
      result.add(
        SyncDevice(
          deviceId: id,
          exchangePublicKey: exchangeBytes,
          addedMs: added as int?,
          activatedMs: activated as int?,
          revokedMs: revoked as int?,
          isCurrent: id == identity.deviceId,
        ),
      );
    }
    if (!result.any((entry) => entry.isCurrent && entry.active)) {
      throw const SyncTransportException('self_missing_from_device_list');
    }
    return _DeviceDirectory(epoch: epoch, devices: result);
  }

  Future<int> _pushAll(SyncIdentity identity) async {
    var uploaded = 0;
    while (true) {
      final pending = orderPendingMutations(await database.pendingMutations());
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

  bool _definitelyRejectedRotation(String code) => const <String>{
        'rotation_stale_cursor',
        'invalid_epoch',
        'invalid_rotation',
        'invalid_rotation_checkpoint',
        'invalid_rotation_recovery',
        'duplicate_rotation_target',
        'rotation_targets_revoked_device',
        'rotation_targets_unknown_device',
        'rotation_missing_device_package',
        'cannot_revoke_rotating_device',
        'device_not_found',
        'payload_too_large',
      }.contains(code);

  String _randomId() => base64UrlNoPadding(_randomBytes(16));

  List<int> _randomBytes(int count) {
    final random = Random.secure();
    return List<int>.generate(count, (_) => random.nextInt(256), growable: false);
  }

  Future<void> _restorePendingRecoveryCode(String? previous) => previous == null
      ? secureVault.clearPendingRecoveryCode()
      : secureVault.writePendingRecoveryCode(previous);

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
