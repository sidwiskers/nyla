import 'package:cycle_engine/cycle_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/nyla_theme.dart';
import '../../data/database/app_database.dart';
import '../../providers.dart';
import '../../widgets/nyla_page.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(periodHistoryProvider);
    final prediction = ref.watch(cyclePredictionProvider);
    final patterns = ref.watch(symptomPatternsProvider);

    return NylaPage(
      title: 'Insights',
      subtitle: 'Patterns Nyla can explain, not guesses it cannot.',
      child: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Text('Your insights could not be loaded.'),
        data: (periods) {
          final stats = _stats(periods);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: _StatCard(value: stats.averageCycle, label: 'Typical cycle', suffix: 'days')),
                  const SizedBox(width: 10),
                  Expanded(child: _StatCard(value: stats.averagePeriod, label: 'Typical period', suffix: 'days')),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _StatCard(value: stats.shortest, label: 'Shortest', suffix: 'days')),
                  const SizedBox(width: 10),
                  Expanded(child: _StatCard(value: stats.longest, label: 'Longest', suffix: 'days')),
                ],
              ),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: prediction.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (_, _) => const Text('Prediction confidence is unavailable.'),
                    data: (result) {
                      final value = result.prediction;
                      if (value == null) {
                        return const _InsightCopy(
                          title: 'Still learning your rhythm',
                          body: 'Nyla needs completed cycle intervals before it can describe your personal variation.',
                        );
                      }
                      return _InsightCopy(
                        title: _confidenceTitle(value.confidence),
                        body:
                            'This estimate uses ${value.completedCyclesUsed} recent cycle${value.completedCyclesUsed == 1 ? '' : 's'}. Your robust variability is about ${value.variabilityDays.toStringAsFixed(1)} days, so Nyla shows a range instead of pretending one date is certain.',
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),
              ..._patternCards(context, patterns, periods.length),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _patternCards(
    BuildContext context,
    AsyncValue<List<SymptomPattern>> patterns,
    int periodCount,
  ) {
    return patterns.when(
      loading: () => [
        const Card(child: Padding(padding: EdgeInsets.all(20), child: LinearProgressIndicator())),
      ],
      error: (_, _) => [
        const Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text('Personal symptom patterns could not be calculated.'),
          ),
        ),
      ],
      data: (items) {
        if (items.isEmpty) {
          return [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: _InsightCopy(
                  title: 'Personal patterns need real coverage',
                  body: periodCount < 4
                      ? 'A repeated pattern needs observations across at least four periods. Keep logging only what matters to you.'
                      : 'Nyla has not found a well-supported repeated symptom pattern yet. Missing days are treated as unknown—not as “no symptom.”',
                ),
              ),
            ),
          ];
        }

        return [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 2, 4, 9),
            child: Text('Patterns in your logs', style: Theme.of(context).textTheme.titleLarge),
          ),
          for (var index = 0; index < items.take(4).length; index++) ...[
            _PatternCard(pattern: items[index]),
            if (index != items.take(4).length - 1) const SizedBox(height: 10),
          ],
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'These are descriptive observations from your own logs. They do not establish a cause or diagnosis.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
            ),
          ),
        ];
      },
    );
  }

  _CycleStats _stats(List<PeriodEntry> rows) {
    final chronological = [...rows]..sort((a, b) => a.startDay.compareTo(b.startDay));
    final intervals = <int>[];
    for (var i = 1; i < chronological.length; i++) {
      final interval = chronological[i].startDay - chronological[i - 1].startDay;
      if (interval >= 15 && interval <= 90) intervals.add(interval);
    }
    final durations = chronological
        .where((row) => row.endDay != null)
        .map((row) => row.endDay! - row.startDay + 1)
        .where((value) => value >= 1 && value <= 14)
        .toList();

    String medianText(List<int> values) => values.isEmpty ? '—' : median(values).round().toString();
    return _CycleStats(
      averageCycle: medianText(intervals),
      averagePeriod: medianText(durations),
      shortest: intervals.isEmpty ? '—' : intervals.reduce((a, b) => a < b ? a : b).toString(),
      longest: intervals.isEmpty ? '—' : intervals.reduce((a, b) => a > b ? a : b).toString(),
    );
  }

  String _confidenceTitle(PredictionConfidence confidence) => switch (confidence) {
        PredictionConfidence.high => 'Your recent cycles are fairly consistent',
        PredictionConfidence.medium => 'There is a usable pattern',
        PredictionConfidence.low => 'Your cycles have meaningful variation',
        PredictionConfidence.insufficient => 'Still learning your rhythm',
      };
}

class _CycleStats {
  const _CycleStats({
    required this.averageCycle,
    required this.averagePeriod,
    required this.shortest,
    required this.longest,
  });

  final String averageCycle;
  final String averagePeriod;
  final String shortest;
  final String longest;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label, required this.suffix});

  final String value;
  final String label;
  final String suffix;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: Theme.of(context).textTheme.headlineMedium,
                  children: [
                    TextSpan(text: value),
                    if (value != '—')
                      TextSpan(
                        text: ' $suffix',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(label, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      );
}

class _PatternCard extends StatelessWidget {
  const _PatternCard({required this.pattern});

  final SymptomPattern pattern;

  @override
  Widget build(BuildContext context) {
    final label = _symptomLabel(pattern.key);
    final timing = switch (pattern.window) {
      CycleWindow.beforePeriod => 'in the three days before your period',
      CycleWindow.periodStart => 'during the first two days of your period',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: NylaColors.sage, borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.repeat_rounded, size: 19),
            ),
            const SizedBox(height: 13),
            Text('$label has shown a repeat', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              'You logged $label $timing in ${pattern.cyclesPresent} of ${pattern.cyclesObserved} adequately observed cycles.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 9),
            Text(
              '${(pattern.occurrenceRate * 100).round()}% of observed cycles · at least ${pattern.coverageRequiredPerCycle} logged days required per cycle',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  String _symptomLabel(String key) => switch (key) {
        'cramps' => 'cramps',
        'headache' => 'headaches',
        'bloating' => 'bloating',
        'nausea' => 'nausea',
        'dizziness' => 'dizziness',
        'back_pain' => 'back pain',
        'breast_tenderness' => 'breast tenderness',
        _ => key.replaceAll('_', ' '),
      };
}

class _InsightCopy extends StatelessWidget {
  const _InsightCopy({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: NylaColors.lavender, borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.auto_awesome_rounded, size: 19),
          ),
          const SizedBox(height: 13),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(body, style: Theme.of(context).textTheme.bodyMedium),
        ],
      );
}
