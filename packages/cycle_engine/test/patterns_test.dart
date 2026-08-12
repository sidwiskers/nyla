import 'package:cycle_engine/cycle_engine.dart';
import 'package:test/test.dart';

void main() {
  const analyzer = SymptomPatternAnalyzer();
  final starts = [
    '2026-01-10',
    '2026-02-07',
    '2026-03-07',
    '2026-04-04',
    '2026-05-02',
    '2026-05-30',
  ].map(LocalDay.parseIso).toList();

  test('finds repeated pre-period pattern with adequate explicit coverage', () {
    final observations = <BinaryObservation>[];
    for (var index = 0; index < starts.length; index++) {
      final start = starts[index];
      observations.add(BinaryObservation(day: start.addDays(-3), key: 'headache', present: false));
      observations.add(BinaryObservation(day: start.addDays(-2), key: 'headache', present: index != 4));
      observations.add(BinaryObservation(day: start.addDays(-1), key: 'headache', present: false));
    }

    final patterns = analyzer.analyze(periodStarts: starts, observations: observations);
    expect(patterns, hasLength(1));
    expect(patterns.single.key, 'headache');
    expect(patterns.single.window, CycleWindow.beforePeriod);
    expect(patterns.single.cyclesPresent, 5);
    expect(patterns.single.cyclesObserved, 6);
  });

  test('missing logs never count as symptom absence', () {
    final observations = <BinaryObservation>[];
    for (var index = 0; index < starts.length; index++) {
      observations.add(BinaryObservation(day: starts[index].addDays(-1), key: 'cramps', present: true));
    }

    final patterns = analyzer.analyze(periodStarts: starts, observations: observations);
    expect(patterns, isEmpty, reason: 'Each cycle has only one observed day, below the coverage threshold.');
  });

  test('sporadic symptoms are not promoted to patterns', () {
    final observations = <BinaryObservation>[];
    for (var index = 0; index < starts.length; index++) {
      final start = starts[index];
      observations.add(BinaryObservation(day: start.addDays(-2), key: 'bloating', present: index < 2));
      observations.add(BinaryObservation(day: start.addDays(-1), key: 'bloating', present: false));
    }

    expect(analyzer.analyze(periodStarts: starts, observations: observations), isEmpty);
  });

  test('detects first-two-days pattern separately from pre-period pattern', () {
    final observations = <BinaryObservation>[];
    for (final start in starts) {
      observations.add(BinaryObservation(day: start, key: 'cramps', present: true));
      observations.add(BinaryObservation(day: start.addDays(1), key: 'cramps', present: true));
    }

    final patterns = analyzer.analyze(periodStarts: starts, observations: observations);
    expect(patterns.single.window, CycleWindow.periodStart);
    expect(patterns.single.cyclesPresent, starts.length);
  });
}
