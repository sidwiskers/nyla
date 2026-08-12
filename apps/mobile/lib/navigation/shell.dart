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
    (path: '/today', icon: Icons.today_outlined, label: 'Today'),
    (path: '/calendar', icon: Icons.calendar_month_outlined, label: 'Calendar'),
    (path: '/log', icon: Icons.add_rounded, label: 'Log'),
    (path: '/insights', icon: Icons.bar_chart_rounded, label: 'Insights'),
    (path: '/more', icon: Icons.person_outline_rounded, label: 'More'),
  ];

  @override
  Widget build(BuildContext context) {
    final found = _destinations.indexWhere((entry) => location.startsWith(entry.path));
    final selected = found < 0 ? 0 : found;

    return Scaffold(
      extendBody: true,
      body: child,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: Color(0xF9FFFDFC),
          border: Border(top: BorderSide(color: NylaColors.outline)),
          boxShadow: [
            BoxShadow(color: Color(0x0A30213F), blurRadius: 20, offset: Offset(0, -5)),
          ],
        ),
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: 4),
          child: SizedBox(
            height: 68,
            child: Row(
              children: [
                for (var i = 0; i < _destinations.length; i++)
                  Expanded(
                    child: _Destination(
                      entry: _destinations[i],
                      selected: i == selected,
                      primary: i == 2,
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
    if (primary) {
      return Semantics(
        selected: selected,
        button: true,
        label: 'Log',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: selected ? NylaColors.night : NylaColors.violet,
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(color: Color(0x2530213F), blurRadius: 14, offset: Offset(0, 6)),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(
                selected ? Icons.check_rounded : Icons.add_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
        ),
      );
    }

    final color = selected ? NylaColors.wine : NylaColors.faintInk;
    return Semantics(
      selected: selected,
      button: true,
      label: entry.label,
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(entry.icon, size: 20, color: color),
              const SizedBox(height: 4),
              Text(
                entry.label,
                style: TextStyle(
                  color: color,
                  fontSize: 9.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
