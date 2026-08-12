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
    final values = ref.watch(dayValuesProvider(today.epochDay));
    final tip = _recommendedTip(values.value ?? const <DayValueEntry>[]);

    return NylaPage(
      title: '',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TodayHeader(
            greeting: _greeting(),
            onNotifications: () {
              NylaHaptics.select();
              context.push('/settings');
            },
          ),
          const SizedBox(height: 18),
          NylaPillTabs(
            labels: const ['Overview', 'Cycle', 'Symptoms'],
            selectedIndex: 0,
            onSelected: (index) {
              if (index == 0) return;
              NylaHaptics.select();
              context.go(index == 1 ? '/calendar' : '/log?day=${today.toIsoString()}');
            },
          ),
          const SizedBox(height: 14),
          _CycleCard(today: today, periods: periods, prediction: prediction),
          const SizedBox(height: 14),
          _InsightCard(
            tip: tip,
            onTap: () {
              NylaHaptics.select();
              context.push('/learn');
            },
          ),
          const SizedBox(height: 14),
          _NextPeriodCard(today: today, prediction: prediction),
          const SizedBox(height: 14),
          _QuickActions(
            onPeriod: () => _openLog(context, today),
            onSymptoms: () => _openLog(context, today),
            onNote: () => _openLog(context, today),
          ),
          const SizedBox(height: 88),
        ],
      ),
    );
  }

  void _openLog(BuildContext context, LocalDay today) {
    NylaHaptics.select();
    context.go('/log?day=${today.toIsoString()}');
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

    final general = healthTips
        .where((item) => item.category != TipCategory.seekCare && item.id != 'tampon-metals-2026')
        .toList(growable: false);
    final index = DateTime.now().difference(DateTime.utc(2026, 1, 1)).inDays.abs() % general.length;
    return general[index];
  }

  HealthTip _tip(String id) => healthTips.firstWhere((tip) => tip.id == id);
}

class _TodayHeader extends StatelessWidget {
  const _TodayHeader({required this.greeting, required this.onNotifications});

  final String greeting;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting,',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: NylaColors.mutedInk,
                        fontSize: 14,
                      ),
                ),
                const SizedBox(height: 1),
                const Row(
                  children: [
                    Text(
                      'Nyla',
                      style: TextStyle(
                        color: NylaColors.ink,
                        fontFamily: 'serif',
                        fontSize: 29,
                        height: 1.1,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.4,
                      ),
                    ),
                    SizedBox(width: 7),
                    NylaBloomMark(size: 23),
                  ],
                ),
              ],
            ),
          ),
          NylaPressable(
            onTap: onNotifications,
            semanticsLabel: 'Reminders',
            borderRadius: BorderRadius.circular(99),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: NylaColors.paper,
                shape: BoxShape.circle,
                border: Border.all(color: NylaColors.outline),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.notifications_none_rounded, color: NylaColors.mutedInk, size: 20),
            ),
          ),
        ],
      );
}

class _CycleCard extends ConsumerWidget {
  const _CycleCard({required this.today, required this.periods, required this.prediction});

  final LocalDay today;
  final AsyncValue<List<PeriodEntry>> periods;
  final AsyncValue<PredictionResult> prediction;

  @override
  Widget build(BuildContext context, WidgetRef ref) => periods.when(
        loading: () => const _LoadingCard(height: 154),
        error: (_, _) => const _SimpleMessage(
          icon: Icons.refresh_rounded,
          title: 'Your cycle is taking a moment',
          body: 'Try again shortly.',
        ),
        data: (history) {
          if (history.isEmpty) {
            return _FirstCycleCard(
              onStart: () async {
                await NylaHaptics.confirm();
                await ref.read(cycleRepositoryProvider).recordPeriod(start: today);
              },
            );
          }
          final lastStart = LocalDay(history.first.startDay);
          final cycleDay = math.max(1, lastStart.daysUntil(today) + 1);
          final estimate = prediction.value?.prediction;
          return _CycleCardBody(
            cycleDay: cycleDay,
            lastStart: lastStart,
            estimate: estimate,
          );
        },
      );
}

class _CycleCardBody extends StatelessWidget {
  const _CycleCardBody({required this.cycleDay, required this.lastStart, required this.estimate});

  final int cycleDay;
  final LocalDay lastStart;
  final CyclePrediction? estimate;

