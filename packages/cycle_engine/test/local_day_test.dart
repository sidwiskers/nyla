import 'package:cycle_engine/cycle_engine.dart';
import 'package:test/test.dart';

void main() {
  test('calendar day is stable across DateTime offsets', () {
    final a = LocalDay.fromDateTime(DateTime.parse('2026-08-12T00:30:00+05:30'));
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
