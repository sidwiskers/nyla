import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

import 'protocol.dart';

final class RecoveryCode {
  const RecoveryCode({required this.vaultId, required this.secret});

  static const prefix = 'NYLA1';

  final String vaultId;
  final List<int> secret;

  factory RecoveryCode.generate(String vaultId) {
    final random = Random.secure();
    return RecoveryCode(
      vaultId: vaultId,
      secret: List<int>.generate(32, (_) => random.nextInt(256), growable: false),
    );
  }

  factory RecoveryCode.parse(String value) {
    final normalized = value.trim();
    final parts = normalized.split('.');
    if (parts.length != 3 || parts[0].toUpperCase() != prefix) {
      throw const FormatException('Invalid Nyla recovery code');
    }
    final vault = parts[1];
    final secret = decodeBase64UrlNoPadding(parts[2]);
    if (!RegExp(r'^[A-Za-z0-9_-]{16,64}$').hasMatch(vault) || secret.length != 32) {
      throw const FormatException('Invalid Nyla recovery code');
    }
    return RecoveryCode(vaultId: vault, secret: secret);
  }

  @override
  String toString() => '$prefix.$vaultId.${base64UrlNoPadding(secret)}';
}

final class RecoveryEnvelopeData {
  const RecoveryEnvelopeData({
    required this.recoveryId,
    required this.recoverySigningPublicKey,
    required this.wrapNonce,
    required this.wrappedVaultKey,
  });

  final String recoveryId;
  final List<int> recoverySigningPublicKey;
  final List<int> wrapNonce;
  final List<int> wrappedVaultKey;
}

final class RecoverySecrets {
  const RecoverySecrets({required this.recoveryId, required this.signingSeed, required this.wrappingKey});

  final String recoveryId;
  final List<int> signingSeed;
  final List<int> wrappingKey;
}

final class NylaRecoveryCrypto {
  NylaRecoveryCrypto({
    Hkdf? hkdf,
    Cipher? cipher,
    Ed25519? signing,
    HashAlgorithm? hash,
  })  : hkdf = hkdf ?? Hkdf(hmac: Hmac.sha256(), outputLength: 32),
        cipher = cipher ?? Xchacha20.poly1305Aead(),
        signing = signing ?? Ed25519(),
        hash = hash ?? Sha256();

  final Hkdf hkdf;
  final Cipher cipher;
  final Ed25519 signing;
  final HashAlgorithm hash;

  Future<RecoverySecrets> derive(RecoveryCode code) async {
    final idHash = await hash.hash(<int>[...code.secret, ...utf8.encode('nyla-recovery-id-v1')]);
    final recoveryId = base64UrlNoPadding(idHash.bytes.take(16).toList(growable: false));
    final signingSeedKey = await hkdf.deriveKey(
      secretKey: SecretKey(code.secret),
      nonce: utf8.encode(code.vaultId),
      info: utf8.encode('nyla-recovery-sign-v1'),
    );
    final wrappingKey = await hkdf.deriveKey(
      secretKey: SecretKey(code.secret),
      nonce: utf8.encode(code.vaultId),
      info: utf8.encode('nyla-recovery-wrap-v1'),
    );
    return RecoverySecrets(
      recoveryId: recoveryId,
      signingSeed: await signingSeedKey.extractBytes(),
      wrappingKey: await wrappingKey.extractBytes(),
    );
  }

  Future<RecoveryEnvelopeData> wrapVaultKey({
    required RecoveryCode code,
    required List<int> vaultKey,
  }) async {
    if (vaultKey.length != 32) throw const FormatException('Vault key must be 256 bits');
    final derived = await derive(code);
    final keyPair = await signing.newKeyPairFromSeed(derived.signingSeed);
    final publicKey = await keyPair.extractPublicKey();
    final nonce = cipher.newNonce();
    final box = await cipher.encrypt(
      vaultKey,
      secretKey: SecretKey(derived.wrappingKey),
      nonce: nonce,
      aad: _aad(code.vaultId, derived.recoveryId),
    );
    return RecoveryEnvelopeData(
      recoveryId: derived.recoveryId,
      recoverySigningPublicKey: publicKey.bytes,
      wrapNonce: nonce,
      wrappedVaultKey: <int>[...box.cipherText, ...box.mac.bytes],
    );
  }

  Future<List<int>> unwrapVaultKey({
    required RecoveryCode code,
    required String recoveryId,
    required List<int> nonce,
    required List<int> wrappedVaultKey,
  }) async {
    final derived = await derive(code);
    if (derived.recoveryId != recoveryId) throw const RecoveryAuthenticationException('Recovery identity mismatch.');
    final macLength = cipher.macAlgorithm.macLength;
    if (nonce.length != cipher.nonceLength || wrappedVaultKey.length < macLength) {
      throw const RecoveryAuthenticationException('Recovery envelope is malformed.');
    }
    final split = wrappedVaultKey.length - macLength;
    try {
      final clear = await cipher.decrypt(
        SecretBox(
          wrappedVaultKey.sublist(0, split),
          nonce: nonce,
          mac: Mac(wrappedVaultKey.sublist(split)),
        ),
        secretKey: SecretKey(derived.wrappingKey),
        aad: _aad(code.vaultId, recoveryId),
      );
      if (clear.length != 32) throw const RecoveryAuthenticationException('Recovered vault key is malformed.');
      return clear;
    } on SecretBoxAuthenticationError {
      throw const RecoveryAuthenticationException('Recovery code could not authenticate the vault.');
    }
  }

  Future<List<int>> signEnrollment({required RecoveryCode code, required List<int> payload}) async {
    final derived = await derive(code);
    final keyPair = await signing.newKeyPairFromSeed(derived.signingSeed);
    return (await signing.sign(payload, keyPair: keyPair)).bytes;
  }

  List<int> _aad(String vaultId, String recoveryId) => utf8.encode('nyla-recovery-v1|$vaultId|$recoveryId');
}

final class RecoveryAuthenticationException implements Exception {
  const RecoveryAuthenticationException(this.message);

  final String message;

  @override
  String toString() => 'RecoveryAuthenticationException: $message';
}
