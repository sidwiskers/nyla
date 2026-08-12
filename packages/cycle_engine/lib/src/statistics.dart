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
