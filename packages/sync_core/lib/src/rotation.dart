import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import 'protocol.dart';

final class RotationPackage {
  const RotationPackage({
    required this.sourceDeviceId,
    required this.targetDeviceId,
    required this.epoch,
    required this.ephemeralPublicKey,
    required this.nonce,
    required this.ciphertextAndMac,
  });

  final String sourceDeviceId;
  final String targetDeviceId;
  final int epoch;
  final List<int> ephemeralPublicKey;
  final List<int> nonce;
  final List<int> ciphertextAndMac;
}

final class RotatedVaultKey {
  const RotatedVaultKey({required this.epoch, required this.vaultKey});

  final int epoch;
  final List<int> vaultKey;
}

final class RotationCheckpointEnvelope {
  const RotationCheckpointEnvelope({required this.nonce, required this.ciphertextAndMac});

  final List<int> nonce;
  final List<int> ciphertextAndMac;
}

/// Cryptographic primitives for vault-key rotation.
///
/// A fresh ephemeral X25519 key pair is generated for every target package.
/// The resulting shared secret is domain-separated with HKDF and used only to
/// wrap the new vault key for that target device. The relay therefore cannot
/// decrypt a rotation package, and possession of the previous vault key alone
/// is insufficient to decrypt a package addressed to another device.
final class NylaRotationCrypto {
  NylaRotationCrypto({X25519? exchange, Hkdf? hkdf, Cipher? cipher})
      : exchange = exchange ?? X25519(),
        hkdf = hkdf ?? Hkdf(hmac: Hmac.sha256(), outputLength: 32),
        cipher = cipher ?? Xchacha20.poly1305Aead();

  final X25519 exchange;
  final Hkdf hkdf;
  final Cipher cipher;

  Future<RotationPackage> wrapVaultKey({
    required String vaultId,
    required String sourceDeviceId,
    required String targetDeviceId,
    required List<int> targetExchangePublicKey,
    required int newEpoch,
    required List<int> newVaultKey,
  }) async {
    _validateIds(vaultId, sourceDeviceId, targetDeviceId);
    if (targetExchangePublicKey.length != 32 || newVaultKey.length != 32 || newEpoch < 2) {
      throw const FormatException('Invalid rotation material');
    }

    final ephemeral = await exchange.newKeyPair();
    final ephemeralPublic = await ephemeral.extractPublicKey();
    final remote = SimplePublicKey(targetExchangePublicKey, type: exchange.keyPairType);
    final shared = await exchange.sharedSecretKey(keyPair: ephemeral, remotePublicKey: remote);
    final wrappingKey = await _deriveWrappingKey(
      shared: shared,
      vaultId: vaultId,
      sourceDeviceId: sourceDeviceId,
      targetDeviceId: targetDeviceId,
      epoch: newEpoch,
      ephemeralPublicKey: ephemeralPublic.bytes,
    );
    final nonce = cipher.newNonce();
    final clear = utf8.encode(
      jsonEncode(<String, Object>{
        'v': 1,
        'epoch': newEpoch,
        'vault_key': base64UrlNoPadding(newVaultKey),
      }),
    );
    final box = await cipher.encrypt(
      clear,
      secretKey: wrappingKey,
      nonce: nonce,
      aad: _packageAad(
        vaultId: vaultId,
        sourceDeviceId: sourceDeviceId,
        targetDeviceId: targetDeviceId,
        epoch: newEpoch,
        ephemeralPublicKey: ephemeralPublic.bytes,
      ),
    );
    return RotationPackage(
      sourceDeviceId: sourceDeviceId,
      targetDeviceId: targetDeviceId,
      epoch: newEpoch,
      ephemeralPublicKey: ephemeralPublic.bytes,
      nonce: nonce,
      ciphertextAndMac: <int>[...box.cipherText, ...box.mac.bytes],
    );
  }

