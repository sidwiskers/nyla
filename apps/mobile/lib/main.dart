import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import 'app.dart';
import 'core/storage/secure_vault.dart';
import 'data/database/app_database.dart';
import 'providers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NylaBootstrap());
}

class NylaBootstrap extends StatefulWidget {
  const NylaBootstrap({super.key});

  @override
  State<NylaBootstrap> createState() => _NylaBootstrapState();
}

class _NylaBootstrapState extends State<NylaBootstrap> {
  final SecureVault _vault = const SecureVault();
  Future<_BootstrapResult>? _bootstrap;

  @override
  void initState() {
    super.initState();
    _bootstrap = _open();
  }

  Future<_BootstrapResult> _open() async {
    if (await _vault.isAppLockEnabled()) {
      final auth = LocalAuthentication();
      final supported = await auth.isDeviceSupported();
      if (!supported) return const _BootstrapResult.locked('Device authentication is unavailable.');
      try {
        final unlocked = await auth.authenticate(
          localizedReason: 'Unlock Nyla',
          persistAcrossBackgrounding: true,
        );
        if (!unlocked) return const _BootstrapResult.locked('Nyla is locked.');
      } on LocalAuthException {
        return const _BootstrapResult.locked('Nyla is locked.');
      }
    }

    final databaseKey = await _vault.databaseKeyHex();
    final deviceId = await _vault.deviceId();
    final database = await AppDatabase.open(databaseKey);
    return _BootstrapResult.ready(database, deviceId);
  }

  void _retry() {
    setState(() => _bootstrap = _open());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_BootstrapResult>(
      future: _bootstrap,
      builder: (context, snapshot) {
        final result = snapshot.data;
        if (result?.database != null) {
          return ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(result!.database!),
              deviceIdProvider.overrideWithValue(result.deviceId!),
              secureVaultProvider.overrideWithValue(_vault),
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
  const _BootstrapResult.ready(this.database, this.deviceId) : lockedMessage = null;
  const _BootstrapResult.locked(this.lockedMessage)
      : database = null,
        deviceId = null;

  final AppDatabase? database;
  final String? deviceId;
  final String? lockedMessage;
}

class _SplashApp extends StatelessWidget {
  const _SplashApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFFFF9F7),
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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFFFF9F7),
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
