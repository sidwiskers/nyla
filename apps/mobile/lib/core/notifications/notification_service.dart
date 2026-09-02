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
  static const _dailyFallbackBaseId = 41100;
  static const _dailyFallbackSlots = 14;
  static const _dailyLongTermFallbackId = 41199;
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
    await _plugin.cancel(id: _dailyLongTermFallbackId);
    for (var index = 0; index < _dailyFallbackSlots; index++) {
      await _plugin.cancel(id: _dailyFallbackBaseId + index);
    }

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
          contextual: periodApproachingCompanionBody(reminderDay.epochDay),
          private: privateCompanionBody(reminderDay.epochDay),
        ),
        payload: '/calendar',
      );
    }

    if (prediction != null && config.expectedWindowStarts) {
      final windowDay = prediction.earliestStart;
      await _scheduleIfFuture(
        id: _windowStartsId,
        day: windowDay,
        hour: 9,
        minute: 0,
        body: _copy(
          config.privacy,
          contextual: expectedWindowCompanionBody(windowDay.epochDay),
          private: privateCompanionBody(windowDay.epochDay + 5),
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

    // Future reminders cannot use today's symptoms without risking stale copy.
    // Keep two weeks of varied neutral messages ready locally. Normal use
    // refreshes this bank long before it runs out, while keeping reschedules
    // light when logs or cycle context change.
    for (var offset = 1; offset <= _dailyFallbackSlots; offset++) {
      final fallbackDay = today.addDays(offset);
      final fallbackDate = fallbackDay.utcDate;
      final scheduled = tz.TZDateTime(
        tz.local,
        fallbackDate.year,
        fallbackDate.month,
        fallbackDate.day,
        config.dailyHour,
        config.dailyMinute,
      );
      await _plugin.zonedSchedule(
        id: _dailyFallbackBaseId + offset - 1,
        title: 'Nyla',
        body: _copy(
          config.privacy,
          contextual: genericCompanionBody(fallbackDay.epochDay),
          private: privateCompanionBody(fallbackDay.epochDay),
        ),
        scheduledDate: scheduled,
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: '/log',
      );
    }

    // Preserve the user's daily reminder even if Nyla has not been opened for
    // more than two weeks. The next launch replaces this simple repeating safety
    // net with a fresh varied bank again.
    final longTermDay = today.addDays(_dailyFallbackSlots + 1);
    final longTermDate = longTermDay.utcDate;
    final longTermStart = tz.TZDateTime(
      tz.local,
      longTermDate.year,
      longTermDate.month,
      longTermDate.day,
      config.dailyHour,
      config.dailyMinute,
    );
    await _plugin.zonedSchedule(
      id: _dailyLongTermFallbackId,
      title: 'Nyla',
      body: _copy(
        config.privacy,
        contextual: genericCompanionBody(longTermDay.epochDay),
        private: privateCompanionBody(longTermDay.epochDay),
      ),
      scheduledDate: longTermStart,
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
      plan.careHour,
      plan.careMinute,
    );
    final now = tz.TZDateTime.now(tz.local);
    if (!scheduled.isAfter(now)) return;

    // Do not stack two Nyla notifications close together. If the user's chosen
    // daily check-in is around this context-specific care moment, the daily
    // personalized notification is enough.
    final dailyMinutes = config.dailyHour * 60 + config.dailyMinute;
    final careMinutes = plan.careHour * 60 + plan.careMinute;
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
