import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/haptics/nyla_haptics.dart';
import '../core/theme/nyla_theme.dart';
import 'nyla_ui.dart';

class NylaPage extends StatelessWidget {
  const NylaPage({
    required this.title,
    required this.child,
    this.subtitle,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: NylaColors.canvas,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const _AmbientLayer(),
          SafeArea(
            bottom: false,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(22, 18, 20, 12),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 700),
                        child: _PageHeader(title: title, subtitle: subtitle),
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 34),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 700),
                        child: child,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.title, required this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const NylaOverline('Nyla', color: NylaColors.rose, dot: true),
              const Spacer(),
              _SettingsButton(
                onTap: () {
                  NylaHaptics.select();
                  context.push('/settings');
                },
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 32,
                  letterSpacing: -0.85,
                ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: NylaColors.mutedInk,
                      height: 1.42,
                    ),
              ),
            ),
          ],
        ],
      );
}

class _SettingsButton extends StatelessWidget {
  const _SettingsButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => NylaPressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        semanticsLabel: 'Settings',
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFFEFEAE6).withValues(alpha: 0.92),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.86)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0C2A111E),
                blurRadius: 18,
                offset: Offset(0, 7),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.tune_rounded,
            size: 20,
            color: NylaColors.wine,
          ),
        ),
      );
}

class _AmbientLayer extends StatelessWidget {
  const _AmbientLayer();

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(1.15, -1.0),
                  radius: 0.92,
                  colors: [
                    NylaColors.roseWash.withValues(alpha: 0.92),
                    Colors.transparent,
                  ],
                  stops: const [0, 1],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-1.18, 0.75),
                  radius: 0.98,
                  colors: [
                    NylaColors.sageSoft.withValues(alpha: 0.72),
                    Colors.transparent,
                  ],
                  stops: const [0, 1],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.22, 1.16),
                  radius: 0.86,
                  colors: [
                    NylaColors.peachSoft.withValues(alpha: 0.42),
                    Colors.transparent,
                  ],
                  stops: const [0, 1],
                ),
              ),
            ),
          ],
        ),
      );
}
