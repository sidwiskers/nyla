import 'dart:ui';

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
    final selected = _destinations.indexWhere((entry) => location.startsWith(entry.path)).clamp(0, 4);
    return Scaffold(
      extendBody: true,
      body: child,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              height: 72,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: const Color(0xEFFFFFFC),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withValues(alpha: 0.88)),
                boxShadow: const [
                  BoxShadow(color: Color(0x2233203E), blurRadius: 28, offset: Offset(0, 12)),
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
  const _Destination({required this.entry, required this.selected, required this.primary, required this.onTap});

  final ({String path, IconData icon, String label}) entry;
  final bool selected;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (primary) {
      return Semantics(
        selected: selected,
        button: true,
        label: entry.label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: selected
                        ? const [NylaColors.violet, NylaColors.rose]
                        : const [NylaColors.wine, NylaColors.violet],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(color: Color(0x337056A3), blurRadius: 16, offset: Offset(0, 7)),
                  ],
                ),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 25),
              ),
            ],
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
        borderRadius: BorderRadius.circular(22),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: selected ? 38 : 30,
              height: 31,
              decoration: BoxDecoration(
                color: selected ? NylaColors.lavenderSoft : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Icon(
                entry.icon,
                size: 20,
                color: selected ? NylaColors.violet : NylaColors.mutedInk,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              entry.label,
              maxLines: 1,
              style: TextStyle(
                fontFamily: 'sans-serif-rounded',
                fontSize: 9.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? NylaColors.wine : NylaColors.mutedInk,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
