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
  affectionate,
}

@immutable
class CyclePetDisposition {
  const CyclePetDisposition({
    required this.mood,
    required this.energy,
    required this.closeness,
    required this.variant,
    this.familiarity = 0,
    this.recentlyPetted = false,
  });

  final CyclePetMood mood;
  final double energy;
  final double closeness;
  final int variant;
  final double familiarity;
  final bool recentlyPetted;

  String get semantics => switch (mood) {
        CyclePetMood.cozy => 'looking cozy',
        CyclePetMood.gentle => 'staying close',
        CyclePetMood.drowsy => 'looking sleepy',
        CyclePetMood.curious => 'looking curious',
        CyclePetMood.bright => 'looking bright and alert',
        CyclePetMood.playful => 'looking playful',
        CyclePetMood.calm => 'looking calm',
        CyclePetMood.affectionate => 'looking especially fond',
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CyclePetDisposition &&
          other.mood == mood &&
          other.energy == energy &&
          other.closeness == closeness &&
          other.variant == variant &&
          other.familiarity == familiarity &&
          other.recentlyPetted == recentlyPetted;

  @override
  int get hashCode => Object.hash(
        mood,
        energy,
        closeness,
        variant,
        familiarity,
        recentlyPetted,
      );
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
    this.familiarity = 0,
    this.recentlyPetted = false,
  });

  final CyclePhase? phase;
  final PhaseConfidence? phaseConfidence;
  final int? cycleDay;
  final int? daysUntilLikelyPeriod;
  final Map<String, String> values;
  final Map<String, int> severities;
  final Set<String> moods;
  final double familiarity;
  final bool recentlyPetted;

  factory CyclePetSignals.fromToday({
    required CyclePhaseContext? phaseContext,
    required List<DayValueEntry> values,
    double familiarity = 0,
    bool recentlyPetted = false,
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
      familiarity: familiarity,
      recentlyPetted: recentlyPetted,
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

  // Actual logged state always outranks cycle rhythm or relationship warmth.
  // The cat supports a rough day; it never performs a cheerful phase stereotype
  // over information the user just logged.
  if (dizziness >= 3 ||
      headache >= 3 ||
      nausea >= 3 ||
      cramps >= 3 ||
      backPain >= 3 ||
      flow == 'heavy' ||
      roughSignals >= 3) {
    return _remember(
      const CyclePetDisposition(
        mood: CyclePetMood.gentle,
        energy: 0.30,
        closeness: 0.96,
        variant: 0,
      ),
      signals,
      variant,
    );
  }

  if (poorSleep && lowEnergy) {
    return _remember(
      const CyclePetDisposition(
        mood: CyclePetMood.drowsy,
        energy: 0.18,
        closeness: 0.82,
        variant: 0,
      ),
      signals,
      variant,
    );
  }

  if (difficultMood.isNotEmpty) {
    return _remember(
      const CyclePetDisposition(
        mood: CyclePetMood.gentle,
        energy: 0.38,
        closeness: 0.92,
        variant: 0,
      ),
      signals,
      variant,
    );
  }

  final meaningfulPhysicalDiscomfort = cramps >= 2 ||
      headache >= 2 ||
      nausea >= 2 ||
      dizziness >= 2 ||
      backPain >= 2 ||
      roughSignals >= 2;
  if (meaningfulPhysicalDiscomfort) {
    return _remember(
      const CyclePetDisposition(
        mood: CyclePetMood.gentle,
        energy: 0.42,
        closeness: 0.86,
        variant: 0,
      ),
      signals,
      variant,
    );
  }

  if (poorSleep || lowEnergy) {
    return _remember(
      const CyclePetDisposition(
        mood: CyclePetMood.drowsy,
        energy: 0.30,
        closeness: 0.76,
        variant: 0,
      ),
      signals,
      variant,
    );
  }

  if (highEnergy || brightMood.isNotEmpty) {
    return _remember(
      const CyclePetDisposition(
        mood: CyclePetMood.playful,
        energy: 0.92,
        closeness: 0.62,
        variant: 0,
      ),
      signals,
      variant,
    );
  }

  final baseline = _baselineDisposition(signals, variant);

  // Familiarity is allowed to change the cat's own emotion, never the health
  // interpretation. It takes several distinct days of affection before this
  // becomes an enduring demeanor, so the first tap does not instantly rewrite
  // its personality.
  if (signals.recentlyPetted && signals.familiarity >= 0.28) {
    return _remember(
      CyclePetDisposition(
        mood: CyclePetMood.affectionate,
        energy: (baseline.energy * 0.92).clamp(0.38, 0.68).toDouble(),
        closeness: baseline.closeness < 0.86 ? 0.86 : baseline.closeness,
        variant: variant,
      ),
      signals,
      variant,
    );
  }

  return _remember(baseline, signals, variant);
}

CyclePetDisposition _remember(
  CyclePetDisposition base,
  CyclePetSignals signals,
  int variant,
) {
  final familiarity = signals.familiarity.clamp(0.0, 1.0).toDouble();
  final closenessBonus =
      familiarity * 0.055 + (signals.recentlyPetted ? 0.025 : 0.0);
  return CyclePetDisposition(
    mood: base.mood,
    energy: base.energy,
    closeness:
        (base.closeness + closenessBonus).clamp(0.0, 1.0).toDouble(),
    variant: variant,
    familiarity: familiarity,
    recentlyPetted: signals.recentlyPetted,
  );
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
