import 'dart:math' as math;

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
      subtitle: 'Your patterns, in context.',
      child: history.when(
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(40),
            child: CircularProgressIndicator(),
          ),
        ),
        error: (_, _) => const _SoftMessage(
          icon: Icons.cloud_off_rounded,
          text: 'Your insights could not be loaded.',
        ),
        data: (periods) {
          final stats = _stats(periods);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _RhythmStory(stats: stats),
              const SizedBox(height: 18),
              _PredictionContext(prediction: prediction),
              const SizedBox(height: 24),
              _PatternsSection(patterns: patterns, periodCount: periods.length),
              const SizedBox(height: 88),
            ],
          );
        },
      ),
    );
  }

  _CycleStats _stats(List<PeriodEntry> rows) {
    final chronological = [...rows]
      ..sort((a, b) => a.startDay.compareTo(b.startDay));
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

    String medianText(List<int> values) =>
        values.isEmpty ? '—' : median(values).round().toString();
    return _CycleStats(
      typicalCycle: medianText(intervals),
      typicalPeriod: medianText(durations),
      shortest: intervals.isEmpty ? '—' : intervals.reduce(math.min).toString(),
      longest: intervals.isEmpty ? '—' : intervals.reduce(math.max).toString(),
      intervals: intervals,
    );
  }
}

class _RhythmStory extends StatelessWidget {
  const _RhythmStory({required this.stats});

