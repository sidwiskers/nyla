import 'package:cycle_engine/cycle_engine.dart';
import 'package:test/test.dart';

void main() {
  const engine = CycleExperienceEngine();

  CyclePrediction prediction({
    required LocalDay latestStart,
    int length = 28,
    PredictionConfidence confidence = PredictionConfidence.high,
  }) =>
      CyclePrediction(
        earliestStart: latestStart.addDays(length - 2),
        likelyStart: latestStart.addDays(length),
        latestStart: latestStart.addDays(length + 2),
        predictedCycleLength: length,
        confidence: confidence,
        completedCyclesUsed: 6,
        variabilityDays: 1.5,
        rawCompletedCycles: 6,
        filteredCompletedCycles: 6,
      );

  test('returns no context before a period has been recorded', () {
    expect(
      engine.describe(today: const LocalDay(21000), records: const []),
      isNull,
    );
  });

  test('period-start context is anchored to the recorded start, not prediction', () {
    final start = const LocalDay(21000);
    final result = engine.describe(
      today: start.addDays(1),
      records: [PeriodRecord(start: start)],
    );

    expect(result?.window, CycleExperienceWindow.periodStart);
    expect(result?.cycleDay, 2);
    expect(result?.usesPrediction, isFalse);
  });

  test('early-cycle context remains available before prediction exists', () {
    final start = const LocalDay(21000);
    final result = engine.describe(
      today: start.addDays(4),
      records: [PeriodRecord(start: start)],
    );

    expect(result?.window, CycleExperienceWindow.earlyCycle);
    expect(result?.cycleDay, 5);
    expect(result?.usesPrediction, isFalse);
  });

  test('middle-cycle context scales with personal predicted cycle length', () {
    final start = const LocalDay(21000);
    final result = engine.describe(
      today: start.addDays(13),
      records: [PeriodRecord(start: start)],
      prediction: prediction(latestStart: start),
    );

    expect(result?.window, CycleExperienceWindow.middleCycle);
    expect(result?.cycleDay, 14);
    expect(result?.usesPrediction, isTrue);
  });

  test('approaching-period context takes precedence near the likely start', () {
    final start = const LocalDay(21000);
    final result = engine.describe(
      today: start.addDays(22),
      records: [PeriodRecord(start: start)],
      prediction: prediction(latestStart: start),
    );

    expect(result?.window, CycleExperienceWindow.approachingPeriod);
    expect(result?.daysUntilLikelyPeriod, 6);
    expect(result?.predictionConfidence, PredictionConfidence.high);
  });

  test('does not keep assigning a phase after the prediction has clearly passed', () {
    final start = const LocalDay(21000);
    final result = engine.describe(
      today: start.addDays(31),
      records: [PeriodRecord(start: start)],
      prediction: prediction(latestStart: start),
    );

    expect(result, isNull);
  });

  test('future records do not replace the active cycle anchor', () {
    final start = const LocalDay(21000);
    final result = engine.describe(
      today: start.addDays(1),
      records: [
        PeriodRecord(start: start),
        PeriodRecord(start: start.addDays(20)),
      ],
    );

    expect(result?.window, CycleExperienceWindow.periodStart);
    expect(result?.cycleDay, 2);
  });
}
