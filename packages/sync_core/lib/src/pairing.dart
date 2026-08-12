import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

import 'protocol.dart';

final class PairingCode {
  const PairingCode({required this.vaultId, required this.pairingId, required this.token});

  static const prefix = 'NYLAP1';

  final String vaultId;
  final String pairingId;
  final List<int> token;

  factory PairingCode.generate(String vaultId) {
    final random = Random.secure();
    List<int> bytes(int length) => List<int>.generate(length, (_) => random.nextInt(256), growable: false);
    return PairingCode(vaultId: vaultId, pairingId: base64UrlNoPadding(bytes(16)), token: bytes(32));
  }

  factory PairingCode.parse(String value) {
    final parts = value.trim().split('.');
    if (parts.length != 4 || parts[0].toUpperCase() != prefix) {
      throw const FormatException('Invalid Nyla pairing code');
    }
    final vaultId = parts[1];
    final pairingId = parts[2];
    final token = decodeBase64UrlNoPadding(parts[3]);
    if (!RegExp(r'^[A-Za-z0-9_-]{16,64}$').hasMatch(vaultId) ||
        !RegExp(r'^[A-Za-z0-9_-]{16,64}$').hasMatch(pairingId) ||
        token.length != 32) {
      throw const FormatException('Invalid Nyla pairing code');
    }
    return PairingCode(vaultId: vaultId, pairingId: pairingId, token: token);
  }

  @override
  String toString() => '$prefix.$vaultId.$pairingId.${base64UrlNoPadding(token)}';
}

final class PairingPackage {
  const PairingPackage({required this.nonce, required this.ciphertextAndMac});

  final List<int> nonce;
  final List<int> ciphertextAndMac;
}

final class PairedVaultKey {
  const PairedVaultKey({required this.epoch, required this.vaultKey});

  final int epoch;
  final List<int> vaultKey;
}

final class NylaPairingCrypto {
  NylaPairingCrypto({Hkdf? hkdf, Cipher? cipher, HashAlgorithm? hash})
      : hkdf = hkdf ?? Hkdf(hmac: Hmac.sha256(), outputLength: 32),
        cipher = cipher ?? Xchacha20.poly1305Aead(),
        hash = hash ?? Sha256();

  final Hkdf hkdf;
  final Cipher cipher;
  final HashAlgorithm hash;

  Future<String> tokenHash(PairingCode code) async =>
      base64UrlNoPadding((await hash.hash(code.token)).bytes);

  Future<PairingPackage> wrap({
    required PairingCode code,
    required List<int> vaultKey,
    required int epoch,
  }) async {
    if (vaultKey.length != 32 || epoch < 1) throw const FormatException('Invalid vault material');
    final key = await _wrappingKey(code);
    final nonce = cipher.newNonce();
    final clear = utf8.encode(jsonEncode({'v': 1, 'epoch': epoch, 'vault_key': base64UrlNoPadding(vaultKey)}));
    final box = await cipher.encrypt(clear, secretKey: key, nonce: nonce, aad: _aad(code));
    return PairingPackage(nonce: nonce, ciphertextAndMac: [...box.cipherText, ...box.mac.bytes]);
  }

  Future<PairedVaultKey> unwrap({required PairingCode code, required PairingPackage package}) async {
    final macLength = cipher.macAlgorithm.macLength;
    if (package.nonce.length != cipher.nonceLength || package.ciphertextAndMac.length < macLength) {
      throw const PairingAuthenticationException('Pairing package is malformed.');
    }
    final split = package.ciphertextAndMac.length - macLength;
    try {
      final clear = await cipher.decrypt(
        SecretBox(
          package.ciphertextAndMac.sublist(0, split),
          nonce: package.nonce,
          mac: Mac(package.ciphertextAndMac.sublist(split)),
        ),
        secretKey: await _wrappingKey(code),
        aad: _aad(code),
      );
      final decoded = jsonDecode(utf8.decode(clear));
      if (decoded is! Map<String, dynamic> || decoded['v'] != 1) {
        throw const PairingAuthenticationException('Pairing package is invalid.');
      }
      final epoch = decoded['epoch'];
      final key = decoded['vault_key'];
      if (epoch is! int || epoch < 1 || key is! String) {
        throw const PairingAuthenticationException('Pairing package is invalid.');
      }
      final vaultKey = decodeBase64UrlNoPadding(key);
      if (vaultKey.length != 32) throw const PairingAuthenticationException('Pairing vault key is invalid.');
      return PairedVaultKey(epoch: epoch, vaultKey: vaultKey);
    } on SecretBoxAuthenticationError {
      throw const PairingAuthenticationException('Pairing package authentication failed.');
    }
  }

  Future<SecretKey> _wrappingKey(PairingCode code) => hkdf.deriveKey(
        secretKey: SecretKey(code.token),
        nonce: utf8.encode('${code.vaultId}|${code.pairingId}'),
        info: utf8.encode('nyla-pairing-wrap-v1'),
      );

  List<int> _aad(PairingCode code) => utf8.encode('nyla-pairing-v1|${code.vaultId}|${code.pairingId}');
}

final class PairingAuthenticationException implements Exception {
  const PairingAuthenticationException(this.message);

  final String message;

  @override
  String toString() => 'PairingAuthenticationException: $message';
}
