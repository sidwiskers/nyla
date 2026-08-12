import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
    (path: '/learn', icon: Icons.local_florist_rounded, label: 'Learn'),
  ];

  @override
  Widget build(BuildContext context) {
    final selected = _destinations.indexWhere((entry) => location.startsWith(entry.path)).clamp(0, 4);
    return Scaffold(
      body: child,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: NylaColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: NylaColors.outline),
            boxShadow: const [
              BoxShadow(color: Color(0x10000000), blurRadius: 24, offset: Offset(0, 8)),
            ],
          ),
          child: SizedBox(
            height: 66,
            child: Row(
              children: [
                for (var i = 0; i < _destinations.length; i++)
                  Expanded(
                    child: _Destination(
                      entry: _destinations[i],
                      selected: i == selected,
                      onTap: () => context.go(_destinations[i].path),
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
  const _Destination({required this.entry, required this.selected, required this.onTap});

  final ({String path, IconData icon, String label}) entry;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
              duration: const Duration(milliseconds: 180),
              width: selected ? 36 : 28,
              height: 30,
              decoration: BoxDecoration(
                color: selected ? NylaColors.roseSoft : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Icon(entry.icon, size: 21, color: selected ? NylaColors.rose : NylaColors.mutedInk),
            ),
            const SizedBox(height: 2),
            Text(
              entry.label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? NylaColors.ink : NylaColors.mutedInk,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
