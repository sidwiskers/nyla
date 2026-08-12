import 'package:sync_core/sync_core.dart';
import 'package:test/test.dart';

void main() {
  final recovery = NylaRecoveryCrypto();
  final code = RecoveryCode(
    vaultId: 'vault_abcdefghijklmnop',
    secret: List<int>.generate(32, (index) => index),
  );
  final vaultKey = List<int>.generate(32, (index) => 31 - index);

  test('recovery code round trips', () {
    final encoded = code.toString();
    final decoded = RecoveryCode.parse(encoded);
    expect(decoded.vaultId, code.vaultId);
    expect(decoded.secret, code.secret);
  });

  test('wrap and unwrap returns exact vault key', () async {
    final envelope = await recovery.wrapVaultKey(code: code, vaultKey: vaultKey);
    final clear = await recovery.unwrapVaultKey(
      code: code,
      recoveryId: envelope.recoveryId,
      nonce: envelope.wrapNonce,
      wrappedVaultKey: envelope.wrappedVaultKey,
    );
    expect(clear, vaultKey);
  });

  test('wrong recovery secret fails authentication', () async {
    final envelope = await recovery.wrapVaultKey(code: code, vaultKey: vaultKey);
    final wrong = RecoveryCode(vaultId: code.vaultId, secret: List<int>.filled(32, 99));
    await expectLater(
      recovery.unwrapVaultKey(
        code: wrong,
        recoveryId: envelope.recoveryId,
        nonce: envelope.wrapNonce,
        wrappedVaultKey: envelope.wrappedVaultKey,
      ),
      throwsA(isA<RecoveryAuthenticationException>()),
    );
  });
}
