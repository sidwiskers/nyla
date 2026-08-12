import 'dart:math' as math;

import 'package:cycle_engine/cycle_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/model/date_text.dart';
import '../../core/theme/nyla_theme.dart';
import '../../data/database/app_database.dart';
import '../../providers.dart';
import '../../widgets/nyla_page.dart';
import '../../widgets/nyla_ui.dart';

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  int selected = 0;

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(periodHistoryProvider);
    final prediction = ref.watch(cyclePredictionProvider);
    final patterns = ref.watch(symptomPatternsProvider);

    return NylaPage(
      title: 'Insights',
      child: history.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => const NylaInlineNote(
          icon: Icons.refresh_rounded,
          title: 'Insights are taking a moment',
          body: 'Your data is still here. Try again shortly.',
        ),
        data: (periods) {
          final stats = _stats(periods);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NylaPillTabs(
                labels: const ['Overview', 'Cycles', 'Symptoms'],
                selectedIndex: selected,
                onSelected: (value) => setState(() => selected = value),
              ),
              const SizedBox(height: 14),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: switch (selected) {
                  0 => _Overview(key: const ValueKey(0), stats: stats, patterns: patterns),
                  1 => _Cycles(key: const ValueKey(1), stats: stats, prediction: prediction),
                  _ => _Symptoms(key: const ValueKey(2), patterns: patterns, periodCount: periods.length),
                },
              ),
              const SizedBox(height: 88),
            ],
          );
        },
      ),
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
        .toList(growable: false);

    return _CycleStats(
      cycle: intervals.isEmpty ? null : median(intervals),
      period: durations.isEmpty ? null : median(durations),
      intervals: intervals,
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.stats, required this.patterns, super.key});

  final _CycleStats stats;
  final AsyncValue<List<SymptomPattern>> patterns;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CycleChart(stats: stats),
          const SizedBox(height: 14),
          patterns.when(
            loading: () => const _SmallLoadingCard(),
            error: (_, _) => const NylaInlineNote(
              icon: Icons.bar_chart_rounded,
              title: 'Symptoms will appear here',
              body: 'Nyla could not refresh them right now.',
            ),
            data: (items) => _TopSymptoms(items: items),
          ),
        ],
      );
}

class _CycleChart extends StatelessWidget {
  const _CycleChart({required this.stats});

  final _CycleStats stats;

  @override
  Widget build(BuildContext context) {
    final average = stats.cycle?.round();
    return NylaPaperSurface(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 15),
      radius: BorderRadius.circular(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Average Cycle Length', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11.5)),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                average == null ? '—' : '$average',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 25),
              ),
              if (average != null)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 3),
                  child: Text('Days', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 10.5)),
                ),
            ],
          ),
          const SizedBox(height: 13),
          SizedBox(
            height: 130,
            child: stats.intervals.length < 2
                ? Center(
                    child: Text(
                      'Your cycle chart will grow here.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                : CustomPaint(
                    painter: _LinePainter(stats.intervals),
                    child: const SizedBox.expand(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  const _LinePainter(this.values);

  final List<int> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final grid = Paint()
      ..color = NylaColors.outline
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final minValue = values.reduce(math.min).toDouble();
    final maxValue = values.reduce(math.max).toDouble();
    final spread = math.max(4.0, maxValue - minValue);

    Offset point(int index) {
      final x = size.width * index / (values.length - 1);
      final normalized = ((values[index] - (minValue - 2)) / (spread + 4)).clamp(0.0, 1.0);
      return Offset(x, size.height - (normalized * size.height * 0.75) - size.height * 0.12);
    }

    final path = Path()..moveTo(point(0).dx, point(0).dy);
    for (var i = 1; i < values.length; i++) {
      path.lineTo(point(i).dx, point(i).dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = NylaColors.violet
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    for (var i = 0; i < values.length; i++) {
      final p = point(i);
      canvas.drawCircle(p, 5, Paint()..color = NylaColors.paper);
      canvas.drawCircle(p, 3, Paint()..color = NylaColors.violet);
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter oldDelegate) => oldDelegate.values != values;
}

class _TopSymptoms extends StatelessWidget {
  const _TopSymptoms({required this.items});

  final List<SymptomPattern> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const NylaInlineNote(
        icon: Icons.favorite_outline_rounded,
        title: 'Your patterns will show up here',
        body: 'Keep logging only what feels useful. Nyla will connect the dots over time.',
        accent: NylaColors.rose,
      );
    }
    final visible = [...items]
      ..sort((a, b) => b.occurrenceRate.compareTo(a.occurrenceRate));
    final top = visible.take(4).toList(growable: false);
    return NylaPaperSurface(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
      shadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Top Symptoms', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 13),
          for (var i = 0; i < top.length; i++) ...[
            _SymptomBar(
              label: _symptomLabel(top[i].key),
              value: top[i].occurrenceRate.clamp(0, 1).toDouble(),
            ),
            if (i != top.length - 1) const SizedBox(height: 11),
          ],
        ],
      ),
    );
  }
}

class _SymptomBar extends StatelessWidget {
  const _SymptomBar({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          SizedBox(
            width: 82,
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11.5)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 5,
                backgroundColor: NylaColors.lavenderSoft,
                valueColor: const AlwaysStoppedAnimation(NylaColors.iris),
              ),
            ),
          ),
          const SizedBox(width: 9),
          SizedBox(
            width: 30,
            child: Text(
              '${(value * 100).round()}%',
              textAlign: TextAlign.right,
              style: const TextStyle(color: NylaColors.mutedInk, fontSize: 9.8, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      );
}

class _Cycles extends StatelessWidget {
  const _Cycles({required this.stats, required this.prediction, super.key});

  final _CycleStats stats;
  final AsyncValue<PredictionResult> prediction;

  @override
  Widget build(BuildContext context) {
    final shortest = stats.intervals.isEmpty ? null : stats.intervals.reduce(math.min);
    final longest = stats.intervals.isEmpty ? null : stats.intervals.reduce(math.max);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _Metric(value: stats.cycle?.round(), label: 'Typical cycle')),
            const SizedBox(width: 9),
            Expanded(child: _Metric(value: stats.period?.round(), label: 'Typical period')),
          ],
        ),
        const SizedBox(height: 9),
        NylaPaperSurface(
          padding: const EdgeInsets.all(16),
          shadow: false,
          child: Row(
            children: [
              const NylaIconToken(icon: Icons.timeline_rounded, background: NylaColors.sageSoft),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Observed range', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 13.5)),
                    const SizedBox(height: 2),
                    Text(
                      shortest == null ? 'A little more history will fill this in.' : '$shortest–$longest days across your completed cycles.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        prediction.when(
          loading: () => const _SmallLoadingCard(),
          error: (_, _) => const NylaInlineNote(
            icon: Icons.calendar_month_outlined,
            title: 'Your next estimate is unavailable',
            body: 'Try again in a moment.',
          ),
          data: (result) {
            final value = result.prediction;
            if (value == null) {
              return const NylaInlineNote(
                icon: Icons.auto_awesome_rounded,
                title: 'Still learning your rhythm',
                body: 'Once you have a few completed cycles, Nyla can show a personal range.',
              );
            }
            return NylaInlineNote(
              icon: Icons.calendar_month_outlined,
              title: 'Expected ${rangeText(value.earliestStart, value.latestStart)}',
              body:
                  'Based on ${value.completedCyclesUsed} recent completed cycle${value.completedCyclesUsed == 1 ? '' : 's'}. Recent variation is about ${value.variabilityDays.toStringAsFixed(1)} days, so Nyla keeps this as a range rather than one exact date.',
              accent: NylaColors.violet,
            );
          },
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});

  final int? value;
  final String label;

  @override
  Widget build(BuildContext context) => NylaPaperSurface(
        padding: const EdgeInsets.all(15),
        shadow: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value == null ? '—' : '$value',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 25, color: NylaColors.wine),
            ),
            const SizedBox(height: 2),
            Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 10.8)),
          ],
        ),
      );
}

