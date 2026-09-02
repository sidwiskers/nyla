import 'dart:math' as math;

import 'package:cycle_engine/cycle_engine.dart';
import 'package:flutter/material.dart';

import '../../core/theme/nyla_theme.dart';
import '../../data/database/app_database.dart';

class TodayCompanionCard extends StatefulWidget {
  const TodayCompanionCard({
    required this.phaseContext,
    required this.values,
    super.key,
  });

  final CyclePhaseContext phaseContext;
  final List<DayValueEntry> values;

  @override
  State<TodayCompanionCard> createState() => _TodayCompanionCardState();
}

class _TodayCompanionCardState extends State<TodayCompanionCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flipController;
  late final Animation<double> _flip;
  bool _showingWhy = false;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 440),
      reverseDuration: const Duration(milliseconds: 390),
    );
    _flip = CurvedAnimation(
      parent: _flipController,
      curve: Curves.easeInOutCubic,
      reverseCurve: Curves.easeInOutCubic,
    );
  }

  @override
  void didUpdateWidget(covariant TodayCompanionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.phaseContext.phase != widget.phaseContext.phase ||
        oldWidget.phaseContext.confidence != widget.phaseContext.confidence ||
        oldWidget.phaseContext.cycleDay != widget.phaseContext.cycleDay ||
        !_sameValues(oldWidget.values, widget.values)) {
      _showingWhy = false;
      _flipController.value = 0;
    }
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _toggleFace() {
    if (_flipController.isAnimating) return;
    setState(() => _showingWhy = !_showingWhy);
    if (_showingWhy) {
      _flipController.forward();
    } else {
      _flipController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = companionMessageFor(widget.phaseContext, widget.values);
    final explanation =
        companionExplanationFor(widget.phaseContext, widget.values);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    if (reduceMotion) {
      return AnimatedSwitcher(
        duration: Duration.zero,
        child: _showingWhy
            ? _WhyFace(
                key: const ValueKey('why'),
                phaseContext: widget.phaseContext,
                explanation: explanation,
                onBack: _toggleFace,
              )
            : _CompanionFace(
                key: const ValueKey('companion'),
                phaseContext: widget.phaseContext,
                message: message,
                onWhy: _toggleFace,
              ),
      );
    }

    return AnimatedBuilder(
      animation: _flip,
      builder: (context, _) {
        final angle = math.pi * _flip.value;
        final showingBack = angle > math.pi / 2;
        final faceAngle = showingBack ? angle - math.pi : angle;

        return AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeInOutCubic,
          alignment: Alignment.topCenter,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0014)
              ..rotateY(faceAngle),
            child: showingBack
                ? _WhyFace(
                    key: const ValueKey('why'),
                    phaseContext: widget.phaseContext,
                    explanation: explanation,
                    onBack: _toggleFace,
                  )
                : _CompanionFace(
                    key: const ValueKey('companion'),
                    phaseContext: widget.phaseContext,
                    message: message,
                    onWhy: _toggleFace,
                  ),
          ),
        );
      },
    );
  }
}

class _CompanionFace extends StatelessWidget {
  const _CompanionFace({
    required this.phaseContext,
    required this.message,
    required this.onWhy,
    super.key,
  });

  final CyclePhaseContext phaseContext;
  final CompanionMessage message;
  final VoidCallback onWhy;

  @override
  Widget build(BuildContext context) {
    final palette = context.nyla;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return _CardShell(
      dark: dark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PhaseHeader(
            phaseContext: phaseContext,
            icon: message.icon,
            dark: dark,
          ),
          const SizedBox(height: 16),
          Text(
            message.title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: dark ? Colors.white : palette.ink,
                  fontSize: 25,
                  height: 1.08,
                  letterSpacing: -0.34,
                ),
          ),
          const SizedBox(height: 9),
          Text(
            message.body,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: dark ? const Color(0xFFF2E9F4) : palette.wine,
                  fontSize: 14.2,
                  height: 1.45,
                ),
          ),
          if (message.tip != null) ...[
            const SizedBox(height: 15),
            _TipBox(text: message.tip!, dark: dark),
          ],
          const SizedBox(height: 15),
          _FlipAction(
            label: 'Why might this be happening?',
            icon: Icons.autorenew_rounded,
            dark: dark,
            onTap: onWhy,
          ),
        ],
      ),
    );
  }
}

class _WhyFace extends StatelessWidget {
  const _WhyFace({
    required this.phaseContext,
    required this.explanation,
    required this.onBack,
    super.key,
  });

