import 'dart:math' as math;

import 'local_day.dart';
import 'models.dart';

/// Evidence-weighted cycle phase context for a local-first period tracker.
///
/// The engine intentionally does not expose a fertile window. Without current-
/// cycle physiological markers, calendar history cannot establish ovulation
/// precisely enough for pregnancy planning or contraception. Nyla instead uses
/// broad phase context and carries uncertainty into the result.
final class CyclePhaseEngine {
  const CyclePhaseEngine({
    this.typicalLutealDays = 12,
    this.minimumPeriOvulatoryRadius = 3,
    this.maximumPeriOvulatoryRadius = 6,
    this.earlyFollicularDaysAfterBleed = 6,
  });

  /// Population evidence places the luteal phase around 12 days on average,
  /// while also showing meaningful variation. This is a prior used only to
  /// center a broad window, never to declare an ovulation day.
  final int typicalLutealDays;
  final int minimumPeriOvulatoryRadius;
  final int maximumPeriOvulatoryRadius;

  /// When there is not yet a personal next-period prediction, a recently ended
  /// period still gives useful early-cycle context. Keep a short post-bleed
  /// window as limited-confidence follicular context instead of dropping to an
  /// unhelpful unknown state immediately after day 7.
  final int earlyFollicularDaysAfterBleed;

