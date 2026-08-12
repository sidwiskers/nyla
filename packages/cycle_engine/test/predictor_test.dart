import 'package:cycle_engine/cycle_engine.dart';
import 'package:test/test.dart';

PeriodRecord p(String start, [String? end]) => PeriodRecord(
      start: LocalDay.parseIso(start),
      end: end == null ? null : LocalDay.parseIso(end),
    );

void main() {
  const predictor = CyclePredictor();

  test('period record rejects an end date before its start', () {
    expect(
      () => PeriodRecord(
        start: const LocalDay(10),
        end: const LocalDay(9),
      ),
      throwsA(isA<AssertionError>()),
    );
  });

  test('requires completed interval', () {
    final result = predictor.predict([p('2026-08-01')]);
    expect(result.isAvailable, isFalse);
  });

  test('predicts from stable recent cycles and retains a range', () {
    final result = predictor.predict([
      p('2026-01-01', '2026-01-05'),
      p('2026-01-29', '2026-02-02'),
      p('2026-02-26', '2026-03-02'),
      p('2026-03-26', '2026-03-30'),
      p('2026-04-23', '2026-04-27'),
      p('2026-05-21', '2026-05-25'),
      p('2026-06-18', '2026-06-22'),
    ]).prediction!;

    expect(result.predictedCycleLength, 28);
    expect(result.likelyStart.toIsoString(), '2026-07-16');
    expect(result.earliestStart.toIsoString(), '2026-07-15');
    expect(result.latestStart.toIsoString(), '2026-07-17');
    expect(result.predictedPeriodDurationDays, 5);
    expect(result.confidence, PredictionConfidence.high);
  });

  test('one strong outlier does not dominate an established pattern', () {
    final result = predictor.predict([
      p('2025-11-01'),
      p('2025-11-29'),
      p('2025-12-27'),
      p('2026-01-24'),
      p('2026-02-21'),
      p('2026-03-21'),
      p('2026-05-10'), // 50-day interval preserved in history but filtered.
      p('2026-06-07'),
      p('2026-07-05'),
    ]).prediction!;

    expect(result.predictedCycleLength, 28);
    expect(result.rawCompletedCycles, 8);
    expect(result.filteredCompletedCycles, 7);
  });

  test('explicitly excluded record does not steer prediction', () {
    final result = predictor.predict([
      p('2026-01-01'),
      p('2026-01-29'),
      PeriodRecord(
        start: LocalDay.parseIso('2026-02-10'),
        excludeFromPrediction: true,
      ),
      p('2026-02-26'),
    ]).prediction!;

    expect(result.predictedCycleLength, 28);
  });
}
