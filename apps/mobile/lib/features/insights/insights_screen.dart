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
      subtitle: 'Patterns Nyla can explain, without pretending certainty.',
      child: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Text('Your insights could not be loaded.'),
        data: (periods) {
          final stats = _stats(periods);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StatsPanel(stats: stats),
              const SizedBox(height: 16),
              _PredictionStory(prediction: prediction),
              const SizedBox(height: 18),
              ..._patternCards(context, patterns, periods.length),
              const SizedBox(height: 82),
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
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(color: NylaColors.lavenderSoft, borderRadius: BorderRadius.circular(28)),
          child: const LinearProgressIndicator(),
        ),
      ],
      error: (_, _) => [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(color: NylaColors.peachSoft, borderRadius: BorderRadius.circular(28)),
          child: const Text('Personal symptom patterns could not be calculated.'),
        ),
      ],
      data: (items) {
        if (items.isEmpty) {
          return [
            _EmptyPatternStory(periodCount: periodCount),
          ];
        }

        return [
          Padding(
            padding: const EdgeInsets.fromLTRB(3, 0, 3, 10),
            child: Row(
              children: [
                Expanded(child: Text('Patterns in your logs', style: Theme.of(context).textTheme.titleLarge)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(color: NylaColors.sageSoft, borderRadius: BorderRadius.circular(99)),
                  child: Text(
                    '${items.length} found',
                    style: const TextStyle(color: NylaColors.wine, fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          for (var index = 0; index < items.take(4).length; index++) ...[
            _PatternCard(pattern: items[index], index: index),
            if (index != items.take(4).length - 1) const SizedBox(height: 11),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, color: NylaColors.mutedInk, size: 19),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'These are descriptive observations from your own logs. They do not establish a cause or diagnosis.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12.5),
                  ),
                ),
              ],
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
}

class _StatsPanel extends StatelessWidget {
  const _StatsPanel({required this.stats});

  final _CycleStats stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [NylaColors.wine, Color(0xFF794059)],
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [
          BoxShadow(color: Color(0x2C542B3C), blurRadius: 30, offset: Offset(0, 14)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'YOUR RHYTHM',
            style: TextStyle(color: Color(0xFFE8D6DE), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2),
          ),
          const SizedBox(height: 7),
          Text(
            'At a glance',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, fontSize: 27),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _Metric(value: stats.averageCycle, label: 'Typical cycle')),
              const _MetricDivider(),
              Expanded(child: _Metric(value: stats.averagePeriod, label: 'Typical period')),
            ],
          ),
          const SizedBox(height: 18),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.14)),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _Metric(value: stats.shortest, label: 'Shortest cycle', compact: true)),
              const _MetricDivider(),
              Expanded(child: _Metric(value: stats.longest, label: 'Longest cycle', compact: true)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label, this.compact = false});

  final String value;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 26 : 34,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
              if (value != '—') ...[
                const SizedBox(width: 5),
                const Padding(
                  padding: EdgeInsets.only(bottom: 2),
                  child: Text('days', style: TextStyle(color: Color(0xFFD9C3CC), fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Color(0xFFEFE2E7), fontSize: 12.5, fontWeight: FontWeight.w600)),
        ],
      );
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider();

  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 48,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        color: Colors.white.withValues(alpha: 0.16),
      );
}

class _PredictionStory extends StatelessWidget {
  const _PredictionStory({required this.prediction});

  final AsyncValue<PredictionResult> prediction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [NylaColors.lavenderSoft, NylaColors.roseWash]),
        borderRadius: BorderRadius.circular(28),
      ),
      child: prediction.when(
        loading: () => const LinearProgressIndicator(),
        error: (_, _) => const Text('Prediction confidence is unavailable.'),
        data: (result) {
          final value = result.prediction;
          if (value == null) {
            return const _InsightCopy(
              icon: Icons.auto_awesome_rounded,
              title: 'Still learning your rhythm',
              body: 'Nyla needs completed cycle intervals before it can describe your personal variation.',
            );
          }
          return _InsightCopy(
            icon: Icons.blur_on_rounded,
            title: _confidenceTitle(value.confidence),
            body:
                'This estimate uses ${value.completedCyclesUsed} recent cycle${value.completedCyclesUsed == 1 ? '' : 's'}. Your robust variability is about ${value.variabilityDays.toStringAsFixed(1)} days, so Nyla shows a range instead of pretending one date is certain.',
          );
        },
      ),
    );
  }

  String _confidenceTitle(PredictionConfidence confidence) => switch (confidence) {
        PredictionConfidence.high => 'Your recent cycles are fairly consistent',
        PredictionConfidence.medium => 'There is a usable pattern',
        PredictionConfidence.low => 'Your cycles have meaningful variation',
        PredictionConfidence.insufficient => 'Still learning your rhythm',
      };
}

class _EmptyPatternStory extends StatelessWidget {
  const _EmptyPatternStory({required this.periodCount});

  final int periodCount;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(21),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [NylaColors.sageSoft, NylaColors.peachSoft]),
          borderRadius: BorderRadius.circular(28),
        ),
        child: _InsightCopy(
          icon: Icons.scatter_plot_rounded,
          title: 'Personal patterns need real coverage',
          body: periodCount < 4
              ? 'A repeated pattern needs observations across at least four periods. Keep logging only what matters to you.'
              : 'Nyla has not found a well-supported repeated symptom pattern yet. Missing days are treated as unknown—not as “no symptom.”',
        ),
      );
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

class _PatternCard extends StatelessWidget {
  const _PatternCard({required this.pattern, required this.index});

  final SymptomPattern pattern;
  final int index;

  @override
  Widget build(BuildContext context) {
    final label = _symptomLabel(pattern.key);
    final timing = switch (pattern.window) {
      CycleWindow.beforePeriod => 'in the three days before your period',
      CycleWindow.periodStart => 'during the first two days of your period',
    };
    final accent = index.isEven ? NylaColors.sage : NylaColors.peach;
    final percent = (pattern.occurrenceRate * 100).round();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [BoxShadow(color: Color(0x10542B3C), blurRadius: 20, offset: Offset(0, 9))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(15)),
                child: const Icon(Icons.repeat_rounded, size: 20, color: NylaColors.wine),
              ),
              const Spacer(),
              Text(
                '$percent%',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 25, color: NylaColors.rose),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text('$label has shown a repeat', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 7),
          Text(
            'You logged $label $timing in ${pattern.cyclesPresent} of ${pattern.cyclesObserved} adequately observed cycles.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: pattern.occurrenceRate.clamp(0, 1).toDouble(),
              minHeight: 7,
              color: NylaColors.rose,
              backgroundColor: NylaColors.roseWash,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'At least ${pattern.coverageRequiredPerCycle} logged days were required in each counted cycle.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11.5),
          ),
        ],
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
  const _InsightCopy({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(15)),
            child: Icon(icon, size: 20, color: NylaColors.wine),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 7),
                Text(body, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: NylaColors.ink)),
              ],
            ),
          ),
        ],
      );
}
