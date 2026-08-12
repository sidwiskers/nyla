import 'local_day.dart';

enum PredictionConfidence { insufficient, low, medium, high }

/// A recorded bleeding episode that the user considers a period.
///
/// Spotting is intentionally modeled separately by the application and must not
/// be promoted to a period start by the prediction engine.
final class PeriodRecord {
  const PeriodRecord({
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
  });

  final LocalDay earliestStart;
  final LocalDay likelyStart;
  final LocalDay latestStart;
  final int predictedCycleLength;
  final int? predictedPeriodDurationDays;
  final PredictionConfidence confidence;
  final int completedCyclesUsed;
  final double variabilityDays;

  /// Number of valid biological intervals before robust filtering.
  final int rawCompletedCycles;

  /// Intervals retained for the actual estimate.
  final int filteredCompletedCycles;

  bool get hasWideRange => earliestStart.daysUntil(latestStart) >= 8;
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
