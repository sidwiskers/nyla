import 'dart:async';

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
import '../companion/cycle_pet.dart';
import '../companion/cycle_pet_state.dart';
import 'today_companion_card.dart';
import 'today_quiet_cycle_card.dart';
import 'today_widgets.dart' hide TodayQuietCycleCard;

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = LocalDay.fromDateTime(DateTime.now());
    final periods = ref.watch(periodHistoryProvider);
    final prediction = ref.watch(cyclePredictionProvider);
    final dayValues = ref.watch(dayValuesProvider(today.epochDay));
    final phase = ref.watch(cyclePhaseContextProvider(today.epochDay));
    final petMemory = ref.watch(cyclePetMemoryProvider).value;
    final cycleDay = cycleDayFor(today, periods.value);
    final current = phase.value;
    final values = dayValues.value ?? const <DayValueEntry>[];
    final estimate = prediction.value?.prediction;
    final hasHistory = periods.value?.isNotEmpty ?? false;
    final hasPersonalEstimate = estimate != null;
    final petDisposition = cyclePetDisposition(
      CyclePetSignals.fromToday(
        phaseContext: current,
        values: values,
        familiarity: petMemory?.familiarity ?? 0,
        recentlyPetted:
            petMemory?.wasPettedRecently(today.epochDay) ?? false,
      ),
    );

    final cycleCard = current != null
        ? TodayCompanionCard(
            key: ValueKey('companion-${current.phase.name}-${values.length}'),
            phaseContext: current,
            values: values,
          )
        : hasHistory && !hasPersonalEstimate
            ? _UnestimatedRhythmCard(
                key: const ValueKey('unestimated'),
                cycleDay: cycleDay,
              )
            : TodayQuietCycleCard(
                key: const ValueKey('quiet-cycle'),
                today: today,
                periods: periods,
                prediction: prediction,
                onStartPeriod: () async {
                  await NylaHaptics.confirm();
                  await ref.read(cycleRepositoryProvider).recordPeriod(start: today);
                },
              );

    return NylaPage(
      title: _greeting(current, values),
      subtitle: _subtitle(today, current),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Transform.translate(
            // Move the complete cat + card composition together. The cat keeps
            // the exact same physical relationship to its ledge; we simply use
            // a little of the spare header air so Today feels better balanced.
            offset: const Offset(0, -6),
            child: CyclePetLedge(
              key: const ValueKey('cycle-pet-ledge'),
              disposition: petDisposition,
              onPetted: () {
                unawaited(
                  ref
                      .read(cyclePetMemoryRepositoryProvider)
                      .recordPet(today.epochDay),
                );
              },
              child: cycleCard,
            ),
          ),
          const SizedBox(height: 12),
          TodayQuickCheckIn(today: today, values: values),
          const SizedBox(height: 13),
          TodayUpcomingCard(today: today, prediction: prediction),
          const SizedBox(height: 13),
          TodayWorthKnowingCard(
            tip: _recommendedTip(values, current),
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

  String _greeting(CyclePhaseContext? phase, List<DayValueEntry> values) {
    final cramps = values
        .where((row) => row.key == 'cramps')
        .map((row) => row.severity ?? 0)
        .fold<int>(0, (a, b) => a > b ? a : b);
    if (phase?.phase == CyclePhase.menstruation && cramps >= 3) {
      return 'I’m here with you';
    }
    if (phase?.phase == CyclePhase.menstruation) return 'Take today gently';

    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _subtitle(LocalDay today, CyclePhaseContext? phase) {
    if (phase?.phase == CyclePhase.menstruation) {
      return '${friendlyDay(today)} · Period day ${phase!.cycleDay}';
    }
    return friendlyDay(today);
  }

  HealthTip _recommendedTip(
    List<DayValueEntry> values,
    CyclePhaseContext? phase,
  ) {
    final byKey = {for (final value in values) value.key: value};
    final cramps = byKey['cramps'];
    final headache = byKey['headache'];
    final dizziness = byKey['dizziness'];
    final backPain = byKey['back_pain'];
    final flow = byKey['flow'];

    if ((cramps?.severity ?? 0) >= 3) return _tip('pain-disrupting-life');

    if (flow?.value == 'heavy' && (dizziness?.severity ?? 0) > 0) {
      return _tip('heavy-flow-and-iron');
    }
    if (flow?.value == 'heavy') return _tip('heavy-bleeding-signs');

    if ((headache?.severity ?? 0) > 0 &&
        (phase?.phase == CyclePhase.menstruation ||
            (phase?.daysUntilLikelyPeriod ?? 99) <= 2)) {
      return _tip('menstrual-migraine-pattern');
    }

    if ((backPain?.severity ?? 0) > 0 &&
        phase?.phase == CyclePhase.menstruation) {
      return _tip('everyday-cramps-can-travel');
    }

    if ((cramps?.severity ?? 0) > 0) return _tip('cycle-body-prostaglandins');

    final discharge = byKey['discharge'];
    if (discharge != null &&
        (discharge.value == 'watery' || discharge.value == 'stretchy')) {
      return _tip('cycle-body-mucus');
    }

    final appetite = byKey['appetite'];
    if (appetite != null &&
        (appetite.value == 'higher' || appetite.value == 'cravings')) {
      return _tip('cycle-body-appetite');
    }

    final breast = byKey['breast_tenderness'];
    if ((breast?.severity ?? 0) > 0) return _tip('cycle-body-breast');

    final digestion = byKey['digestion'];
    if (digestion != null && digestion.value != 'usual') {
      return _tip('cycle-body-digestion');
    }

    final sleep = byKey['sleep'];
    if (sleep != null && (sleep.value == 'poor' || sleep.value == 'very_poor')) {
      return _tip('cycle-body-sleep');
    }

    if (values.any((row) => row.key == 'skin.breakout')) {
      return _tip('cycle-body-skin');
    }

    if (phase?.phase == CyclePhase.luteal &&
        values.any(
          (row) => row.key.startsWith('mood.') &&
              const {'sensitive', 'low', 'irritable', 'anxious', 'overwhelmed'}
                  .contains(row.value),
        )) {
      return _tip('cycle-body-mood-is-personal');
    }

    if (phase?.phase == CyclePhase.menstruation && phase?.cycleDay == 1) {
      return _tip('everyday-cycle-day-one');
    }

    if (discharge != null && discharge.value != 'none') {
      return _tip('normal-discharge');
    }
    if (flow != null && flow.value != 'none') {
      return _tip('hands-before-after-products');
    }

    final safeGeneral = healthTips
        .where(
          (tip) =>
              tip.category != TipCategory.seekCare &&
              tip.id != 'tampon-metals-2026' &&
              !tip.id.startsWith('cycle-'),
        )
        .toList(growable: false);
    final index = DateTime.now()
            .difference(DateTime.utc(2026, 1, 1))
            .inDays
            .abs() %
        safeGeneral.length;
    return safeGeneral[index];
  }

  HealthTip _tip(String id) => healthTips.firstWhere((tip) => tip.id == id);
}

class _UnestimatedRhythmCard extends StatelessWidget {
  const _UnestimatedRhythmCard({required this.cycleDay, super.key});

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
                'YOUR CYCLE',
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
            'A little more history will sharpen the timing',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 19),
          ),
          const SizedBox(height: 5),
          Text(
            cycleDay == null
                ? 'There is not enough cycle history yet for a reliable next-period estimate. Keep recording periods as they happen.'
                : 'Day $cycleDay is still useful context. There is not enough cycle history yet for a reliable next-period estimate, so the timing will stay broad for now.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.42),
          ),
        ],
      ),
    );
  }
}
