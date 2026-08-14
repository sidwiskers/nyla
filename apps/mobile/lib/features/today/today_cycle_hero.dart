import 'package:cycle_engine/cycle_engine.dart';
import 'package:flutter/material.dart';
import 'package:health_content/health_content.dart';

import '../../core/theme/nyla_theme.dart';

class TodayCycleMomentHero extends StatelessWidget {
  const TodayCycleMomentHero({
    required this.phaseContext,
    required this.tip,
    required this.pattern,
    required this.estimate,
    required this.onExplore,
    super.key,
  });

  final CyclePhaseContext phaseContext;
  final HealthTip tip;
  final SymptomPattern? pattern;
  final CyclePrediction? estimate;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    final palette = context.nyla;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final motion = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 420);
    final identity = _phaseIdentity(phaseContext);
    final why = tip.details.isEmpty ? tip.flash : tip.details.first;
    final cycleLength = estimate?.predictedCycleLength;
    final progress = cycleLength == null || cycleLength <= 0
        ? null
        : (phaseContext.cycleDay / cycleLength).clamp(0.0, 1.0).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
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
                      : _lightGradient(phaseContext.phase),
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
                    blurRadius: 25,
                    offset: const Offset(0, 11),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(21, 20, 21, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            identity.eyebrow,
                            style: TextStyle(
                              color: dark ? const Color(0xFFDCCDE4) : palette.violet,
                              fontSize: 9.3,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _CycleDayPill(day: phaseContext.cycleDay, dark: dark),
                      ],
                    ),
                    const SizedBox(height: 15),
                    AnimatedSwitcher(
                      duration: motion,
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.025),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: Text(
                        identity.title,
                        key: ValueKey(phaseContext.phase),
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: dark ? Colors.white : palette.ink,
                              fontSize: 25,
                              height: 1.08,
                              letterSpacing: -0.32,
                            ),
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      tip.flash,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: dark ? const Color(0xFFF3EAF5) : palette.wine,
                            fontSize: 14.4,
                            height: 1.42,
                          ),
                    ),
                    if (progress != null && cycleLength != null) ...[
                      const SizedBox(height: 19),
                      _CycleProgress(
                        progress: progress,
                        day: phaseContext.cycleDay,
                        cycleLength: cycleLength,
                        dark: dark,
                        duration: motion,
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Text(
                            identity.evidence,
                            style: TextStyle(
                              color: dark ? const Color(0xFFCDBFD2) : palette.mutedInk,
                              fontSize: 10.4,
                              height: 1.3,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _ExploreAction(dark: dark),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (tip.experiences.isNotEmpty) ...[
          const SizedBox(height: 18),
          _SectionLabel('YOU MIGHT NOTICE'),
          const SizedBox(height: 9),
          _ExperienceChips(experiences: tip.experiences),
        ],
        const SizedBox(height: 18),
        _WhySection(text: why),
        if (phaseContext.mucusSupportsPeriOvulatory) ...[
          const SizedBox(height: 15),
          const _ObservationNote(
            icon: Icons.opacity_rounded,
            text:
                'Watery or stretchy discharge often appears as estrogen rises before ovulation. Your log fits that broader pattern.',
          ),
        ],
        if (pattern case final personal?) ...[
          const SizedBox(height: 12),
          _PersonalPatternNote(pattern: personal),
        ],
      ],
    );
  }
}

({String eyebrow, String title, String evidence}) _phaseIdentity(
  CyclePhaseContext context,
) =>
    switch (context.phase) {
      CyclePhase.menstruation => (
          eyebrow: 'MENSTRUATION · EARLY FOLLICULAR',
          title: 'Menstruation',
          evidence: context.periodIsObserved
              ? 'Based on your recorded bleeding.'
              : 'Based on your recorded period timing.',
        ),
      CyclePhase.follicular => (
          eyebrow: 'FOLLICULAR PHASE',
          title: 'Follicular phase',
          evidence: context.predictedCycleLength == null
              ? 'Based on your recorded period start.'
              : 'Placed from your period timing and recent cycle pattern.',
        ),
      CyclePhase.periOvulatory => (
          eyebrow: context.mucusSupportsPeriOvulatory
              ? 'PERI-OVULATORY · SUPPORTED'
              : 'PERI-OVULATORY · ESTIMATED',
          title: 'Around the ovulatory part of your cycle',
          evidence: context.mucusSupportsPeriOvulatory
              ? 'Estimated timing · today’s discharge adds supporting context.'
              : 'Estimated from your recent cycle pattern.',
        ),
      CyclePhase.luteal => (
          eyebrow: 'LUTEAL PHASE · ESTIMATED',
          title: 'Likely luteal phase',
          evidence: 'Estimated from your period timing and recent cycle pattern.',
        ),
      CyclePhase.uncertain => (
          eyebrow: 'CYCLE TIMING · LIMITED',
          title: 'Your cycle timing is less clear today',
          evidence: 'Recent timing is not strong enough for a useful phase label.',
        ),
    };

