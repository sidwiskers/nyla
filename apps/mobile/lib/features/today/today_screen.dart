import 'package:cycle_engine/cycle_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:health_content/health_content.dart';

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
          _CycleCard(today: today, periods: periods, prediction: prediction),
          const SizedBox(height: 14),
          _TodayLogCard(today: today, values: dayValues),
          const SizedBox(height: 14),
          _TipPreview(
            tip: _recommendedTip(dayValues.value ?? const <DayValueEntry>[]),
            onTap: () => context.go('/learn'),
          ),
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

class _CycleCard extends ConsumerWidget {
  const _CycleCard({required this.today, required this.periods, required this.prediction});

  final LocalDay today;
  final AsyncValue<List<PeriodEntry>> periods;
  final AsyncValue<PredictionResult> prediction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: periods.when(
          loading: () => const SizedBox(height: 150, child: Center(child: CircularProgressIndicator())),
          error: (_, _) => const _GentleError(),
          data: (history) {
            if (history.isEmpty) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _MiniLabel('YOUR CYCLE'),
                  const SizedBox(height: 10),
                  Text('Start with today', style: Theme.of(context).textTheme.displaySmall),
                  const SizedBox(height: 8),
                  const Text('When your period begins, tell Nyla. Predictions grow from your own history.'),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: () => ref.read(cycleRepositoryProvider).recordPeriod(start: today),
                    icon: const Icon(Icons.water_drop_rounded, size: 18),
                    label: const Text('My period started'),
                  ),
                ],
              );
            }

            final lastStart = LocalDay(history.first.startDay);
            final cycleDay = lastStart.daysUntil(today) + 1;
            return prediction.when(
              loading: () => const SizedBox(height: 150, child: Center(child: CircularProgressIndicator())),
              error: (_, _) => const _GentleError(),
              data: (result) {
                final estimate = result.prediction;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _CycleHalo(day: cycleDay > 0 ? cycleDay : null, estimate: estimate),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _MiniLabel('YOUR CYCLE'),
                          const SizedBox(height: 8),
                          Text(
                            _headline(today, cycleDay, estimate),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 7),
                          Text(
                            estimate == null
                                ? 'One more completed cycle will give Nyla a first estimate.'
                                : 'Expected ${rangeText(estimate.earliestStart, estimate.latestStart)} · ${_confidence(estimate.confidence)} confidence',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 14),
                          TextButton(
                            onPressed: () => context.go('/calendar'),
                            style: TextButton.styleFrom(padding: EdgeInsets.zero),
                            child: const Text('See calendar'),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
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

  String _confidence(PredictionConfidence confidence) => switch (confidence) {
        PredictionConfidence.high => 'High',
        PredictionConfidence.medium => 'Medium',
        PredictionConfidence.low => 'Low',
        PredictionConfidence.insufficient => 'Early',
      };
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
      dimension: 104,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 8,
            strokeCap: StrokeCap.round,
            backgroundColor: NylaColors.roseSoft.withValues(alpha: 0.45),
            color: NylaColors.rose,
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(day?.toString() ?? '—', style: Theme.of(context).textTheme.headlineMedium),
                Text('day', style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
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
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: () => context.go('/log?day=${today.toIsoString()}'),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: NylaColors.peach, borderRadius: BorderRadius.circular(17)),
                child: const Icon(Icons.add_rounded),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(count == 0 ? 'How are you today?' : '$count things logged today',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 3),
                    Text('A few taps is enough.', style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
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
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(21),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: NylaColors.sage, borderRadius: BorderRadius.circular(20)),
                    child: const Text('A tiny useful thing', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_rounded, size: 19),
                ],
              ),
              const SizedBox(height: 16),
              Text(tip.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(tip.flash, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniLabel extends StatelessWidget {
  const _MiniLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          color: NylaColors.mutedInk,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
        ),
      );
}

class _GentleError extends StatelessWidget {
  const _GentleError();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Text('This part of your history could not be loaded.'),
      );
}
