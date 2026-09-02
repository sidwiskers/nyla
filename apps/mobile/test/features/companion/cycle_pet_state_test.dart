import 'package:cycle_engine/cycle_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyla/features/companion/cycle_pet_state.dart';

void main() {
  test('strong symptoms make the pet stay close instead of mirroring distress', () {
    final disposition = cyclePetDisposition(
      const CyclePetSignals(
        phase: CyclePhase.follicular,
        cycleDay: 9,
        severities: {'cramps': 3},
      ),
    );

    expect(disposition.mood, CyclePetMood.gentle);
    expect(disposition.closeness, greaterThan(0.9));
    expect(disposition.energy, lessThan(0.5));
  });

  test('one meaningful physical discomfort is noticed without looking ill', () {
    final disposition = cyclePetDisposition(
      const CyclePetSignals(
        phase: CyclePhase.follicular,
        cycleDay: 10,
        severities: {'headache': 2},
      ),
    );

    expect(disposition.mood, CyclePetMood.gentle);
    expect(disposition.closeness, inInclusiveRange(0.8, 0.9));
  });

  test('poor sleep plus low energy produces a drowsy companion', () {
    final disposition = cyclePetDisposition(
      const CyclePetSignals(
        phase: CyclePhase.luteal,
        cycleDay: 23,
        values: {
          'sleep': 'very_poor',
          'energy': 'very_low',
        },
      ),
    );

    expect(disposition.mood, CyclePetMood.drowsy);
    expect(disposition.energy, lessThan(0.25));
  });

  test('poor sleep alone can soften the pet without inventing a phase mood', () {
    final disposition = cyclePetDisposition(
      const CyclePetSignals(
        phase: CyclePhase.periOvulatory,
        cycleDay: 15,
        values: {'sleep': 'poor'},
      ),
    );

    expect(disposition.mood, CyclePetMood.drowsy);
  });

  test('positive logs outrank phase stereotypes', () {
    final disposition = cyclePetDisposition(
      const CyclePetSignals(
        phase: CyclePhase.luteal,
        cycleDay: 25,
        daysUntilLikelyPeriod: 2,
        values: {'energy': 'high'},
        moods: {'happy'},
      ),
    );

    expect(disposition.mood, CyclePetMood.playful);
    expect(disposition.energy, greaterThan(0.85));
  });

  test('difficult mood makes the pet supportive rather than sad', () {
    final disposition = cyclePetDisposition(
      const CyclePetSignals(
        phase: CyclePhase.periOvulatory,
        cycleDay: 15,
        moods: {'anxious'},
      ),
    );

    expect(disposition.mood, CyclePetMood.gentle);
    expect(disposition.closeness, greaterThan(0.9));
  });

  test('several moderate rough signals collapse into one gentle demeanor', () {
    final disposition = cyclePetDisposition(
      const CyclePetSignals(
        phase: CyclePhase.follicular,
        cycleDay: 8,
        severities: {
          'cramps': 2,
          'headache': 2,
          'bloating': 2,
        },
      ),
    );

    expect(disposition.mood, CyclePetMood.gentle);
    expect(disposition.closeness, greaterThan(0.9));
  });

  test('cycle context supplies a gentle visual rhythm, not a user diagnosis', () {
    final period = cyclePetDisposition(
      const CyclePetSignals(
        phase: CyclePhase.menstruation,
        phaseConfidence: PhaseConfidence.observed,
        cycleDay: 1,
      ),
    );
    final earlyFollicular = cyclePetDisposition(
      const CyclePetSignals(
        phase: CyclePhase.follicular,
        phaseConfidence: PhaseConfidence.limited,
        cycleDay: 7,
      ),
    );
    final laterFollicular = cyclePetDisposition(
      const CyclePetSignals(
        phase: CyclePhase.follicular,
        phaseConfidence: PhaseConfidence.supported,
        cycleDay: 10,
      ),
    );
    final midCycle = cyclePetDisposition(
      const CyclePetSignals(
        phase: CyclePhase.periOvulatory,
        cycleDay: 15,
      ),
    );
    final luteal = cyclePetDisposition(
      const CyclePetSignals(
        phase: CyclePhase.luteal,
        cycleDay: 21,
        daysUntilLikelyPeriod: 7,
      ),
    );
    final settling = cyclePetDisposition(
      const CyclePetSignals(
        phase: CyclePhase.luteal,
        cycleDay: 26,
        daysUntilLikelyPeriod: 2,
      ),
    );

    expect(period.mood, CyclePetMood.cozy);
    expect(earlyFollicular.mood, CyclePetMood.curious);
    expect(laterFollicular.mood, CyclePetMood.bright);
    expect(midCycle.mood, CyclePetMood.curious);
    expect(luteal.mood, CyclePetMood.calm);
    expect(settling.mood, CyclePetMood.cozy);
  });

  test('unknown timing stays curious rather than pretending certainty', () {
    expect(
      cyclePetDisposition(
        const CyclePetSignals(phase: CyclePhase.uncertain, cycleDay: 18),
      ).mood,
      CyclePetMood.curious,
    );
    expect(
      cyclePetDisposition(const CyclePetSignals()).mood,
      CyclePetMood.curious,
    );
  });

  test('familiarity can warm the cat without overriding health interpretation', () {
    final newCompanion = cyclePetDisposition(
      const CyclePetSignals(
        phase: CyclePhase.luteal,
        cycleDay: 21,
        daysUntilLikelyPeriod: 7,
      ),
    );
    final familiarCompanion = cyclePetDisposition(
      const CyclePetSignals(
        phase: CyclePhase.luteal,
        cycleDay: 21,
        daysUntilLikelyPeriod: 7,
        familiarity: 1,
        recentlyPetted: true,
      ),
    );

    expect(newCompanion.mood, CyclePetMood.calm);
    expect(familiarCompanion.mood, CyclePetMood.affectionate);
    expect(familiarCompanion.closeness, greaterThan(newCompanion.closeness));
    expect(familiarCompanion.familiarity, 1);
    expect(familiarCompanion.recentlyPetted, isTrue);
  });

  test('tiny pose variation is deterministic by cycle day', () {
    final first = cyclePetDisposition(
      const CyclePetSignals(phase: CyclePhase.follicular, cycleDay: 8),
    );
    final again = cyclePetDisposition(
      const CyclePetSignals(phase: CyclePhase.follicular, cycleDay: 8),
    );
    final nextDay = cyclePetDisposition(
      const CyclePetSignals(phase: CyclePhase.follicular, cycleDay: 9),
    );

    expect(first.variant, again.variant);
    expect(first.variant, isNot(nextDay.variant));
  });
}
