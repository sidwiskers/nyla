import 'package:cryptography/cryptography.dart';

import 'protocol.dart';

final class NylaSyncCrypto {
  NylaSyncCrypto({
    Cipher? cipher,
    Ed25519? signatureAlgorithm,
    X25519? exchangeAlgorithm,
    HashAlgorithm? hashAlgorithm,
  })  : cipher = cipher ?? Xchacha20.poly1305Aead(),
        signatureAlgorithm = signatureAlgorithm ?? Ed25519(),
        exchangeAlgorithm = exchangeAlgorithm ?? X25519(),
        hashAlgorithm = hashAlgorithm ?? Sha256();

  final Cipher cipher;
  final Ed25519 signatureAlgorithm;
  final X25519 exchangeAlgorithm;
  final HashAlgorithm hashAlgorithm;

  Future<SyncPublicIdentity> publicIdentity(SyncKeyMaterial keys) async {
    keys.validate();
    final signing = await signatureAlgorithm.newKeyPairFromSeed(keys.signingSeed);
    final exchange = await exchangeAlgorithm.newKeyPairFromSeed(keys.exchangeSeed);
    final signingPublic = await signing.extractPublicKey();
    final exchangePublic = await exchange.extractPublicKey();
    return SyncPublicIdentity(
      signingPublicKey: signingPublic.bytes,
      exchangePublicKey: exchangePublic.bytes,
    );
  }

  Future<List<int>> sign(List<int> message, SyncKeyMaterial keys) async {
    keys.validate();
    final keyPair = await signatureAlgorithm.newKeyPairFromSeed(keys.signingSeed);
    final signature = await signatureAlgorithm.sign(message, keyPair: keyPair);
    return signature.bytes;
  }

  Future<bool> verify({
    required List<int> message,
    required List<int> signature,
    required List<int> publicKey,
  }) async {
    if (signature.length != 64 || publicKey.length != 32) return false;
    return signatureAlgorithm.verify(
      message,
      signature: Signature(
        signature,
        publicKey: SimplePublicKey(publicKey, type: signatureAlgorithm.keyPairType),
      ),
    );
  }

  Future<SyncEnvelope> encryptOperation(SyncPlainOperation operation, SyncKeyMaterial keys) async {
    keys.validate();
    final secretKey = SecretKey(keys.vaultKey);
    final unsigned = SyncEnvelope(
      vaultId: keys.vaultId,
      deviceId: keys.deviceId,
      epoch: keys.epoch,
      opId: operation.opId,
      nonce: cipher.newNonce(),
      ciphertextAndMac: const [],
      signature: const [],
    );
    final secretBox = await cipher.encrypt(
      operation.canonicalBytes(),
      secretKey: secretKey,
      nonce: unsigned.nonce,
      aad: unsigned.aad(),
    );
    final ciphertextAndMac = <int>[...secretBox.cipherText, ...secretBox.mac.bytes];
    final envelopeForSigning = SyncEnvelope(
      vaultId: keys.vaultId,
      deviceId: keys.deviceId,
      epoch: keys.epoch,
      opId: operation.opId,
      nonce: secretBox.nonce,
      ciphertextAndMac: ciphertextAndMac,
      signature: const [],
    );
    return SyncEnvelope(
      vaultId: keys.vaultId,
      deviceId: keys.deviceId,
      epoch: keys.epoch,
      opId: operation.opId,
      nonce: secretBox.nonce,
      ciphertextAndMac: ciphertextAndMac,
      signature: await sign(envelopeForSigning.signaturePayload(), keys),
    );
  }

  Future<SyncPlainOperation> decryptAndVerify({
    required SyncEnvelope envelope,
    required SyncKeyMaterial keys,
    required List<int> senderSigningPublicKey,
  }) async {
    keys.validate();
    if (envelope.vaultId != keys.vaultId || envelope.epoch != keys.epoch) {
      throw const SyncAuthenticationException('Envelope belongs to another vault or key epoch.');
    }
    final signatureOk = await verify(
      message: envelope.signaturePayload(),
      signature: envelope.signature,
      publicKey: senderSigningPublicKey,
    );
    if (!signatureOk) throw const SyncAuthenticationException('Envelope signature is invalid.');

    final macLength = cipher.macAlgorithm.macLength;
    if (envelope.nonce.length != cipher.nonceLength || envelope.ciphertextAndMac.length < macLength) {
      throw const SyncAuthenticationException('Encrypted envelope is malformed.');
    }
    final split = envelope.ciphertextAndMac.length - macLength;
    final secretBox = SecretBox(
      envelope.ciphertextAndMac.sublist(0, split),
      nonce: envelope.nonce,
      mac: Mac(envelope.ciphertextAndMac.sublist(split)),
    );
    try {
      final clear = await cipher.decrypt(
        secretBox,
        secretKey: SecretKey(keys.vaultKey),
        aad: envelope.aad(),
      );
      final operation = SyncPlainOperation.decode(clear);
      if (operation.opId != envelope.opId) {
        throw const SyncAuthenticationException('Operation identifier mismatch.');
      }
      return operation;
    } on SecretBoxAuthenticationError {
      throw const SyncAuthenticationException('Encrypted envelope authentication failed.');
    }
  }

  Future<String> sha256Base64Url(List<int> body) async {
    final hash = await hashAlgorithm.hash(body);
    return base64UrlNoPadding(hash.bytes);
  }
}

final class SyncAuthenticationException implements Exception {
  const SyncAuthenticationException(this.message);

  final String message;

  @override
  String toString() => 'SyncAuthenticationException: $message';
}
