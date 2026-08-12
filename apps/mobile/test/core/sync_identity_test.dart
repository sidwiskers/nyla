import 'package:flutter_test/flutter_test.dart';
import 'package:nyla/core/sync/sync_identity.dart';

void main() {
  test('sync identity round-trips without changing cryptographic material', () {
    final original = SyncIdentity.create('device-identity-001');
    final decoded = SyncIdentity.decode(original.encode());

    expect(decoded.vaultId, original.vaultId);
    expect(decoded.deviceId, original.deviceId);
    expect(decoded.epoch, original.epoch);
    expect(decoded.vaultKey, original.vaultKey);
    expect(decoded.signingSeed, original.signingSeed);
    expect(decoded.exchangeSeed, original.exchangeSeed);
  });

  test('pending pairing identity keeps permanent device keys when vault material arrives', () {
    final pending = SyncIdentity.pendingForVault(
      deviceId: 'device-identity-002',
      vaultId: 'vault-identity-0002',
    );
    final completed = pending.copyForVault(
      vaultId: 'vault-identity-0002',
      vaultKey: List<int>.filled(32, 7),
      epoch: 4,
    );

    expect(completed.vaultKey, List<int>.filled(32, 7));
    expect(completed.epoch, 4);
    expect(completed.signingSeed, pending.signingSeed);
    expect(completed.exchangeSeed, pending.exchangeSeed);
  });
}
