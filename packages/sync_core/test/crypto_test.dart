import 'package:sync_core/sync_core.dart';
import 'package:test/test.dart';

void main() {
  final crypto = NylaSyncCrypto();
  const keys = SyncKeyMaterial(
    vaultId: 'vault_abcdefghijklmnop',
    deviceId: 'device_abcdefghijklmnop',
    epoch: 1,
    vaultKey: [
      0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
      16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31,
    ],
    signingSeed: [
      31, 30, 29, 28, 27, 26, 25, 24, 23, 22, 21, 20, 19, 18, 17, 16,
      15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0,
    ],
    exchangeSeed: [
      9, 8, 7, 6, 5, 4, 3, 2, 1, 0, 9, 8, 7, 6, 5, 4,
      3, 2, 1, 0, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0, 9, 8,
    ],
  );

  const operation = SyncPlainOperation(
    opId: 'operation_abcdefghijkl',
    entityId: 'day:21000',
    entityType: 'day',
    field: 'cramps',
    hlc: '1786500000000:2:device_abcdefghijklmnop',
    kind: 'set',
    value: {'value': 'moderate', 'severity': 2},
  );

  test('encrypt, sign, verify and decrypt round trip', () async {
    final public = await crypto.publicIdentity(keys);
    final envelope = await crypto.encryptOperation(operation, keys);
    final clear = await crypto.decryptAndVerify(
      envelope: envelope,
      keys: keys,
      senderSigningPublicKey: public.signingPublicKey,
    );
    expect(clear.opId, operation.opId);
    expect(clear.entityId, operation.entityId);
    expect(clear.field, operation.field);
    expect(clear.value, {'value': 'moderate', 'severity': 2});
  });

  test('tampered ciphertext is rejected', () async {
    final public = await crypto.publicIdentity(keys);
    final envelope = await crypto.encryptOperation(operation, keys);
    final changed = [...envelope.ciphertextAndMac]..[0] ^= 1;
    final tampered = SyncEnvelope(
      vaultId: envelope.vaultId,
      deviceId: envelope.deviceId,
      epoch: envelope.epoch,
      opId: envelope.opId,
      nonce: envelope.nonce,
      ciphertextAndMac: changed,
      signature: envelope.signature,
    );
    await expectLater(
      crypto.decryptAndVerify(
        envelope: tampered,
        keys: keys,
        senderSigningPublicKey: public.signingPublicKey,
      ),
      throwsA(isA<SyncAuthenticationException>()),
    );
  });

  test('different vault key cannot decrypt', () async {
    final public = await crypto.publicIdentity(keys);
    final envelope = await crypto.encryptOperation(operation, keys);
    final wrong = SyncKeyMaterial(
      vaultId: keys.vaultId,
      deviceId: keys.deviceId,
      epoch: keys.epoch,
      vaultKey: List<int>.filled(32, 99),
      signingSeed: keys.signingSeed,
      exchangeSeed: keys.exchangeSeed,
    );
    await expectLater(
      crypto.decryptAndVerify(
        envelope: envelope,
        keys: wrong,
        senderSigningPublicKey: public.signingPublicKey,
      ),
      throwsA(isA<SyncAuthenticationException>()),
    );
  });
}
