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
    final explanation = companionExplanationFor(widget.phaseContext, widget.values);
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
          Row(
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
                  message.icon,
                  size: 20,
                  color: dark ? const Color(0xFFF0E5F2) : palette.violet,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  message.eyebrow,
                  style: TextStyle(
                    color: dark ? const Color(0xFFD9CADF) : palette.violet,
                    fontSize: 9.4,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.02,
                  ),
                ),
              ),
              _DayPill(
                text: phaseContext.phase == CyclePhase.menstruation
                    ? 'Period day ${phaseContext.cycleDay}'
                    : 'Day ${phaseContext.cycleDay}',
                dark: dark,
              ),
            ],
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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
              decoration: BoxDecoration(
                color: dark
                    ? Colors.white.withValues(alpha: 0.075)
                    : palette.glass,
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
                      message.tip!,
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
            ),
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
          Row(
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
                  Icons.lightbulb_rounded,
                  size: 19,
                  color: dark ? const Color(0xFFF0E5F2) : palette.violet,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  'A LITTLE CONTEXT',
                  style: TextStyle(
                    color: dark ? const Color(0xFFD9CADF) : palette.violet,
                    fontSize: 9.4,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.02,
                  ),
                ),
              ),
              _DayPill(
                text: phaseContext.phase == CyclePhase.menstruation
                    ? 'Period day ${phaseContext.cycleDay}'
                    : 'Day ${phaseContext.cycleDay}',
                dark: dark,
              ),
            ],
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
              ? const [NylaColors.night, Color(0xFF3A2947), Color(0xFF5B455F)]
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

