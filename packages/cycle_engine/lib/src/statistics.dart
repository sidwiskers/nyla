import 'dart:math' as math;

double median(Iterable<num> source) {
  final values = source.map((e) => e.toDouble()).toList()..sort();
  if (values.isEmpty) {
    throw ArgumentError.value(source, 'source', 'Must not be empty');
  }
  final middle = values.length ~/ 2;
  if (values.length.isOdd) return values[middle];
  return (values[middle - 1] + values[middle]) / 2;
}

double quantile(Iterable<num> source, double probability) {
  if (probability < 0 || probability > 1) {
    throw ArgumentError.value(probability, 'probability', 'Must be between 0 and 1');
  }
  final values = source.map((e) => e.toDouble()).toList()..sort();
  if (values.isEmpty) {
    throw ArgumentError.value(source, 'source', 'Must not be empty');
  }
  if (values.length == 1) return values.single;
  final position = (values.length - 1) * probability;
  final lower = position.floor();
  final upper = position.ceil();
  if (lower == upper) return values[lower];
  final fraction = position - lower;
  return values[lower] + (values[upper] - values[lower]) * fraction;
}

double medianAbsoluteDeviation(Iterable<num> source) {
  final values = source.map((e) => e.toDouble()).toList();
  if (values.isEmpty) {
    throw ArgumentError.value(source, 'source', 'Must not be empty');
  }
  final center = median(values);
  return median(values.map((value) => (value - center).abs()));
}

/// Removes only strong statistical outliers and only when enough history exists.
///
/// Values are never deleted from user history; this function merely decides
/// which intervals should influence the next estimate.
List<int> robustCycleFilter(List<int> source) {
  if (source.length < 5) return List.unmodifiable(source);

  final center = median(source);
  final mad = medianAbsoluteDeviation(source);
  final threshold = math.max(7.0, 3.5 * math.max(1.0, mad));
  final filtered = source.where((value) => (value - center).abs() <= threshold).toList();

  // A filter should never make a confident-looking estimate from a tiny subset.
  if (filtered.length < 3) return List.unmodifiable(source);
  return List.unmodifiable(filtered);
}

double recencyWeightedMean(List<int> chronologicalValues, {double decay = 0.88}) {
  if (chronologicalValues.isEmpty) {
    throw ArgumentError.value(chronologicalValues, 'chronologicalValues', 'Must not be empty');
  }
  var weighted = 0.0;
  var totalWeight = 0.0;
  for (var i = 0; i < chronologicalValues.length; i++) {
    final age = chronologicalValues.length - 1 - i;
    final weight = math.pow(decay, age).toDouble();
    weighted += chronologicalValues[i] * weight;
    totalWeight += weight;
  }
  return weighted / totalWeight;
}

double robustVariability(List<int> values) {
  if (values.length < 2) return 0;
  final mad = medianAbsoluteDeviation(values);
  if (mad > 0) return 1.4826 * mad;

  final center = median(values);
  final meanAbsoluteDeviation =
      values.fold<double>(0, (sum, value) => sum + (value - center).abs()) / values.length;
  return meanAbsoluteDeviation;
}

/// Back-tests the same recency-weighted estimator against the person's earlier
/// cycles. This turns past forecasting mistakes into a directly interpretable
/// uncertainty signal instead of deriving the displayed range from dispersion
/// alone.
double? rollingForecastAbsoluteError(List<int> chronologicalValues) {
  if (chronologicalValues.length < 4) return null;
  final errors = <double>[];
  for (var target = 3; target < chronologicalValues.length; target++) {
    final history = robustCycleFilter(chronologicalValues.sublist(0, target));
    final forecast = recencyWeightedMean(history);
    errors.add((chronologicalValues[target] - forecast).abs());
  }
  if (errors.isEmpty) return null;
  return quantile(errors, 0.8);
}

/// Detects only high-confidence tracking gaps: intervals close to a clean
/// multiple of an already-established personal rhythm. It does not mutate the
/// history and intentionally refuses to act when the baseline is sparse.
List<int> probableTrackedCycleIntervals(List<int> chronologicalValues) {
  if (chronologicalValues.length < 4) return List.unmodifiable(chronologicalValues);

  final center = median(chronologicalValues);
  if (center < 18 || center > 50) return List.unmodifiable(chronologicalValues);

  final retained = <int>[];
  for (final value in chronologicalValues) {
    var probableGap = false;
    for (var multiple = 2; multiple <= 3; multiple++) {
      final expected = center * multiple;
      final tolerance = math.max(3.0, center * 0.12);
      if ((value - expected).abs() <= tolerance) {
        probableGap = true;
        break;
      }
    }
    if (!probableGap) retained.add(value);
  }

  // Never let adherence adjustment collapse a sparse or genuinely irregular
  // history into a tiny, falsely precise subset.
  if (retained.length < 3) return List.unmodifiable(chronologicalValues);
  return List.unmodifiable(retained);
}
