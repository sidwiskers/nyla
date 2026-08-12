import 'dart:math' as math;

import 'package:cycle_engine/cycle_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:health_content/health_content.dart';

import '../../core/haptics/nyla_haptics.dart';
import '../../core/model/date_text.dart';
import '../../core/theme/nyla_theme.dart';
import '../../data/database/app_database.dart';
import '../../providers.dart';
import '../../widgets/nyla_page.dart';
import '../../widgets/nyla_ui.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = LocalDay.fromDateTime(DateTime.now());
    final periods = ref.watch(periodHistoryProvider);
    final prediction = ref.watch(cyclePredictionProvider);
    final dayValues = ref.watch(dayValuesProvider(today.epochDay));
    final tip = _recommendedTip(dayValues.value ?? const <DayValueEntry>[]);

    return NylaPage(
      title: _greeting(),
      subtitle: friendlyDay(today),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CycleHero(
            today: today,
            periods: periods,
            prediction: prediction,
          ),
          const SizedBox(height: 14),
          _CheckInStrip(today: today, values: dayValues),
          const SizedBox(height: 30),
          const NylaSectionHeader(
            title: 'A little context for today',
            subtitle: 'Useful, short, and never required.',
          ),
          const SizedBox(height: 12),
          _TodayReading(
            tip: tip,
            onTap: () {
              NylaHaptics.select();
              context.go('/learn');
            },
          ),
          const SizedBox(height: 92),
        ],
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  HealthTip _recommendedTip(List<DayValueEntry> values) {
    final byKey = {for (final value in values) value.key: value};
    final cramps = byKey['cramps'];
    if ((cramps?.severity ?? 0) > 0) return _tip('why-cramps-happen');
    final discharge = byKey['discharge'];
    if (discharge != null && discharge.value != 'none') {
      return _tip('normal-discharge');
    }
    final sleep = byKey['sleep'];
    if (sleep != null &&
        (sleep.value == 'poor' || sleep.value == 'very_poor')) {
      return _tip('sleep-and-discomfort');
    }
    final flow = byKey['flow'];
    if (flow != null && flow.value != 'none') {
      return _tip('hands-before-after-products');
    }

    final safeGeneral = healthTips
        .where(
          (tip) =>
              tip.category != TipCategory.seekCare &&
              tip.id != 'tampon-metals-2026',
        )
        .toList(growable: false);
    final index =
        DateTime.now().difference(DateTime.utc(2026, 1, 1)).inDays.abs() %
            safeGeneral.length;
    return safeGeneral[index];
  }

  HealthTip _tip(String id) => healthTips.firstWhere((tip) => tip.id == id);
}

class _CycleHero extends ConsumerWidget {
  const _CycleHero({
    required this.today,
    required this.periods,
    required this.prediction,
  });

  final LocalDay today;
  final AsyncValue<List<PeriodEntry>> periods;
  final AsyncValue<PredictionResult> prediction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return periods.when(
      loading: () => const _HeroLoading(),
      error: (_, _) => const _HeroError(),
      data: (history) {
        if (history.isEmpty) {
          return _FirstCycleHero(
            onStarted: () async {
              await NylaHaptics.confirm();
              await ref.read(cycleRepositoryProvider).recordPeriod(start: today);
            },
          );
        }

        final lastStart = LocalDay(history.first.startDay);
        final cycleDay = lastStart.daysUntil(today) + 1;
        return prediction.when(
          loading: () => _CycleHeroBody(
            today: today,
            lastStart: lastStart,
            cycleDay: cycleDay,
            prediction: null,
            loadingPrediction: true,
          ),
          error: (_, _) => _CycleHeroBody(
            today: today,
            lastStart: lastStart,
            cycleDay: cycleDay,
            prediction: null,
          ),
          data: (result) => _CycleHeroBody(
            today: today,
            lastStart: lastStart,
            cycleDay: cycleDay,
            prediction: result.prediction,
          ),
        );
      },
    );
  }
}

class _CycleHeroBody extends StatelessWidget {
  const _CycleHeroBody({
    required this.today,
    required this.lastStart,
    required this.cycleDay,
    required this.prediction,
    this.loadingPrediction = false,
  });

