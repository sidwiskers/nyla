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

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = LocalDay.fromDateTime(DateTime.now());
    final periods = ref.watch(periodHistoryProvider);
    final prediction = ref.watch(cyclePredictionProvider);
    final dayValues = ref.watch(dayValuesProvider(today.epochDay));

    return NylaPage(
      title: _greeting(),
      subtitle: friendlyDay(today),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CycleDashboard(today: today, periods: periods, prediction: prediction),
          const SizedBox(height: 18),
          _QuickRow(today: today, values: dayValues),
          const SizedBox(height: 18),
          _TodayCard(
            tip: _recommendedTip(dayValues.value ?? const <DayValueEntry>[]),
            onTap: () {
              NylaHaptics.select();
              context.go('/learn');
            },
          ),
          const SizedBox(height: 88),
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
    if (discharge != null && discharge.value != 'none') return _tip('normal-discharge');
    final sleep = byKey['sleep'];
    if (sleep != null && (sleep.value == 'poor' || sleep.value == 'very_poor')) {
      return _tip('sleep-and-discomfort');
    }
    final flow = byKey['flow'];
    if (flow != null && flow.value != 'none') return _tip('hands-before-after-products');

    final safeGeneral = healthTips
        .where((tip) => tip.category != TipCategory.seekCare && tip.id != 'tampon-metals-2026')
        .toList(growable: false);
    final index = DateTime.now().difference(DateTime.utc(2026, 1, 1)).inDays.abs() % safeGeneral.length;
    return safeGeneral[index];
  }

  HealthTip _tip(String id) => healthTips.firstWhere((tip) => tip.id == id);
}

class _CycleDashboard extends ConsumerWidget {
  const _CycleDashboard({required this.today, required this.periods, required this.prediction});

  final LocalDay today;
  final AsyncValue<List<PeriodEntry>> periods;
  final AsyncValue<PredictionResult> prediction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [NylaColors.night, Color(0xFF3A2447), NylaColors.violet],
          stops: [0, 0.58, 1],
        ),
        borderRadius: BorderRadius.circular(36),
        boxShadow: const [
          BoxShadow(color: Color(0x3A33203E), blurRadius: 38, offset: Offset(0, 18)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          const Positioned(right: -68, top: -62, child: _Glow(size: 190, color: Color(0x1FFFFFFF))),
          const Positioned(left: -54, bottom: -86, child: _Glow(size: 175, color: Color(0x14E27E83))),
          Padding(
            padding: const EdgeInsets.fromLTRB(23, 23, 23, 21),
            child: periods.when(
              loading: () => const SizedBox(height: 258, child: Center(child: CircularProgressIndicator(color: Colors.white))),
              error: (_, _) => const SizedBox(height: 258, child: Center(child: Text('Your cycle could not be loaded.', style: TextStyle(color: Colors.white)))),
              data: (history) {
                if (history.isEmpty) return _FirstCycle(today: today, ref: ref);
                final lastStart = LocalDay(history.first.startDay);
                final cycleDay = lastStart.daysUntil(today) + 1;
                return prediction.when(
                  loading: () => const SizedBox(height: 258, child: Center(child: CircularProgressIndicator(color: Colors.white))),
                  error: (_, _) => _CycleBody(today: today, day: cycleDay, estimate: null),
                  data: (result) => _CycleBody(today: today, day: cycleDay, estimate: result.prediction),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FirstCycle extends StatelessWidget {
  const _FirstCycle({required this.today, required this.ref});

  final LocalDay today;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 258,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Eyebrow('YOUR CYCLE'),
            const Spacer(),
            Text(
              'Start with what you know.',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(color: Colors.white, fontSize: 35),
            ),
            const SizedBox(height: 10),
            Text(
              'When your period begins, mark it. Nyla learns from your history instead of assuming everyone has the same cycle.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: const Color(0xFFEFE4F4)),
            ),
            const Spacer(),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: NylaColors.wine),
              onPressed: () async {
                await NylaHaptics.confirm();
                await ref.read(cycleRepositoryProvider).recordPeriod(start: today);
              },
              icon: const Icon(Icons.water_drop_rounded, size: 18),
              label: const Text('My period started'),
            ),
          ],
        ),
      );
}

class _CycleBody extends StatelessWidget {
  const _CycleBody({required this.today, required this.day, required this.estimate});

  final LocalDay today;
  final int day;
  final CyclePrediction? estimate;

  @override
  Widget build(BuildContext context) {
    final headline = _headline(today, day, estimate);
    final cycleLength = estimate?.predictedCycleLength ?? 28;
    final progress = day <= 0 ? 0.04 : (day / cycleLength).clamp(0.04, 1.0).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const _Eyebrow('YOUR CYCLE'),
            const Spacer(),
            if (estimate != null) _ConfidenceBadge(confidence: estimate!.confidence),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    headline,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, fontSize: 29),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    estimate == null
                        ? 'A little more history will make your first estimate possible.'
                        : 'Expected ${rangeText(estimate!.earliestStart, estimate!.latestStart)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFFE9DDEA)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            _CycleDial(day: day > 0 ? day : null, progress: progress),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_month_rounded, color: Color(0xFFE9DDEA), size: 18),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  estimate == null ? 'Prediction starts after enough completed history.' : 'The range widens when your cycles vary more.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFFE9DDEA), fontSize: 12.5),
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 17),
            ],
          ),
        ),
      ],
    );
  }

  String _headline(LocalDay today, int cycleDay, CyclePrediction? prediction) {
    if (prediction == null) return cycleDay > 0 ? 'Cycle day $cycleDay' : 'Building your history';
    final until = today.daysUntil(prediction.likelyStart);
    if (until > 1) return 'Period may start in $until days';
    if (until == 1) return 'Period may start tomorrow';
    if (until >= -1) return 'Your period may start around now';
    return cycleDay > 0 ? 'Cycle day $cycleDay' : 'Cycle in progress';
  }
}

