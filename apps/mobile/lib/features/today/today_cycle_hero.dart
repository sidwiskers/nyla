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
                    Expanded(
                      child: Text(
                        identity.eyebrow,
                        style: TextStyle(
                          color: eyebrowColor,
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
                        begin: const Offset(0, 0.035),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: Text(
                    identity.title,
                    key: ValueKey(phaseContext.phase),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: headlineColor,
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
                        color: bodyColor,
                        fontSize: 14.8,
                        height: 1.43,
                      ),
                ),
                if (tip.experiences.isNotEmpty) ...[
                  const SizedBox(height: 15),
                  Text(
                    'YOU MIGHT NOTICE',
                    style: TextStyle(
                      color: eyebrowColor,
                      fontSize: 8.9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.02,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _ExperienceChips(
                    experiences: tip.experiences,
                    dark: dark,
                  ),
                ],
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
                if (phaseContext.mucusSupportsPeriOvulatory) ...[
                  const SizedBox(height: 10),
                  _EvidenceNote(
                    dark: dark,
                    icon: Icons.opacity_rounded,
                    text:
                        'Your watery or stretchy discharge log supports this broad context. It still cannot establish an exact ovulation day.',
                  ),
                ],
                if (pattern case final personal?) ...[
                  const SizedBox(height: 10),
                  _PersonalPatternNote(pattern: personal, dark: dark),
                ],
                if (progress != null && cycleLength != null) ...[
                  const SizedBox(height: 17),
                  _CycleProgress(
                    progress: progress,
                    day: phaseContext.cycleDay,
                    cycleLength: cycleLength,
                    dark: dark,
                    duration: motion,
                  ),
                ],
                const SizedBox(height: 13),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        identity.evidence,
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

({String eyebrow, String title, String evidence}) _phaseIdentity(
  CyclePhaseContext context,
) =>
    switch (context.phase) {
      CyclePhase.menstruation => (
          eyebrow: 'MENSTRUATION · EARLY FOLLICULAR',
          title: 'Menstruation',
          evidence: context.periodIsObserved
              ? 'Grounded in your recorded bleeding.'
              : 'Supported by your recorded period timing.',
        ),
      CyclePhase.follicular => (
          eyebrow: 'FOLLICULAR PHASE',
          title: 'Follicular phase',
          evidence: context.predictedCycleLength == null
              ? 'Grounded in your recorded period start.'
              : 'Placed from your period start and recent cycle history.',
        ),
      CyclePhase.periOvulatory => (
          eyebrow: context.mucusSupportsPeriOvulatory
              ? 'PERI-OVULATORY · SUPPORTED'
              : 'PERI-OVULATORY · ESTIMATED',
          title: 'Around the ovulatory part of your cycle',
          evidence: context.mucusSupportsPeriOvulatory
              ? 'Broad timing estimate, supported by today’s discharge log.'
              : 'Broad timing estimate from your recent cycle history.',
        ),
      CyclePhase.luteal => (
          eyebrow: 'LUTEAL PHASE · ESTIMATED',
          title: 'Likely luteal phase',
          evidence: 'Estimated from your period timing and recent cycle history.',
        ),
      CyclePhase.uncertain => (
          eyebrow: 'CYCLE CONTEXT · LIMITED',
          title: 'Your phase is not clear enough to name',
          evidence: 'Nyla is keeping uncertainty visible instead of forcing a label.',
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

class _ExperienceChips extends StatelessWidget {
  const _ExperienceChips({required this.experiences, required this.dark});

  final List<String> experiences;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final palette = context.nyla;
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        for (final experience in experiences.take(4))
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: dark
                  ? Colors.white.withValues(alpha: 0.09)
                  : Colors.white.withValues(alpha: 0.52),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(
                color: dark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.68),
              ),
            ),
            child: Text(
              experience,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: dark ? const Color(0xFFF3EAF5) : palette.wine,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
      ],
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

class _EvidenceNote extends StatelessWidget {
  const _EvidenceNote({required this.dark, required this.icon, required this.text});

  final bool dark;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.nyla;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
      decoration: BoxDecoration(
        color: dark
            ? const Color(0xFFC9E4DC).withValues(alpha: 0.09)
            : Colors.white.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: dark
              ? const Color(0xFFD5EFE8).withValues(alpha: 0.1)
              : palette.sage.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: dark ? const Color(0xFFCDE9E0) : palette.expectedInk, size: 17),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: dark ? const Color(0xFFE8F4F0) : palette.wine,
                    fontSize: 11.2,
                    height: 1.38,
                  ),
            ),
          ),
        ],
      ),
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
              'Your logs · $label showed up around this part of the cycle in '
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
