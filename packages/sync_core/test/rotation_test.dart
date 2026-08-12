import 'package:cryptography/cryptography.dart';
import 'package:sync_core/sync_core.dart';
import 'package:test/test.dart';

void main() {
  final crypto = NylaRotationCrypto();
  final exchange = X25519();
  const vaultId = 'vault_abcdefghijklmnop';
  const sourceId = 'device_source_abcdefgh';
  const targetId = 'device_target_abcdefgh';
  const otherId = 'device_other_abcdefghi';
  final newKey = List<int>.generate(32, (index) => 31 - index);

  test('rotation package can be opened only by its target exchange key', () async {
    final targetSeed = List<int>.generate(32, (index) => index + 1);
    final targetPair = await exchange.newKeyPairFromSeed(targetSeed);
    final targetPublic = await targetPair.extractPublicKey();

    final package = await crypto.wrapVaultKey(
      vaultId: vaultId,
      sourceDeviceId: sourceId,
      targetDeviceId: targetId,
      targetExchangePublicKey: targetPublic.bytes,
      newEpoch: 2,
      newVaultKey: newKey,
    );
    final opened = await crypto.unwrapVaultKey(
      vaultId: vaultId,
      targetExchangeSeed: targetSeed,
      package: package,
    );
    expect(opened.epoch, 2);
    expect(opened.vaultKey, newKey);

    final otherSeed = List<int>.generate(32, (index) => 100 + index);
    await expectLater(
      crypto.unwrapVaultKey(
        vaultId: vaultId,
        targetExchangeSeed: otherSeed,
        package: RotationPackage(
          sourceDeviceId: package.sourceDeviceId,
          targetDeviceId: otherId,
          epoch: package.epoch,
          ephemeralPublicKey: package.ephemeralPublicKey,
          nonce: package.nonce,
          ciphertextAndMac: package.ciphertextAndMac,
        ),
      ),
      throwsA(isA<RotationAuthenticationException>()),
    );
  });

  test('rotation package rejects ciphertext modification', () async {
    final seed = List<int>.filled(32, 7);
    final pair = await exchange.newKeyPairFromSeed(seed);
    final public = await pair.extractPublicKey();
    final package = await crypto.wrapVaultKey(
      vaultId: vaultId,
      sourceDeviceId: sourceId,
      targetDeviceId: targetId,
      targetExchangePublicKey: public.bytes,
      newEpoch: 4,
      newVaultKey: newKey,
    );
    final changed = [...package.ciphertextAndMac]..[0] ^= 1;
    await expectLater(
      crypto.unwrapVaultKey(
        vaultId: vaultId,
        targetExchangeSeed: seed,
        package: RotationPackage(
          sourceDeviceId: package.sourceDeviceId,
          targetDeviceId: package.targetDeviceId,
          epoch: package.epoch,
          ephemeralPublicKey: package.ephemeralPublicKey,
          nonce: package.nonce,
          ciphertextAndMac: changed,
        ),
      ),
      throwsA(isA<RotationAuthenticationException>()),
    );
  });

  test('checkpoint is bound to vault, epoch and base cursor', () async {
    final clear = List<int>.generate(4096, (index) => index % 251);
    final envelope = await crypto.encryptCheckpoint(
      vaultId: vaultId,
      epoch: 3,
      baseCursor: 812,
      vaultKey: newKey,
      cleartext: clear,
    );
    expect(
      await crypto.decryptCheckpoint(
        vaultId: vaultId,
        epoch: 3,
        baseCursor: 812,
        vaultKey: newKey,
        envelope: envelope,
      ),
      clear,
    );
    await expectLater(
      crypto.decryptCheckpoint(
        vaultId: vaultId,
        epoch: 3,
        baseCursor: 813,
        vaultKey: newKey,
        envelope: envelope,
      ),
      throwsA(isA<RotationAuthenticationException>()),
    );
  });
}