CompanionMessage companionMessageFor(
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
      return const CompanionMessage(
        eyebrow: 'NYLA IS WITH YOU',
        title: 'That sounds like a rough cramp day',
        body:
            'You do not have to treat today like a normal day. Slow down where you can and give your body a little room.',
        tip:
            'Warmth, a comfortable position, water and gentle movement can help some people. If the pain is unusually severe or worrying, please get medical care.',
        icon: Icons.favorite_rounded,
      );
    }
    if (sleep == 'poor' || sleep == 'very_poor') {
      return const CompanionMessage(
        eyebrow: 'A GENTLER DAY',
        title: 'Period day and poor sleep is a lot',
        body:
            'Lower the bar a little today. Being tired does not mean you are doing anything wrong.',
        tip: 'A quieter evening and a little extra rest may feel better than pushing through.',
        icon: Icons.bedtime_rounded,
      );
    }
    return const CompanionMessage(
      eyebrow: 'YOUR PERIOD',
      title: 'Be a little softer with yourself today',
      body:
          'Your period is here. Nyla will keep track of the numbers — you can focus on how you actually feel.',
      tip: 'Check in with your body, eat and drink normally, and rest when you need it.',
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
      eyebrow: 'A LITTLE CHECK-IN',
      title: 'Feeling more sensitive lately?',
      body:
          'That feeling is worth noticing, not judging. Your cycle may be part of the picture, but you are more than a phase label.',
      tip: 'Give yourself a little more space today if that is what you need.',
      icon: Icons.self_improvement_rounded,
    );
  }

  return switch (phase.phase) {
    CyclePhase.follicular => const CompanionMessage(
        eyebrow: 'TODAY',
        title: 'See how your energy feels today',
        body:
            'This part of the cycle can feel lighter for some people. No need to match a textbook — just notice your own rhythm.',
        tip: null,
        icon: Icons.wb_sunny_rounded,
      ),
    CyclePhase.periOvulatory => const CompanionMessage(
        eyebrow: 'AROUND MID-CYCLE',
        title: 'Your body may be around the middle of its cycle',
        body:
            'Nyla has an estimate, not a verdict. Your own signs and how you feel matter more than a perfect label.',
        tip: null,
        icon: Icons.auto_awesome_rounded,
      ),
    CyclePhase.luteal => CompanionMessage(
        eyebrow: 'CHECKING IN',
        title: phase.daysUntilLikelyPeriod != null &&
                phase.daysUntilLikelyPeriod! <= 4
            ? 'Your period may be getting close'
            : 'How are you feeling today?',
        body: phase.daysUntilLikelyPeriod != null &&
                phase.daysUntilLikelyPeriod! <= 4
            ? 'If you feel a little more tired, hungry or emotional, you are allowed to meet yourself where you are.'
            : 'You do not need a scientific explanation for every feeling. Nyla can keep the context in the background.',
        tip: null,
        icon: Icons.nightlight_round,
      ),
    CyclePhase.uncertain => const CompanionMessage(
        eyebrow: 'NO PRESSURE',
        title: 'Today does not need a phase label',
        body:
            'Your timing is a little unclear right now, and that is okay. Keep logging what feels useful and Nyla will learn with you.',
        tip: null,
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
        title: 'Your uterus is doing some hard work',
        body:
            'During a period, the uterus contracts as it sheds its lining. Natural chemicals called prostaglandins help trigger those contractions, and stronger contractions can mean stronger cramps.',
        note:
            'Cramps are common, but pain that is unusually severe, suddenly worse, or stopping you from normal activities deserves medical attention.',
      );
    }
    if (sleep == 'poor' || sleep == 'very_poor') {
      return const CompanionExplanation(
        title: 'Your period can nudge sleep around too',
        body:
            'Bleeding, cramps, temperature changes and shifting hormones can all make sleep feel less settled for some people during a period.',
        note:
            'That does not mean every bad night is caused by your cycle. Nyla treats it as useful context, not a diagnosis.',
      );
    }
    return const CompanionExplanation(
      title: 'Your cycle has reached its reset point',
      body:
          'A period begins after estrogen and progesterone fall and the uterine lining starts to shed. That is the biology Nyla tracks underneath the softer day-to-day view.',
      note:
          'Your experience can still vary from one period to another, even when the underlying cycle is completely ordinary.',
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
      title: 'Hormone shifts may be part of the picture',
      body:
          'After ovulation, progesterone and estrogen change again as the body moves toward the next period. Some people notice mood changes around this time, while others notice very little.',
      note:
          'Nyla never assumes a feeling is “just hormones.” Your mood has context beyond your cycle too.',
    );
  }

  return switch (phase.phase) {
    CyclePhase.follicular => const CompanionExplanation(
        title: 'This is the stretch after your period',
        body:
            'Estrogen often begins rising again after menstruation while the body prepares for the next ovulatory part of the cycle. Some people notice more energy here, but there is no feeling you are supposed to have.',
        note:
            'Nyla uses your timing as context, not as a rule for how your body or mood should behave.',
      ),
    CyclePhase.periOvulatory => const CompanionExplanation(
        title: 'Nyla thinks you may be around mid-cycle',
        body:
            'The estimate comes from your recent period timing and cycle pattern. Ovulation itself cannot be confirmed from calendar dates alone, so Nyla deliberately keeps this language uncertain.',
        note:
            'Body signs can add context, but an app prediction is still an estimate rather than proof of ovulation.',
      ),
    CyclePhase.luteal => CompanionExplanation(
        title: phase.daysUntilLikelyPeriod != null &&
                phase.daysUntilLikelyPeriod! <= 4
            ? 'Your cycle may be moving toward the next period'
            : 'This is likely the later part of your cycle',
        body:
            'After the ovulatory part of a cycle, progesterone and estrogen shift again. Energy, appetite, sleep or mood can change for some people as the next period approaches.',
        note:
            'These changes are personal. Nyla uses them as gentle context rather than treating them as symptoms you should have.',
      ),
    CyclePhase.uncertain => const CompanionExplanation(
        title: 'There simply is not enough signal today',
        body:
            'Cycle lengths naturally move around, and recent timing may not support a useful phase estimate. Nyla would rather say “not sure” than turn a weak guess into a confident label.',
        note:
            'More completed cycles and useful logs can make future context more personal without forcing certainty.',
      ),
    CyclePhase.menstruation => throw StateError('Handled above'),
  };
}

class CompanionMessage {
  const CompanionMessage({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.tip,
    required this.icon,
  });

  final String eyebrow;
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
