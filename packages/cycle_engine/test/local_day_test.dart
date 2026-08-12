import 'package:cycle_engine/cycle_engine.dart';
import 'package:test/test.dart';

void main() {
  test('calendar day uses the DateTime calendar components', () {
    // LocalDay intentionally accepts the components it is given. Callers should
    // pass a date-picker/local calendar value, not convert it to UTC first.
    final a = LocalDay.fromDateTime(DateTime(2026, 8, 12, 23, 59));
    final b = LocalDay.parseIso('2026-08-12');
    expect(a, b);
  });

  test('day arithmetic is exact', () {
    final start = LocalDay.parseIso('2026-01-30');
    expect(start.addDays(2).toIsoString(), '2026-02-01');
  });

  test('invalid ISO day is rejected', () {
    expect(() => LocalDay.parseIso('2026-02-31'), throwsFormatException);
  });
}
