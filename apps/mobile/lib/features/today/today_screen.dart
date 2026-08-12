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
          _CycleHero(today: today, periods: periods, prediction: prediction),
          const SizedBox(height: 17),
          _TodayLogCard(today: today, values: dayValues),
          const SizedBox(height: 17),
          _TipPreview(
            tip: _recommendedTip(dayValues.value ?? const <DayValueEntry>[]),
            onTap: () {
              NylaHaptics.select();
              context.go('/learn');
            },
          ),
          const SizedBox(height: 82),
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

class _CycleHero extends ConsumerWidget {
  const _CycleHero({required this.today, required this.periods, required this.prediction});

  final LocalDay today;
  final AsyncValue<List<PeriodEntry>> periods;
  final AsyncValue<PredictionResult> prediction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      constraints: const BoxConstraints(minHeight: 238),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4D2638), NylaColors.rose, NylaColors.coral],
          stops: [0, 0.62, 1],
        ),
        borderRadius: BorderRadius.circular(34),
        boxShadow: const [
          BoxShadow(color: Color(0x33542B3C), blurRadius: 34, offset: Offset(0, 16)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(34),
        child: Stack(
          children: [
            const Positioned(
              right: -48,
              top: -42,
              child: _GlowOrb(size: 158, color: Color(0x28FFFFFF)),
            ),
            const Positioned(
              left: -34,
              bottom: -60,
              child: _GlowOrb(size: 128, color: Color(0x18FFFFFF)),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: periods.when(
                loading: () => const SizedBox(height: 190, child: Center(child: CircularProgressIndicator(color: Colors.white))),
                error: (_, _) => const _GentleError(dark: true),
                data: (history) {
                  if (history.isEmpty) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _MiniLabel('YOUR CYCLE', dark: true),
                        const SizedBox(height: 14),
                        Text(
                          'Start with today.',
                          style: Theme.of(context).textTheme.displaySmall?.copyWith(color: Colors.white),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'When your period begins, tell Nyla. Your own history becomes the pattern—not a generic 28-day assumption.',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: const Color(0xFFFBEFF3)),
                        ),
                        const SizedBox(height: 22),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: NylaColors.wine,
                          ),
                          onPressed: () async {
                            await NylaHaptics.confirm();
                            await ref.read(cycleRepositoryProvider).recordPeriod(start: today);
                          },
                          icon: const Icon(Icons.water_drop_rounded, size: 18),
                          label: const Text('My period started'),
                        ),
                      ],
                    );
                  }

                  final lastStart = LocalDay(history.first.startDay);
                  final cycleDay = lastStart.daysUntil(today) + 1;
                  return prediction.when(
                    loading: () => const SizedBox(height: 190, child: Center(child: CircularProgressIndicator(color: Colors.white))),
                    error: (_, _) => const _GentleError(dark: true),
                    data: (result) {
                      final estimate = result.prediction;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const _MiniLabel('YOUR CYCLE', dark: true),
                              const Spacer(),
                              if (estimate != null) _ConfidencePill(confidence: estimate.confidence),
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
                                      _headline(today, cycleDay, estimate),
                                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                            color: Colors.white,
                                            fontSize: 28,
                                          ),
                                    ),
                                    const SizedBox(height: 9),
                                    Text(
                                      estimate == null
                                          ? 'One more completed cycle will give Nyla a first estimate.'
                                          : 'Expected ${rangeText(estimate.earliestStart, estimate.latestStart)}',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: const Color(0xFFF7E7ED),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              _CycleHalo(day: cycleDay > 0 ? cycleDay : null, estimate: estimate),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: () {
                              NylaHaptics.select();
                              context.go('/calendar');
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.zero,
                            ),
                            icon: const Icon(Icons.arrow_forward_rounded, size: 17),
                            label: const Text('Open your calendar'),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
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

class _CycleHalo extends StatelessWidget {
  const _CycleHalo({required this.day, required this.estimate});

  final int? day;
  final CyclePrediction? estimate;

  @override
  Widget build(BuildContext context) {
    final cycleLength = estimate?.predictedCycleLength ?? 28;
    final progress = day == null ? 0.08 : (day! / cycleLength).clamp(0.04, 1.0).toDouble();
    return SizedBox.square(
      dimension: 92,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 7,
            strokeCap: StrokeCap.round,
            backgroundColor: Colors.white.withValues(alpha: 0.17),
            color: Colors.white,
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  day?.toString() ?? '—',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontSize: 25,
                      ),
                ),
                const Text('DAY', style: TextStyle(color: Color(0xFFDCC9D1), fontSize: 9, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfidencePill extends StatelessWidget {
  const _ConfidencePill({required this.confidence});

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
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.6),
      ),
    );
  }
}

class _TodayLogCard extends StatelessWidget {
  const _TodayLogCard({required this.today, required this.values});

  final LocalDay today;
  final AsyncValue<List<DayValueEntry>> values;

  @override
  Widget build(BuildContext context) {
    final count = values.value?.length ?? 0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(29),
        onTap: () {
          NylaHaptics.select();
          context.go('/log?day=${today.toIsoString()}');
        },
        child: Ink(
          padding: const EdgeInsets.fromLTRB(20, 19, 18, 19),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [NylaColors.peachSoft, NylaColors.lavenderSoft]),
            borderRadius: BorderRadius.circular(29),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: NylaColors.wine,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      count == 0 ? 'How are you today?' : '$count things logged today',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      count == 0 ? 'A quick check-in, only if useful.' : 'Tap to add or change anything.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 35,
                height: 35,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const Icon(Icons.arrow_forward_rounded, size: 18, color: NylaColors.wine),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TipPreview extends StatelessWidget {
  const _TipPreview({required this.tip, required this.onTap});

  final HealthTip tip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: NylaColors.sage,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.52),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Text(
                      'TODAY’S CARD',
                      style: TextStyle(color: NylaColors.wine, fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 0.7),
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.style_rounded, color: NylaColors.wine),
                ],
              ),
              const SizedBox(height: 19),
              Text(tip.title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 25)),
              const SizedBox(height: 9),
              Text(
                tip.flash,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: NylaColors.wine),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('Open the deck', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: NylaColors.wine)),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward_rounded, size: 17, color: NylaColors.wine),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniLabel extends StatelessWidget {
  const _MiniLabel(this.text, {this.dark = false});

  final String text;
  final bool dark;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          color: dark ? const Color(0xFFEBDCE2) : NylaColors.mutedInk,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      );
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

class _GentleError extends StatelessWidget {
  const _GentleError({this.dark = false});

  final bool dark;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Text(
          'This part of your history could not be loaded.',
          style: TextStyle(color: dark ? Colors.white : NylaColors.ink),
        ),
      );
}
