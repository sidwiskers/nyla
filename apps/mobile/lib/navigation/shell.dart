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
        child: Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [NylaColors.wine, Color(0xFF38202D)],
            ),
            borderRadius: BorderRadius.circular(27),
            boxShadow: const [
              BoxShadow(color: Color(0x2C542B3C), blurRadius: 30, offset: Offset(0, 12)),
            ],
          ),
          child: Row(
            children: [
              for (var i = 0; i < _destinations.length; i++)
                Expanded(
                  child: _Destination(
                    entry: _destinations[i],
                    selected: i == selected,
                    isPrimary: _destinations[i].path == '/log',
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
    );
  }
}

class _Destination extends StatelessWidget {
  const _Destination({
    required this.entry,
    required this.selected,
    required this.isPrimary,
    required this.onTap,
  });

  final ({String path, IconData icon, String label}) entry;
  final bool selected;
  final bool isPrimary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? NylaColors.wine : const Color(0xFFEEDFE6);
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
              width: isPrimary ? 42 : (selected ? 42 : 31),
              height: isPrimary ? 42 : 31,
              decoration: BoxDecoration(
                color: isPrimary
                    ? (selected ? NylaColors.coral : NylaColors.rose)
                    : (selected ? NylaColors.cream : Colors.transparent),
                shape: isPrimary ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: isPrimary ? null : BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Icon(
                entry.icon,
                size: isPrimary ? 24 : 20,
                color: isPrimary ? Colors.white : foreground,
              ),
            ),
            if (!isPrimary) ...[
              const SizedBox(height: 3),
              Text(
                entry.label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? Colors.white : const Color(0xFFCDBAC4),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
