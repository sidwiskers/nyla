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

  test('stable recent cycles retain honest finite-history uncertainty', () {
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
    expect(result.earliestStart.toIsoString(), '2026-07-14');
    expect(result.latestStart.toIsoString(), '2026-07-18');
    expect(result.predictionRangeRadiusDays, 2);
    expect(result.predictedPeriodDurationDays, 5);
    expect(result.confidence, PredictionConfidence.high);
  });

  test('sparse history is not presented as precise even when identical', () {
    final result = predictor.predict([
      p('2026-01-01'),
      p('2026-01-29'),
      p('2026-02-26'),
    ]).prediction!;

    expect(result.predictedCycleLength, 28);
    expect(result.predictionRangeRadiusDays, 4);
    expect(result.confidence, PredictionConfidence.low);
  });

  test('one strong outlier does not dominate the center but still widens uncertainty', () {
    final result = predictor.predict([
      p('2025-11-01'),
      p('2025-11-29'),
      p('2025-12-27'),
      p('2026-01-24'),
      p('2026-02-21'),
      p('2026-03-21'),
      p('2026-05-10'), // 50-day biological-looking outlier preserved in history.
      p('2026-06-07'),
      p('2026-07-05'),
    ]).prediction!;

    expect(result.predictedCycleLength, 28);
    expect(result.rawCompletedCycles, 8);
    expect(result.filteredCompletedCycles, 7);
    expect(result.predictionRangeRadiusDays, greaterThan(3));
    expect(result.confidence, isNot(PredictionConfidence.high));
  });

  test('probable missed tracking does not steer center but remains uncertainty evidence', () {
    final result = predictor.predict([
      p('2026-01-01'),
      p('2026-01-29'),
      p('2026-02-26'),
      p('2026-03-26'),
      p('2026-05-21'), // 56 days: very close to two established 28-day cycles.
      p('2026-06-18'),
    ]).prediction!;

    expect(result.predictedCycleLength, 28);
    expect(result.rawCompletedCycles, 5);
    expect(result.suspectedSkippedIntervals, 1);
    expect(result.filteredCompletedCycles, 4);
    expect(result.predictionRangeRadiusDays, greaterThan(4));
    expect(result.confidence, PredictionConfidence.low);
  });

  test('personal rolling forecast error contributes to uncertainty', () {
    final result = predictor.predict([
      p('2026-01-01'),
      p('2026-01-29'), // 28
      p('2026-02-28'), // 30
      p('2026-03-27'), // 27
      p('2026-04-27'), // 31
      p('2026-05-26'), // 29
      p('2026-06-24'), // 29
    ]).prediction!;

    expect(result.calibrationErrorDays, isNotNull);
    expect(result.predictionRangeRadiusDays, greaterThanOrEqualTo(2));
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
      p('2026-03-26'),
    ]).prediction!;

    expect(result.predictedCycleLength, 28);
    expect(result.rawCompletedCycles, 2);
  });

  test('excluded period never bridges neighbours into a false interval', () {
    final result = predictor.predict([
      p('2026-01-01'),
      p('2026-01-29'),
      PeriodRecord(
        start: LocalDay.parseIso('2026-02-26'),
        excludeFromPrediction: true,
      ),
      p('2026-03-26'),
      p('2026-04-23'),
    ]).prediction!;

    // Only Jan 1→Jan 29 and Mar 26→Apr 23 are eligible. Jan 29→Mar 26 must
    // never be invented as a 56-day completed cycle.
    expect(result.rawCompletedCycles, 2);
    expect(result.predictedCycleLength, 28);
  });

  test('latest excluded period remains the anchor for the next estimate', () {
    final result = predictor.predict([
      p('2026-01-01'),
      p('2026-01-29'),
      p('2026-02-26'),
      PeriodRecord(
        start: LocalDay.parseIso('2026-03-30'),
        excludeFromPrediction: true,
      ),
    ]).prediction!;

    expect(result.predictedCycleLength, 28);
    expect(result.likelyStart.toIsoString(), '2026-04-27');
    expect(result.rawCompletedCycles, 2);
  });

  test('excluded periods do not influence predicted period duration', () {
    final result = predictor.predict([
      p('2026-01-01', '2026-01-05'),
      p('2026-01-29', '2026-02-02'),
      PeriodRecord(
        start: LocalDay.parseIso('2026-02-26'),
        end: LocalDay.parseIso('2026-03-10'),
        excludeFromPrediction: true,
      ),
      p('2026-03-26', '2026-03-30'),
      p('2026-04-23', '2026-04-27'),
    ]).prediction!;

    expect(result.predictedPeriodDurationDays, 5);
  });
}
