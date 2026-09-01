import 'dart:async';
import 'dart:io';

import 'package:cycle_engine/cycle_engine.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../data/database/app_database.dart';
import 'companion_notification.dart';
import 'notification_config.dart';

class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _periodApproachingId = 41001;
  static const _windowStartsId = 41002;
  static const _dailyLogId = 41003;
  static const _careNudgeId = 41004;
  static const _dailyFallbackId = 41005;
  static const _channelId = 'nyla_reminders_v1';
  static const _allowedRoutes = {'/calendar', '/log'};

  final FlutterLocalNotificationsPlugin _plugin;
  final StreamController<String> _navigationController =
      StreamController<String>.broadcast();
  Future<void> _rescheduleTail = Future<void>.value();
  bool _initialized = false;
  String? _initialLaunchRoute;

  Stream<String> get navigationRoutes => _navigationController.stream;

  String? takeInitialLaunchRoute() {
    final route = _initialLaunchRoute;
    _initialLaunchRoute = null;
    return route;
  }

  static String? routeFromPayload(String? payload) {
    if (payload == null || !_allowedRoutes.contains(payload)) return null;
    return payload;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (_) {
      // The timezone package safely remains on Etc/UTC if a platform reports an
      // unknown identifier. We retry initialization next app launch.
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const apple = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: android,
        iOS: apple,
        macOS: apple,
      ),
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) {
      _initialLaunchRoute =
          routeFromPayload(launch?.notificationResponse?.payload);
    }
    _initialized = true;
  }

  void _onNotificationResponse(NotificationResponse response) {
    final route = routeFromPayload(response.payload);
    if (route != null && !_navigationController.isClosed) {
      _navigationController.add(route);
    }
  }

  Future<void> cancelAll() async {
    await initialize();
    await _plugin.cancelAll();
  }

  Future<bool?> notificationsEnabled() async {
    await initialize();
    if (Platform.isAndroid) {
      return _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.areNotificationsEnabled();
    }
    if (Platform.isIOS) {
      final options = await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.checkPermissions();
      return options?.isEnabled;
    }
    if (Platform.isMacOS) {
      final options = await _plugin
          .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin>()
          ?.checkPermissions();
      return options?.isEnabled;
    }
    return true;
  }

  Future<bool> requestPermission() async {
    await initialize();
    bool granted = true;
    if (Platform.isAndroid) {
      granted = await _plugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.requestNotificationsPermission() ??
          true;
    } else if (Platform.isIOS) {
      granted = await _plugin
              .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, badge: false, sound: true) ??
          false;
    } else if (Platform.isMacOS) {
      granted = await _plugin
              .resolvePlatformSpecificImplementation<
                  MacOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, badge: false, sound: true) ??
          false;
    }
    return granted;
  }

  Future<void> reschedule({
    required NotificationConfig config,
    CyclePrediction? prediction,
    LocalDay? today,
    CyclePhaseContext? phaseContext,
    List<DayValueEntry> dayValues = const <DayValueEntry>[],
  }) {
    final day = today ?? LocalDay.fromDateTime(DateTime.now());
    final plan = _companionPlan(
      day: day,
      phaseContext: phaseContext,
      dayValues: dayValues,
    );

    final next = _rescheduleTail.then(
      (_) => _rescheduleNow(
        config: config,
        prediction: prediction,
        today: day,
        plan: plan,
      ),
      onError: (_) => _rescheduleNow(
        config: config,
        prediction: prediction,
        today: day,
        plan: plan,
      ),
    );
    _rescheduleTail = next;
    return next;
  }

  Future<void> _rescheduleNow({
    required NotificationConfig config,
    required LocalDay today,
    required CompanionNotificationPlan plan,
    CyclePrediction? prediction,
  }) async {
    await initialize();
    await _plugin.cancel(id: _periodApproachingId);
    await _plugin.cancel(id: _windowStartsId);
    await _plugin.cancel(id: _dailyLogId);
    await _plugin.cancel(id: _careNudgeId);
    await _plugin.cancel(id: _dailyFallbackId);

    if (prediction != null && config.periodApproaching) {
      final reminderDay =
          prediction.earliestStart.addDays(-config.periodDaysBefore);
      await _scheduleIfFuture(
        id: _periodApproachingId,
        day: reminderDay,
        hour: 9,
        minute: 0,
        body: _copy(
          config.privacy,
          contextual:
              'Your period may be getting close. Maybe keep the comfy things nearby.',
        ),
        payload: '/calendar',
      );
    }

    if (prediction != null && config.expectedWindowStarts) {
      await _scheduleIfFuture(
        id: _windowStartsId,
        day: prediction.earliestStart,
        hour: 9,
        minute: 0,
        body: _copy(
          config.privacy,
          contextual:
              'Your period could start around now. Be a little extra kind to yourself today.',
        ),
        payload: '/calendar',
      );
    }

    if (!config.dailyLogReminder) return;

    await _scheduleDaily(
      config: config,
      today: today,
      plan: plan,
    );
    await _scheduleCareNudgeIfUseful(
      config: config,
      today: today,
      plan: plan,
    );
  }

  CompanionNotificationPlan _companionPlan({
    required LocalDay day,
    required CyclePhaseContext? phaseContext,
    required List<DayValueEntry> dayValues,
  }) {
    final values = <String, String>{};
    final severities = <String, int>{};
    final moods = <String>{};

    for (final row in dayValues) {
      if (row.key.startsWith('mood.')) {
        moods.add(row.key.substring('mood.'.length));
        continue;
      }
      values[row.key] = row.value;
      if (row.severity != null) severities[row.key] = row.severity!;
    }

    return companionNotificationPlan(
      CompanionNotificationContext(
        phase: phaseContext?.phase,
        cycleDay: phaseContext?.cycleDay,
        daysUntilLikelyPeriod: phaseContext?.daysUntilLikelyPeriod,
        values: values,
        severities: severities,
        moods: moods,
        daySeed: day.epochDay,
      ),
    );
  }

  Future<void> _scheduleDaily({
    required NotificationConfig config,
    required LocalDay today,
    required CompanionNotificationPlan plan,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    final date = today.utcDate;
    final todayAtReminder = tz.TZDateTime(
      tz.local,
      date.year,
      date.month,
      date.day,
      config.dailyHour,
      config.dailyMinute,
    );
    final tomorrow = today.addDays(1).utcDate;
    final fallbackStart = tz.TZDateTime(
      tz.local,
      tomorrow.year,
      tomorrow.month,
      tomorrow.day,
      config.dailyHour,
      config.dailyMinute,
    );

    if (todayAtReminder.isAfter(now)) {
      await _plugin.zonedSchedule(
        id: _dailyLogId,
        title: 'Nyla',
        body: _copy(
          config.privacy,
          contextual: plan.dailyBody,
          private: privateCompanionBody(today.epochDay),
        ),
        scheduledDate: todayAtReminder,
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: '/log',
      );
    }

    // Today's message can use today's context. Future days intentionally fall
    // back to a generic repeating check-in so yesterday's cramps, mood or sleep
    // can never be repeated as though they were still current. Opening Nyla or
    // changing a log replaces the next occurrence with fresh context again.
    await _plugin.zonedSchedule(
      id: _dailyFallbackId,
      title: 'Nyla',
      body: _copy(
        config.privacy,
        contextual:
            'How are you feeling today? No perfect log needed — just a small check-in with yourself.',
        private: privateCompanionBody(today.epochDay + 1),
      ),
      scheduledDate: fallbackStart,
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: '/log',
    );
  }

  Future<void> _scheduleCareNudgeIfUseful({
    required NotificationConfig config,
    required LocalDay today,
    required CompanionNotificationPlan plan,
  }) async {
    final careBody = plan.careBody;
    if (careBody == null) return;

    final date = today.utcDate;
    final scheduled = tz.TZDateTime(
      tz.local,
      date.year,
      date.month,
      date.day,
      14,
    );
    final now = tz.TZDateTime.now(tz.local);
    if (!scheduled.isAfter(now)) return;

    // Do not stack two Nyla notifications close together. If the user's chosen
    // daily check-in is around the daytime care window, that personalized daily
    // notification is enough.
    final dailyMinutes = config.dailyHour * 60 + config.dailyMinute;
    const careMinutes = 14 * 60;
    if ((dailyMinutes - careMinutes).abs() <= 90) return;

    await _plugin.zonedSchedule(
      id: _careNudgeId,
      title: 'Nyla',
      body: _copy(
        config.privacy,
        contextual: careBody,
        private: privateCompanionBody(today.epochDay + 17),
      ),
      scheduledDate: scheduled,
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: '/log',
    );
  }

  Future<void> _scheduleIfFuture({
    required int id,
    required LocalDay day,
    required int hour,
    required int minute,
    required String body,
    required String payload,
  }) async {
    final date = day.utcDate;
    final scheduled =
        tz.TZDateTime(tz.local, date.year, date.month, date.day, hour, minute);
    if (!scheduled.isAfter(tz.TZDateTime.now(tz.local))) return;
    await _plugin.zonedSchedule(
      id: id,
      title: 'Nyla',
      body: body,
      scheduledDate: scheduled,
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
  }

  String _copy(
    NotificationPrivacy privacy, {
    required String contextual,
    String private = 'Nyla is thinking of you.',
  }) =>
      privacy == NotificationPrivacy.private ? private : contextual;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      'Nyla reminders',
      channelDescription: 'Private period reminders and optional Nyla check-ins',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      visibility: NotificationVisibility.private,
    ),
    iOS: DarwinNotificationDetails(presentBadge: false),
    macOS: DarwinNotificationDetails(presentBadge: false),
  );
}