  final CyclePhaseContext phaseContext;
  final CompanionExplanation explanation;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final palette = context.nyla;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return _CardShell(
      dark: dark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PhaseHeader(
            phaseContext: phaseContext,
            icon: Icons.lightbulb_rounded,
            dark: dark,
          ),
          const SizedBox(height: 16),
          Text(
            explanation.title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: dark ? Colors.white : palette.ink,
                  fontSize: 23,
                  height: 1.1,
                  letterSpacing: -0.3,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            explanation.body,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: dark ? const Color(0xFFF2E9F4) : palette.wine,
                  fontSize: 13.8,
                  height: 1.48,
                ),
          ),
          const SizedBox(height: 13),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
            decoration: BoxDecoration(
              color: dark
                  ? Colors.white.withValues(alpha: 0.065)
                  : palette.glass,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: dark
                    ? Colors.white.withValues(alpha: 0.05)
                    : palette.glassBorder,
              ),
            ),
            child: Text(
              explanation.note,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: dark
                        ? const Color(0xFFE0D5E4)
                        : palette.mutedInk,
                    fontSize: 11.5,
                    height: 1.4,
                  ),
            ),
          ),
          const SizedBox(height: 15),
          _FlipAction(
            label: 'Back to today',
            icon: Icons.autorenew_rounded,
            dark: dark,
            onTap: onBack,
          ),
        ],
      ),
    );
  }
}

class _PhaseHeader extends StatelessWidget {
  const _PhaseHeader({
    required this.phaseContext,
    required this.icon,
    required this.dark,
  });

  final CyclePhaseContext phaseContext;
  final IconData icon;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final palette = context.nyla;
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: dark
                ? Colors.white.withValues(alpha: 0.09)
                : palette.glass,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            icon,
            size: 20,
            color: dark ? const Color(0xFFF0E5F2) : palette.violet,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            companionPhaseLabelFor(phaseContext),
            style: TextStyle(
              color: dark ? const Color(0xFFD9CADF) : palette.violet,
              fontSize: 9.4,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.02,
            ),
          ),
        ),
        _DayPill(text: 'Day ${phaseContext.cycleDay}', dark: dark),
      ],
    );
  }
}

class _TipBox extends StatelessWidget {
  const _TipBox({required this.text, required this.dark});

