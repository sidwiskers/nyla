import 'dart:async';
import 'dart:io';

import 'package:cycle_engine/cycle_engine.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'notification_config.dart';

class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _periodApproachingId = 41001;
  static const _windowStartsId = 41002;
  static const _dailyLogId = 41003;
  static const _channelId = 'nyla_reminders_v1';
  static const _allowedRoutes = {'/calendar', '/log'};

  final FlutterLocalNotificationsPlugin _plugin;
  final StreamController<String> _navigationController = StreamController<String>.broadcast();
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
      settings: const InitializationSettings(android: android, iOS: apple, macOS: apple),
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) {
      _initialLaunchRoute = routeFromPayload(launch?.notificationResponse?.payload);
    }
    _initialized = true;
  }

  void _onNotificationResponse(NotificationResponse response) {
    final route = routeFromPayload(response.payload);
    if (route != null && !_navigationController.isClosed) _navigationController.add(route);
  }

  Future<void> cancelAll() async {
    await initialize();
    await _plugin.cancelAll();
  }

  Future<bool?> notificationsEnabled() async {
    await initialize();
    if (Platform.isAndroid) {
      return _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.areNotificationsEnabled();
    }
    if (Platform.isIOS) {
      final options = await _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.checkPermissions();
      return options?.isEnabled;
    }
    if (Platform.isMacOS) {
      final options = await _plugin
          .resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>()
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
              .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
              ?.requestNotificationsPermission() ??
          true;
    } else if (Platform.isIOS) {
      granted = await _plugin
              .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, badge: false, sound: true) ??
          false;
    } else if (Platform.isMacOS) {
      granted = await _plugin
              .resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, badge: false, sound: true) ??
          false;
    }
    return granted;
  }

  Future<void> reschedule({required NotificationConfig config, CyclePrediction? prediction}) async {
    await initialize();
    await _plugin.cancel(id: _periodApproachingId);
    await _plugin.cancel(id: _windowStartsId);
    await _plugin.cancel(id: _dailyLogId);

    if (prediction != null && config.periodApproaching) {
      final reminderDay = prediction.earliestStart.addDays(-config.periodDaysBefore);
      await _scheduleIfFuture(
        id: _periodApproachingId,
        day: reminderDay,
        hour: 9,
        minute: 0,
        body: _copy(config.privacy, contextual: 'Your expected period window is getting closer.'),
        payload: '/calendar',
      );
    }
    if (prediction != null && config.expectedWindowStarts) {
      await _scheduleIfFuture(
        id: _windowStartsId,
        day: prediction.earliestStart,
        hour: 9,
        minute: 0,
        body: _copy(config.privacy, contextual: 'Your expected period window starts around today.'),
        payload: '/calendar',
      );
    }
    if (config.dailyLogReminder) {
      await _scheduleDaily(config);
    }
  }

  Future<void> _scheduleDaily(NotificationConfig config) async {
    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(tz.local, now.year, now.month, now.day, config.dailyHour, config.dailyMinute);
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
    await _plugin.zonedSchedule(
      id: _dailyLogId,
      title: 'Nyla',
      body: _copy(config.privacy, contextual: 'Time for today’s check-in.'),
      scheduledDate: next,
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
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
    final scheduled = tz.TZDateTime(tz.local, date.year, date.month, date.day, hour, minute);
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

  String _copy(NotificationPrivacy privacy, {required String contextual}) =>
      privacy == NotificationPrivacy.private ? 'Nyla reminder.' : contextual;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      'Nyla reminders',
      channelDescription: 'Private period and optional daily logging reminders',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      visibility: NotificationVisibility.private,
    ),
    iOS: DarwinNotificationDetails(presentBadge: false),
    macOS: DarwinNotificationDetails(presentBadge: false),
  );
}
