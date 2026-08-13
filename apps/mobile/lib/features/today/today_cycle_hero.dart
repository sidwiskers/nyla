import 'package:cycle_engine/cycle_engine.dart';
import 'package:flutter/material.dart';
import 'package:health_content/health_content.dart';

import '../../core/theme/nyla_theme.dart';

class TodayCycleMomentHero extends StatelessWidget {
  const TodayCycleMomentHero({
    required this.experience,
    required this.tip,
    required this.pattern,
    required this.estimate,
    required this.onExplore,
    super.key,
  });

  final CycleExperience experience;
  final HealthTip tip;
  final SymptomPattern? pattern;
  final CyclePrediction? estimate;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    final palette = context.nyla;
    final dark = Theme.of(context).brightness == Brightness.dark;
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
    final cycleLength = estimate?.predictedCycleLength;
    final progress = cycleLength == null || cycleLength <= 0
        ? null
        : (experience.cycleDay / cycleLength).clamp(0.0, 1.0).toDouble();

    final headlineColor = dark ? Colors.white : palette.ink;
    final bodyColor = dark ? const Color(0xFFF3EAF5) : palette.wine;
    final quietColor = dark ? const Color(0xFFCDBFD2) : palette.mutedInk;
    final eyebrowColor = dark ? const Color(0xFFDCCDE4) : palette.violet;
    final whyLabelColor = dark ? const Color(0xFFCDB9D6) : palette.violet;
    final whyTextColor = dark ? const Color(0xFFF1E8F3) : palette.ink;
    final actionColor = dark ? Colors.white : palette.violet;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onExplore,
        borderRadius: BorderRadius.circular(31),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dark
                  ? const [
                      NylaColors.night,
                      Color(0xFF3B2C4D),
                      Color(0xFF624A70),
                    ]
                  : const [
                      Color(0xFFF2D7E1),
                      Color(0xFFE4D9F0),
                      Color(0xFFF7E1D6),
                    ],
              stops: const [0, 0.56, 1],
            ),
            borderRadius: BorderRadius.circular(31),
            border: Border.all(
              color: dark
                  ? Colors.white.withValues(alpha: 0.055)
                  : Colors.white.withValues(alpha: 0.78),
            ),
            boxShadow: [
              BoxShadow(
                color: palette.shadow,
                blurRadius: 27,
                offset: const Offset(0, 12),
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
                      style: TextStyle(
                        color: eyebrowColor,
                        fontSize: 9.3,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.12,
                      ),
                    ),
                    const Spacer(),
                    _CycleDayPill(day: experience.cycleDay, dark: dark),
                  ],
                ),
                const SizedBox(height: 15),
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: headlineColor,
                        fontSize: 25,
                        height: 1.08,
                        letterSpacing: -0.32,
                      ),
                ),
                const SizedBox(height: 9),
                Text(
                  tip.flash,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: bodyColor,
                        fontSize: 14.8,
                        height: 1.43,
                      ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(15, 13, 15, 14),
                  decoration: BoxDecoration(
                    color: dark
                        ? Colors.white.withValues(alpha: 0.085)
                        : Colors.white.withValues(alpha: 0.48),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: dark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.white.withValues(alpha: 0.62),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'WHY',
                        style: TextStyle(
                          color: whyLabelColor,
                          fontSize: 8.9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.02,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        why,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: whyTextColor,
                              fontSize: 12.8,
                              height: 1.43,
                            ),
                      ),
                    ],
                  ),
                ),
                if (pattern case final personal?) ...[
                  const SizedBox(height: 10),
                  _PersonalPatternNote(pattern: personal, dark: dark),
                ],
                if (progress != null && cycleLength != null) ...[
                  const SizedBox(height: 17),
                  _CycleProgress(
                    progress: progress,
                    day: experience.cycleDay,
                    cycleLength: cycleLength,
                    dark: dark,
                  ),
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
                        style: TextStyle(
                          color: quietColor,
                          fontSize: 10.2,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Explore',
                          style: TextStyle(
                            color: actionColor,
                            fontSize: 11.3,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Icon(Icons.arrow_forward_rounded, color: actionColor, size: 16),
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

class _CycleDayPill extends StatelessWidget {
  const _CycleDayPill({required this.day, required this.dark});

  final int day;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final palette = context.nyla;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: dark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.74),
        ),
      ),
      child: Text(
        'Day $day',
        style: TextStyle(
          color: dark ? const Color(0xFFF5EBF7) : palette.wine,
          fontSize: 10.4,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CycleProgress extends StatelessWidget {
  const _CycleProgress({
    required this.progress,
    required this.day,
    required this.cycleLength,
    required this.dark,
  });

  final double progress;
  final int day;
  final int cycleLength;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final palette = context.nyla;
    final labelColor = dark ? const Color(0xFFD7CADB) : palette.mutedInk;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 7,
            backgroundColor: dark
                ? Colors.white.withValues(alpha: 0.13)
                : Colors.white.withValues(alpha: 0.72),
            valueColor: AlwaysStoppedAnimation<Color>(palette.rose),
          ),
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            Text(
              'Day $day',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: labelColor,
                    fontSize: 10.4,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const Spacer(),
            Text(
              '~$cycleLength day cycle',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: labelColor,
                    fontSize: 10.4,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PersonalPatternNote extends StatelessWidget {
  const _PersonalPatternNote({required this.pattern, required this.dark});

  final SymptomPattern pattern;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final palette = context.nyla;
    final label = _symptomLabel(pattern.key);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
      decoration: BoxDecoration(
        color: dark
            ? const Color(0xFFE8B8CB).withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: dark
              ? const Color(0xFFF2D4E0).withValues(alpha: 0.11)
              : palette.rose.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            color: dark ? const Color(0xFFF0C7D8) : palette.rose,
            size: 17,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Your logs · $label showed up around this point in '
              '${pattern.cyclesPresent} of ${pattern.cyclesObserved} '
              'well-observed cycles.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: dark ? const Color(0xFFF4E8EE) : palette.wine,
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
