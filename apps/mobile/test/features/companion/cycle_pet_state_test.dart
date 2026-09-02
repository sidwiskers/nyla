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

  test('positive logs outrank phase stereotypes', () {
    final disposition = cyclePetDisposition(
      const CyclePetSignals(
        phase: CyclePhase.luteal,
        cycleDay: 25,
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
  });

  test('cycle context supplies only the baseline demeanor', () {
    CyclePetDisposition resolve(CyclePhase? phase) => cyclePetDisposition(
          CyclePetSignals(phase: phase, cycleDay: 7),
        );

    expect(resolve(CyclePhase.menstruation).mood, CyclePetMood.cozy);
    expect(resolve(CyclePhase.follicular).mood, CyclePetMood.bright);
    expect(resolve(CyclePhase.periOvulatory).mood, CyclePetMood.curious);
    expect(resolve(CyclePhase.luteal).mood, CyclePetMood.calm);
    expect(resolve(CyclePhase.uncertain).mood, CyclePetMood.curious);
    expect(resolve(null).mood, CyclePetMood.curious);
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
