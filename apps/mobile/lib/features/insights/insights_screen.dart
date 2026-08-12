import 'dart:math' as math;

import 'package:cycle_engine/cycle_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/nyla_theme.dart';
import '../../data/database/app_database.dart';
import '../../providers.dart';
import '../../widgets/nyla_page.dart';
import '../../widgets/nyla_ui.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(periodHistoryProvider);
    final prediction = ref.watch(cyclePredictionProvider);
    final patterns = ref.watch(symptomPatternsProvider);

    return NylaPage(
      title: 'Insights',
      subtitle: 'Patterns with context, not conclusions.',
      child: history.when(
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(40),
            child: CircularProgressIndicator(),
          ),
        ),
        error: (_, _) => const _SoftMessage(
          icon: Icons.refresh_rounded,
          text: 'Your insights could not be loaded right now.',
        ),
        data: (periods) {
          final stats = _stats(periods);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _RhythmCanvas(stats: stats),
              const SizedBox(height: 28),
              _PredictionNarrative(prediction: prediction),
              const SizedBox(height: 32),
              _PatternsSection(
                patterns: patterns,
                periodCount: periods.length,
              ),
              const SizedBox(height: 92),
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

class _RhythmCanvas extends StatelessWidget {
  const _RhythmCanvas({required this.stats});

  final _CycleStats stats;

  @override
  Widget build(BuildContext context) {
    final hasRhythm = stats.intervals.length >= 2;
    return NylaPaperSurface(
      padding: EdgeInsets.zero,
      radius: const BorderRadius.only(
        topLeft: Radius.circular(34),
        topRight: Radius.circular(18),
        bottomLeft: Radius.circular(18),
        bottomRight: Radius.circular(34),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(34),
          topRight: Radius.circular(18),
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(34),
        ),
        child: Stack(
          children: [
            const Positioned.fill(
              child: IgnorePointer(child: _RhythmAtmosphere()),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const NylaOverline('Your rhythm'),
                  const SizedBox(height: 9),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          hasRhythm
                              ? 'Cycle length over time'
                              : 'Still taking shape',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(fontSize: 27),
                        ),
                      ),
                      if (stats.typicalCycle != '—')
                        _BigMetric(
                          value: stats.typicalCycle,
                          suffix: 'days',
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 170,
                    child: hasRhythm
                        ? CustomPaint(
                            painter: _RhythmPainter(values: stats.intervals),
                            child: const SizedBox.expand(),
                          )
                        : _EmptyRhythm(),
                  ),
                  const SizedBox(height: 18),
                  const NylaHairline(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _SmallMetric(
                          value: stats.typicalPeriod,
                          label: 'Typical period',
                          suffix: 'days',
                        ),
                      ),
                      Expanded(
                        child: _SmallMetric(
                          value: _range(stats),
                          label: 'Observed range',
                          suffix: 'days',
                        ),
                      ),
                      Expanded(
                        child: _SmallMetric(
                          value: '${stats.intervals.length}',
                          label: 'Intervals used',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _range(_CycleStats value) {
    if (value.shortest == '—' || value.longest == '—') return '—';
    return '${value.shortest}–${value.longest}';
  }
}

class _BigMetric extends StatelessWidget {
  const _BigMetric({required this.value, required this.suffix});

  final String value;
  final String suffix;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: NylaColors.wine,
                  fontSize: 42,
                  height: 0.92,
                ),
          ),
          const SizedBox(width: 5),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              suffix,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      );
}

class _SmallMetric extends StatelessWidget {
  const _SmallMetric({
    required this.value,
    required this.label,
    this.suffix,
  });

  final String value;
  final String label;
  final String? suffix;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: NylaColors.wine,
                        fontSize: 19,
                      ),
                ),
              ),
              if (suffix != null && value != '—')
                Padding(
                  padding: const EdgeInsets.only(left: 3, bottom: 1),
                  child: Text(
                    suffix!,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontSize: 9.5),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontSize: 10.5),
          ),
        ],
      );
}

class _RhythmPainter extends CustomPainter {
  const _RhythmPainter({required this.values});

  final List<int> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final minValue = values.reduce(math.min).toDouble();
    final maxValue = values.reduce(math.max).toDouble();
    final spread = math.max(4.0, maxValue - minValue);
    final low = minValue - 2;
    final high = minValue + spread + 2;

    final grid = Paint()
      ..color = NylaColors.outline.withValues(alpha: 0.72)
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    Offset point(int index) {
      final x = size.width * index / (values.length - 1);
      final normalized =
          ((values[index] - low) / (high - low)).clamp(0.0, 1.0);
      final y =
          size.height - (normalized * size.height * 0.72) - size.height * 0.14;
      return Offset(x, y);
    }

    final line = Path()..moveTo(point(0).dx, point(0).dy);
    for (var i = 1; i < values.length; i++) {
      final previous = point(i - 1);
      final current = point(i);
      final midX = (previous.dx + current.dx) / 2;
      line.cubicTo(
        midX,
        previous.dy,
        midX,
        current.dy,
        current.dx,
        current.dy,
      );
    }

    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x38B76570), Color(0x00B76570)],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      line,
      Paint()
        ..shader = const LinearGradient(
          colors: [NylaColors.rose, NylaColors.wine],
        ).createShader(Offset.zero & size)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );

    for (var i = 0; i < values.length; i++) {
      final p = point(i);
      canvas.drawCircle(
        p,
        6,
        Paint()..color = NylaColors.paper,
      );
      canvas.drawCircle(
        p,
        3,
        Paint()..color = NylaColors.rose,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RhythmPainter oldDelegate) =>
      oldDelegate.values != values;
}

