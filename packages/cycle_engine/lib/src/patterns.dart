import 'local_day.dart';

enum CycleWindow {
  beforePeriod,
  periodStart,
  earlyFollicular,
  periOvulatory,
  midLuteal,
}

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
/// feature on enough days inside the window. Missing data is therefore unknown,
/// not an implicit "no". Peri-ovulatory windows are retrospective, broad, and
/// based on the next observed period plus a population luteal prior; they are
/// not evidence that ovulation occurred on a particular day.
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
      final byDay = entry.value;

      _maybeAdd(
        patterns,
        key: entry.key,
        window: CycleWindow.periodStart,
        evaluations: [
          for (final start in starts)
            _evaluateFixed(byDay, start: start, from: 0, to: 2, minimumCoverage: 2),
        ],
        coverageRequired: 2,
      );

      _maybeAdd(
        patterns,
        key: entry.key,
        window: CycleWindow.beforePeriod,
        evaluations: [
          for (final start in starts.skip(1))
            _evaluateFixed(byDay, start: start, from: -4, to: -1, minimumCoverage: 2),
        ],
        coverageRequired: 2,
      );

      _maybeAdd(
        patterns,
        key: entry.key,
        window: CycleWindow.earlyFollicular,
        evaluations: [
          for (final start in starts.take(starts.length - 1))
            _evaluateFixed(byDay, start: start, from: 4, to: 8, minimumCoverage: 2),
        ],
        coverageRequired: 2,
      );

      final periEvaluations = <_CycleEvaluation>[];
      final lutealEvaluations = <_CycleEvaluation>[];
      for (var i = 0; i < starts.length - 1; i++) {
        final start = starts[i];
        final next = starts[i + 1];
        final cycleLength = start.daysUntil(next);
        if (cycleLength < 18 || cycleLength > 60) continue;

        // Retrospective broad proxy only. Mean luteal length in large marker-
        // based cohorts is around 12 days but varies materially, so use ±3 days
        // around a 13-days-before-next-period center rather than one magic day.
        final estimatedOvulationOffset = cycleLength - 13;
        periEvaluations.add(
          _evaluateFixed(
            byDay,
            start: start,
            from: estimatedOvulationOffset - 3,
            to: estimatedOvulationOffset + 3,
            minimumCoverage: 2,
          ),
        );

        lutealEvaluations.add(
          _evaluateFixed(
            byDay,
            start: next,
            from: -10,
            to: -6,
            minimumCoverage: 2,
          ),
        );
      }

      _maybeAdd(
        patterns,
        key: entry.key,
        window: CycleWindow.periOvulatory,
        evaluations: periEvaluations,
        coverageRequired: 2,
      );
      _maybeAdd(
        patterns,
        key: entry.key,
        window: CycleWindow.midLuteal,
        evaluations: lutealEvaluations,
        coverageRequired: 2,
      );
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

  _CycleEvaluation _evaluateFixed(
    Map<int, bool> byDay, {
    required LocalDay start,
    required int from,
    required int to,
    required int minimumCoverage,
  }) {
    var explicitDays = 0;
    var present = false;
    for (var offset = from; offset <= to; offset++) {
      final value = byDay[start.addDays(offset).epochDay];
      if (value == null) continue;
      explicitDays += 1;
      if (value) present = true;
    }
    return _CycleEvaluation(
      observed: explicitDays >= minimumCoverage,
      present: present,
    );
  }

  void _maybeAdd(
    List<SymptomPattern> destination, {
    required String key,
    required CycleWindow window,
    required List<_CycleEvaluation> evaluations,
    required int coverageRequired,
  }) {
    var observedCycles = 0;
    var presentCycles = 0;
    for (final evaluation in evaluations) {
      if (!evaluation.observed) continue;
      observedCycles += 1;
      if (evaluation.present) presentCycles += 1;
    }

    if (observedCycles < minimumObservedCycles) return;
    if (presentCycles < 3) return;
    final rate = presentCycles / observedCycles;
    if (rate < minimumOccurrenceRate) return;

    destination.add(
      SymptomPattern(
        key: key,
        window: window,
        cyclesPresent: presentCycles,
        cyclesObserved: observedCycles,
        coverageRequiredPerCycle: coverageRequired,
      ),
    );
  }
}

final class _CycleEvaluation {
  const _CycleEvaluation({required this.observed, required this.present});

  final bool observed;
  final bool present;
}
