import 'dart:convert';
import 'dart:math';

import 'package:sync_core/sync_core.dart';

import '../storage/secure_vault.dart';

final class SyncIdentity {
  const SyncIdentity({
    required this.vaultId,
    required this.deviceId,
    required this.epoch,
    required this.vaultKey,
    required this.signingSeed,
    required this.exchangeSeed,
  });

  final String vaultId;
  final String deviceId;
  final int epoch;
  final List<int> vaultKey;
  final List<int> signingSeed;
  final List<int> exchangeSeed;

  SyncKeyMaterial get keys => SyncKeyMaterial(
        vaultId: vaultId,
        deviceId: deviceId,
        epoch: epoch,
        vaultKey: vaultKey,
        signingSeed: signingSeed,
        exchangeSeed: exchangeSeed,
      );

  factory SyncIdentity.create(String deviceId) => SyncIdentity(
        vaultId: _randomId(),
        deviceId: deviceId,
        epoch: 1,
        vaultKey: _randomBytes(32),
        signingSeed: _randomBytes(32),
        exchangeSeed: _randomBytes(32),
      );

  factory SyncIdentity.decode(String value) {
    final decoded = jsonDecode(value);
    if (decoded is! Map<String, dynamic> || decoded['v'] != 1) {
      throw const FormatException('Unsupported sync identity');
    }
    final identity = SyncIdentity(
      vaultId: decoded['vault'] as String,
      deviceId: decoded['device'] as String,
      epoch: decoded['epoch'] as int,
      vaultKey: decodeBase64UrlNoPadding(decoded['vault_key'] as String),
      signingSeed: decodeBase64UrlNoPadding(decoded['signing_seed'] as String),
      exchangeSeed: decodeBase64UrlNoPadding(decoded['exchange_seed'] as String),
    );
    identity.keys.validate();
    return identity;
  }

  String encode() => jsonEncode({
        'v': 1,
        'vault': vaultId,
        'device': deviceId,
        'epoch': epoch,
        'vault_key': base64UrlNoPadding(vaultKey),
        'signing_seed': base64UrlNoPadding(signingSeed),
        'exchange_seed': base64UrlNoPadding(exchangeSeed),
      });

  SyncIdentity copyWith({int? epoch, List<int>? vaultKey}) => SyncIdentity(
        vaultId: vaultId,
        deviceId: deviceId,
        epoch: epoch ?? this.epoch,
        vaultKey: vaultKey ?? this.vaultKey,
        signingSeed: signingSeed,
        exchangeSeed: exchangeSeed,
      );

  static String _randomId() => base64UrlNoPadding(_randomBytes(16));

  static List<int> _randomBytes(int count) {
    final random = Random.secure();
    return List<int>.generate(count, (_) => random.nextInt(256), growable: false);
  }
}

final class SyncIdentityStore {
  const SyncIdentityStore(this.secureVault);

  final SecureVault secureVault;

  Future<SyncIdentity?> read() async {
    final raw = await secureVault.readSyncIdentity();
    if (raw == null) return null;
    return SyncIdentity.decode(raw);
  }

  Future<void> write(SyncIdentity identity) => secureVault.writeSyncIdentity(identity.encode());

  Future<void> delete() => secureVault.deleteSyncIdentity();
}
