import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import 'core/theme/nyla_theme.dart';
import 'navigation/router.dart';
import 'providers.dart';

class NylaApp extends ConsumerWidget {
  const NylaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(cyclePredictionProvider, (_, _) => unawaited(_refreshNotifications(ref)));
    ref.listen(notificationConfigProvider, (_, _) => unawaited(_refreshNotifications(ref)));
    ref.listen(notificationNavigationProvider, (_, next) {
      final route = next.value;
      if (route != null && nylaRouter.state.uri.path != route) nylaRouter.go(route);
    });

    return MaterialApp.router(
      title: 'Nyla',
      debugShowCheckedModeBanner: false,
      theme: NylaTheme.light,
      routerConfig: nylaRouter,
      builder: (context, child) => _PrivacyGate(child: child ?? const SizedBox.shrink()),
    );
  }

  Future<void> _refreshNotifications(WidgetRef ref) async {
    final config = ref.read(notificationConfigProvider).value;
    if (config == null) return;
    final prediction = ref.read(cyclePredictionProvider).value?.prediction;
    final service = await ref.read(notificationServiceProvider.future);
    await service.reschedule(config: config, prediction: prediction);
  }
}

class _PrivacyGate extends ConsumerStatefulWidget {
  const _PrivacyGate({required this.child});

  final Widget child;

  @override
  ConsumerState<_PrivacyGate> createState() => _PrivacyGateState();
}

class _PrivacyGateState extends ConsumerState<_PrivacyGate> with WidgetsBindingObserver {
  bool _concealed = false;
  bool _authenticating = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        if (mounted && !_concealed) setState(() => _concealed = true);
      case AppLifecycleState.resumed:
        unawaited(_resume());
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _resume() async {
    if (_authenticating || !mounted) return;
    final lockEnabled = await ref.read(secureVaultProvider).isAppLockEnabled();
    if (!mounted) return;
    if (!lockEnabled) {
      if (_concealed) setState(() => _concealed = false);
      return;
    }
    await _unlock();
  }

  Future<void> _unlock() async {
    if (_authenticating || !mounted) return;
    setState(() {
      _authenticating = true;
      _concealed = true;
      _message = null;
    });
    var unlocked = false;
    try {
      unlocked = await LocalAuthentication().authenticate(
        localizedReason: 'Unlock Nyla',
        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException {
      unlocked = false;
    }
    if (!mounted) return;
    setState(() {
      _authenticating = false;
      _concealed = !unlocked;
      _message = unlocked ? null : 'Nyla is locked.';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_concealed) return widget.child;
    return ColoredBox(
      color: NylaColors.canvas,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_rounded, size: 34),
                const SizedBox(height: 16),
                Text(
                  _authenticating ? 'Unlocking Nyla…' : (_message ?? 'Nyla is private while you are away.'),
                  textAlign: TextAlign.center,
                ),
                if (!_authenticating) ...[
                  const SizedBox(height: 22),
                  FilledButton(onPressed: _unlock, child: const Text('Unlock')),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