class _CycleDial extends StatelessWidget {
  const _CycleDial({required this.day, required this.progress});

  final int? day;
  final double progress;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: 112,
        child: CustomPaint(
          painter: _CycleDialPainter(progress: progress),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  day?.toString() ?? '—',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, fontSize: 28),
                ),
                const SizedBox(height: 1),
                const Text('DAY', style: TextStyle(color: Color(0xFFD9CBE0), fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.9)),
              ],
            ),
          ),
        ),
      );
}

class _CycleDialPainter extends CustomPainter {
  const _CycleDialPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.42;
    final base = Paint()
      ..color = const Color(0x28FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    final active = Paint()
      ..shader = const LinearGradient(colors: [Colors.white, Color(0xFFF0B9CE)]).createShader(Offset.zero & size)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, base);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      active,
    );
    for (var i = 0; i < 4; i++) {
      final angle = -math.pi / 2 + (math.pi * 2 / 4) * i;
      final point = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      canvas.drawCircle(point, 2.2, Paint()..color = const Color(0xAAFFFFFF));
    }
  }

  @override
  bool shouldRepaint(covariant _CycleDialPainter oldDelegate) => oldDelegate.progress != progress;
}

class _ConfidenceBadge extends StatelessWidget {
  const _ConfidenceBadge({required this.confidence});

  final PredictionConfidence confidence;

  @override
  Widget build(BuildContext context) {
    final label = switch (confidence) {
      PredictionConfidence.high => 'HIGH CONFIDENCE',
      PredictionConfidence.medium => 'MEDIUM CONFIDENCE',
      PredictionConfidence.low => 'LOW CONFIDENCE',
      PredictionConfidence.insufficient => 'EARLY ESTIMATE',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(99)),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 8.7, fontWeight: FontWeight.w800, letterSpacing: 0.55)),
    );
  }
}

class _QuickRow extends StatelessWidget {
  const _QuickRow({required this.today, required this.values});

  final LocalDay today;
  final AsyncValue<List<DayValueEntry>> values;

  @override
  Widget build(BuildContext context) {
    final count = values.value?.length ?? 0;
    return Row(
      children: [
        Expanded(
          flex: 6,
          child: _QuickAction(
            tint: NylaColors.peachSoft,
            icon: count == 0 ? Icons.add_rounded : Icons.check_rounded,
            title: count == 0 ? 'Check in' : '$count logged',
            subtitle: count == 0 ? 'How is today?' : 'Edit today',
            onTap: () {
              NylaHaptics.select();
              context.go('/log?day=${today.toIsoString()}');
            },
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          flex: 5,
          child: _QuickAction(
            tint: NylaColors.lavenderSoft,
            icon: Icons.calendar_month_rounded,
            title: 'Calendar',
            subtitle: 'See your rhythm',
            onTap: () {
              NylaHaptics.select();
              context.go('/calendar');
            },
          ),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.tint, required this.icon, required this.title, required this.subtitle, required this.onTap});

  final Color tint;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(27),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.fromLTRB(17, 17, 15, 16),
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(27),
              border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.72), borderRadius: BorderRadius.circular(15)),
                  child: Icon(icon, color: NylaColors.violet, size: 21),
                ),
                const SizedBox(height: 17),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 3),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11.5)),
              ],
            ),
          ),
        ),
      );
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.tip, required this.onTap});

  final HealthTip tip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(31),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [NylaColors.sageSoft, Color(0xFFE7DDF3)],
              ),
              borderRadius: BorderRadius.circular(31),
              border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.66), borderRadius: BorderRadius.circular(99)),
                      child: const Text('TODAY’S CARD', style: TextStyle(color: NylaColors.violet, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                    ),
                    const Spacer(),
                    const Icon(Icons.style_rounded, color: NylaColors.violet, size: 21),
                  ],
                ),
                const SizedBox(height: 18),
                Text(tip.title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 25)),
                const SizedBox(height: 10),
                Text(
                  tip.flash,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: NylaColors.wine),
                ),
                const SizedBox(height: 17),
                Row(
                  children: [
                    Text('Open the deck', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: NylaColors.violet)),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward_rounded, color: NylaColors.violet, size: 18),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(color: Color(0xFFD9CBE0), fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 1.15),
      );
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}
