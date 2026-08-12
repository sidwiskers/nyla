import 'package:cycle_engine/cycle_engine.dart';

const _months = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const _shortMonths = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String monthYear(DateTime value) => '${_months[value.month - 1]} ${value.year}';

String shortDay(LocalDay value) {
  final date = value.utcDate;
  return '${_shortMonths[date.month - 1]} ${date.day}';
}

String friendlyDay(LocalDay value) {
  final date = value.utcDate;
  return '${_months[date.month - 1]} ${date.day}, ${date.year}';
}

String rangeText(LocalDay start, LocalDay end) {
  if (start == end) return shortDay(start);
  final a = start.utcDate;
  final b = end.utcDate;
  if (a.year == b.year && a.month == b.month) {
    return '${_shortMonths[a.month - 1]} ${a.day}–${b.day}';
  }
  return '${shortDay(start)}–${shortDay(end)}';
}
