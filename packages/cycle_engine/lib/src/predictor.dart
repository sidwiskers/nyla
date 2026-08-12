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
    final usable = records.where((r) => !r.excludeFromPrediction).toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    if (usable.length < 2) {
      return const PredictionResult.unavailable(
        'At least two recorded period starts are needed before a cycle interval can be estimated.',
      );
    }

    // Deduplicate period starts defensively. Two records on one day should not
    // create a zero-day cycle.
    final unique = <PeriodRecord>[];
    for (final record in usable) {
      if (unique.isEmpty || unique.last.start != record.start) unique.add(record);
    }

    if (unique.length < 2) {
      return const PredictionResult.unavailable(
        'At least two different period-start days are needed for prediction.',
      );
    }

    final allIntervals = <int>[];
    for (var i = 1; i < unique.length; i++) {
      final days = unique[i - 1].start.daysUntil(unique[i].start);
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
    final filtered = robustCycleFilter(limited);

    final estimated = recencyWeightedMean(filtered)
        .round()
        .clamp(minimumCycleDays, maximumCycleDays)
        .toInt();
    final variability = robustVariability(filtered);

    // A range is always shown. Even exceptionally consistent history gets a
    // minimum one-day uncertainty in either direction.
    final radius = math.max(1, (variability * 1.5).ceil()).clamp(1, 21).toInt();
    final lastStart = unique.last.start;
    final likely = lastStart.addDays(estimated);

    final durationValues = unique
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
        confidence: _confidence(filtered.length, variability),
        completedCyclesUsed: filtered.length,
        variabilityDays: variability,
        rawCompletedCycles: allIntervals.length,
        filteredCompletedCycles: filtered.length,
      ),
    );
  }

  PredictionConfidence _confidence(int cycles, double variability) {
    if (cycles < 2) return PredictionConfidence.insufficient;
    if (cycles >= 6 && variability <= 2.5) return PredictionConfidence.high;
    if (cycles >= 3 && variability <= 5.0) return PredictionConfidence.medium;
    return PredictionConfidence.low;
  }
}
