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
    final experience = ref.watch(cycleExperienceProvider(today.epochDay));
    final patterns = ref.watch(symptomPatternsProvider);

    return NylaPage(
      title: _greeting(),
      subtitle: friendlyDay(today),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CycleDashboard(today: today, periods: periods, prediction: prediction),
          const SizedBox(height: 16),
          _QuickRow(today: today, values: dayValues),
          if (experience.value case final current?) ...[
            const SizedBox(height: 16),
            _CycleCompanionCard(
              experience: current,
              tip: _experienceTip(current.window),
              pattern: _matchingPattern(
                current,
                patterns.value ?? const <SymptomPattern>[],
              ),
              onTap: () {
                NylaHaptics.select();
                context.go('/learn');
              },
            ),
          ],
          const SizedBox(height: 16),
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
        CycleExperienceWindow.approachingPeriod =>
          _tip('cycle-now-before-period'),
      };

  SymptomPattern? _matchingPattern(
    CycleExperience experience,
    List<SymptomPattern> patterns,
  ) {
    final target = switch (experience.window) {
      CycleExperienceWindow.periodStart => CycleWindow.periodStart,
      CycleExperienceWindow.approachingPeriod => CycleWindow.beforePeriod,
      CycleExperienceWindow.earlyCycle || CycleExperienceWindow.middleCycle =>
        null,
    };
    if (target == null) return null;
    for (final pattern in patterns) {
      if (pattern.window == target) return pattern;
    }
    return null;
  }

  HealthTip _tip(String id) => healthTips.firstWhere((tip) => tip.id == id);
}

class _CycleDashboard extends ConsumerWidget {
  const _CycleDashboard({
    required this.today,
    required this.periods,
    required this.prediction,
  });

  final LocalDay today;
  final AsyncValue<List<PeriodEntry>> periods;
  final AsyncValue<PredictionResult> prediction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.fromLTRB(21, 20, 21, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF0E9F8),
            Color(0xFFFBECEF),
            Color(0xFFFFF8F4),
          ],
          stops: [0, 0.58, 1],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x102B2231),
            blurRadius: 20,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: periods.when(
        loading: () => const SizedBox(
          height: 250,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => const SizedBox(
          height: 250,
          child: Center(child: Text('Couldn’t load your cycle.')),
        ),
        data: (history) {
          if (history.isEmpty) return _FirstCycle(today: today, ref: ref);
          final lastStart = LocalDay(history.first.startDay);
          final cycleDay = lastStart.daysUntil(today) + 1;
          return prediction.when(
            loading: () => const SizedBox(
              height: 250,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) =>
                _CycleBody(today: today, day: cycleDay, estimate: null),
            data: (result) => _CycleBody(
              today: today,
              day: cycleDay,
              estimate: result.prediction,
            ),
          );
        },
      ),
    );
  }
}

class _FirstCycle extends StatelessWidget {
  const _FirstCycle({required this.today, required this.ref});

  final LocalDay today;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SoftEyebrow('YOUR CYCLE'),
          const SizedBox(height: 20),
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.water_drop_rounded,
              color: NylaColors.rose,
              size: 23,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Start your cycle history',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 7),
          Text(
            'Mark the first day of your period.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () async {
                await NylaHaptics.confirm();
                await ref
                    .read(cycleRepositoryProvider)
                    .recordPeriod(start: today);
              },
              icon: const Icon(Icons.water_drop_rounded, size: 17),
              label: const Text('My period started'),
            ),
          ),
        ],
      );
}

class _CycleBody extends StatelessWidget {
  const _CycleBody({
    required this.today,
    required this.day,
    required this.estimate,
  });

  final LocalDay today;
  final int day;
  final CyclePrediction? estimate;

  @override
  Widget build(BuildContext context) {
    final headline = _headline(today, day, estimate);
    final cycleLength = estimate?.predictedCycleLength ?? 28;
    final progress = day <= 0
        ? 0.04
        : (day / cycleLength).clamp(0.04, 1.0).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const _SoftEyebrow('YOUR CYCLE'),
            const Spacer(),
            if (estimate != null)
              _ConfidenceBadge(confidence: estimate!.confidence),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    headline,
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontSize: 25),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    estimate == null
                        ? 'Add more cycle history for an estimate.'
                        : 'Expected ${rangeText(estimate!.earliestStart, estimate!.latestStart)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            _CycleDayBadge(day: day > 0 ? day : null),
          ],
        ),
        const SizedBox(height: 21),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 9,
            backgroundColor: Colors.white.withValues(alpha: 0.82),
            valueColor: const AlwaysStoppedAnimation<Color>(NylaColors.rose),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              day > 0 ? 'Day $day' : 'Building history',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontSize: 11.5),
            ),
            const Spacer(),
            Text(
              estimate == null ? 'More history needed' : '~$cycleLength day cycle',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontSize: 11.5),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.calendar_month_rounded,
                color: NylaColors.violet,
                size: 18,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  estimate == null
                      ? 'Predictions start after enough completed cycles.'
                      : 'Expected dates can shift as your cycles change.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
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
    if (until > 1) return 'Period may start in $until days';
    if (until == 1) return 'Period may start tomorrow';
    if (until >= -1) return 'Your period may start around now';
    return cycleDay > 0 ? 'Cycle day $cycleDay' : 'Cycle in progress';
  }
}

class _CycleDayBadge extends StatelessWidget {
  const _CycleDayBadge({required this.day});

  final int? day;