  Future<RotatedVaultKey> unwrapVaultKey({
    required String vaultId,
    required List<int> targetExchangeSeed,
    required RotationPackage package,
  }) async {
    _validateIds(vaultId, package.sourceDeviceId, package.targetDeviceId);
    if (targetExchangeSeed.length != 32 ||
        package.ephemeralPublicKey.length != 32 ||
        package.epoch < 2 ||
        package.nonce.length != cipher.nonceLength ||
        package.ciphertextAndMac.length < cipher.macAlgorithm.macLength) {
      throw const RotationAuthenticationException('Rotation package is malformed.');
    }

    final target = await exchange.newKeyPairFromSeed(targetExchangeSeed);
    final remote = SimplePublicKey(package.ephemeralPublicKey, type: exchange.keyPairType);
    final shared = await exchange.sharedSecretKey(keyPair: target, remotePublicKey: remote);
    final wrappingKey = await _deriveWrappingKey(
      shared: shared,
      vaultId: vaultId,
      sourceDeviceId: package.sourceDeviceId,
      targetDeviceId: package.targetDeviceId,
      epoch: package.epoch,
      ephemeralPublicKey: package.ephemeralPublicKey,
    );
    final split = package.ciphertextAndMac.length - cipher.macAlgorithm.macLength;
    try {
      final clear = await cipher.decrypt(
        SecretBox(
          package.ciphertextAndMac.sublist(0, split),
          nonce: package.nonce,
          mac: Mac(package.ciphertextAndMac.sublist(split)),
        ),
        secretKey: wrappingKey,
        aad: _packageAad(
          vaultId: vaultId,
          sourceDeviceId: package.sourceDeviceId,
          targetDeviceId: package.targetDeviceId,
          epoch: package.epoch,
          ephemeralPublicKey: package.ephemeralPublicKey,
        ),
      );
      final decoded = jsonDecode(utf8.decode(clear));
      if (decoded is! Map<String, dynamic> || decoded['v'] != 1 || decoded['epoch'] != package.epoch) {
        throw const RotationAuthenticationException('Rotation package is invalid.');
      }
      final encodedKey = decoded['vault_key'];
      if (encodedKey is! String) throw const RotationAuthenticationException('Rotation package is invalid.');
      final vaultKey = decodeBase64UrlNoPadding(encodedKey);
      if (vaultKey.length != 32) throw const RotationAuthenticationException('Rotated vault key is malformed.');
      return RotatedVaultKey(epoch: package.epoch, vaultKey: vaultKey);
    } on SecretBoxAuthenticationError {
      throw const RotationAuthenticationException('Rotation package authentication failed.');
    } on FormatException {
      throw const RotationAuthenticationException('Rotation package is invalid.');
    }
  }

  Future<RotationCheckpointEnvelope> encryptCheckpoint({
    required String vaultId,
    required int epoch,
    required int baseCursor,
    required List<int> vaultKey,
    required List<int> cleartext,
  }) async {
    if (epoch < 2 || baseCursor < 0 || vaultKey.length != 32) {
      throw const FormatException('Invalid checkpoint material');
    }
    final nonce = cipher.newNonce();
    final box = await cipher.encrypt(
      cleartext,
      secretKey: SecretKey(vaultKey),
      nonce: nonce,
      aad: _checkpointAad(vaultId, epoch, baseCursor),
    );
    return RotationCheckpointEnvelope(
      nonce: nonce,
      ciphertextAndMac: <int>[...box.cipherText, ...box.mac.bytes],
    );
  }

  Future<List<int>> decryptCheckpoint({
    required String vaultId,
    required int epoch,
    required int baseCursor,
    required List<int> vaultKey,
    required RotationCheckpointEnvelope envelope,
  }) async {
    if (epoch < 2 ||
        baseCursor < 0 ||
        vaultKey.length != 32 ||
        envelope.nonce.length != cipher.nonceLength ||
        envelope.ciphertextAndMac.length < cipher.macAlgorithm.macLength) {
      throw const RotationAuthenticationException('Rotation checkpoint is malformed.');
    }
    final split = envelope.ciphertextAndMac.length - cipher.macAlgorithm.macLength;
    try {
      return await cipher.decrypt(
        SecretBox(
          envelope.ciphertextAndMac.sublist(0, split),
          nonce: envelope.nonce,
          mac: Mac(envelope.ciphertextAndMac.sublist(split)),
        ),
        secretKey: SecretKey(vaultKey),
        aad: _checkpointAad(vaultId, epoch, baseCursor),
      );
    } on SecretBoxAuthenticationError {
      throw const RotationAuthenticationException('Rotation checkpoint authentication failed.');
    }
  }

  Future<SecretKey> _deriveWrappingKey({
    required SecretKey shared,
    required String vaultId,
    required String sourceDeviceId,
    required String targetDeviceId,
    required int epoch,
    required List<int> ephemeralPublicKey,
  }) =>
      hkdf.deriveKey(
        secretKey: shared,
        nonce: utf8.encode(vaultId),
        info: utf8.encode(
          'nyla-rotation-wrap-v1|$sourceDeviceId|$targetDeviceId|$epoch|${base64UrlNoPadding(ephemeralPublicKey)}',
        ),
      );

  List<int> _packageAad({
    required String vaultId,
    required String sourceDeviceId,
    required String targetDeviceId,
    required int epoch,
    required List<int> ephemeralPublicKey,
  }) =>
      utf8.encode(
        'nyla-rotation-package-v1|$vaultId|$sourceDeviceId|$targetDeviceId|$epoch|${base64UrlNoPadding(ephemeralPublicKey)}',
      );

  List<int> _checkpointAad(String vaultId, int epoch, int baseCursor) =>
      utf8.encode('nyla-rotation-checkpoint-v1|$vaultId|$epoch|$baseCursor');

  void _validateIds(String vaultId, String sourceDeviceId, String targetDeviceId) {
    final pattern = RegExp(r'^[A-Za-z0-9_-]{16,64}$');
    if (!pattern.hasMatch(vaultId) || !pattern.hasMatch(sourceDeviceId) || !pattern.hasMatch(targetDeviceId)) {
      throw const FormatException('Invalid rotation identity');
    }
  }
}

final class RotationAuthenticationException implements Exception {
  const RotationAuthenticationException(this.message);

  final String message;

  @override
  String toString() => 'RotationAuthenticationException: $message';
}