class _EmptyRhythm extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Text(
            'Once a few cycles are complete, this space will show how your cycle length moves over time.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
}

class _PredictionNarrative extends StatelessWidget {
  const _PredictionNarrative({required this.prediction});

  final AsyncValue<PredictionResult> prediction;

  @override
  Widget build(BuildContext context) => prediction.when(
        loading: () => const _SoftMessage(
          icon: Icons.blur_on_rounded,
          text: 'Updating prediction context…',
        ),
        error: (_, _) => const _SoftMessage(
          icon: Icons.blur_off_rounded,
          text: 'Prediction context is unavailable right now.',
        ),
        data: (result) {
          final value = result.prediction;
          if (value == null) {
            return const NylaInlineNote(
              icon: Icons.auto_awesome_rounded,
              title: 'Still learning your rhythm',
              body:
                  'A personal estimate needs completed cycle intervals. Nyla will not invent certainty before there is enough history.',
              accent: NylaColors.violet,
            );
          }

          return NylaInlineNote(
            icon: Icons.blur_on_rounded,
            title: _confidenceTitle(value.confidence),
            body:
                'This estimate uses ${value.completedCyclesUsed} recent cycle${value.completedCyclesUsed == 1 ? '' : 's'}. Recent variation is about ${value.variabilityDays.toStringAsFixed(1)} days, so your calendar shows a range instead of one exact date.',
            accent: NylaColors.violet,
          );
        },
      );

  String _confidenceTitle(PredictionConfidence confidence) =>
      switch (confidence) {
        PredictionConfidence.high => 'Your recent cycles are fairly consistent',
        PredictionConfidence.medium => 'There is a usable pattern',
        PredictionConfidence.low => 'Your cycles have meaningful variation',
        PredictionConfidence.insufficient => 'Still learning your rhythm',
      };
}

class _PatternsSection extends StatelessWidget {
  const _PatternsSection({
    required this.patterns,
    required this.periodCount,
  });

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
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const NylaSectionHeader(
                  title: 'Patterns in your logs',
                  subtitle: 'Only repeated observations appear here.',
                ),
                const SizedBox(height: 14),
                NylaInlineNote(
                  icon: Icons.scatter_plot_rounded,
                  title: 'No strong repeated pattern yet',
                  body: periodCount < 4
                      ? 'A repeated pattern needs observations across at least four periods. Keep logging only what matters to you.'
                      : 'Nyla has not found a well-supported repeated symptom pattern yet. Missing days remain unknown rather than becoming “no symptom.”',
                  accent: const Color(0xFF4C7565),
                ),
              ],
            );
          }

          final visible = items.take(4).toList(growable: false);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NylaSectionHeader(
                title: 'Patterns in your logs',
                subtitle:
                    '${items.length} repeated pattern${items.length == 1 ? '' : 's'} with enough coverage.',
              ),
              const SizedBox(height: 17),
              for (var i = 0; i < visible.length; i++)
                _PatternRow(
                  pattern: visible[i],
                  last: i == visible.length - 1,
                ),
              const SizedBox(height: 18),
              Text(
                'These describe your own logs. They do not establish a cause or diagnosis.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 11.5,
                      color: NylaColors.faintInk,
                    ),
              ),
            ],
          );
        },
      );
}

class _PatternRow extends StatelessWidget {
  const _PatternRow({
    required this.pattern,
    required this.last,
  });

  final SymptomPattern pattern;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final label = _symptomLabel(pattern.key);
    final timing = switch (pattern.window) {
      CycleWindow.beforePeriod => 'in the three days before your period',
      CycleWindow.periodStart => 'during the first two days of your period',
    };
    final percent = (pattern.occurrenceRate * 100).round();

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 44,
            child: Column(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: NylaColors.sageSoft,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$percent',
                    style: const TextStyle(
                      color: NylaColors.wine,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 1,
                      color: NylaColors.outlineStrong,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$label tends to repeat',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'You logged $label $timing in ${pattern.cyclesPresent} of ${pattern.cyclesObserved} adequately observed cycles.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'At least ${pattern.coverageRequiredPerCycle} logged days were required in each counted cycle.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 10.8,
                          color: NylaColors.faintInk,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _symptomLabel(String key) => switch (key) {
        'cramps' => 'Cramps',
        'headache' => 'Headaches',
        'bloating' => 'Bloating',
        'nausea' => 'Nausea',
        'dizziness' => 'Dizziness',
        'back_pain' => 'Back pain',
        'breast_tenderness' => 'Breast tenderness',
        _ => key.replaceAll('_', ' '),
      };
}

class _RhythmAtmosphere extends StatelessWidget {
  const _RhythmAtmosphere();

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(1.12, -1.0),
                radius: 0.95,
                colors: [
                  NylaColors.roseSoft.withValues(alpha: 0.56),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-1.0, 1.1),
                radius: 0.88,
                colors: [
                  NylaColors.sageSoft.withValues(alpha: 0.72),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ],
      );
}

class _SoftMessage extends StatelessWidget {
  const _SoftMessage({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => NylaPaperSurface(
        child: Row(
          children: [
            NylaIconToken(
              icon: icon,
              background: NylaColors.lavenderSoft,
              foreground: NylaColors.violet,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: NylaColors.ink,
                    ),
              ),
            ),
          ],
        ),
      );
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
