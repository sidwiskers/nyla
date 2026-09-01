import 'package:cycle_engine/cycle_engine.dart';
import 'package:flutter/material.dart';

import '../../core/theme/nyla_theme.dart';
import '../../data/database/app_database.dart';

class TodayCompanionCard extends StatelessWidget {
  const TodayCompanionCard({
    required this.phaseContext,
    required this.values,
    required this.onExplore,
    super.key,
  });

  final CyclePhaseContext phaseContext;
  final List<DayValueEntry> values;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    final palette = context.nyla;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final message = companionMessageFor(phaseContext, values);

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
          InkWell(
            onTap: onExplore,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Why might this be happening?',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: dark
                              ? const Color(0xFFDCCDE4)
                              : palette.violet,
                          fontSize: 11.5,
                        ),
                  ),
                  const SizedBox(width: 5),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 15,
                    color: dark ? const Color(0xFFDCCDE4) : palette.violet,
                  ),
                ],
              ),
            ),
          ),
        ],
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