class _Symptoms extends StatelessWidget {
  const _Symptoms({required this.patterns, required this.periodCount, super.key});

  final AsyncValue<List<SymptomPattern>> patterns;
  final int periodCount;

  @override
  Widget build(BuildContext context) => patterns.when(
        loading: () => const _SmallLoadingCard(),
        error: (_, _) => const NylaInlineNote(
          icon: Icons.favorite_outline_rounded,
          title: 'Symptoms are taking a moment',
          body: 'Try again shortly.',
        ),
        data: (items) {
          if (items.isEmpty) {
            return NylaInlineNote(
              icon: Icons.favorite_outline_rounded,
              title: 'No clear pattern yet',
              body: periodCount < 4
                  ? 'A few more cycles will make this space more useful.'
                  : 'Your recent logs do not show a strong repeated pattern, and that is useful too.',
              accent: NylaColors.rose,
            );
          }
          return NylaPaperSurface(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            shadow: false,
            child: Column(
              children: [
                for (var i = 0; i < items.length && i < 6; i++) ...[
                  _PatternRow(pattern: items[i]),
                  if (i != items.length - 1 && i != 5) const NylaHairline(margin: EdgeInsets.only(left: 48)),
                ],
              ],
            ),
          );
        },
      );
}

class _PatternRow extends StatelessWidget {
  const _PatternRow({required this.pattern});

  final SymptomPattern pattern;

  @override
  Widget build(BuildContext context) {
    final percent = (pattern.occurrenceRate * 100).round();
    final timing = switch (pattern.window) {
      CycleWindow.beforePeriod => 'before your period',
      CycleWindow.periodStart => 'at the start of your period',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          const NylaIconToken(icon: Icons.favorite_outline_rounded, size: 38, background: NylaColors.roseWash),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_symptomLabel(pattern.key), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 13.5)),
                const SizedBox(height: 2),
                Text(
                  '${pattern.cyclesPresent} of ${pattern.cyclesObserved} well-observed cycles · $timing · at least ${pattern.coverageRequiredPerCycle} logged days each.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 10.8),
                ),
              ],
            ),
          ),
          Text('$percent%', style: const TextStyle(color: NylaColors.violet, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _SmallLoadingCard extends StatelessWidget {
  const _SmallLoadingCard();

  @override
  Widget build(BuildContext context) => const NylaPaperSurface(
        child: SizedBox(height: 70, child: Center(child: CircularProgressIndicator())),
      );
}

class _CycleStats {
  const _CycleStats({required this.cycle, required this.period, required this.intervals});

  final double? cycle;
  final double? period;
  final List<int> intervals;
}

String _symptomLabel(String key) => switch (key) {
      'cramps' => 'Cramps',
      'headache' => 'Headache',
      'bloating' => 'Bloating',
      'nausea' => 'Nausea',
      'dizziness' => 'Dizziness',
      'back_pain' => 'Back pain',
      'breast_tenderness' => 'Breast tenderness',
      _ => key.replaceAll('_', ' '),
    };
