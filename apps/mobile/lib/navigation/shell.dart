import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/haptics/nyla_haptics.dart';
import '../core/theme/nyla_theme.dart';

class NylaShell extends StatelessWidget {
  const NylaShell({required this.location, required this.child, super.key});

  final String location;
  final Widget child;

  static const _destinations = <({String path, IconData icon, String label})>[
    (path: '/today', icon: Icons.home_rounded, label: 'Today'),
    (path: '/calendar', icon: Icons.calendar_month_rounded, label: 'Calendar'),
    (path: '/log', icon: Icons.add_rounded, label: 'Log'),
    (path: '/insights', icon: Icons.auto_graph_rounded, label: 'Insights'),
    (path: '/learn', icon: Icons.style_rounded, label: 'Learn'),
  ];

  @override
  Widget build(BuildContext context) {
    final selected = _destinations
        .indexWhere((entry) => location.startsWith(entry.path))
        .clamp(0, _destinations.length - 1);
    final palette = context.nyla;

    return Scaffold(
      extendBody: true,
      body: child,
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
              child: Row(
                children: [
                  for (var i = 0; i < _destinations.length; i++)
                    Expanded(
                      child: _Destination(
                        entry: _destinations[i],
                        selected: i == selected,
                        primary: _destinations[i].path == '/log',
                        onTap: () {
                          if (i == selected) return;
                          NylaHaptics.select();
                          context.go(_destinations[i].path);
                        },
                      ),
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

class _Destination extends StatelessWidget {
  const _Destination({
    required this.entry,
    required this.selected,
    required this.primary,
    required this.onTap,
  });

  final ({String path, IconData icon, String label}) entry;
  final bool selected;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.nyla;
    if (primary) {
      return Semantics(
        selected: selected,
        button: true,
        label: entry.label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 170),
              curve: Curves.easeOutCubic,
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: selected ? palette.rose : palette.violet,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: palette.violet.withValues(alpha: 0.24),
                    blurRadius: 12,
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
      );
    }

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
            AnimatedContainer(
              duration: const Duration(milliseconds: 170),
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
            const SizedBox(height: 3),
            Text(
              entry.label,
              maxLines: 1,
              style: TextStyle(
                fontFamily: 'sans-serif-rounded',
                fontSize: 9.4,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? palette.wine : palette.mutedInk,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
