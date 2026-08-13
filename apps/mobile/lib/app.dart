import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/haptics/nyla_haptics.dart';
import 'core/security/app_lock_service.dart';
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
  bool _concealed = true;
  bool _checking = true;
  bool _authenticating = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_checkInitialLock()));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final appLock = ref.read(appLockServiceProvider);

    // The Android PIN/pattern/password UI can pause and resume our activity.
    // That is part of the authentication already in progress, not a reason to
    // start a second lock cycle.
    if (appLock.authenticationInProgress) return;

    switch (state) {
      // `inactive` is also used for short-lived system UI such as camera or
      // notification permission prompts. Treating that as a real background
      // transition creates needless lock prompts while the user is still in
      // Nyla. Only actual background states end the unlocked session.
      case AppLifecycleState.inactive:
        return;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        appLock.lockSession();
        if (mounted && !_concealed) setState(() => _concealed = true);
        return;
      case AppLifecycleState.resumed:
        if (!_checking) unawaited(_resume());
        return;
      case AppLifecycleState.detached:
        return;
    }
  }

  Future<void> _checkInitialLock() async {
    final appLock = ref.read(appLockServiceProvider);
    final enabled = await appLock.isEnabled();
    if (!mounted) return;

    // Bootstrap authenticates before opening the encrypted database. Reuse
    // that successful foreground session instead of prompting a second time.
    if (!enabled || appLock.sessionUnlocked) {
      setState(() {
        _checking = false;
        _concealed = false;
      });
      return;
    }

    setState(() => _checking = false);
    await _unlock();
  }

  Future<void> _resume() async {
    if (_authenticating || _checking || !mounted) return;
    final appLock = ref.read(appLockServiceProvider);
    if (appLock.authenticationInProgress) return;

    final enabled = await appLock.isEnabled();
    if (!mounted) return;
    if (!enabled || appLock.sessionUnlocked) {
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

    final result = await ref.read(appLockServiceProvider).authenticate(
          localizedReason: 'Unlock Nyla',
        );
    if (!mounted) return;

    final unlocked = result == AppLockAuthResult.success;
    setState(() {
      _authenticating = false;
      _concealed = !unlocked;
      _message = switch (result) {
        AppLockAuthResult.success => null,
        AppLockAuthResult.unsupported => 'Phone lock unavailable',
        AppLockAuthResult.cancelled || AppLockAuthResult.failed => 'Still locked',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_concealed) return widget.child;
    return const _PrivacyBackdrop().withContent(
      childBuilder: _buildPrivacyContent,
    );
  }

  Widget _buildPrivacyContent(BuildContext context) {
    return Semantics(
      label: _checking ? 'Nyla is opening' : 'Nyla is locked',
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _BloomMark(size: 112),
              const SizedBox(height: 24),
              Text(
                'Nyla',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: Colors.white,
                      fontSize: 36,
                      letterSpacing: -0.8,
                    ),
              ),
              const SizedBox(height: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Text(
                  _checking
                      ? 'Opening…'
                      : _authenticating
                          ? 'Unlocking…'
                          : (_message ?? 'Locked'),
                  key: ValueKey((_checking, _authenticating, _message)),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: const Color(0xFFE6D9ED),
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              const SizedBox(height: 26),
              if (_checking || _authenticating)
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                    backgroundColor: Color(0x33FFFFFF),
                  ),
                )
              else
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: NylaColors.wine,
                    minimumSize: const Size(190, 54),
                  ),
                  onPressed: () async {
                    await NylaHaptics.select();
                    await _unlock();
                  },
                  icon: const Icon(Icons.lock_open_rounded, size: 19),
                  label: const Text('Unlock'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrivacyBackdrop extends StatelessWidget {
  const _PrivacyBackdrop();

  Widget withContent({required Widget Function(BuildContext context) childBuilder}) {
    return Builder(
      builder: (context) => DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [NylaColors.night, Color(0xFF33203E), NylaColors.wine],
            stops: [0, 0.58, 1],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const Positioned(
              right: -120,
              top: -90,
              child: _AmbientOrb(size: 310, color: Color(0x187F62B0)),
            ),
            const Positioned(
              left: -110,
              bottom: -130,
              child: _AmbientOrb(size: 330, color: Color(0x16D66A91)),
            ),
            SafeArea(child: Center(child: childBuilder(context))),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _AmbientOrb extends StatelessWidget {
  const _AmbientOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

class _BloomMark extends StatelessWidget {
  const _BloomMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _BloomPainter()),
      );
}

class _BloomPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final halo = Paint()..color = const Color(0x1FFFFFFF);
    canvas.drawCircle(center, size.width * 0.48, halo);

    for (var i = 0; i < 6; i++) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate((math.pi * 2 / 6) * i);
      final petal = Paint()
        ..color = i.isEven ? const Color(0xFFE0D3F2) : const Color(0xFFC9B3E8);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(0, -size.height * 0.22),
          width: size.width * 0.23,
          height: size.height * 0.38,
        ),
        petal,
      );
      canvas.restore();
    }

    canvas.drawCircle(center, size.width * 0.105, Paint()..color = const Color(0xFFF5D9B6));
    canvas.drawCircle(center, size.width * 0.045, Paint()..color = NylaColors.wine);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
