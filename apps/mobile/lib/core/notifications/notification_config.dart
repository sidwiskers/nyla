import 'dart:convert';

enum NotificationPrivacy { private, contextual }

class NotificationConfig {
  const NotificationConfig({
    this.periodApproaching = false,
    this.expectedWindowStarts = false,
    this.dailyLogReminder = false,
    this.periodDaysBefore = 2,
    this.dailyHour = 20,
    this.dailyMinute = 0,
    this.privacy = NotificationPrivacy.private,
  });

  final bool periodApproaching;
  final bool expectedWindowStarts;
  final bool dailyLogReminder;
  final int periodDaysBefore;
  final int dailyHour;
  final int dailyMinute;
  final NotificationPrivacy privacy;

  NotificationConfig copyWith({
    bool? periodApproaching,
    bool? expectedWindowStarts,
    bool? dailyLogReminder,
    int? periodDaysBefore,
    int? dailyHour,
    int? dailyMinute,
    NotificationPrivacy? privacy,
  }) =>
      NotificationConfig(
        periodApproaching: periodApproaching ?? this.periodApproaching,
        expectedWindowStarts: expectedWindowStarts ?? this.expectedWindowStarts,
        dailyLogReminder: dailyLogReminder ?? this.dailyLogReminder,
        periodDaysBefore: periodDaysBefore ?? this.periodDaysBefore,
        dailyHour: dailyHour ?? this.dailyHour,
        dailyMinute: dailyMinute ?? this.dailyMinute,
        privacy: privacy ?? this.privacy,
      );

  Map<String, Object> toJson() => {
        'period_approaching': periodApproaching,
        'expected_window_starts': expectedWindowStarts,
        'daily_log_reminder': dailyLogReminder,
        'period_days_before': periodDaysBefore,
        'daily_hour': dailyHour,
        'daily_minute': dailyMinute,
        'privacy': privacy.name,
      };

  String encode() => jsonEncode(toJson());

  factory NotificationConfig.decode(String? raw) {
    if (raw == null) return const NotificationConfig();
    try {
      final value = jsonDecode(raw);
      if (value is! Map<String, dynamic>) return const NotificationConfig();
      final days = value['period_days_before'];
      final hour = value['daily_hour'];
      final minute = value['daily_minute'];
      final privacyRaw = value['privacy'];
      return NotificationConfig(
        periodApproaching: value['period_approaching'] == true,
        expectedWindowStarts: value['expected_window_starts'] == true,
        dailyLogReminder: value['daily_log_reminder'] == true,
        periodDaysBefore: days is int ? days.clamp(1, 7) : 2,
        dailyHour: hour is int ? hour.clamp(0, 23) : 20,
        dailyMinute: minute is int ? minute.clamp(0, 59) : 0,
        privacy: privacyRaw == NotificationPrivacy.contextual.name
            ? NotificationPrivacy.contextual
            : NotificationPrivacy.private,
      );
    } catch (_) {
      return const NotificationConfig();
    }
  }
}