List<Color> _lightGradient(CyclePhase phase) => switch (phase) {
      CyclePhase.menstruation => const [
          Color(0xFFF4D4DF),
          Color(0xFFEADCF0),
          Color(0xFFF8E0D7),
        ],
      CyclePhase.follicular => const [
          Color(0xFFE8E1F4),
          Color(0xFFE4F0EA),
          Color(0xFFF5E9DD),
        ],
      CyclePhase.periOvulatory => const [
          Color(0xFFDDEBE9),
          Color(0xFFE5DDF2),
          Color(0xFFF6E4DD),
        ],
      CyclePhase.luteal => const [
          Color(0xFFF1DCE5),
          Color(0xFFE4DAEF),
          Color(0xFFF3E5D9),
        ],
      CyclePhase.uncertain => const [
          Color(0xFFEDE8F3),
          Color(0xFFF0E7EC),
          Color(0xFFF7ECE6),
        ],
    };

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 5),
        child: Text(
          text,
          style: TextStyle(
            color: context.nyla.violet,
            fontSize: 9.1,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.08,
          ),
        ),
      );
}

class _ExperienceChips extends StatelessWidget {
  const _ExperienceChips({required this.experiences});

  final List<String> experiences;

  @override
  Widget build(BuildContext context) {
    final palette = context.nyla;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        for (final experience in experiences.take(4))
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: dark ? palette.glass : palette.glassStrong,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: palette.glassBorder),
            ),
            child: Text(
              experience,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: palette.wine,
                    fontSize: 10.8,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
      ],
    );
  }
}

class _WhySection extends StatelessWidget {
  const _WhySection({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.nyla;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Container(
        padding: const EdgeInsets.only(left: 14),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: palette.rose.withValues(alpha: 0.72), width: 2.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'WHY THIS CAN HAPPEN',
              style: TextStyle(
                color: palette.violet,
                fontSize: 9.1,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.05,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: palette.ink,
                    fontSize: 13.2,
                    height: 1.5,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ObservationNote extends StatelessWidget {
  const _ObservationNote({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.nyla;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 31,
            height: 31,
            decoration: BoxDecoration(
              color: palette.sageSoft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: palette.expectedInk, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: palette.mutedInk,
                    fontSize: 11.6,
                    height: 1.42,
                  ),
            ),
          ),
        ],
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
    required this.duration,
  });

  final double progress;
  final int day;
  final int cycleLength;
  final bool dark;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final palette = context.nyla;
    final labelColor = dark ? const Color(0xFFD7CADB) : palette.mutedInk;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: duration,
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 7,
              backgroundColor: dark
                  ? Colors.white.withValues(alpha: 0.13)
                  : Colors.white.withValues(alpha: 0.72),
              valueColor: AlwaysStoppedAnimation<Color>(palette.rose),
            ),
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

class _ExploreAction extends StatelessWidget {
  const _ExploreAction({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    final color = dark ? Colors.white : context.nyla.violet;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Explore',
          style: TextStyle(
            color: color,
            fontSize: 11.3,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 5),
        Icon(Icons.arrow_forward_rounded, color: color, size: 16),
      ],
    );
  }
}

class _PersonalPatternNote extends StatelessWidget {
  const _PersonalPatternNote({required this.pattern});

  final SymptomPattern pattern;

  @override
  Widget build(BuildContext context) {
    final palette = context.nyla;
    final label = _symptomLabel(pattern.key);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: palette.roseWash,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.rose.withValues(alpha: 0.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome_rounded, color: palette.rose, size: 17),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Your pattern · $label appeared around this part of the cycle in '
              '${pattern.cyclesPresent} of ${pattern.cyclesObserved} '
              'well-observed cycles.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: palette.wine,
                    fontSize: 11.5,
                    height: 1.4,
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
      'energy.low' => 'Lower energy',
      'energy.high' => 'Higher energy',
      'sleep.poor' => 'Poorer sleep',
      'appetite.higher' => 'Higher appetite',
      'appetite.cravings' => 'Cravings',
      'discharge.estrogenic' => 'Watery or stretchy discharge',
      'discharge.dry' => 'Drier discharge',
      'digestion.constipation' => 'Constipation',
      'digestion.loose_stool' => 'Looser stools',
      'digestion.gassy' => 'Gas',
      'flow.heavy' => 'Heavy flow',
      'mood.sensitive' => 'Feeling more sensitive',
      'mood.low' => 'Lower mood',
      'mood.irritable' => 'Irritability',
      'mood.anxious' => 'Anxiety',
      'mood.overwhelmed' => 'Feeling overwhelmed',
      'mood.happy' => 'Feeling happier',
      'skin.breakout' => 'Breakouts',
      'skin.oily' => 'Oilier skin',
      'skin.dry' => 'Drier skin',
      'skin.sensitive' => 'Sensitive skin',
      _ => key.replaceAll('.', ' · ').replaceAll('_', ' '),
    };
