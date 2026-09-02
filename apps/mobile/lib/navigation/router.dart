import 'package:cycle_engine/cycle_engine.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/calendar/calendar_screen.dart';
import '../features/calendar/period_history_screen.dart';
import '../features/insights/insights_screen.dart';
import '../features/learn/learn_screen.dart';
import '../features/log/log_screen.dart';
import '../features/settings/custom_logs_screen.dart';
import '../features/settings/export_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/settings/sync_screen.dart';
import '../features/today/today_screen.dart';
import 'motion.dart';
import 'shell.dart';

final nylaRouter = GoRouter(
  initialLocation: '/today',
  routes: [
    StatefulShellRoute(
      builder: (context, state, navigationShell) => NylaShell(
        navigationShell: navigationShell,
      ),
      navigatorContainerBuilder: (context, navigationShell, children) =>
          NylaBranchMotion(
        currentIndex: navigationShell.currentIndex,
        reduceMotion: MediaQuery.disableAnimationsOf(context),
        children: children,
      ),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/today',
              pageBuilder: (context, state) => nylaSectionPage(
                key: state.pageKey,
                child: const TodayScreen(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/calendar',
              pageBuilder: (context, state) => nylaSectionPage(
                key: state.pageKey,
                child: const CalendarScreen(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/log',
              pageBuilder: (context, state) {
                final raw = state.uri.queryParameters['day'];
                LocalDay? day;
                if (raw != null) {
                  try {
                    day = LocalDay.parseIso(raw);
                  } on FormatException {
                    day = null;
                  }
                }
                return nylaSectionPage(
                  key: state.pageKey,
                  child: LogScreen(initialDay: day),
                );
              },
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/insights',
              pageBuilder: (context, state) => nylaSectionPage(
                key: state.pageKey,
                child: const InsightsScreen(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/learn',
              pageBuilder: (context, state) => nylaSectionPage(
                key: state.pageKey,
                child: const LearnScreen(),
              ),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/periods',
      pageBuilder: (context, state) => nylaDepthPage(
        key: state.pageKey,
        child: const PeriodHistoryScreen(),
      ),
    ),
    GoRoute(
      path: '/settings',
      pageBuilder: (context, state) => nylaDepthPage(
        key: state.pageKey,
        modal: true,
        child: const SettingsScreen(),
      ),
    ),
    GoRoute(
      path: '/settings/logs',
      pageBuilder: (context, state) => nylaDepthPage(
        key: state.pageKey,
        child: const CustomLogsScreen(),
      ),
    ),
    GoRoute(
      path: '/settings/export',
      pageBuilder: (context, state) => nylaDepthPage(
        key: state.pageKey,
        child: const ExportScreen(),
      ),
    ),
    GoRoute(
      path: '/settings/sync',
      pageBuilder: (context, state) => nylaDepthPage(
        key: state.pageKey,
        child: const SyncScreen(),
      ),
    ),
  ],
);
