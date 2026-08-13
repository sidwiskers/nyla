import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/security/app_lock_service.dart';
import 'core/storage/secure_vault.dart';
import 'core/sync/background_sync.dart';
import 'core/sync/sync_run_lock.dart';
import 'core/theme/nyla_appearance.dart';
import 'data/database/app_database.dart';
import 'data/repositories/preferences_repository.dart';
import 'providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Background scheduling is an availability enhancement, never a condition
  // for opening a local-first health app. Foreground/manual sync remains usable
  // if an OEM or platform rejects scheduler initialization.
  try {
    await NylaBackgroundSync.initialize();
  } catch (_) {}
  runApp(const NylaBootstrap());
}

class NylaBootstrap extends StatefulWidget {
  const NylaBootstrap({super.key});

  @override
  State<NylaBootstrap> createState() => _NylaBootstrapState();
}

class _NylaBootstrapState extends State<NylaBootstrap> {
  final SecureVault _vault = const SecureVault();
  final SyncRunLock _syncRunLock = SyncRunLock();
  late final AppLockService _appLock;
  Future<_BootstrapResult>? _bootstrap;
  AppDatabase? _activeDatabase;
  bool _resetting = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _appLock = AppLockService(vault: _vault);
    _bootstrap = _open();
  }

  Future<_BootstrapResult> _open() async {
    if (await _appLock.isEnabled()) {
      final result = await _appLock.authenticate(localizedReason: 'Unlock Nyla');
      if (result == AppLockAuthResult.unsupported) {
        return const _BootstrapResult.locked(
          'Device authentication is unavailable.',
        );
      }
      if (result != AppLockAuthResult.success) {
        return const _BootstrapResult.locked('Nyla is locked.');
      }
    }

    final databaseKey = await _vault.databaseKeyHex();
    final deviceId = await _vault.deviceId();
    final database = await AppDatabase.open(databaseKey);
    _activeDatabase = database;
    final appearance = await PreferencesRepository(database).appearance();
    return _BootstrapResult.ready(database, deviceId, appearance);
  }

  Future<void> _resetLocalData() async {
    if (_resetting) return;
    setState(() => _resetting = true);

    // The state change above removes ProviderScope. Wait one frame so active
    // repository streams are disposed before their database is closed.
    await WidgetsBinding.instance.endOfFrame;
    final database = _activeDatabase;
    _activeDatabase = null;
    try {
      // A queued/running WorkManager isolate must never race local erasure.
      // Once this lock is ours, destroy key material first, then remove
      // SQLCipher files. Cancellation is best-effort only: a stale worker that
      // wakes later re-checks secure storage under this same lock and exits.
      await _syncRunLock.synchronized(() async {
        try {
          await NylaBackgroundSync.cancelPending();
        } catch (_) {}
        if (database != null) await database.close();

        // Destroy the encryption key first. Even if filesystem cleanup is
        // interrupted, remaining SQLCipher pages are cryptographically useless.
        await _vault.clearAll();
        _appLock.lockSession();
        await AppDatabase.deleteLocalFiles();
      });
    } catch (error, stackTrace) {
      if (!mounted) rethrow;
      setState(() {
        _resetting = false;
        _bootstrap = Future<_BootstrapResult>.error(error, stackTrace);
      });
      rethrow;
    }

    if (!mounted) return;
    setState(() {
      _generation += 1;
      _resetting = false;
      _bootstrap = _open();
    });
  }

  void _retry() {
    setState(() => _bootstrap = _open());
  }

  @override
  Widget build(BuildContext context) {
    if (_resetting) return const _SplashApp();
    return FutureBuilder<_BootstrapResult>(
      future: _bootstrap,
      builder: (context, snapshot) {
        final result = snapshot.data;
        if (result?.database != null) {
          return ProviderScope(
            key: ValueKey(_generation),
            overrides: [
              databaseProvider.overrideWithValue(result!.database!),
              deviceIdProvider.overrideWithValue(result.deviceId!),
              secureVaultProvider.overrideWithValue(_vault),
              appLockServiceProvider.overrideWithValue(_appLock),
              resetLocalDataProvider.overrideWithValue(_resetLocalData),
              initialAppearanceProvider.overrideWithValue(result.appearance!),
            ],
            child: const NylaApp(),
          );
        }
        if (result?.lockedMessage != null) {
          return _LockedApp(message: result!.lockedMessage!, onRetry: _retry);
        }
        if (snapshot.hasError) {
          return _LockedApp(
            message: 'Nyla could not open its encrypted data safely.',
            onRetry: _retry,
          );
        }
        return const _SplashApp();
      },
    );
  }
}

class _BootstrapResult {
  const _BootstrapResult.ready(this.database, this.deviceId, this.appearance)
      : lockedMessage = null;
  const _BootstrapResult.locked(this.lockedMessage)
      : database = null,
        deviceId = null,
        appearance = null;

  final AppDatabase? database;
  final String? deviceId;
  final NylaAppearance? appearance;
  final String? lockedMessage;
}

class _SplashApp extends StatelessWidget {
  const _SplashApp();

  @override
  Widget build(BuildContext context) {
    final dark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: dark ? Brightness.dark : Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8269AE),
          brightness: dark ? Brightness.dark : Brightness.light,
        ),
        scaffoldBackgroundColor: dark
            ? const Color(0xFF151219)
            : const Color(0xFFFFF9F7),
      ),
      home: Scaffold(
        body: Center(
          child: Semantics(
            label: 'Opening Nyla',
            child: const SizedBox.square(
              dimension: 28,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          ),
        ),
      ),
    );
  }
}

class _LockedApp extends StatelessWidget {
  const _LockedApp({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final dark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: dark ? Brightness.dark : Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8269AE),
          brightness: dark ? Brightness.dark : Brightness.light,
        ),
        scaffoldBackgroundColor: dark
            ? const Color(0xFF151219)
            : const Color(0xFFFFF9F7),
      ),
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_rounded, size: 34),
                  const SizedBox(height: 18),
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  FilledButton(onPressed: onRetry, child: const Text('Unlock')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
