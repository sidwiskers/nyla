import 'package:cycle_engine/cycle_engine.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/calendar/calendar_screen.dart';
import '../features/insights/insights_screen.dart';
import '../features/learn/learn_screen.dart';
import '../features/log/log_screen.dart';
import '../features/settings/export_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/today/today_screen.dart';
import 'shell.dart';

final nylaRouter = GoRouter(
  initialLocation: '/today',
  routes: [
    ShellRoute(
      builder: (context, state, child) => NylaShell(location: state.uri.path, child: child),
      routes: [
        GoRoute(path: '/today', builder: (context, state) => const TodayScreen()),
        GoRoute(path: '/calendar', builder: (context, state) => const CalendarScreen()),
        GoRoute(
          path: '/log',
          builder: (context, state) {
            final raw = state.uri.queryParameters['day'];
            LocalDay? day;
            if (raw != null) {
              try {
                day = LocalDay.parseIso(raw);
              } on FormatException {
                day = null;
              }
            }
            return LogScreen(initialDay: day);
          },
        ),
        GoRoute(path: '/insights', builder: (context, state) => const InsightsScreen()),
        GoRoute(path: '/learn', builder: (context, state) => const LearnScreen()),
      ],
    ),
    GoRoute(
      path: '/settings',
      pageBuilder: (context, state) => MaterialPage<void>(
        fullscreenDialog: true,
        child: const SettingsScreen(),
      ),
    ),
    GoRoute(
      path: '/settings/export',
      builder: (context, state) => const ExportScreen(),
    ),
  ],
);
