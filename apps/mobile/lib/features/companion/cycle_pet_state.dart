import 'package:cycle_engine/cycle_engine.dart';
import 'package:flutter/foundation.dart';

import '../../data/database/app_database.dart';

enum CyclePetMood {
  cozy,
  gentle,
  drowsy,
  curious,
  bright,
  playful,
  calm,
}

@immutable
class CyclePetDisposition {
  const CyclePetDisposition({
    required this.mood,
    required this.energy,
    required this.closeness,
    required this.variant,
  });

  final CyclePetMood mood;

  /// 0 is tucked-in and sleepy; 1 is bouncy and alert.
  final double energy;

  /// 0 is independent/observant; 1 is physically close and comforting.
  final double closeness;

  /// A deterministic tiny visual variant so the pet does not hold one exact
  /// pose every day. It never changes the health meaning of the disposition.
  final int variant;

  String get semantics => switch (mood) {
        CyclePetMood.cozy => 'looking cozy',
        CyclePetMood.gentle => 'staying close',
        CyclePetMood.drowsy => 'looking sleepy',
        CyclePetMood.curious => 'looking curious',
        CyclePetMood.bright => 'looking bright and alert',
        CyclePetMood.playful => 'looking playful',
        CyclePetMood.calm => 'looking calm',
      };
}

@immutable
class CyclePetSignals {
  const CyclePetSignals({
    this.phase,
    this.cycleDay,
    this.values = const <String, String>{},
    this.severities = const <String, int>{},
    this.moods = const <String>{},
  });

  final CyclePhase? phase;
  final int? cycleDay;
  final Map<String, String> values;
  final Map<String, int> severities;
  final Set<String> moods;

  factory CyclePetSignals.fromToday({
    required CyclePhaseContext? phaseContext,
    required List<DayValueEntry> values,
  }) {
    final plain = <String, String>{};
    final severities = <String, int>{};
    final moods = <String>{};

    for (final row in values) {
      if (row.key.startsWith('mood.')) {
        moods.add(row.key.substring('mood.'.length));
        continue;
      }
      plain[row.key] = row.value;
      if (row.severity != null) severities[row.key] = row.severity!;
    }

    return CyclePetSignals(
      phase: phaseContext?.phase,
      cycleDay: phaseContext?.cycleDay,
      values: plain,
      severities: severities,
      moods: moods,
    );
  }
}

CyclePetDisposition cyclePetDisposition(CyclePetSignals signals) {
  final severity = signals.severities;
  final values = signals.values;

  final cramps = severity['cramps'] ?? 0;
  final headache = severity['headache'] ?? 0;
  final nausea = severity['nausea'] ?? 0;
  final dizziness = severity['dizziness'] ?? 0;
  final backPain = severity['back_pain'] ?? 0;
  final bloating = severity['bloating'] ?? 0;
  final tenderness = severity['breast_tenderness'] ?? 0;
  final flow = values['flow'];
  final sleep = values['sleep'];
  final energy = values['energy'];

  final poorSleep = sleep == 'poor' || sleep == 'very_poor';
  final lowEnergy = energy == 'low' || energy == 'very_low';
  final highEnergy = energy == 'high' || energy == 'very_high';
  final difficultMood = signals.moods.intersection(const {
    'sensitive',
    'low',
    'irritable',
    'anxious',
    'overwhelmed',
  });
  final brightMood = signals.moods.intersection(const {
    'good',
    'happy',
    'calm',
  });

  var roughSignals = 0;
  if (cramps >= 2) roughSignals++;
  if (headache >= 2) roughSignals++;
  if (nausea >= 2) roughSignals++;
  if (dizziness >= 2) roughSignals++;
  if (backPain >= 2) roughSignals++;
  if (bloating >= 2) roughSignals++;
  if (tenderness >= 2) roughSignals++;
  if (flow == 'heavy') roughSignals++;
  if (poorSleep) roughSignals++;
  if (lowEnergy) roughSignals++;
  if (difficultMood.isNotEmpty) roughSignals++;

  final variant = ((signals.cycleDay ?? 1) - 1).abs() % 3;

  // The pet supports the person; it does not impersonate their symptom. Strong
  // or multiple rough signals therefore make it stay close rather than look
  // distressed or "sick" itself.
  if (dizziness >= 3 ||
      headache >= 3 ||
      nausea >= 3 ||
      cramps >= 3 ||
      backPain >= 3 ||
      flow == 'heavy' ||
      roughSignals >= 3) {
    return CyclePetDisposition(
      mood: CyclePetMood.gentle,
      energy: 0.32,
      closeness: 0.96,
      variant: variant,
    );
  }

  if (poorSleep && lowEnergy) {
    return CyclePetDisposition(
      mood: CyclePetMood.drowsy,
      energy: 0.18,
      closeness: 0.82,
      variant: variant,
    );
  }

  if (difficultMood.isNotEmpty) {
    return CyclePetDisposition(
      mood: CyclePetMood.gentle,
      energy: 0.38,
      closeness: 0.92,
      variant: variant,
    );
  }

  // Fresh positive logs outrank a phase stereotype. A good day is allowed to
  // look like a good day in any part of the cycle.
  if (highEnergy || brightMood.isNotEmpty) {
    return CyclePetDisposition(
      mood: CyclePetMood.playful,
      energy: 0.92,
      closeness: 0.62,
      variant: variant,
    );
  }

  return switch (signals.phase) {
    CyclePhase.menstruation => CyclePetDisposition(
        mood: CyclePetMood.cozy,
        energy: 0.34,
        closeness: 0.88,
        variant: variant,
      ),
    CyclePhase.follicular => CyclePetDisposition(
        mood: CyclePetMood.bright,
        energy: 0.72,
        closeness: 0.55,
        variant: variant,
      ),
    CyclePhase.periOvulatory => CyclePetDisposition(
        mood: CyclePetMood.curious,
        energy: 0.78,
        closeness: 0.58,
        variant: variant,
      ),
    CyclePhase.luteal => CyclePetDisposition(
        mood: CyclePetMood.calm,
        energy: 0.48,
        closeness: 0.72,
        variant: variant,
      ),
    CyclePhase.uncertain || null => CyclePetDisposition(
        mood: CyclePetMood.curious,
        energy: 0.52,
        closeness: 0.66,
        variant: variant,
      ),
  };
}