  CyclePhaseContext? describe({
    required LocalDay today,
    required List<PeriodRecord> records,
    CyclePrediction? prediction,
    CycleDaySignals signals = const CycleDaySignals(),
  }) {
    final started = records
        .where((record) => record.start.compareTo(today) <= 0)
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    if (started.isEmpty) return null;

    final latest = started.last;
    final cycleDay = latest.start.daysUntil(today) + 1;
    if (cycleDay <= 0) return null;

    final recordedBleeding =
        latest.end != null && today.compareTo(latest.end!) <= 0;
    final onsetObserved = cycleDay == 1;

    // A flow log can support an already-recorded recent period, including a
    // longer bleed, but it must never create a new period anchor by itself. A
    // new mid-cycle bleeding log may be intermenstrual bleeding or an unrecorded
    // new period; either way the honest response is to keep the old cycle anchor
    // until the user explicitly records a new period start.
    final flowSupportsRecentPeriod =
        signals.bleeding == true && cycleDay <= 14;
    final periodObserved =
        recordedBleeding || onsetObserved || flowSupportsRecentPeriod;

    final personalBleedLength = prediction?.predictedPeriodDurationDays;
    final inferredBleedDays =
        (personalBleedLength ?? 3).clamp(2, 7).toInt();
    final likelyStillBleeding = latest.end == null &&
        signals.bleeding != false &&
        cycleDay <= inferredBleedDays;

    if (periodObserved || likelyStillBleeding) {
      return CyclePhaseContext(
        phase: CyclePhase.menstruation,
        confidence: periodObserved
            ? PhaseConfidence.observed
            : PhaseConfidence.supported,
        cycleDay: cycleDay,
        predictedCycleLength: prediction?.predictedCycleLength,
        daysUntilLikelyPeriod:
            prediction == null ? null : today.daysUntil(prediction.likelyStart),
        periodIsObserved: periodObserved,
      );
    }

    if (prediction == null) {
      // A single recorded period is not enough to estimate ovulation or the
      // next period, but it does tell us where this cycle began. Immediately
      // after bleeding, follicular context remains useful even though the
      // confidence is deliberately limited.
      final recordedBleedDays = latest.end == null
          ? inferredBleedDays
          : latest.start.daysUntil(latest.end!) + 1;
      final earlyFollicularThrough = (recordedBleedDays +
              earlyFollicularDaysAfterBleed)
          .clamp(7, 12)
          .toInt();

      if (cycleDay <= earlyFollicularThrough) {
        return CyclePhaseContext(
          phase: CyclePhase.follicular,
          confidence: PhaseConfidence.limited,
          cycleDay: cycleDay,
        );
      }

      // Beyond the early-cycle window, calendar day alone cannot responsibly
      // distinguish a later follicular day from peri-ovulatory or luteal timing
      // without a personal cycle interval. Keep the cycle day, but not a made-up
      // phase.
      return CyclePhaseContext(
        phase: CyclePhase.uncertain,
        confidence: PhaseConfidence.limited,
        cycleDay: cycleDay,
      );
    }

    final daysUntilLikely = today.daysUntil(prediction.likelyStart);

    // Once even the outer prediction range has passed, do not stretch a luteal
    // label indefinitely. A late period can have many explanations and the
    // current cycle deserves fresh observation rather than stronger guessing.
    if (today.compareTo(prediction.latestStart.addDays(1)) > 0) {
      return CyclePhaseContext(
        phase: CyclePhase.uncertain,
        confidence: PhaseConfidence.limited,
        cycleDay: cycleDay,
        predictedCycleLength: prediction.predictedCycleLength,
        daysUntilLikelyPeriod: daysUntilLikely,
      );
    }

    // If the luteal phase is defined as the days after ovulation through the day
    // before the next period, a ~12-day luteal phase places the ovulation day
    // roughly 13 days before the next period. Prediction uncertainty and known
    // biological luteal variability are deliberately converted into a broad
    // peri-ovulatory window rather than a single date.
    final center =
        prediction.likelyStart.addDays(-(typicalLutealDays + 1));
    final radiusFromPrediction =
        2 + (prediction.predictionRangeRadiusDays / 2).ceil();
    final radius = math
        .max(minimumPeriOvulatoryRadius, radiusFromPrediction)
        .clamp(minimumPeriOvulatoryRadius, maximumPeriOvulatoryRadius)
        .toInt();
    final ovulationStart = center.addDays(-radius);
    final ovulationEnd = center.addDays(radius);

    final estrogenicMucus =
        signals.cervicalMucus == CervicalMucusSignal.estrogenic;
    final mucusNearby = estrogenicMucus &&
        today.compareTo(ovulationStart.addDays(-2)) >= 0 &&
        today.compareTo(ovulationEnd.addDays(2)) <= 0;
    final insideWindow = today.compareTo(ovulationStart) >= 0 &&
        today.compareTo(ovulationEnd) <= 0;

    if (insideWindow || mucusNearby) {
      return CyclePhaseContext(
        phase: CyclePhase.periOvulatory,
        confidence: mucusNearby
            ? PhaseConfidence.supported
            : PhaseConfidence.estimated,
        cycleDay: cycleDay,
        predictedCycleLength: prediction.predictedCycleLength,
        daysUntilLikelyPeriod: daysUntilLikely,
        estimatedOvulationStart: ovulationStart,
        estimatedOvulationEnd: ovulationEnd,
        mucusSupportsPeriOvulatory: mucusNearby,
      );
    }

    if (today.compareTo(ovulationStart) < 0) {
      return CyclePhaseContext(
        phase: CyclePhase.follicular,
        confidence: _phaseConfidence(prediction.confidence),
        cycleDay: cycleDay,
        predictedCycleLength: prediction.predictedCycleLength,
        daysUntilLikelyPeriod: daysUntilLikely,
        estimatedOvulationStart: ovulationStart,
        estimatedOvulationEnd: ovulationEnd,
      );
    }

    return CyclePhaseContext(
      phase: CyclePhase.luteal,
      confidence: PhaseConfidence.estimated,
      cycleDay: cycleDay,
      predictedCycleLength: prediction.predictedCycleLength,
      daysUntilLikelyPeriod: daysUntilLikely,
      estimatedOvulationStart: ovulationStart,
      estimatedOvulationEnd: ovulationEnd,
    );
  }

  PhaseConfidence _phaseConfidence(PredictionConfidence confidence) =>
      switch (confidence) {
        PredictionConfidence.high || PredictionConfidence.medium =>
          PhaseConfidence.supported,
        PredictionConfidence.low || PredictionConfidence.insufficient =>
          PhaseConfidence.estimated,
      };
}
