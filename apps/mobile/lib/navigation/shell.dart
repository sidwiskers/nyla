import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/haptics/nyla_haptics.dart';
import '../core/theme/nyla_theme.dart';

class NylaShell extends StatelessWidget {
  const NylaShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  static const _destinations = <({String path, IconData icon, String label})>[
    (path: '/today', icon: Icons.home_rounded, label: 'Today'),
    (path: '/calendar', icon: Icons.calendar_month_rounded, label: 'Calendar'),
    (path: '/log', icon: Icons.add_rounded, label: 'Log'),
    (path: '/insights', icon: Icons.auto_graph_rounded, label: 'Insights'),
    (path: '/learn', icon: Icons.style_rounded, label: 'Learn'),
  ];

  @override
  Widget build(BuildContext context) {
    final selected = navigationShell.currentIndex;
    final palette = context.nyla;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Container(
              height: 70,
              padding: const EdgeInsets.symmetric(horizontal: 7),
              decoration: BoxDecoration(
                color: palette.navSurface,
                borderRadius: BorderRadius.circular(27),
                border: Border.all(color: palette.glassBorder),
                boxShadow: [
                  BoxShadow(
                    color: palette.shadow,
                    blurRadius: 22,
                    offset: const Offset(0, 9),
                  ),
                ],
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _NavigationThread(
                    selected: selected,
                    reduceMotion: reduceMotion,
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < _destinations.length; i++)
                        Expanded(
                          child: _Destination(
                            entry: _destinations[i],
                            selected: i == selected,
                            primary: _destinations[i].path == '/log',
                            reduceMotion: reduceMotion,
                            onTap: () {
                              if (i == selected) return;
                              NylaHaptics.select();
                              navigationShell.goBranch(i);
                            },
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavigationThread extends StatelessWidget {
  const _NavigationThread({required this.selected, required this.reduceMotion});

  final int selected;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final palette = context.nyla;
    final duration =
        reduceMotion ? Duration.zero : const Duration(milliseconds: 330);
    final alignmentX = -1.0 + ((selected / 4) * 2);

    return IgnorePointer(
      child: AnimatedAlign(
        duration: duration,
        curve: const Cubic(0.16, 1, 0.3, 1),
        alignment: Alignment(alignmentX, 1),
        child: Transform.translate(
          offset: const Offset(0, -4),
          child: AnimatedContainer(
            duration: duration,
            curve: const Cubic(0.16, 1, 0.3, 1),
            width: selected == 2 ? 31 : 23,
            height: 3,
            decoration: BoxDecoration(
              color: selected == 2 ? palette.rose : palette.violet,
              borderRadius: BorderRadius.circular(99),
              boxShadow: [
                BoxShadow(
                  color: (selected == 2 ? palette.rose : palette.violet)
                      .withValues(alpha: 0.28),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Destination extends StatelessWidget {
  const _Destination({
    required this.entry,
    required this.selected,
    required this.primary,
    required this.reduceMotion,
    required this.onTap,
  });

  final ({String path, IconData icon, String label}) entry;
  final bool selected;
  final bool primary;
  final bool reduceMotion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.nyla;
    final duration =
        reduceMotion ? Duration.zero : const Duration(milliseconds: 190);
    if (primary) {
      return Semantics(
        selected: selected,
        button: true,
        label: entry.label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Center(
            child: AnimatedScale(
              duration: duration,
              curve: Curves.easeOutCubic,
              scale: selected ? 1.06 : 1,
              child: AnimatedContainer(
                duration: duration,
                curve: Curves.easeOutCubic,
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected ? palette.rose : palette.violet,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (selected ? palette.rose : palette.violet)
                          .withValues(alpha: selected ? 0.3 : 0.22),
                      blurRadius: selected ? 15 : 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF1D1428)
                      : Colors.white,
                  size: 25,
                ),
              ),
            ),
          ),
        ),
      );
    }

    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 9.4,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              color: selected ? palette.wine : palette.mutedInk,
            ) ??
        const TextStyle(fontSize: 9.4);

    return Semantics(
      selected: selected,
      button: true,
      label: entry.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              duration: duration,
              curve: Curves.easeOutCubic,
              scale: selected ? 1.04 : 1,
              child: AnimatedContainer(
                duration: duration,
                curve: Curves.easeOutCubic,
                width: selected ? 38 : 31,
                height: 30,
                decoration: BoxDecoration(
                  color: selected ? palette.lavenderSoft : Colors.transparent,
                  borderRadius: BorderRadius.circular(13),
                ),
                alignment: Alignment.center,
                child: Icon(
                  entry.icon,
                  size: 19,
                  color: selected ? palette.violet : palette.mutedInk,
                ),
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: duration,
              curve: Curves.easeOutCubic,
              style: labelStyle,
              child: Text(entry.label, maxLines: 1),
            ),
          ],
        ),
      ),
    );
  }
}
