import 'package:local_auth/local_auth.dart';

import '../storage/secure_vault.dart';

enum AppLockAuthResult { success, cancelled, unsupported, failed }

/// Owns Nyla's device-authentication session so lifecycle locking and an
/// in-progress system PIN/biometric prompt can never race each other.
class AppLockService {
  AppLockService({
    required SecureVault vault,
    LocalAuthentication? localAuthentication,
  })  : _vault = vault,
        _localAuthentication = localAuthentication ?? LocalAuthentication();

  final SecureVault _vault;
  final LocalAuthentication _localAuthentication;

  bool _authenticationInProgress = false;
  bool _sessionUnlocked = false;

  bool get authenticationInProgress => _authenticationInProgress;
  bool get sessionUnlocked => _sessionUnlocked;

  Future<bool> isEnabled() => _vault.isAppLockEnabled();

  /// Marks the current foreground session as requiring authentication again.
  /// Calls made while the OS authentication UI is active are intentionally
  /// ignored because that UI can pause/resume the Flutter activity itself.
  void lockSession() {
    if (!_authenticationInProgress) _sessionUnlocked = false;
  }

  Future<AppLockAuthResult> authenticate({required String localizedReason}) async {
    if (_authenticationInProgress) return AppLockAuthResult.failed;

    try {
      if (!await _localAuthentication.isDeviceSupported()) {
        return AppLockAuthResult.unsupported;
      }
    } catch (_) {
      return AppLockAuthResult.failed;
    }

    _authenticationInProgress = true;
    try {
      final authenticated = await _localAuthentication.authenticate(
        localizedReason: localizedReason,
        biometricOnly: false,
        sensitiveTransaction: true,
        // A PIN/pattern/password flow can itself move the Android activity
        // through pause/resume. Retrying that prompt on resume can leave some
        // devices waiting forever. Nyla coordinates lifecycle locking itself.
        persistAcrossBackgrounding: false,
      );
      if (!authenticated) return AppLockAuthResult.cancelled;
      _sessionUnlocked = true;
      return AppLockAuthResult.success;
    } catch (_) {
      return AppLockAuthResult.failed;
    } finally {
      _authenticationInProgress = false;
    }
  }

  Future<bool> setEnabled(bool enabled) async {
    try {
      await _vault.setAppLockEnabled(enabled);
      final stored = await _vault.isAppLockEnabled();
      if (!enabled) _sessionUnlocked = false;
      return stored == enabled;
    } catch (_) {
      return false;
    }
  }
}
