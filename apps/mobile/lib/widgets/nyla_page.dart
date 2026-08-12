import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/haptics/nyla_haptics.dart';
import '../core/theme/nyla_theme.dart';

class NylaPage extends StatelessWidget {
  const NylaPage({required this.title, required this.child, this.subtitle, super.key});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFF4F0),
            NylaColors.canvas,
            Color(0xFFFFFAF3),
          ],
          stops: [0, 0.52, 1],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(22, 20, 18, 10),
              sliver: SliverToBoxAdapter(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: NylaColors.coral,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 7),
                              const Text(
                                'NYLA',
                                style: TextStyle(
                                  color: NylaColors.rose,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.65,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 9),
                          Text(title, style: Theme.of(context).textTheme.headlineMedium),
                          if (subtitle != null) ...[
                            const SizedBox(height: 5),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 360),
                              child: Text(
                                subtitle!,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: NylaColors.mutedInk,
                                      height: 1.36,
                                    ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Material(
                      color: Colors.white.withValues(alpha: 0.72),
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: 'Settings',
                        onPressed: () {
                          NylaHaptics.select();
                          context.push('/settings');
                        },
                        icon: const Icon(Icons.tune_rounded, size: 20),
                        color: NylaColors.wine,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 34),
              sliver: SliverToBoxAdapter(child: child),
            ),
          ],
        ),
      ),
    );
  }
}