  final String text;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final palette = context.nyla;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
      decoration: BoxDecoration(
        color: dark ? Colors.white.withValues(alpha: 0.075) : palette.glass,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: dark
              ? Colors.white.withValues(alpha: 0.055)
              : palette.glassBorder,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.favorite_rounded,
            size: 16,
            color: dark ? const Color(0xFFF0C9D5) : palette.wine,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: dark
                        ? const Color(0xFFE6DCE9)
                        : palette.mutedInk,
                    fontSize: 11.8,
                    height: 1.38,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({required this.dark, required this.child});

  final bool dark;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.nyla;
    return Container(
      padding: const EdgeInsets.fromLTRB(21, 20, 21, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [
                  NylaColors.night,
                  Color(0xFF3A2947),
                  Color(0xFF5B455F),
                ]
              : [palette.roseWash, palette.lavenderSoft, palette.peachSoft],
        ),
        borderRadius: BorderRadius.circular(31),
        border: Border.all(
          color: dark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.76),
        ),
        boxShadow: [
          BoxShadow(
            color: palette.shadow,
            blurRadius: 25,
            offset: const Offset(0, 11),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _FlipAction extends StatelessWidget {
  const _FlipAction({
    required this.label,
    required this.icon,
    required this.dark,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.nyla;
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: dark
                          ? const Color(0xFFDCCDE4)
                          : palette.violet,
                      fontSize: 11.5,
                    ),
              ),
              const SizedBox(width: 6),
              Icon(
                icon,
                size: 15,
                color: dark ? const Color(0xFFDCCDE4) : palette.violet,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String companionPhaseLabelFor(CyclePhaseContext phase) => switch (phase.phase) {
      CyclePhase.menstruation => 'PERIOD',
      CyclePhase.follicular => phase.confidence == PhaseConfidence.limited
          ? 'LIKELY FOLLICULAR'
          : 'FOLLICULAR PHASE',
      CyclePhase.periOvulatory => 'AROUND MID-CYCLE',
      CyclePhase.luteal => 'LUTEAL PHASE',
      CyclePhase.uncertain => 'YOUR CYCLE',
    };

CompanionMessage companionMessageFor(
  CyclePhaseContext phase,
  List<DayValueEntry> values,
) {
  final byKey = {for (final value in values) value.key: value};
  final cramps = byKey['cramps']?.severity ?? 0;
  final sleep = byKey['sleep']?.value;
  final energy = byKey['energy']?.value;
  final mood = values
      .where((row) => row.key.startsWith('mood.'))
      .map((row) => row.value)
      .toSet();

  if (phase.phase == CyclePhase.menstruation) {
    if (cramps >= 3) {
      return const CompanionMessage(
        title: 'That sounds like a rough cramp day',
        body:
            'Take the day a little more gently where you can. You do not have to push through pain just because the rest of the day is busy.',
        tip:
            'Warmth, a comfortable position and gentle movement can help some people. If the pain is unusually severe, suddenly worse, or worrying, please get medical care.',
        icon: Icons.favorite_rounded,
      );
    }
    if (sleep == 'poor' || sleep == 'very_poor') {
      return const CompanionMessage(
        title: 'A softer day may feel better',
        body:
            'A period plus poor sleep can leave you running on less than usual. Keep the important things, and make the rest easier if you can.',
        tip:
            'A little extra rest, food, water and a quieter evening may be exactly what you need.',
        icon: Icons.bedtime_rounded,
      );
    }
    return const CompanionMessage(
      title: 'Take today gently',
      body:
          'Your period is here. Check in with comfort, energy and what your body is asking for instead of expecting a normal day by default.',
      tip: 'Eat, drink and rest as you normally need to. Comfort counts.',
      icon: Icons.favorite_rounded,
    );
  }

  if (phase.phase == CyclePhase.luteal &&
      mood.intersection(const {
        'sensitive',
        'low',
        'irritable',
        'anxious',
        'overwhelmed',
      }).isNotEmpty) {
    return const CompanionMessage(
      title: 'Give yourself a little more room today',
      body:
          'You logged a tougher mood today. A cycle shift may be one part of the picture, but the useful thing right now is simply to make the day a little easier on yourself.',
      tip: 'Keep the next thing small if everything feels louder than usual.',
      icon: Icons.self_improvement_rounded,
    );
  }

  return switch (phase.phase) {
    CyclePhase.follicular => CompanionMessage(
        title: energy == 'low' || energy == 'very_low'
            ? 'Still feeling low on energy?'
            : 'You may notice a little more energy',
        body: energy == 'low' || energy == 'very_low'
            ? 'This is often an early-cycle stretch after a period, but your energy does not have to bounce back on schedule. Take the slower day if that is what you have.'
            : 'The stretch after a period is often part of the follicular phase. Some people feel their energy or focus pick up here; for others the change is subtle.',
        tip: energy == 'low' || energy == 'very_low'
            ? 'A low-energy day is still useful information. Work with the energy you actually have.'
            : 'If you feel good, enjoy it. If you do not notice a change, that can be completely ordinary too.',
        icon: Icons.wb_sunny_rounded,
      ),
    CyclePhase.periOvulatory => const CompanionMessage(
        title: 'You may be around mid-cycle',
        body:
            'Around this part of a cycle, some people notice a change in energy or discharge as estrogen rises. Others barely notice anything at all.',
        tip:
            'Calendar timing can only place this broadly. A predicted phase is not confirmation of ovulation.',
        icon: Icons.auto_awesome_rounded,
      ),
    CyclePhase.luteal => CompanionMessage(
        title: phase.daysUntilLikelyPeriod != null &&
                phase.daysUntilLikelyPeriod! <= 4
            ? 'Your period may be getting closer'
            : 'A steadier pace may feel good',
        body: phase.daysUntilLikelyPeriod != null &&
                phase.daysUntilLikelyPeriod! <= 4
            ? 'In the days before a period, some people notice changes in sleep, appetite, energy or mood. If today feels a little different, make room for what your body needs.'
            : 'As the cycle moves through its later phase, sleep, appetite, energy or mood can shift for some people. Your own pattern matters more than any one expected feeling.',
        tip: null,
        icon: Icons.nightlight_round,
      ),
    CyclePhase.uncertain => const CompanionMessage(
        title: 'How is your body feeling today?',
        body:
            'Energy, sleep, mood, appetite and comfort can tell you more about today than the calendar alone. Notice what feels different, familiar, easy or difficult.',
        tip: 'A small check-in is enough. You do not need to analyse every change.',
        icon: Icons.spa_rounded,
      ),
    CyclePhase.menstruation => throw StateError('Handled above'),
  };
}

CompanionExplanation companionExplanationFor(
  CyclePhaseContext phase,
  List<DayValueEntry> values,
) {
  final byKey = {for (final value in values) value.key: value};
  final cramps = byKey['cramps']?.severity ?? 0;
  final sleep = byKey['sleep']?.value;
  final mood = values
      .where((row) => row.key.startsWith('mood.'))
      .map((row) => row.value)
      .toSet();

  if (phase.phase == CyclePhase.menstruation) {
    if (cramps >= 3) {
      return const CompanionExplanation(
        title: 'Your uterus is contracting',
        body:
            'During a period, the uterus contracts as it sheds its lining. Natural chemicals called prostaglandins help drive those contractions, and stronger contractions can mean stronger cramps.',
        note:
            'Cramps are common, but pain that is unusually severe, suddenly worse, or stopping normal activities deserves medical attention.',
      );
    }
    if (sleep == 'poor' || sleep == 'very_poor') {
      return const CompanionExplanation(
        title: 'Periods can affect sleep too',
        body:
            'Bleeding, cramps, temperature changes and hormonal shifts can all make sleep feel less settled for some people during a period.',
        note:
            'A bad night can have many causes, so cycle timing is useful context rather than a diagnosis.',
      );
    }
    return const CompanionExplanation(
      title: 'A new cycle has started',
      body:
          'A period begins after estrogen and progesterone fall and the uterine lining starts to shed. Cycle day 1 is the first day of menstrual bleeding.',
      note:
          'Flow, cramps, energy and mood can vary from one period to another even when the underlying cycle is ordinary.',
    );
  }

  if (phase.phase == CyclePhase.luteal &&
      mood.intersection(const {
        'sensitive',
        'low',
        'irritable',
        'anxious',
        'overwhelmed',
      }).isNotEmpty) {
    return const CompanionExplanation(
      title: 'Hormone shifts may be one part of it',
      body:
          'After ovulation, progesterone and estrogen change again as the body moves toward the next period. Some people notice mood changes around this time, while others notice very little.',
      note:
          'Mood is shaped by much more than the menstrual cycle, so a difficult day should never be dismissed as “just hormones.”',
    );
  }

  return switch (phase.phase) {
    CyclePhase.follicular => CompanionExplanation(
        title: phase.confidence == PhaseConfidence.limited
            ? 'This is likely the stretch after your period'
            : 'This is the stretch after your period',
        body:
            'During the follicular phase, ovarian follicles develop and estrogen generally rises as the body moves toward ovulation. The length of this phase can vary quite a bit from cycle to cycle.',
        note: phase.confidence == PhaseConfidence.limited
            ? 'With only a short cycle history, this is broad early-cycle context rather than a precise hormonal reading.'
            : 'Some people notice changes in energy or discharge here, but there is no single feeling that defines this phase.',
      ),
    CyclePhase.periOvulatory => const CompanionExplanation(
        title: 'Mid-cycle timing is only approximate',
        body:
            'Ovulation happens after the follicular phase, but its timing can move from cycle to cycle. Recent period timing can place a broad mid-cycle window, and watery or stretchy discharge can add context.',
        note:
            'Calendar dates and symptoms cannot confirm an exact ovulation day, so this should not be used as fertility or contraception guidance.',
      ),
    CyclePhase.luteal => CompanionExplanation(
        title: phase.daysUntilLikelyPeriod != null &&
                phase.daysUntilLikelyPeriod! <= 4
            ? 'Your cycle is moving toward the next period'
            : 'This is likely the later part of your cycle',
        body:
            'After ovulation, progesterone and estrogen shift again. Some people notice changes in energy, appetite, sleep, breast tenderness or mood as the next period approaches.',
        note:
            'These changes are personal. One cycle can feel quite different from the next.',
      ),
    CyclePhase.uncertain => const CompanionExplanation(
        title: 'Cycle timing can move around',
        body:
            'The follicular part of a cycle can vary in length, which means calendar day alone cannot always tell whether ovulation is still ahead, nearby, or has already passed.',
        note:
            'Cycle day is still useful context. Bleeding, discharge and your own repeated patterns can add more detail without pretending the timing is exact.',
      ),
    CyclePhase.menstruation => throw StateError('Handled above'),
  };
}

class CompanionMessage {
  const CompanionMessage({
    required this.title,
    required this.body,
    required this.tip,
    required this.icon,
  });

  final String title;
  final String body;
  final String? tip;
  final IconData icon;
}

class CompanionExplanation {
  const CompanionExplanation({
    required this.title,
    required this.body,
    required this.note,
  });

  final String title;
  final String body;
  final String note;
}

class _DayPill extends StatelessWidget {
  const _DayPill({required this.text, required this.dark});

  final String text;
  final bool dark;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: dark
              ? Colors.white.withValues(alpha: 0.09)
              : context.nyla.glass,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: dark ? Colors.white : context.nyla.wine,
                fontSize: 10.2,
              ),
        ),
      );
}

bool _sameValues(List<DayValueEntry> a, List<DayValueEntry> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var index = 0; index < a.length; index++) {
    final left = a[index];
    final right = b[index];
    if (left.day != right.day ||
        left.key != right.key ||
        left.value != right.value ||
        left.severity != right.severity) {
      return false;
    }
  }
  return true;
}
