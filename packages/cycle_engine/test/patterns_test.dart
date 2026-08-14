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
    final pattern = patterns.singleWhere((item) => item.window == CycleWindow.beforePeriod);
    expect(pattern.key, 'headache');
    expect(pattern.cyclesPresent, 5);
    expect(pattern.cyclesObserved, 6);
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

  test('detects first-days pattern separately from pre-period pattern', () {
    final observations = <BinaryObservation>[];
    for (final start in starts) {
      observations.add(BinaryObservation(day: start, key: 'cramps', present: true));
      observations.add(BinaryObservation(day: start.addDays(1), key: 'cramps', present: true));
    }

    final patterns = analyzer.analyze(periodStarts: starts, observations: observations);
    final pattern = patterns.singleWhere((item) => item.window == CycleWindow.periodStart);
    expect(pattern.cyclesPresent, starts.length);
  });

  test('finds a repeated early-follicular pattern', () {
    final observations = <BinaryObservation>[];
    for (var index = 0; index < starts.length - 1; index++) {
      final start = starts[index];
      observations.add(BinaryObservation(day: start.addDays(4), key: 'energy.high', present: true));
      observations.add(BinaryObservation(day: start.addDays(6), key: 'energy.high', present: index != 3));
    }

    final patterns = analyzer.analyze(periodStarts: starts, observations: observations);
    final pattern = patterns.singleWhere((item) => item.window == CycleWindow.earlyFollicular);
    expect(pattern.key, 'energy.high');
    expect(pattern.cyclesObserved, 5);
  });

  test('finds broad retrospective peri-ovulatory patterns without naming a day', () {
    final observations = <BinaryObservation>[];
    for (var index = 0; index < starts.length - 1; index++) {
      final start = starts[index];
      // All intervals in this fixture are 28 days. The broad proxy is centered
      // at offset 15 and spans offsets 12..18.
      observations.add(
        BinaryObservation(
          day: start.addDays(13),
          key: 'discharge.estrogenic',
          present: index != 3,
        ),
      );
      observations.add(
        BinaryObservation(
          day: start.addDays(16),
          key: 'discharge.estrogenic',
          present: true,
        ),
      );
    }

    final patterns = analyzer.analyze(periodStarts: starts, observations: observations);
    final pattern = patterns.singleWhere((item) => item.window == CycleWindow.periOvulatory);
    expect(pattern.key, 'discharge.estrogenic');
    expect(pattern.cyclesObserved, 5);
    expect(pattern.cyclesPresent, 5);
  });

  test('finds a repeated mid-luteal pattern separately from late-luteal days', () {
    final observations = <BinaryObservation>[];
    for (var index = 1; index < starts.length; index++) {
      final nextStart = starts[index];
      observations.add(
        BinaryObservation(day: nextStart.addDays(-9), key: 'appetite.higher', present: true),
      );
      observations.add(
        BinaryObservation(
          day: nextStart.addDays(-7),
          key: 'appetite.higher',
          present: index != 4,
        ),
      );
    }

    final patterns = analyzer.analyze(periodStarts: starts, observations: observations);
    final pattern = patterns.singleWhere((item) => item.window == CycleWindow.midLuteal);
    expect(pattern.key, 'appetite.higher');
    expect(pattern.cyclesObserved, 5);
  });
}
