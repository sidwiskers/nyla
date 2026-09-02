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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CyclePetDisposition &&
          other.mood == mood &&
          other.energy == energy &&
          other.closeness == closeness &&
          other.variant == variant;

  @override
  int get hashCode => Object.hash(mood, energy, closeness, variant);
}

@immutable
class CyclePetSignals {
  const CyclePetSignals({
    this.phase,
    this.phaseConfidence,
    this.cycleDay,
    this.daysUntilLikelyPeriod,
    this.values = const <String, String>{},
    this.severities = const <String, int>{},
    this.moods = const <String>{},
  });

  final CyclePhase? phase;
  final PhaseConfidence? phaseConfidence;
  final int? cycleDay;
  final int? daysUntilLikelyPeriod;
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
      phaseConfidence: phaseContext?.confidence,
      cycleDay: phaseContext?.cycleDay,
      daysUntilLikelyPeriod: phaseContext?.daysUntilLikelyPeriod,
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
  // or several rough signals therefore make it stay close rather than look ill.
  if (dizziness >= 3 ||
      headache >= 3 ||
      nausea >= 3 ||
      cramps >= 3 ||
      backPain >= 3 ||
      flow == 'heavy' ||
      roughSignals >= 3) {
    return CyclePetDisposition(
      mood: CyclePetMood.gentle,
      energy: 0.30,
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

  final meaningfulPhysicalDiscomfort = cramps >= 2 ||
      headache >= 2 ||
      nausea >= 2 ||
      dizziness >= 2 ||
      backPain >= 2 ||
      roughSignals >= 2;
  if (meaningfulPhysicalDiscomfort) {
    return CyclePetDisposition(
      mood: CyclePetMood.gentle,
      energy: 0.42,
      closeness: 0.86,
      variant: variant,
    );
  }

  if (poorSleep || lowEnergy) {
    return CyclePetDisposition(
      mood: CyclePetMood.drowsy,
      energy: 0.30,
      closeness: 0.76,
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

  return _baselineDisposition(signals, variant);
}

CyclePetDisposition _baselineDisposition(CyclePetSignals signals, int variant) {
  switch (signals.phase) {
    case CyclePhase.menstruation:
      final early = (signals.cycleDay ?? 1) <= 2;
      return CyclePetDisposition(
        mood: CyclePetMood.cozy,
        energy: early ? 0.30 : 0.40,
        closeness: early ? 0.90 : 0.82,
        variant: variant,
      );
    case CyclePhase.follicular:
      final earlyOrBroad = signals.phaseConfidence == PhaseConfidence.limited ||
          (signals.cycleDay ?? 99) <= 7;
      return CyclePetDisposition(
        mood: earlyOrBroad ? CyclePetMood.curious : CyclePetMood.bright,
        energy: earlyOrBroad ? 0.58 : 0.72,
        closeness: earlyOrBroad ? 0.64 : 0.55,
        variant: variant,
      );
    case CyclePhase.periOvulatory:
      return CyclePetDisposition(
        mood: CyclePetMood.curious,
        energy: 0.78,
        closeness: 0.58,
        variant: variant,
      );
    case CyclePhase.luteal:
      final settling = signals.daysUntilLikelyPeriod != null &&
          signals.daysUntilLikelyPeriod! >= 0 &&
          signals.daysUntilLikelyPeriod! <= 3;
      return CyclePetDisposition(
        mood: settling ? CyclePetMood.cozy : CyclePetMood.calm,
        energy: settling ? 0.38 : 0.48,
        closeness: settling ? 0.82 : 0.72,
        variant: variant,
      );
    case CyclePhase.uncertain:
    case null:
      return CyclePetDisposition(
        mood: CyclePetMood.curious,
        energy: 0.52,
        closeness: 0.66,
        variant: variant,
      );
  }
}