  @override
  Widget build(BuildContext context) => Container(
        width: 82,
        height: 82,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.82),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              day?.toString() ?? '—',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: NylaColors.wine,
                    fontSize: 25,
                  ),
            ),
            const Text(
              'DAY',
              style: TextStyle(
                color: NylaColors.violet,
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.7,
              ),
            ),
          ],
        ),
      );
}

class _ConfidenceBadge extends StatelessWidget {
  const _ConfidenceBadge({required this.confidence});

  final PredictionConfidence confidence;

  @override
  Widget build(BuildContext context) {
    final label = switch (confidence) {
      PredictionConfidence.high => 'High confidence',
      PredictionConfidence.medium => 'Medium confidence',
      PredictionConfidence.low => 'Low confidence',
      PredictionConfidence.insufficient => 'Early estimate',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: NylaColors.violet,
              fontSize: 10.5,
            ),
      ),
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
        const SizedBox(width: 10),
        Expanded(
          flex: 5,
          child: _QuickAction(
            tint: NylaColors.lavenderSoft,
            icon: Icons.calendar_month_rounded,
            title: 'Calendar',
            subtitle: 'Dates & history',
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
  const _QuickAction({
    required this.tint,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Color tint;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.fromLTRB(16, 16, 14, 15),
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.76),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: NylaColors.violet, size: 20),
                ),
                const SizedBox(height: 15),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontSize: 11.5),
                ),
              ],
            ),
          ),
        ),
      );
}

class _CycleCompanionCard extends StatelessWidget {
  const _CycleCompanionCard({
    required this.experience,
    required this.tip,
    required this.pattern,
    required this.onTap,
  });

  final CycleExperience experience;
  final HealthTip tip;
  final SymptomPattern? pattern;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = switch (experience.window) {
      CycleExperienceWindow.periodStart => 'Your period has just started',
      CycleExperienceWindow.earlyCycle => 'The early days are still shifting',
      CycleExperienceWindow.middleCycle => 'Around the middle of your cycle',
      CycleExperienceWindow.approachingPeriod =>
        'Your next period may be getting closer',
    };
    final eyebrow = switch (experience.window) {
      CycleExperienceWindow.periodStart => 'FIRST DAYS',
      CycleExperienceWindow.earlyCycle => 'EARLY CYCLE',
      CycleExperienceWindow.middleCycle => 'AROUND THIS POINT',
      CycleExperienceWindow.approachingPeriod => 'PERIOD APPROACHING',
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                NylaColors.night,
                Color(0xFF392A50),
                Color(0xFF614A73),
              ],
              stops: [0, 0.58, 1],
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: const [
              BoxShadow(
                color: Color(0x242A1D34),
                blurRadius: 28,
                offset: Offset(0, 13),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(21, 20, 21, 19),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      eyebrow,
                      style: const TextStyle(
                        color: Color(0xFFDCCDE4),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.15,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Text(
                        'Day ${experience.cycleDay}',
                        style: const TextStyle(
                          color: Color(0xFFF5EBF7),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontSize: 24,
                        height: 1.1,
                      ),
                ),
                const SizedBox(height: 9),
                Text(
                  tip.flash,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: const Color(0xFFF2E9F4),
                        height: 1.42,
                      ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(15, 13, 15, 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.085),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'WHY',
                        style: TextStyle(
                          color: Color(0xFFCDB9D6),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.05,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        tip.details.first,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFFF1E8F3),
                              height: 1.42,
                            ),
                      ),
                    ],
                  ),
                ),
                if (pattern case final personal?) ...[
                  const SizedBox(height: 11),
                  _PersonalPatternNote(pattern: personal),
                ],
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        experience.usesPrediction
                            ? 'Timing is estimated from your cycle history.'
                            : 'Timed from your recorded period start.',
                        style: const TextStyle(
                          color: Color(0xFFCDBFD2),
                          fontSize: 10.5,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Explore',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PersonalPatternNote extends StatelessWidget {
  const _PersonalPatternNote({required this.pattern});

  final SymptomPattern pattern;

  @override
  Widget build(BuildContext context) {
    final label = _symptomLabel(pattern.key);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
      decoration: BoxDecoration(
        color: const Color(0xFFE8B8CB).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFF2D4E0).withValues(alpha: 0.11),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            color: Color(0xFFF0C7D8),
            size: 17,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Your logs · $label showed up around this point in '
              '${pattern.cyclesPresent} of ${pattern.cyclesObserved} '
              'well-observed cycles.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFF4E8EE),
                    fontSize: 11.5,
                    height: 1.38,
                  ),
            ),
          ),
        ],
      ),
    );
  }
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

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.tip, required this.onTap});

  final HealthTip tip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.fromLTRB(20, 19, 20, 19),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [NylaColors.sageSoft, NylaColors.lavenderSoft],
              ),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Colors.white),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const _SoftEyebrow('TODAY’S CARD'),
                    const Spacer(),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.style_rounded,
                        color: NylaColors.violet,
                        size: 17,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Text(
                  tip.title,
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontSize: 23),
                ),
                const SizedBox(height: 8),
                Text(
                  tip.flash,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: NylaColors.wine),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Text(
                      'Open card',
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(color: NylaColors.violet),
                    ),
                    const SizedBox(width: 5),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: NylaColors.violet,
                      size: 17,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}

class _SoftEyebrow extends StatelessWidget {
  const _SoftEyebrow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          color: NylaColors.violet,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
        ),
      );
}
