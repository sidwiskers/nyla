import 'local_day.dart';
import 'models.dart';

/// Broad cycle moments that are useful for gentle, contextual education.
///
/// These are deliberately not ovulation or fertility states. Calendar timing
/// cannot establish either, so the engine only describes where today sits
/// relative to a recorded period start and, when available, Nyla's existing
/// period prediction.
enum CycleExperienceWindow {
  periodStart,
  earlyCycle,
  middleCycle,
  approachingPeriod,
}

final class CycleExperience {
  const CycleExperience({
    required this.window,
    required this.cycleDay,
    this.predictedCycleLength,
    this.daysUntilLikelyPeriod,
    this.predictionConfidence,
  });

  final CycleExperienceWindow window;
  final int cycleDay;
  final int? predictedCycleLength;
  final int? daysUntilLikelyPeriod;
  final PredictionConfidence? predictionConfidence;

  /// True when placement depends on an estimated next-period date or length.
  bool get usesPrediction =>
      window == CycleExperienceWindow.middleCycle ||
      window == CycleExperienceWindow.approachingPeriod;
}

/// Places today into a small set of education windows without claiming that a
/// calendar can observe hormone levels or determine ovulation.
final class CycleExperienceEngine {
  const CycleExperienceEngine({
    this.periodStartDays = 3,
    this.earlyCycleEndDay = 7,
    this.approachingPeriodDays = 7,
    this.middleCycleStart = 0.35,
    this.middleCycleEnd = 0.65,
  })  : assert(periodStartDays >= 1),
        assert(earlyCycleEndDay >= periodStartDays),
        assert(approachingPeriodDays >= 1),
        assert(middleCycleStart > 0 && middleCycleStart < 1),
        assert(middleCycleEnd > middleCycleStart && middleCycleEnd < 1);

  final int periodStartDays;
  final int earlyCycleEndDay;
  final int approachingPeriodDays;
  final double middleCycleStart;
  final double middleCycleEnd;

  CycleExperience? describe({
    required LocalDay today,
    required List<PeriodRecord> records,
    CyclePrediction? prediction,
  }) {
    final started = records
        .where((record) => record.start.compareTo(today) <= 0)
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    if (started.isEmpty) return null;

    final latest = started.last;
    final cycleDay = latest.start.daysUntil(today) + 1;
    if (cycleDay <= 0) return null;

    if (cycleDay <= periodStartDays) {
      return CycleExperience(
        window: CycleExperienceWindow.periodStart,
        cycleDay: cycleDay,
        predictedCycleLength: prediction?.predictedCycleLength,
        predictionConfidence: prediction?.confidence,
      );
    }

    final daysUntilLikely = prediction == null
        ? null
        : today.daysUntil(prediction.likelyStart);

    // This is intentionally close to the existing likely-period estimate. PMS
    // can begin earlier for some people, but a wider calendar trigger would make
    // Nyla sound more certain about physiology than its date prediction allows.
    if (daysUntilLikely != null &&
        daysUntilLikely >= -1 &&
        daysUntilLikely <= approachingPeriodDays) {
      return CycleExperience(
        window: CycleExperienceWindow.approachingPeriod,
        cycleDay: cycleDay,
        predictedCycleLength: prediction!.predictedCycleLength,
        daysUntilLikelyPeriod: daysUntilLikely,
        predictionConfidence: prediction.confidence,
      );
    }

    // The first week remains useful even before enough history exists for a
    // prediction. Copy shown for this window never assumes that bleeding ended.
    if (cycleDay <= earlyCycleEndDay) {
      return CycleExperience(
        window: CycleExperienceWindow.earlyCycle,
        cycleDay: cycleDay,
        predictedCycleLength: prediction?.predictedCycleLength,
        predictionConfidence: prediction?.confidence,
      );
    }

    if (prediction == null ||
        daysUntilLikely == null ||
        daysUntilLikely < -1) {
      return null;
    }

    final progress = cycleDay / prediction.predictedCycleLength;
    if (progress >= middleCycleStart &&
        progress <= middleCycleEnd &&
        daysUntilLikely > approachingPeriodDays) {
      return CycleExperience(
        window: CycleExperienceWindow.middleCycle,
        cycleDay: cycleDay,
        predictedCycleLength: prediction.predictedCycleLength,
        daysUntilLikelyPeriod: daysUntilLikely,
        predictionConfidence: prediction.confidence,
      );
    }

    return null;
  }
}
