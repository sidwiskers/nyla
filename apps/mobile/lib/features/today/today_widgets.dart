import 'package:cycle_engine/cycle_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:health_content/health_content.dart';

import '../../core/haptics/nyla_haptics.dart';
import '../../core/model/date_text.dart';
import '../../core/model/log_catalog.dart';
import '../../core/theme/nyla_theme.dart';
import '../../data/database/app_database.dart';
import '../../providers.dart';
import '../log/quick_log_sheet.dart';

class TodayCycleMomentHero extends StatelessWidget {
  const TodayCycleMomentHero({
    required this.experience,
    required this.tip,
    required this.pattern,
    required this.onExplore,
    super.key,
  });

  final CycleExperience experience;
  final HealthTip tip;
  final SymptomPattern? pattern;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    final title = switch (experience.window) {
      CycleExperienceWindow.periodStart => 'Your period has just started',
      CycleExperienceWindow.earlyCycle => 'The early days are still shifting',
      CycleExperienceWindow.middleCycle => 'Around the middle of your cycle',
      CycleExperienceWindow.approachingPeriod => 'Your next period may be getting closer',
    };
    final eyebrow = switch (experience.window) {
      CycleExperienceWindow.periodStart => 'FIRST DAYS',
      CycleExperienceWindow.earlyCycle => 'EARLY CYCLE',
      CycleExperienceWindow.middleCycle => 'AROUND THIS POINT',
      CycleExperienceWindow.approachingPeriod => 'PERIOD APPROACHING',
    };
    final why = tip.details.isEmpty ? tip.flash : tip.details.first;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onExplore,
        borderRadius: BorderRadius.circular(31),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [NylaColors.night, Color(0xFF392A50), Color(0xFF674E76)],
              stops: [0, 0.58, 1],
            ),
            borderRadius: BorderRadius.circular(31),
            boxShadow: [
              BoxShadow(
                color: context.nyla.shadow,
                blurRadius: 28,
                offset: const Offset(0, 13),
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
                        fontSize: 9.3,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.12,
                      ),
                    ),
                    const Spacer(),
                    _DarkPill(text: 'Day ${experience.cycleDay}'),
                  ],
                ),
                const SizedBox(height: 15),
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontSize: 25,
                        height: 1.08,
                        letterSpacing: -0.32,
                      ),
                ),
                const SizedBox(height: 9),
                Text(
                  tip.flash,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: const Color(0xFFF3EAF5),
                        fontSize: 14.8,
                        height: 1.43,
                      ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(15, 13, 15, 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.085),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'WHY',
                        style: TextStyle(
                          color: Color(0xFFCDB9D6),
                          fontSize: 8.9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.02,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        why,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFFF1E8F3),
                              fontSize: 12.8,
                              height: 1.43,
                            ),
                      ),
                    ],
                  ),
                ),
                if (pattern case final personal?) ...[
                  const SizedBox(height: 10),
                  _PersonalPatternNote(pattern: personal),
                ],
                const SizedBox(height: 13),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        experience.usesPrediction
                            ? 'Estimated from your recent cycle history.'
                            : 'Timed from your recorded period start.',
                        style: const TextStyle(
                          color: Color(0xFFCDBFD2),
                          fontSize: 10.2,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Explore',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11.3,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(width: 5),
                        Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
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

class TodayQuietCycleCard extends StatelessWidget {
  const TodayQuietCycleCard({
    required this.today,
    required this.periods,
    required this.prediction,
    required this.onStartPeriod,
    super.key,
  });

  final LocalDay today;
  final AsyncValue<List<PeriodEntry>> periods;
  final AsyncValue<PredictionResult> prediction;
  final Future<void> Function() onStartPeriod;

  @override
  Widget build(BuildContext context) {
    final palette = context.nyla;
    return periods.when(
      loading: () => Container(
        height: 128,
        decoration: BoxDecoration(
          color: palette.glass,
          borderRadius: BorderRadius.circular(27),
          border: Border.all(color: palette.glassBorder),
        ),
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      ),
      error: (_, _) => const _QuietMessage(
        icon: Icons.favorite_border_rounded,
        title: 'Your day is still yours',
        body: 'Nyla couldn’t read your cycle context just now.',
      ),
      data: (history) {
        if (history.isEmpty) {
          return _FirstCycleCard(onStartPeriod: onStartPeriod);
        }
        final day = cycleDayFor(today, history);
        if (day == null) {
          return const _QuietMessage(
            icon: Icons.favorite_border_rounded,
            title: 'Your rhythm is taking shape',
            body: 'Nyla will bring cycle context forward when it becomes useful.',
          );
        }
        final estimate = prediction.value?.prediction;
        final cycleLength = estimate?.predictedCycleLength ?? 28;
        final progress = (day / cycleLength).clamp(0.04, 1.0).toDouble();
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
                  const _SoftEyebrow('YOUR RHYTHM'),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: palette.glass,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      'Day $day',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: palette.wine,
                            fontSize: 10.5,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'A quieter point in your cycle',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 19),
              ),
              const SizedBox(height: 5),
              Text(
                'Nyla will bring something forward when your timing or your own patterns make it worth mentioning.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.42),
              ),
              const SizedBox(height: 13),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  backgroundColor: palette.glassStrong,
                  valueColor: AlwaysStoppedAnimation<Color>(palette.rose),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

int? cycleDayFor(LocalDay today, List<PeriodEntry>? history) {
  if (history == null || history.isEmpty) return null;
  final day = LocalDay(history.first.startDay).daysUntil(today) + 1;
  return day > 0 ? day : null;
}

class TodayQuickCheckIn extends ConsumerWidget {
  const TodayQuickCheckIn({required this.today, required this.values, super.key});

  final LocalDay today;
  final List<DayValueEntry> values;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.nyla;
    final shortcuts = <({LogDefinition definition, Color tint})>[
      (definition: flowDefinition, tint: palette.roseSoft),
      (definition: _builtIn('cramps'), tint: palette.peachSoft),
      (definition: _builtIn('mood'), tint: palette.lavenderSoft),
      (definition: _builtIn('energy'), tint: palette.sageSoft),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(17, 16, 17, 16),
      decoration: BoxDecoration(
        color: palette.glassStrong,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: palette.glassBorder),
        boxShadow: [
          BoxShadow(
            color: palette.shadow,
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How are you today?',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18.5),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      values.isEmpty
                          ? 'A few taps is enough.'
                          : 'Your log is already taking shape.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  NylaHaptics.select();
                  context.go('/log?day=${today.toIsoString()}');
                },
                child: const Text('More'),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              for (var index = 0; index < shortcuts.length; index++) ...[
                if (index > 0) const SizedBox(width: 7),
                Expanded(
                  child: _LogShortcut(
                    definition: shortcuts[index].definition,
                    tint: shortcuts[index].tint,
                    summary: _shortcutSummary(shortcuts[index].definition, values),
                    onTap: () => showQuickLogEditor(
                      context: context,
                      ref: ref,
                      day: today,
                      definition: shortcuts[index].definition,
                      values: values,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class TodayUpcomingCard extends StatelessWidget {
  const TodayUpcomingCard({required this.today, required this.prediction, super.key});

  final LocalDay today;
  final AsyncValue<PredictionResult> prediction;

  @override
  Widget build(BuildContext context) {
    final palette = context.nyla;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          NylaHaptics.select();
          context.go('/calendar');
        },
        borderRadius: BorderRadius.circular(25),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(17, 15, 14, 15),
          decoration: BoxDecoration(
            color: palette.glass,
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: palette.glassBorder),
          ),
          child: prediction.when(
            loading: () => const _UpcomingRow(
              icon: Icons.calendar_month_rounded,
              eyebrow: 'UPCOMING',
              title: 'Checking your recent rhythm…',
              subtitle: 'Your calendar stays available while Nyla catches up.',
              trailing: null,
            ),
            error: (_, _) => const _UpcomingRow(
              icon: Icons.calendar_month_rounded,
              eyebrow: 'UPCOMING',
              title: 'Your calendar',
              subtitle: 'Open dates and period history.',
              trailing: null,
            ),
            data: (result) {
              final estimate = result.prediction;
              if (estimate == null) {
                return const _UpcomingRow(
                  icon: Icons.calendar_month_rounded,
                  eyebrow: 'UPCOMING',
                  title: 'Learning your rhythm',
                  subtitle: 'Period estimates appear after enough completed cycles.',
                  trailing: null,
                );
              }
              return _UpcomingRow(
                icon: Icons.water_drop_outlined,
                eyebrow: 'NEXT PERIOD',
                title: _relativeStart(today, estimate.likelyStart),
                subtitle: 'Expected ${rangeText(estimate.earliestStart, estimate.latestStart)}',
                trailing: shortDay(estimate.likelyStart),
              );
            },
          ),
        ),
      ),
    );
  }
}

class TodayWorthKnowingCard extends StatelessWidget {
  const TodayWorthKnowingCard({required this.tip, required this.onTap, super.key});

  final HealthTip tip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.nyla;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(25),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.fromLTRB(17, 16, 15, 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [palette.sageSoft, palette.lavenderSoft],
            ),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: palette.glassBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 39,
                height: 39,
                decoration: BoxDecoration(
                  color: palette.glass,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.lightbulb_outline_rounded, color: palette.violet, size: 19),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SoftEyebrow('WORTH KNOWING'),
                    const SizedBox(height: 5),
                    Text(
                      tip.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14.8),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tip.flash,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: palette.mutedInk,
                            fontSize: 11.7,
                            height: 1.4,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(top: 9),
                child: Icon(Icons.arrow_forward_rounded, color: palette.violet, size: 17),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DarkPill extends StatelessWidget {
  const _DarkPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFFF5EBF7),
            fontSize: 10.4,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

class _FirstCycleCard extends StatelessWidget {
  const _FirstCycleCard({required this.onStartPeriod});

  final Future<void> Function() onStartPeriod;

  @override
  Widget build(BuildContext context) {
    final palette = context.nyla;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 19, 20, 19),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.lavenderSoft, palette.roseWash, palette.peachSoft],
        ),
        borderRadius: BorderRadius.circular(29),
        border: Border.all(color: palette.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SoftEyebrow('START HERE'),
          const SizedBox(height: 12),
          Text(
            'Your cycle begins with one date',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 24),
          ),
          const SizedBox(height: 6),
          Text(
            'When your period starts, mark that first day. Nyla can build your rhythm from there.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.44),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onStartPeriod,
              icon: const Icon(Icons.water_drop_rounded, size: 17),
              label: const Text('My period started'),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuietMessage extends StatelessWidget {
  const _QuietMessage({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final palette = context.nyla;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.glass,
        borderRadius: BorderRadius.circular(27),
        border: Border.all(color: palette.glassBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: palette.lavenderSoft,
              borderRadius: BorderRadius.circular(15),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: palette.violet, size: 20),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 3),
                Text(body, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LogShortcut extends StatelessWidget {
  const _LogShortcut({
    required this.definition,
    required this.tint,
    required this.summary,
    required this.onTap,
  });

  final LogDefinition definition;
  final Color tint;
  final String? summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.nyla;
    final selected = summary != null;
    return Semantics(
      button: true,
      label: selected
          ? '${definition.label}, $summary. Edit today’s log.'
          : '${definition.label}. Add to today’s log.',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(19),
          child: Ink(
            height: 94,
            padding: const EdgeInsets.fromLTRB(6, 10, 6, 8),
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(19),
              border: Border.all(
                color: selected ? palette.outlineStrong : palette.glassBorder,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 35,
                      height: 35,
                      decoration: BoxDecoration(
                        color: palette.glass,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(definition.icon, color: palette.wine, size: 17),
                    ),
                    if (selected)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          width: 13,
                          height: 13,
                          decoration: BoxDecoration(
                            color: palette.violet,
                            shape: BoxShape.circle,
                            border: Border.all(color: tint, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  definition.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: palette.ink,
                        fontSize: 10.6,
                      ),
                ),
                const SizedBox(height: 1),
                Text(
                  summary ?? 'Add',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: selected ? palette.wine : palette.mutedInk,
                        fontSize: 9.2,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

LogDefinition _builtIn(String key) {
  for (final definition in builtInLogs) {
    if (definition.key == key) return definition;
  }
  throw StateError('Missing built-in log definition: $key');
}

String? _shortcutSummary(LogDefinition definition, List<DayValueEntry> values) {
  if (definition.kind == LogKind.multiChoice) {
    final selected = definition.choices
        .where(
          (choice) => values.any((value) => value.key == '${definition.key}.${choice.id}'),
        )
        .map((choice) => choice.label)
        .toList(growable: false);
    if (selected.isEmpty) return null;
    if (selected.length == 1) return selected.first;
    return '${selected.first} +${selected.length - 1}';
  }

  DayValueEntry? current;
  for (final value in values) {
    if (value.key == definition.key) {
      current = value;
      break;
    }
  }
  if (current == null) return null;
  if (definition.kind == LogKind.choice) return definition.choiceLabel(current.value);
  final severity = current.severity;
  if (severity == null || severity < 0 || severity >= severityChoices.length) {
    return current.value;
  }
  return severityChoices[severity].label;
}

class _UpcomingRow extends StatelessWidget {
  const _UpcomingRow({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final String subtitle;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.nyla;
    return Row(
      children: [
        Container(
          width: 43,
          height: 43,
          decoration: BoxDecoration(
            color: palette.roseWash,
            borderRadius: BorderRadius.circular(15),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: palette.rose, size: 20),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: TextStyle(
                  color: palette.violet,
                  fontSize: 8.8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.92,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14.7),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11.2),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 9),
          Text(
            trailing!,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: palette.wine,
                  fontSize: 11.3,
                ),
          ),
        ],
        const SizedBox(width: 4),
        Icon(Icons.chevron_right_rounded, color: palette.faintInk, size: 20),
      ],
    );
  }
}

String _relativeStart(LocalDay today, LocalDay likelyStart) {
  final days = today.daysUntil(likelyStart);
  if (days > 1) return 'In $days days';
  if (days == 1) return 'Tomorrow';
  if (days >= -1) return 'Around now';
  return 'A little later than expected';
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
        border: Border.all(color: const Color(0xFFF2D4E0).withValues(alpha: 0.11)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome_rounded, color: Color(0xFFF0C7D8), size: 17),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Your logs · $label showed up around this point in '
              '${pattern.cyclesPresent} of ${pattern.cyclesObserved} '
              'well-observed cycles.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFF4E8EE),
                    fontSize: 11.4,
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

class _SoftEyebrow extends StatelessWidget {
  const _SoftEyebrow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          color: context.nyla.violet,
          fontSize: 9.2,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.96,
        ),
      );
}
