import 'package:cycle_engine/cycle_engine.dart';
import 'package:test/test.dart';

void main() {
  const engine = CyclePhaseEngine();

  CyclePrediction prediction({
    required LocalDay latestStart,
    int length = 28,
    int radius = 2,
    int? periodDuration = 5,
  }) =>
      CyclePrediction(
        earliestStart: latestStart.addDays(length - radius),
        likelyStart: latestStart.addDays(length),
        latestStart: latestStart.addDays(length + radius),
        predictedCycleLength: length,
        predictedPeriodDurationDays: periodDuration,
        confidence: PredictionConfidence.high,
        completedCyclesUsed: 8,
        variabilityDays: 1.4,
        rawCompletedCycles: 8,
        filteredCompletedCycles: 8,
        predictionRangeRadiusDays: radius,
      );

  test('returns no phase before any period is recorded', () {
    expect(
      engine.describe(today: const LocalDay(22000), records: const []),
      isNull,
    );
  });

  test('first day of a recorded period is observed menstruation', () {
    const start = LocalDay(22000);
    final context = engine.describe(
      today: start,
      records: [PeriodRecord(start: start)],
    )!;

    expect(context.phase, CyclePhase.menstruation);
    expect(context.confidence, PhaseConfidence.observed);
    expect(context.periodIsObserved, isTrue);
  });

  test('recorded period end keeps menstruation observed', () {
    const start = LocalDay(22000);
    final context = engine.describe(
      today: start.addDays(3),
      records: [PeriodRecord(start: start, end: start.addDays(4))],
    )!;

    expect(context.phase, CyclePhase.menstruation);
    expect(context.periodIsObserved, isTrue);
  });

  test('explicit no-flow log can end an unclosed inferred bleed', () {
    const start = LocalDay(22000);
    final context = engine.describe(
      today: start.addDays(3),
      records: [PeriodRecord(start: start)],
      signals: const CycleDaySignals(bleeding: false),
    )!;

    expect(context.phase, CyclePhase.follicular);
  });

  test('without a prediction later cycle timing becomes uncertain', () {
    const start = LocalDay(22000);
    final context = engine.describe(
      today: start.addDays(10),
      records: [PeriodRecord(start: start, end: start.addDays(4))],
    )!;

    expect(context.phase, CyclePhase.uncertain);
    expect(context.confidence, PhaseConfidence.limited);
  });

  test('personal prediction yields a broad peri-ovulatory window', () {
    const start = LocalDay(22000);
    // With a 28-day cycle and a 12-day luteal prior, the center is cycle day
    // 16 (15-day offset) with a deliberately broad radius around it.
    final context = engine.describe(
      today: start.addDays(15),
      records: [PeriodRecord(start: start, end: start.addDays(4))],
      prediction: prediction(latestStart: start),
      signals: const CycleDaySignals(bleeding: false),
    )!;

    expect(context.phase, CyclePhase.periOvulatory);
    expect(context.confidence, PhaseConfidence.estimated);
    expect(context.estimatedOvulationStart, isNotNull);
    expect(context.estimatedOvulationEnd, isNotNull);
  });

  test('estrogenic mucus supports but does not narrow peri-ovulatory context', () {
    const start = LocalDay(22000);
    final context = engine.describe(
      today: start.addDays(14),
      records: [PeriodRecord(start: start, end: start.addDays(4))],
      prediction: prediction(latestStart: start),
      signals: const CycleDaySignals(
        bleeding: false,
        cervicalMucus: CervicalMucusSignal.estrogenic,
      ),
    )!;

    expect(context.phase, CyclePhase.periOvulatory);
    expect(context.confidence, PhaseConfidence.supported);
    expect(context.mucusSupportsPeriOvulatory, isTrue);
  });

  test('days before estimated ovulatory window remain follicular', () {
    const start = LocalDay(22000);
    final context = engine.describe(
      today: start.addDays(8),
      records: [PeriodRecord(start: start, end: start.addDays(4))],
      prediction: prediction(latestStart: start),
      signals: const CycleDaySignals(bleeding: false),
    )!;

    expect(context.phase, CyclePhase.follicular);
  });

  test('days after estimated ovulatory window are luteal context', () {
    const start = LocalDay(22000);
    final context = engine.describe(
      today: start.addDays(21),
      records: [PeriodRecord(start: start, end: start.addDays(4))],
      prediction: prediction(latestStart: start),
      signals: const CycleDaySignals(bleeding: false),
    )!;

    expect(context.phase, CyclePhase.luteal);
    expect(context.confidence, PhaseConfidence.estimated);
  });

  test('phase confidence falls after the prediction range has passed', () {
    const start = LocalDay(22000);
    final context = engine.describe(
      today: start.addDays(32),
      records: [PeriodRecord(start: start, end: start.addDays(4))],
      prediction: prediction(latestStart: start),
      signals: const CycleDaySignals(bleeding: false),
    )!;

    expect(context.phase, CyclePhase.uncertain);
    expect(context.confidence, PhaseConfidence.limited);
  });
}
