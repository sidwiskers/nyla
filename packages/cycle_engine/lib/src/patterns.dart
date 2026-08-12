import 'local_day.dart';

enum CycleWindow { beforePeriod, periodStart }

final class BinaryObservation {
  const BinaryObservation({required this.day, required this.key, required this.present});

  final LocalDay day;
  final String key;
  final bool present;
}

final class SymptomPattern {
  const SymptomPattern({
    required this.key,
    required this.window,
    required this.cyclesPresent,
    required this.cyclesObserved,
    required this.coverageRequiredPerCycle,
  });

  final String key;
  final CycleWindow window;
  final int cyclesPresent;
  final int cyclesObserved;
  final int coverageRequiredPerCycle;

  double get occurrenceRate => cyclesPresent / cyclesObserved;
}

/// Finds repeated descriptive patterns without converting them into diagnoses.
///
/// A cycle only enters the denominator if the user explicitly recorded the
/// symptom on enough days inside the window. Missing data is therefore unknown,
/// not an implicit "no".
final class SymptomPatternAnalyzer {
  const SymptomPatternAnalyzer({
    this.minimumObservedCycles = 4,
    this.minimumOccurrenceRate = 0.65,
  });

  final int minimumObservedCycles;
  final double minimumOccurrenceRate;

  List<SymptomPattern> analyze({
    required List<LocalDay> periodStarts,
    required List<BinaryObservation> observations,
  }) {
    if (periodStarts.length < minimumObservedCycles || observations.isEmpty) return const [];

    final starts = periodStarts.toSet().toList()..sort();
    final byKeyAndDay = <String, Map<int, bool>>{};
    for (final observation in observations) {
      final byDay = byKeyAndDay.putIfAbsent(observation.key, () => <int, bool>{});
      // Multiple writes to the same materialized day/key should not normally
      // reach this API. If they do, an explicit presence wins for safety.
      byDay.update(
        observation.day.epochDay,
        (existing) => existing || observation.present,
        ifAbsent: () => observation.present,
      );
    }

    final patterns = <SymptomPattern>[];
    for (final entry in byKeyAndDay.entries) {
      for (final definition in const [
        _WindowDefinition(CycleWindow.beforePeriod, -3, -1, 2),
        _WindowDefinition(CycleWindow.periodStart, 0, 1, 2),
      ]) {
        var observedCycles = 0;
        var presentCycles = 0;
        final byDay = entry.value;

        for (final start in starts) {
          var explicitDays = 0;
          var cyclePresent = false;
          for (var offset = definition.startOffset; offset <= definition.endOffset; offset++) {
            final value = byDay[start.addDays(offset).epochDay];
            if (value == null) continue;
            explicitDays += 1;
            if (value) cyclePresent = true;
          }
          if (explicitDays < definition.minimumCoverageDays) continue;
          observedCycles += 1;
          if (cyclePresent) presentCycles += 1;
        }

        if (observedCycles < minimumObservedCycles) continue;
        if (presentCycles < 3) continue;
        final rate = presentCycles / observedCycles;
        if (rate < minimumOccurrenceRate) continue;

        patterns.add(
          SymptomPattern(
            key: entry.key,
            window: definition.window,
            cyclesPresent: presentCycles,
            cyclesObserved: observedCycles,
            coverageRequiredPerCycle: definition.minimumCoverageDays,
          ),
        );
      }
    }

    patterns.sort((a, b) {
      final rate = b.occurrenceRate.compareTo(a.occurrenceRate);
      if (rate != 0) return rate;
      final coverage = b.cyclesObserved.compareTo(a.cyclesObserved);
      if (coverage != 0) return coverage;
      final key = a.key.compareTo(b.key);
      if (key != 0) return key;
      return a.window.index.compareTo(b.window.index);
    });
    return List.unmodifiable(patterns);
  }
}

final class _WindowDefinition {
  const _WindowDefinition(this.window, this.startOffset, this.endOffset, this.minimumCoverageDays);

  final CycleWindow window;
  final int startOffset;
  final int endOffset;
  final int minimumCoverageDays;
}
