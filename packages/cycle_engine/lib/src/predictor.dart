import 'dart:math' as math;

import 'models.dart';
import 'statistics.dart';

final class CyclePredictor {
  const CyclePredictor({
    this.minimumCycleDays = 15,
    this.maximumCycleDays = 90,
    this.historyLimit = 12,
  });

  /// Broad validity bounds guard against data-entry mistakes without declaring
  /// anything inside or outside the range medically normal.
  final int minimumCycleDays;
  final int maximumCycleDays;
  final int historyLimit;

  PredictionResult predict(List<PeriodRecord> records) {
    final chronological = [...records]..sort((a, b) => a.start.compareTo(b.start));

    if (chronological.length < 2) {
      return const PredictionResult.unavailable(
        'At least two recorded period starts are needed before a cycle interval can be estimated.',
      );
    }

    // Deduplicate starts defensively. When duplicates disagree about
    // exclusion, prefer the included record: an accidental duplicate must not
    // suppress an otherwise valid interval. Prefer a completed representative
    // when both records have the same exclusion state.
    final unique = <PeriodRecord>[];
    for (final record in chronological) {
      if (unique.isEmpty || unique.last.start != record.start) {
        unique.add(record);
        continue;
      }
      final existing = unique.last;
      final preferRecord = (existing.excludeFromPrediction && !record.excludeFromPrediction) ||
          (existing.excludeFromPrediction == record.excludeFromPrediction &&
              existing.durationDays == null &&
              record.durationDays != null);
      if (preferRecord) unique[unique.length - 1] = record;
    }

    if (unique.length < 2) {
      return const PredictionResult.unavailable(
        'At least two different period-start days are needed for prediction.',
      );
    }

    final allIntervals = <int>[];
    for (var i = 1; i < unique.length; i++) {
      final previous = unique[i - 1];
      final current = unique[i];

      // Exclusion applies to intervals touching that period. We deliberately
      // keep the start in the chronology: deleting it first would bridge over
      // an unusual cycle and invent a false long cycle.
      if (previous.excludeFromPrediction || current.excludeFromPrediction) continue;

      final days = previous.start.daysUntil(current.start);
      if (days >= minimumCycleDays && days <= maximumCycleDays) {
        allIntervals.add(days);
      }
    }

    if (allIntervals.isEmpty) {
      return const PredictionResult.unavailable(
        'Recorded history does not yet contain a usable completed cycle interval.',
      );
    }

    final limited = allIntervals.length > historyLimit
        ? allIntervals.sublist(allIntervals.length - historyLimit)
        : allIntervals;

    // Center and uncertainty intentionally see history differently. A clean
    // multiple of an established rhythm may be missed tracking, and a strong
    // statistical outlier should not dominate the likely date. But either may
    // also be real biology. They therefore remain in the uncertainty/calibration
    // history even when they receive little or no weight in the point estimate.
    final centerCandidates = probableTrackedCycleIntervals(limited);
    final suspectedSkipped = limited.length - centerCandidates.length;
    final centerHistory = robustCycleFilter(centerCandidates);

    final estimated = recencyWeightedMean(centerHistory)
        .round()
        .clamp(minimumCycleDays, maximumCycleDays)
        .toInt();

    // Do not let robust centering erase evidence that this person's cycle can
    // move. The full valid recent history determines how cautious the displayed
    // range should be.
    final variability = robustVariability(limited);
    final calibrationError = rollingForecastAbsoluteError(limited);
    final radius = _predictionRadius(
      cycles: limited.length,
      variability: variability,
      calibrationError: calibrationError,
    );

    // An unusual/excluded period is still a real period start and therefore
    // the correct anchor for the current cycle. Exclusion changes what Nyla
    // learns from that cycle, not where the next cycle is measured from.
    final lastStart = unique.last.start;
    final likely = lastStart.addDays(estimated);

    final durationValues = unique
        .where((record) => !record.excludeFromPrediction)
        .map((record) => record.durationDays)
        .whereType<int>()
        .where((days) => days >= 1 && days <= 14)
        .toList();
    final predictedDuration = durationValues.isEmpty ? null : median(durationValues).round();

    return PredictionResult.available(
      CyclePrediction(
        earliestStart: likely.addDays(-radius),
        likelyStart: likely,
        latestStart: likely.addDays(radius),
        predictedCycleLength: estimated,
        predictedPeriodDurationDays: predictedDuration,
        confidence: _confidence(centerHistory.length, variability, radius),
        completedCyclesUsed: centerHistory.length,
        variabilityDays: variability,
        rawCompletedCycles: allIntervals.length,
        filteredCompletedCycles: centerHistory.length,
        predictionRangeRadiusDays: radius,
        calibrationErrorDays: calibrationError,
        suspectedSkippedIntervals: suspectedSkipped,
      ),
    );
  }

  int _predictionRadius({
    required int cycles,
    required double variability,
    required double? calibrationError,
  }) {
    // Sparse history deserves visibly wider uncertainty even when the handful
    // of recorded intervals happen to be identical.
    final finiteHistoryFloor = switch (cycles) {
      <= 1 => 5,
      2 => 4,
      3 => 3,
      4 || 5 => 2,
      _ => 2,
    };

    final dispersionRadius = (variability * 1.5).ceil();
    final calibratedRadius = calibrationError == null
        ? 0
        : (calibrationError + 1).ceil();
    return math
        .max(finiteHistoryFloor, math.max(dispersionRadius, calibratedRadius))
        .clamp(2, 21)
        .toInt();
  }

  PredictionConfidence _confidence(int cycles, double variability, int radius) {
    if (cycles < 2) return PredictionConfidence.insufficient;
    if (cycles >= 6 && variability <= 2.5 && radius <= 3) {
      return PredictionConfidence.high;
    }
    if (cycles >= 3 && variability <= 5.5 && radius <= 6) {
      return PredictionConfidence.medium;
    }
    return PredictionConfidence.low;
  }
}
