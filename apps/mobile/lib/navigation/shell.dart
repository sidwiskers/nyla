import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/haptics/nyla_haptics.dart';
import '../core/theme/nyla_theme.dart';

class NylaShell extends StatelessWidget {
  const NylaShell({
    required this.location,
    required this.child,
    super.key,
  });

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
    final selected =
        _destinations.indexWhere((entry) => location.startsWith(entry.path)).clamp(0, 4);

    return Scaffold(
      extendBody: true,
      body: child,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(31),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              height: 76,
              padding: const EdgeInsets.symmetric(horizontal: 7),
              decoration: BoxDecoration(
                color: NylaColors.wine.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(31),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x382A111E),
                    blurRadius: 34,
                    offset: Offset(0, 15),
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
    if (primary) return _PrimaryDestination(selected: selected, onTap: onTap);

    return Semantics(
      selected: selected,
      button: true,
      label: entry.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.symmetric(
              horizontal: selected ? 11 : 7,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(19),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  entry.icon,
                  size: 20,
                  color: selected
                      ? Colors.white
                      : const Color(0xFFD5C4CC),
                ),
                const SizedBox(height: 4),
                Text(
                  entry.label,
                  maxLines: 1,
                  style: TextStyle(
                    color: selected
                        ? Colors.white
                        : const Color(0xFFCAB7C0),
                    fontSize: 9.5,
                    height: 1,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryDestination extends StatelessWidget {
  const _PrimaryDestination({
    required this.selected,
    required this.onTap,
  });

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        button: true,
        label: 'Log',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: selected
                      ? const [Color(0xFFF2B1B5), NylaColors.coral]
                      : const [Color(0xFFF4C5C0), Color(0xFFEBA39F)],
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.54),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x422A111E),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(
                selected ? Icons.check_rounded : Icons.add_rounded,
                color: NylaColors.wine,
                size: selected ? 25 : 27,
              ),
            ),
          ),
        ),
      );
}
