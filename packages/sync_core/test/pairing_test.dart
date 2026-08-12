import 'package:sync_core/sync_core.dart';
import 'package:test/test.dart';

void main() {
  final crypto = NylaPairingCrypto();
  final code = PairingCode(
    vaultId: 'vault_abcdefghijklmnop',
    pairingId: 'pairing_abcdefghijkl',
    token: List<int>.generate(32, (index) => index + 1),
  );
  final vaultKey = List<int>.generate(32, (index) => 31 - index);

  test('pairing code round trips', () {
    final decoded = PairingCode.parse(code.toString());
    expect(decoded.vaultId, code.vaultId);
    expect(decoded.pairingId, code.pairingId);
    expect(decoded.token, code.token);
  });

  test('pairing package round trips without exposing vault key', () async {
    final package = await crypto.wrap(code: code, vaultKey: vaultKey, epoch: 4);
    final clear = await crypto.unwrap(code: code, package: package);
    expect(clear.epoch, 4);
    expect(clear.vaultKey, vaultKey);
  });

  test('different QR token cannot open package', () async {
    final package = await crypto.wrap(code: code, vaultKey: vaultKey, epoch: 1);
    final wrong = PairingCode(vaultId: code.vaultId, pairingId: code.pairingId, token: List<int>.filled(32, 7));
    await expectLater(
      crypto.unwrap(code: wrong, package: package),
      throwsA(isA<PairingAuthenticationException>()),
    );
  });
}
