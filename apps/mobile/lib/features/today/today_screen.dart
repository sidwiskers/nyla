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
import 'today_cycle_hero.dart';
import 'today_widgets.dart' hide TodayCycleMomentHero;

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = LocalDay.fromDateTime(DateTime.now());
    final periods = ref.watch(periodHistoryProvider);
    final prediction = ref.watch(cyclePredictionProvider);
    final dayValues = ref.watch(dayValuesProvider(today.epochDay));
    final experience = ref.watch(cycleExperienceProvider(today.epochDay));
    final patterns = ref.watch(symptomPatternsProvider);
    final cycleDay = cycleDayFor(today, periods.value);
    final current = experience.value;
    final values = dayValues.value ?? const <DayValueEntry>[];
    final estimate = prediction.value?.prediction;
    final hasHistory = periods.value?.isNotEmpty ?? false;
    final hasPersonalEstimate = estimate != null;

    return NylaPage(
      title: _greeting(),
      subtitle: cycleDay == null
          ? friendlyDay(today)
          : '${friendlyDay(today)} · Cycle day $cycleDay',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (current case final moment?)
            TodayCycleMomentHero(
              experience: moment,
              tip: _experienceTip(moment.window),
              pattern: _matchingPattern(
                moment,
                patterns.value ?? const <SymptomPattern>[],
              ),
              estimate: estimate,
              onExplore: () {
                NylaHaptics.select();
                context.go('/learn');
              },
            )
          else if (hasHistory && !hasPersonalEstimate)
            _UnestimatedRhythmCard(cycleDay: cycleDay)
          else
            TodayQuietCycleCard(
              today: today,
              periods: periods,
              prediction: prediction,
              onStartPeriod: () async {
                await NylaHaptics.confirm();
                await ref.read(cycleRepositoryProvider).recordPeriod(start: today);
              },
            ),
          const SizedBox(height: 13),
          TodayQuickCheckIn(today: today, values: values),
          const SizedBox(height: 13),
          TodayUpcomingCard(today: today, prediction: prediction),
          const SizedBox(height: 13),
          TodayWorthKnowingCard(
            tip: _recommendedTip(values),
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
        .where(
          (tip) =>
              tip.category != TipCategory.seekCare &&
              tip.id != 'tampon-metals-2026' &&
              !tip.id.startsWith('cycle-now-'),
        )
        .toList(growable: false);
    final index = DateTime.now()
            .difference(DateTime.utc(2026, 1, 1))
            .inDays
            .abs() %
        safeGeneral.length;
    return safeGeneral[index];
  }

  HealthTip _experienceTip(CycleExperienceWindow window) => switch (window) {
        CycleExperienceWindow.periodStart => _tip('cycle-now-period-start'),
        CycleExperienceWindow.earlyCycle => _tip('cycle-now-early'),
        CycleExperienceWindow.middleCycle => _tip('cycle-now-middle'),
        CycleExperienceWindow.approachingPeriod => _tip('cycle-now-before-period'),
      };

  SymptomPattern? _matchingPattern(
    CycleExperience experience,
    List<SymptomPattern> patterns,
  ) {
    final target = switch (experience.window) {
      CycleExperienceWindow.periodStart => CycleWindow.periodStart,
      CycleExperienceWindow.approachingPeriod => CycleWindow.beforePeriod,
      CycleExperienceWindow.earlyCycle || CycleExperienceWindow.middleCycle => null,
    };
    if (target == null) return null;
    for (final pattern in patterns) {
      if (pattern.window == target) return pattern;
    }
    return null;
  }

  HealthTip _tip(String id) => healthTips.firstWhere((tip) => tip.id == id);
}

class _UnestimatedRhythmCard extends StatelessWidget {
  const _UnestimatedRhythmCard({required this.cycleDay});

  final int? cycleDay;

  @override
  Widget build(BuildContext context) {
    final palette = context.nyla;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 17, 18, 17),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.lavenderSoft, palette.roseWash],
        ),
        borderRadius: BorderRadius.circular(27),
        border: Border.all(color: palette.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'YOUR RHYTHM',
                style: TextStyle(
                  color: palette.violet,
                  fontSize: 9.2,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.96,
                ),
              ),
              if (cycleDay != null) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: palette.glass,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    'Day $cycleDay',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: palette.wine,
                          fontSize: 10.5,
                        ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Your rhythm is still taking shape',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 19),
          ),
          const SizedBox(height: 5),
          Text(
            'Nyla will bring timing and personal patterns forward once your own history supports them.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.42),
          ),
        ],
      ),
    );
  }
}