  final LocalDay today;
  final LocalDay lastStart;
  final int cycleDay;
  final CyclePrediction? prediction;
  final bool loadingPrediction;

  @override
  Widget build(BuildContext context) {
    final estimate = prediction;
    final cycleLength = estimate?.predictedCycleLength ?? math.max(cycleDay, 28);
    final progress =
        (cycleDay / math.max(cycleLength, 1)).clamp(0.03, 1.0).toDouble();
    final rangeStart = estimate == null
        ? null
        : (lastStart.daysUntil(estimate.earliestStart) / cycleLength)
            .clamp(0.0, 1.0)
            .toDouble();
    final rangeEnd = estimate == null
        ? null
        : (lastStart.daysUntil(estimate.latestStart) / cycleLength)
            .clamp(0.0, 1.0)
            .toDouble();

    return Container(
      decoration: BoxDecoration(
        color: NylaColors.paper,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(34),
          topRight: Radius.circular(34),
          bottomLeft: Radius.circular(34),
          bottomRight: Radius.circular(14),
        ),
        border: Border.all(color: Colors.white),
        boxShadow: const [
          BoxShadow(
            color: Color(0x122A111E),
            blurRadius: 32,
            offset: Offset(0, 14),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          const Positioned.fill(
            child: IgnorePointer(child: _HeroAtmosphere()),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(23, 22, 23, 21),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const NylaOverline(
                      'Your cycle',
                      color: NylaColors.rose,
                    ),
                    const Spacer(),
                    if (estimate != null)
                      _ConfidenceLabel(confidence: estimate.confidence)
                    else if (loadingPrediction)
                      const _SmallLoading(),
                  ],
                ),
                const SizedBox(height: 19),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _headline(today, cycleDay, estimate),
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(fontSize: 28),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            estimate == null
                                ? 'Nyla will add an expected window once there is enough completed history.'
                                : 'Expected ${rangeText(estimate.earliestStart, estimate.latestStart)}',
                            style:
                                Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: NylaColors.mutedInk,
                                    ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    _CycleOrbit(day: cycleDay, progress: progress),
                  ],
                ),
                const SizedBox(height: 20),
                _CycleRail(
                  progress: progress,
                  rangeStart: rangeStart,
                  rangeEnd: rangeEnd,
                ),
                const SizedBox(height: 11),
                Row(
                  children: [
                    Text(
                      'Cycle day $cycleDay',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: NylaColors.wine,
                            fontSize: 12.5,
                          ),
                    ),
                    const Spacer(),
                    Text(
                      estimate == null
                          ? 'Learning from your history'
                          : 'Range reflects your variation',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 11.5,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _headline(
    LocalDay today,
    int cycleDay,
    CyclePrediction? prediction,
  ) {
    if (prediction == null) {
      return cycleDay > 0 ? 'Cycle day $cycleDay' : 'Building your history';
    }
    final until = today.daysUntil(prediction.likelyStart);
    if (until > 1) return 'Your period may start in $until days';
    if (until == 1) return 'Your period may start tomorrow';
    if (until >= -1) return 'Your period may start around now';
    return cycleDay > 0 ? 'Cycle day $cycleDay' : 'Cycle in progress';
  }
}

class _FirstCycleHero extends StatelessWidget {
  const _FirstCycleHero({required this.onStarted});

  final VoidCallback onStarted;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: NylaColors.paper,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(34),
            topRight: Radius.circular(34),
            bottomLeft: Radius.circular(34),
            bottomRight: Radius.circular(14),
          ),
          border: Border.all(color: Colors.white),
          boxShadow: const [
            BoxShadow(
              color: Color(0x122A111E),
              blurRadius: 32,
              offset: Offset(0, 14),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            const Positioned.fill(
              child: IgnorePointer(child: _HeroAtmosphere()),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(23, 23, 23, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const NylaOverline('Your cycle'),
                  const SizedBox(height: 46),
                  Text(
                    'Start with today.',
                    style: Theme.of(context)
                        .textTheme
                        .displaySmall
                        ?.copyWith(fontSize: 35),
                  ),
                  const SizedBox(height: 11),
                  Text(
                    'When your period begins, tell Nyla. Your own history becomes the pattern—not a generic 28-day assumption.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: onStarted,
                      icon: const Icon(Icons.water_drop_rounded, size: 18),
                      label: const Text('My period started'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _CheckInStrip extends StatelessWidget {
  const _CheckInStrip({required this.today, required this.values});

  final LocalDay today;
  final AsyncValue<List<DayValueEntry>> values;

  @override
  Widget build(BuildContext context) {
    final count = values.value?.length ?? 0;
    final hasLog = count > 0;
    return NylaPressable(
      onTap: () {
        NylaHaptics.select();
        context.go('/log?day=${today.toIsoString()}');
      },
      borderRadius: BorderRadius.circular(27),
      semanticsLabel: hasLog ? 'Edit today’s check-in' : 'Check in for today',
      child: Container(
        padding: const EdgeInsets.fromLTRB(17, 15, 15, 15),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: hasLog
                ? const [NylaColors.sageSoft, Color(0xFFF4F0E8)]
                : const [NylaColors.roseWash, NylaColors.peachSoft],
          ),
          borderRadius: BorderRadius.circular(27),
          border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
        ),
        child: Row(
          children: [
            NylaIconToken(
              icon: hasLog ? Icons.check_rounded : Icons.add_rounded,
              size: 48,
              background: hasLog ? NylaColors.sage : NylaColors.wine,
              foreground: hasLog ? NylaColors.wine : Colors.white,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasLog ? '$count things logged' : 'How are you today?',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    hasLog ? 'Review or add anything useful.' : 'A quick check-in, only if useful.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 12.3,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: NylaColors.paper,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.arrow_forward_rounded,
                size: 19,
                color: NylaColors.wine,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayReading extends StatelessWidget {
  const _TodayReading({required this.tip, required this.onTap});

  final HealthTip tip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => NylaPressable(
        onTap: onTap,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(30),
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: NylaColors.sageSoft,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(30),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              const Positioned(
                right: -30,
                top: -18,
                child: _ReadingMotif(),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(21, 20, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const NylaOverline(
                          'Today’s reading',
                          color: Color(0xFF4C7565),
                        ),
                        const Spacer(),
                        Text(
                          _categoryName(tip.category),
                          style: const TextStyle(
                            color: Color(0xFF4C7565),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: Text(
                        tip.title,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(fontSize: 27),
                      ),
                    ),
                    const SizedBox(height: 11),
                    Text(
                      tip.flash,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: NylaColors.ink,
                            height: 1.46,
                          ),
                    ),
                    const SizedBox(height: 22),
                    const Row(
                      children: [
                        Text(
                          'Read the card',
                          style: TextStyle(
                            color: NylaColors.wine,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(width: 7),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: NylaColors.wine,
                          size: 18,
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

  String _categoryName(TipCategory category) => switch (category) {
        TipCategory.cycle => 'Cycle',
        TipCategory.understanding => 'Understanding',
        TipCategory.body => 'Body',
        TipCategory.care => 'Care',
        TipCategory.products => 'Products',
        TipCategory.comfort => 'Comfort',
        TipCategory.symptoms => 'Symptoms',
        TipCategory.seekCare => 'Care note',
      };
}

class _CycleOrbit extends StatelessWidget {
  const _CycleOrbit({required this.day, required this.progress});

  final int day;
  final double progress;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: 118,
        child: CustomPaint(
          painter: _CycleOrbitPainter(progress: progress),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$day',
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontSize: 28),
                ),
                const Text(
                  'DAY',
                  style: TextStyle(
                    color: NylaColors.mutedInk,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.05,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _CycleOrbitPainter extends CustomPainter {
  const _CycleOrbitPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.39;
    final track = Paint()
      ..color = NylaColors.outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    final active = Paint()
      ..shader = const SweepGradient(
        colors: [NylaColors.rose, NylaColors.coral, NylaColors.wine],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, track);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      active,
    );

    for (var i = 0; i < 4; i++) {
      final angle = -math.pi / 2 + i * math.pi / 2;
      final point = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      canvas.drawCircle(
        point,
        2.1,
        Paint()..color = NylaColors.paper,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CycleOrbitPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _CycleRail extends StatelessWidget {
  const _CycleRail({
    required this.progress,
    required this.rangeStart,
    required this.rangeEnd,
  });

  final double progress;
  final double? rangeStart;
  final double? rangeEnd;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 18,
        child: CustomPaint(
          painter: _CycleRailPainter(
            progress: progress,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
          ),
          child: const SizedBox.expand(),
        ),
      );
}

class _CycleRailPainter extends CustomPainter {
  const _CycleRailPainter({
    required this.progress,
    required this.rangeStart,
    required this.rangeEnd,
  });

  final double progress;
  final double? rangeStart;
  final double? rangeEnd;

  @override
  void paint(Canvas canvas, Size size) {
    const y = 9.0;
    final line = Paint()
      ..color = NylaColors.outline
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(3, y), Offset(size.width - 3, y), line);

    final start = rangeStart;
    final end = rangeEnd;
    if (start != null && end != null) {
      final left = size.width * math.min(start, end);
      final right = size.width * math.max(start, end);
      final rangePaint = Paint()
        ..color = NylaColors.roseSoft
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(left, y), Offset(right, y), rangePaint);
    }

    final x = size.width * progress;
    canvas.drawCircle(
      Offset(x, y),
      7,
      Paint()..color = NylaColors.paper,
    );
    canvas.drawCircle(
      Offset(x, y),
      4.5,
      Paint()..color = NylaColors.wine,
    );
  }

  @override
  bool shouldRepaint(covariant _CycleRailPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.rangeStart != rangeStart ||
      oldDelegate.rangeEnd != rangeEnd;
}

class _ConfidenceLabel extends StatelessWidget {
  const _ConfidenceLabel({required this.confidence});

  final PredictionConfidence confidence;

  @override
  Widget build(BuildContext context) {
    final label = switch (confidence) {
      PredictionConfidence.high => 'Steady pattern',
      PredictionConfidence.medium => 'Usable pattern',
      PredictionConfidence.low => 'Wide variation',
      PredictionConfidence.insufficient => 'Early estimate',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: NylaColors.roseWash,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: NylaColors.wine,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _HeroAtmosphere extends StatelessWidget {
  const _HeroAtmosphere();

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(1.0, -0.9),
                radius: 0.95,
                colors: [
                  NylaColors.roseSoft.withValues(alpha: 0.62),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-1.1, 1.0),
                radius: 0.85,
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

class _ReadingMotif extends StatelessWidget {
  const _ReadingMotif();

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 150,
        height: 150,
        child: CustomPaint(painter: _ReadingMotifPainter()),
      );
}

class _ReadingMotifPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..color = const Color(0x244C7565);
    canvas.drawArc(
      Rect.fromLTWH(18, 16, 114, 114),
      -0.45,
      2.35,
      false,
      paint,
    );
    paint
      ..strokeWidth = 4
      ..color = const Color(0x304C7565);
    canvas.drawArc(
      Rect.fromLTWH(43, 40, 76, 76),
      1.0,
      3.0,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HeroLoading extends StatelessWidget {
  const _HeroLoading();

  @override
  Widget build(BuildContext context) => const NylaPaperSurface(
        padding: EdgeInsets.all(30),
        radius: BorderRadius.only(
          topLeft: Radius.circular(34),
          topRight: Radius.circular(34),
          bottomLeft: Radius.circular(34),
          bottomRight: Radius.circular(14),
        ),
        child: SizedBox(
          height: 190,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
}

class _HeroError extends StatelessWidget {
  const _HeroError();

  @override
  Widget build(BuildContext context) => const NylaPaperSurface(
        radius: BorderRadius.only(
          topLeft: Radius.circular(34),
          topRight: Radius.circular(34),
          bottomLeft: Radius.circular(34),
          bottomRight: Radius.circular(14),
        ),
        child: NylaInlineNote(
          icon: Icons.refresh_rounded,
          title: 'Your cycle could not be loaded',
          body: 'Your local data is still here. Try again in a moment.',
        ),
      );
}

class _SmallLoading extends StatelessWidget {
  const _SmallLoading();

  @override
  Widget build(BuildContext context) => const SizedBox.square(
        dimension: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
}
