import 'package:flutter_test/flutter_test.dart';
import 'package:nyla/core/notifications/notification_config.dart';
import 'package:nyla/core/notifications/notification_service.dart';

void main() {
  test('notification config round-trips every user-visible option', () {
    const original = NotificationConfig(
      periodApproaching: true,
      expectedWindowStarts: true,
      dailyLogReminder: true,
      periodDaysBefore: 5,
      dailyHour: 7,
      dailyMinute: 35,
      privacy: NotificationPrivacy.contextual,
    );

    final decoded = NotificationConfig.decode(original.encode());
    expect(decoded.periodApproaching, isTrue);
    expect(decoded.expectedWindowStarts, isTrue);
    expect(decoded.dailyLogReminder, isTrue);
    expect(decoded.periodDaysBefore, 5);
    expect(decoded.dailyHour, 7);
    expect(decoded.dailyMinute, 35);
    expect(decoded.privacy, NotificationPrivacy.contextual);
  });

  test('notification config clamps corrupt numeric preferences and defaults privacy closed', () {
    final decoded = NotificationConfig.decode(
      '{"period_days_before":99,"daily_hour":99,"daily_minute":-8,"privacy":"unknown"}',
    );

    expect(decoded.periodDaysBefore, 7);
    expect(decoded.dailyHour, 23);
    expect(decoded.dailyMinute, 0);
    expect(decoded.privacy, NotificationPrivacy.private);
  });

  test('notification navigation accepts only routes owned by reminder payloads', () {
    expect(NotificationService.routeFromPayload('/calendar'), '/calendar');
    expect(NotificationService.routeFromPayload('/log'), '/log');
    expect(NotificationService.routeFromPayload('/settings'), isNull);
    expect(NotificationService.routeFromPayload('https://example.com'), isNull);
    expect(NotificationService.routeFromPayload(null), isNull);
  });
}