  @override
  Widget build(BuildContext context) {
    final cycleLength = estimate?.predictedCycleLength ?? math.max(28, cycleDay);
    final progress = (cycleDay / math.max(cycleLength, 1)).clamp(0.02, 1.0).toDouble();
    final phase = _phase(cycleDay, cycleLength);
    final range = estimate == null ? shortDay(lastStart) : rangeText(estimate!.earliestStart, estimate!.latestStart);

    return NylaPaperSurface(
      padding: const EdgeInsets.fromLTRB(17, 17, 16, 17),
      radius: BorderRadius.circular(22),
      child: Row(
        children: [
          _CycleRing(day: cycleDay, progress: progress),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cycle Day $cycleDay',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
                ),
                const SizedBox(height: 4),
                Text(
                  phase,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: NylaColors.violet,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  estimate == null ? 'Started $range' : 'Expected period $range',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11.8),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: NylaColors.faintInk, size: 20),
        ],
      ),
    );
  }

  String _phase(int day, int cycleLength) {
    if (day <= 5) return 'Menstrual phase';
    final ovulation = math.max(10, cycleLength - 14);
    if (day < ovulation - 1) return 'Follicular phase';
    if ((day - ovulation).abs() <= 1) return 'Ovulation window';
    return 'Luteal phase';
  }
}

class _CycleRing extends StatelessWidget {
  const _CycleRing({required this.day, required this.progress});

  final int day;
  final double progress;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: 78,
        child: CustomPaint(
          painter: _RingPainter(progress),
          child: Center(
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: NylaColors.night,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      );
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.39;
    final track = Paint()
      ..color = NylaColors.roseSoft
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    final active = Paint()
      ..shader = const SweepGradient(colors: [NylaColors.rose, NylaColors.violet, NylaColors.wine])
          .createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, track);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      active,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) => oldDelegate.progress != progress;
}

class _FirstCycleCard extends StatelessWidget {
  const _FirstCycleCard({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => NylaPaperSurface(
        padding: const EdgeInsets.all(18),
        radius: BorderRadius.circular(22),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const NylaIconToken(
              icon: Icons.water_drop_outlined,
              size: 48,
              background: NylaColors.roseWash,
              foreground: NylaColors.rose,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Start your cycle', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18)),
                  const SizedBox(height: 5),
                  Text(
                    'Tell Nyla when your period begins. Your view becomes more personal from there.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: onStart, child: const Text('My period started')),
                ],
              ),
            ),
          ],
        ),
      );
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.tip, required this.onTap});

  final HealthTip tip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => NylaPressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(17, 16, 13, 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFFCFB), Color(0xFFF7EAF4)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: NylaColors.outline),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Today’s Insight', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      tip.flash,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: NylaColors.ink,
                            fontSize: 12.6,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: NylaColors.lavenderSoft,
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.self_improvement_rounded, color: NylaColors.violet, size: 42),
              ),
            ],
          ),
        ),
      );
}

class _NextPeriodCard extends StatelessWidget {
  const _NextPeriodCard({required this.today, required this.prediction});

  final LocalDay today;
  final AsyncValue<PredictionResult> prediction;

  @override
  Widget build(BuildContext context) {
    final value = prediction.value?.prediction;
    final days = value == null ? null : today.daysUntil(value.likelyStart);
    final headline = days == null
        ? 'Still learning your rhythm'
        : days <= 0
            ? 'Around now'
            : 'In $days day${days == 1 ? '' : 's'}';
    final date = value == null ? 'Add a few cycles to see an estimate' : shortDay(value.likelyStart);

    return NylaPaperSurface(
      padding: const EdgeInsets.fromLTRB(17, 16, 14, 16),
      radius: BorderRadius.circular(20),
      shadow: false,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Next Period', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  headline,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 22),
                ),
                const SizedBox(height: 2),
                Text(date, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11.5)),
              ],
            ),
          ),
          const NylaIconToken(
            icon: Icons.calendar_month_outlined,
            size: 54,
            background: NylaColors.lavenderSoft,
            foreground: NylaColors.violet,
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onPeriod, required this.onSymptoms, required this.onNote});

  final VoidCallback onPeriod;
  final VoidCallback onSymptoms;
  final VoidCallback onNote;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: _Action(
              icon: Icons.water_drop_outlined,
              label: 'Log Period',
              tint: NylaColors.roseWash,
              onTap: onPeriod,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: _Action(
              icon: Icons.bolt_rounded,
              label: 'Log Symptoms',
              tint: NylaColors.lavenderSoft,
              onTap: onSymptoms,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: _Action(
              icon: Icons.notes_rounded,
              label: 'Add Note',
              tint: NylaColors.lavenderMist,
              onTap: onNote,
            ),
          ),
        ],
      );
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.tint, required this.onTap});

  final IconData icon;
  final String label;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => NylaPressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
          decoration: BoxDecoration(
            color: NylaColors.paper,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: NylaColors.outline),
          ),
          child: Column(
            children: [
              NylaIconToken(icon: icon, size: 38, background: tint),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: NylaColors.ink,
                      fontSize: 10.6,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      );
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) => NylaPaperSurface(
        child: SizedBox(height: height, child: const Center(child: CircularProgressIndicator())),
      );
}

class _SimpleMessage extends StatelessWidget {
  const _SimpleMessage({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => NylaInlineNote(icon: icon, title: title, body: body);
}
