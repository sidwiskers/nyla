import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/haptics/nyla_haptics.dart';
import '../core/theme/nyla_theme.dart';
import '../core/theme/nyla_typography.dart';

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
    final palette = context.nyla;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.pageTop, palette.canvas, palette.pageBottom],
          stops: const [0, 0.46, 1],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            right: -88,
            top: -72,
            child: _PageOrb(size: 238, color: palette.orbViolet),
          ),
          Positioned(
            left: -96,
            top: 230,
            child: _PageOrb(size: 208, color: palette.orbRose),
          ),
          SafeArea(
            bottom: false,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(22, 22, 18, 12),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 38,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [palette.violet, palette.rose],
                                      ),
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    title,
                                    style: NylaTypography.display(
                                      Theme.of(context).textTheme.headlineMedium,
                                      size: 33,
                                      opticalSize: 38,
                                      weight: FontWeight.w600,
                                      height: 1.03,
                                      letterSpacing: -0.38,
                                    ),
                                  ),
                                  if (subtitle != null) ...[
                                    const SizedBox(height: 7),
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(maxWidth: 380),
                                      child: Text(
                                        subtitle!,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: palette.mutedInk,
                                              height: 1.4,
                                            ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: palette.glass,
                                shape: BoxShape.circle,
                                border: Border.all(color: palette.glassBorder),
                                boxShadow: [
                                  BoxShadow(
                                    color: palette.shadow,
                                    blurRadius: 18,
                                    offset: const Offset(0, 7),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                tooltip: 'Settings',
                                onPressed: () {
                                  NylaHaptics.select();
                                  context.push('/settings');
                                },
                                icon: const Icon(Icons.tune_rounded, size: 20),
                                color: palette.wine,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 34),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
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

class _PageOrb extends StatelessWidget {
  const _PageOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      );
}