  final _CycleStats stats;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final palette = context.nyla;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [NylaColors.night, Color(0xFF382044), NylaColors.violet]
              : const [Color(0xFFE5DDF2), Color(0xFFF1DDE6), Color(0xFFF6E6DC)],
        ),
        borderRadius: BorderRadius.circular(36),
        border: dark ? null : Border.all(color: Colors.white.withValues(alpha: 0.72)),
        boxShadow: [
          BoxShadow(
            color: palette.shadow,
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(23, 23, 23, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'YOUR RHYTHM',
                        style: TextStyle(
                          color: dark ? const Color(0xFFD9CBE0) : palette.violet,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        stats.intervals.length < 2
                            ? 'Still taking shape'
                            : 'Cycle length over time',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: dark ? Colors.white : palette.ink,
                              fontSize: 27,
                            ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 43,
                  height: 43,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: dark ? 0.1 : 0.52),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    Icons.show_chart_rounded,
                    color: dark ? Colors.white : palette.violet,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 152,
            child: stats.intervals.length < 2
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Text(
                        'Once you have a few completed cycles, this space will show how your cycle length moves over time.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: dark ? const Color(0xFFE6D9ED) : palette.wine,
                            ),
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _RhythmPainter(
                          values: stats.intervals,
                          dark: dark,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 17, 20, 19),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: dark ? 0.075 : 0.34),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _Metric(
                    value: stats.typicalCycle,
                    label: 'Typical cycle',
                    dark: dark,
                  ),
                ),
                _MetricDivider(dark: dark),
                Expanded(
                  child: _Metric(
                    value: stats.typicalPeriod,
                    label: 'Typical period',
                    dark: dark,
                  ),
                ),
                _MetricDivider(dark: dark),
                Expanded(
                  child: _Metric(
                    value: _range(stats),
                    label: 'Observed range',
                    suffix: false,
                    dark: dark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _range(_CycleStats stats) {
    if (stats.shortest == '—' || stats.longest == '—') return '—';
    return '${stats.shortest}–${stats.longest}';
  }
}

class _RhythmPainter extends CustomPainter {
  const _RhythmPainter({required this.values, required this.dark});

  final List<int> values;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final minValue = values.reduce(math.min).toDouble();
    final maxValue = values.reduce(math.max).toDouble();
    final spread = math.max(4.0, maxValue - minValue);
    final low = minValue - 2;
    final high = minValue + spread + 2;

    final grid = Paint()
      ..color = dark ? const Color(0x1FFFFFFF) : const Color(0x267A647E)
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    Offset point(int index) {
      final x = size.width * index / (values.length - 1);
      final normalized = ((values[index] - low) / (high - low)).clamp(0.0, 1.0);
      final y = size.height - (normalized * size.height * 0.78) - size.height * 0.11;
      return Offset(x, y);
    }

    final path = Path()..moveTo(point(0).dx, point(0).dy);
    for (var i = 1; i < values.length; i++) {
      final previous = point(i - 1);
      final current = point(i);
      final midX = (previous.dx + current.dx) / 2;
      path.cubicTo(midX, previous.dy, midX, current.dy, current.dx, current.dy);
    }

    final stroke = Paint()
      ..shader = LinearGradient(
        colors: dark
            ? const [Color(0xFFF1D8F0), Color(0xFFF3B4CB)]
            : const [Color(0xFF8C72B0), Color(0xFFC86F8E)],
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, stroke);

    for (var i = 0; i < values.length; i++) {
      final p = point(i);
      canvas.drawCircle(p, 5.5, Paint()..color = dark ? Colors.white : const Color(0xFFFFFAFC));
      canvas.drawCircle(p, 2.5, Paint()..color = NylaColors.rose);
    }
  }

  @override
  bool shouldRepaint(covariant _RhythmPainter oldDelegate) =>
      oldDelegate.dark != dark || oldDelegate.values != values;
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.value,
    required this.label,
    required this.dark,
    this.suffix = true,
  });

  final String value;
  final String label;
  final bool dark;
  final bool suffix;

  @override
  Widget build(BuildContext context) {
    final palette = context.nyla;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                style: TextStyle(
                  color: dark ? Colors.white : palette.ink,
                  fontSize: 24,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.7,
                ),
              ),
            ),
            if (suffix && value != '—')
              Padding(
                padding: const EdgeInsets.only(left: 3, bottom: 1),
                child: Text(
                  'd',
                  style: TextStyle(
                    color: dark ? const Color(0xFFCEBDD6) : palette.mutedInk,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: TextStyle(
            color: dark ? const Color(0xFFE6D9ED) : palette.mutedInk,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 40,
        margin: const EdgeInsets.symmetric(horizontal: 11),
        color: dark
            ? Colors.white.withValues(alpha: 0.13)
            : context.nyla.outlineStrong.withValues(alpha: 0.8),
      );
}

class _PredictionContext extends StatelessWidget {
  const _PredictionContext({required this.prediction});

  final AsyncValue<PredictionResult> prediction;

  @override
  Widget build(BuildContext context) => prediction.when(
        loading: () => const _SoftMessage(
          icon: Icons.blur_on_rounded,
          text: 'Updating your prediction context…',
        ),
        error: (_, _) => const _SoftMessage(
          icon: Icons.blur_off_rounded,
          text: 'Prediction confidence is unavailable right now.',
        ),
        data: (result) {
          final value = result.prediction;
          if (value == null) {
            return const _StoryPanel(
              icon: Icons.auto_awesome_rounded,
              title: 'Still learning your rhythm',
              body:
                  'A few completed cycle intervals are needed before your personal variation becomes meaningful.',
            );
          }

          final sentences = <String>[
            'Based on ${value.completedCyclesUsed} recent completed cycle${value.completedCyclesUsed == 1 ? '' : 's'}, the current window extends about ${value.predictionRangeRadiusDays} day${value.predictionRangeRadiusDays == 1 ? '' : 's'} on either side of the likely date.',
          ];
          if (value.calibrationErrorDays case final error?) {
            sentences.add(
              'Recent predictions have usually landed within about ${error.toStringAsFixed(1)} days at the cautious end.',
            );
          } else {
            sentences.add(
              'There is not enough history yet to judge how closely recent predictions have matched.',
            );
          }
          if (value.suspectedSkippedIntervals > 0) {
            sentences.add(
              '${value.suspectedSkippedIntervals} unusually long gap${value.suspectedSkippedIntervals == 1 ? '' : 's'} may reflect missed tracking, so ${value.suspectedSkippedIntervals == 1 ? 'it was' : 'they were'} treated cautiously.',
            );
          }
          sentences.add('A date range is more useful than presenting one day as certain.');

          return _StoryPanel(
            icon: Icons.blur_on_rounded,
            title: _confidenceTitle(value.confidence),
            body: sentences.join(' '),
          );
        },
      );

  String _confidenceTitle(PredictionConfidence confidence) => switch (confidence) {
        PredictionConfidence.high => 'Your recent rhythm is well supported',
        PredictionConfidence.medium => 'There is a useful personal pattern',
        PredictionConfidence.low => 'Your recent cycles carry meaningful uncertainty',
        PredictionConfidence.insufficient => 'Still learning your rhythm',
      };
}

class _StoryPanel extends StatelessWidget {
  const _StoryPanel({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final palette = context.nyla;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [palette.lavenderSoft, palette.roseWash]),
        borderRadius: BorderRadius.circular(29),
        border: Border.all(color: palette.glassBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: palette.glass,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: palette.violet, size: 21),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 7),
                Text(
                  body,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: palette.ink),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PatternsSection extends StatelessWidget {
  const _PatternsSection({required this.patterns, required this.periodCount});

  final AsyncValue<List<SymptomPattern>> patterns;
  final int periodCount;

  @override
  Widget build(BuildContext context) => patterns.when(
        loading: () => const _SoftMessage(
          icon: Icons.scatter_plot_rounded,
          text: 'Looking for repeated patterns…',
        ),
        error: (_, _) => const _SoftMessage(
          icon: Icons.scatter_plot_rounded,
          text: 'Personal symptom patterns could not be calculated.',
        ),
        data: (items) {
          if (items.isEmpty) {
            return _StoryPanel(
              icon: Icons.scatter_plot_rounded,
              title: 'No strong repeated pattern yet',
              body: periodCount < 4
                  ? 'A repeated pattern needs observations across at least four periods. Keep logging only what matters to you.'
                  : 'No well-supported repeated pattern has emerged yet. Missing days stay unknown rather than being treated as “no symptom.”',
            );
          }
          final palette = context.nyla;
          final shown = items.take(6).toList(growable: false);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Patterns in your logs', style: Theme.of(context).textTheme.titleLarge),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: palette.sageSoft,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '${items.length} found',
                      style: TextStyle(
                        color: palette.violet,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 11),
              for (var i = 0; i < shown.length; i++) ...[
                _PatternCard(pattern: shown[i], index: i),
                if (i != shown.length - 1) const SizedBox(height: 11),
              ],
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: palette.glass,
                  borderRadius: BorderRadius.circular(21),
                  border: Border.all(color: palette.glassBorder),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, color: palette.mutedInk, size: 18),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'These are observations from your own logs. They describe timing, not a cause or diagnosis.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      );
}

class _PatternCard extends StatelessWidget {
  const _PatternCard({required this.pattern, required this.index});

  final SymptomPattern pattern;
  final int index;

  @override
  Widget build(BuildContext context) {
    final label = _symptomLabel(pattern.key);
    final timing = _timingLabel(pattern.window);
    final percent = (pattern.occurrenceRate * 100).round();
    final palette = context.nyla;
    final tint = index.isEven ? palette.sageSoft : palette.peachSoft;

    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: palette.glassStrong,
        borderRadius: BorderRadius.circular(27),
        border: Border.all(color: palette.glassBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 58,
            height: 58,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: pattern.occurrenceRate.clamp(0, 1).toDouble(),
                  strokeWidth: 6,
                  backgroundColor: tint,
                  color: palette.violet,
                ),
                Text(
                  '$percent',
                  style: TextStyle(
                    color: palette.wine,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$label tends to repeat', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(
                  'You logged $label $timing in ${pattern.cyclesPresent} of ${pattern.cyclesObserved} well-observed cycles.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 7),
                Text(
                  'Only cycles with enough daily entries are counted, so missing days are not treated as symptom-free.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 10.8,
                        color: palette.faintInk,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _timingLabel(CycleWindow window) => switch (window) {
        CycleWindow.beforePeriod => 'in the four days before your period',
        CycleWindow.periodStart => 'during the first three days of your period',
        CycleWindow.earlyFollicular => 'in the early follicular part of your cycle',
        CycleWindow.periOvulatory => 'around your broad estimated peri-ovulatory window',
        CycleWindow.midLuteal => 'in the mid-luteal part of your cycle',
      };

  String _symptomLabel(String key) => switch (key) {
        'cramps' => 'Cramps',
        'headache' => 'Headaches',
        'bloating' => 'Bloating',
        'nausea' => 'Nausea',
        'dizziness' => 'Dizziness',
        'back_pain' => 'Back pain',
        'breast_tenderness' => 'Breast tenderness',
        'energy.low' => 'Lower energy',
        'energy.high' => 'Higher energy',
        'sleep.poor' => 'Poorer sleep',
        'appetite.higher' => 'Higher appetite',
        'appetite.cravings' => 'Cravings',
        'discharge.estrogenic' => 'Watery or stretchy discharge',
        'discharge.dry' => 'Drier discharge',
        'digestion.constipation' => 'Constipation',
        'digestion.loose_stool' => 'Looser stools',
        'digestion.gassy' => 'Gas',
        'flow.heavy' => 'Heavy flow',
        'mood.sensitive' => 'Feeling more sensitive',
        'mood.low' => 'Lower mood',
        'mood.irritable' => 'Irritability',
        'mood.anxious' => 'Anxiety',
        'mood.overwhelmed' => 'Feeling overwhelmed',
        'mood.happy' => 'Feeling happier',
        'skin.breakout' => 'Breakouts',
        'skin.oily' => 'Oilier skin',
        'skin.dry' => 'Drier skin',
        'skin.sensitive' => 'Sensitive skin',
        _ => key.replaceAll('.', ' · ').replaceAll('_', ' '),
      };
}

class _SoftMessage extends StatelessWidget {
  const _SoftMessage({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.nyla;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.lavenderSoft,
        borderRadius: BorderRadius.circular(27),
        border: Border.all(color: palette.glassBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: palette.violet),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: palette.ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _CycleStats {
  const _CycleStats({
    required this.typicalCycle,
    required this.typicalPeriod,
    required this.shortest,
    required this.longest,
    required this.intervals,
  });

  final String typicalCycle;
  final String typicalPeriod;
  final String shortest;
  final String longest;
  final List<int> intervals;
}
