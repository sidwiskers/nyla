import 'local_day.dart';

enum PredictionConfidence { insufficient, low, medium, high }

enum CyclePhase {
  menstruation,
  follicular,
  periOvulatory,
  luteal,
  uncertain,
}

enum PhaseConfidence {
  observed,
  supported,
  estimated,
  limited,
}

enum CervicalMucusSignal {
  unknown,
  dryOrSticky,
  creamy,
  estrogenic,
}

/// Current-cycle observations that can support, but never prove, phase context.
///
/// `bleeding` is null when the user has not explicitly logged flow today.
/// `estrogenic` mucus means watery/stretchy self-observation. It can make an
/// estimated peri-ovulatory interpretation more plausible, but it is not an
/// ovulation test and must never be used as contraceptive guidance.
final class CycleDaySignals {
  const CycleDaySignals({
    this.bleeding,
    this.cervicalMucus = CervicalMucusSignal.unknown,
  });

  final bool? bleeding;
  final CervicalMucusSignal cervicalMucus;
}

/// A recorded bleeding episode that the user considers a period.
///
/// Spotting is intentionally modeled separately by the application and must not
/// be promoted to a period start by the prediction engine.
final class PeriodRecord {
  PeriodRecord({
    required this.start,
    this.end,
    this.excludeFromPrediction = false,
  }) : assert(end == null || end.epochDay >= start.epochDay);

  final LocalDay start;
  final LocalDay? end;

  /// Allows a user to preserve unusual history without letting it steer the
  /// next prediction (for example, a clinician-directed medication event).
  final bool excludeFromPrediction;

  int? get durationDays => end == null ? null : start.daysUntil(end!) + 1;
}

final class CyclePrediction {
  const CyclePrediction({
    required this.earliestStart,
    required this.likelyStart,
    required this.latestStart,
    required this.predictedCycleLength,
    required this.confidence,
    required this.completedCyclesUsed,
    required this.variabilityDays,
    required this.rawCompletedCycles,
    required this.filteredCompletedCycles,
    this.predictedPeriodDurationDays,
    this.predictionRangeRadiusDays = 0,
    this.calibrationErrorDays,
    this.suspectedSkippedIntervals = 0,
  });

  final LocalDay earliestStart;
  final LocalDay likelyStart;
  final LocalDay latestStart;
  final int predictedCycleLength;
  final int? predictedPeriodDurationDays;
  final PredictionConfidence confidence;
  final int completedCyclesUsed;
  final double variabilityDays;

  /// Number of valid biological-looking intervals before robust filtering.
  final int rawCompletedCycles;

  /// Intervals retained for the actual estimate.
  final int filteredCompletedCycles;

  /// Half-width of the displayed next-period date range.
  final int predictionRangeRadiusDays;

  /// Personal rolling forecast error when enough prior cycles exist to
  /// back-test the predictor. Null means history is still too short.
  final double? calibrationErrorDays;

  /// Long intervals that looked like clean multiples of an established personal
  /// rhythm and were therefore treated as probable missed tracking, not silently
  /// rewritten as biological cycles.
  final int suspectedSkippedIntervals;

  bool get hasWideRange => earliestStart.daysUntil(latestStart) >= 8;
}

/// Nyla's best current description of where a person may be in the cycle.
///
/// This is deliberately not a fertility state. Calendar history can support a
/// phase estimate, but only physiological markers can establish ovulation with
/// useful precision. The model therefore carries its evidence quality with it.
final class CyclePhaseContext {
  const CyclePhaseContext({
    required this.phase,
    required this.confidence,
    required this.cycleDay,
    this.predictedCycleLength,
    this.daysUntilLikelyPeriod,
    this.estimatedOvulationStart,
    this.estimatedOvulationEnd,
    this.mucusSupportsPeriOvulatory = false,
    this.periodIsObserved = false,
  });

  final CyclePhase phase;
  final PhaseConfidence confidence;
  final int cycleDay;
  final int? predictedCycleLength;
  final int? daysUntilLikelyPeriod;
  final LocalDay? estimatedOvulationStart;
  final LocalDay? estimatedOvulationEnd;
  final bool mucusSupportsPeriOvulatory;
  final bool periodIsObserved;

  bool get usesPrediction =>
      phase == CyclePhase.periOvulatory || phase == CyclePhase.luteal;

  bool get isPhaseEstimated =>
      confidence == PhaseConfidence.estimated ||
      confidence == PhaseConfidence.limited;
}

final class PredictionResult {
  const PredictionResult._({this.prediction, this.reason});

  const PredictionResult.available(CyclePrediction value)
      : this._(prediction: value);

  const PredictionResult.unavailable(String reason) : this._(reason: reason);

  final CyclePrediction? prediction;
  final String? reason;

  bool get isAvailable => prediction != null;
}
