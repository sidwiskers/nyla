import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureVault {
  const SecureVault({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();

  static const _databaseKeyName = 'nyla.database-key.v1';
  static const _deviceIdName = 'nyla.device-id.v1';
  static const _appLockName = 'nyla.app-lock.v1';
  static const _syncIdentityName = 'nyla.sync-identity.v1';
  static const _pendingRecoveryName = 'nyla.pending-recovery.v1';
  static const _pendingRotationName = 'nyla.pending-rotation.v1';

  final FlutterSecureStorage _storage;

  Future<String> databaseKeyHex() async {
    final existing = await existingDatabaseKeyHex();
    if (existing != null) return existing;

    final bytes = _randomBytes(32);
    final key = bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    await _storage.write(key: _databaseKeyName, value: key);
    return key;
  }

  /// Reads the existing database key without creating replacement material.
  ///
  /// Background work uses this fail-closed form so a stale worker that runs
  /// after local erasure cannot recreate Nyla's storage identity.
  Future<String?> existingDatabaseKeyHex() async {
    final existing = await _storage.read(key: _databaseKeyName);
    return existing != null && RegExp(r'^[0-9a-f]{64}$').hasMatch(existing) ? existing : null;
  }

  Future<String> deviceId() async {
    final existing = await existingDeviceId();
    if (existing != null) return existing;
    final id = base64UrlEncode(_randomBytes(16)).replaceAll('=', '');
    await _storage.write(key: _deviceIdName, value: id);
    return id;
  }

  /// Reads the existing installation ID without creating a new installation.
  Future<String?> existingDeviceId() async {
    final existing = await _storage.read(key: _deviceIdName);
    return existing != null && existing.length >= 16 ? existing : null;
  }

  Future<bool> isAppLockEnabled() async => (await _storage.read(key: _appLockName)) == 'true';

  Future<void> setAppLockEnabled(bool enabled) =>
      _storage.write(key: _appLockName, value: enabled ? 'true' : 'false');

  Future<String?> readSyncIdentity() => _storage.read(key: _syncIdentityName);

  Future<void> writeSyncIdentity(String encoded) => _storage.write(key: _syncIdentityName, value: encoded);

  Future<void> deleteSyncIdentity() => _storage.delete(key: _syncIdentityName);

  Future<String?> readPendingRecoveryCode() => _storage.read(key: _pendingRecoveryName);

  Future<void> writePendingRecoveryCode(String code) => _storage.write(key: _pendingRecoveryName, value: code);

  Future<void> clearPendingRecoveryCode() => _storage.delete(key: _pendingRecoveryName);

  Future<String?> readPendingRotation() => _storage.read(key: _pendingRotationName);

  Future<void> writePendingRotation(String value) => _storage.write(key: _pendingRotationName, value: value);

  Future<void> clearPendingRotation() => _storage.delete(key: _pendingRotationName);

  /// Cryptographically forgets every Nyla secret held by this installation,
  /// including the SQLCipher key, sync identity and recovery/rotation state.
  Future<void> clearAll() => _storage.deleteAll();

  List<int> _randomBytes(int count) {
    final random = Random.secure();
    return List<int>.generate(count, (_) => random.nextInt(256), growable: false);
  }
}
