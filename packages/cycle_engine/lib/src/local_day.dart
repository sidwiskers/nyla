/// A timezone-free calendar day represented as days since 1970-01-01 UTC.
///
/// Menstrual events are day-based. Using a DateTime timestamp directly can move
/// an event to a neighboring calendar day when the device timezone changes.
final class LocalDay implements Comparable<LocalDay> {
  static const int _millisPerDay = 24 * 60 * 60 * 1000;

  const LocalDay(this.epochDay);

  final int epochDay;

  factory LocalDay.fromDateTime(DateTime value) {
    final utcMidnight = DateTime.utc(value.year, value.month, value.day);
    return LocalDay(utcMidnight.millisecondsSinceEpoch ~/ _millisPerDay);
  }

  factory LocalDay.parseIso(String value) {
    final parts = value.split('-');
    if (parts.length != 3) {
      throw FormatException('Expected YYYY-MM-DD', value);
    }
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final day = int.parse(parts[2]);
    final parsed = DateTime.utc(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      throw FormatException('Invalid calendar day', value);
    }
    return LocalDay.fromDateTime(parsed);
  }

  DateTime get utcDate =>
      DateTime.fromMillisecondsSinceEpoch(epochDay * _millisPerDay, isUtc: true);

  LocalDay addDays(int days) => LocalDay(epochDay + days);

  int daysUntil(LocalDay other) => other.epochDay - epochDay;

  String toIsoString() {
    final d = utcDate;
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  @override
  int compareTo(LocalDay other) => epochDay.compareTo(other.epochDay);

  @override
  bool operator ==(Object other) => other is LocalDay && other.epochDay == epochDay;

  @override
  int get hashCode => epochDay.hashCode;

  @override
  String toString() => toIsoString();
}
