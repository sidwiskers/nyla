import 'package:cycle_engine/cycle_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyla/features/companion/cycle_pet_state.dart';

void main() {
  test('familiar recent affection can become the cat own demeanor', () {
    final disposition = cyclePetDisposition(
      const CyclePetSignals(
        phase: CyclePhase.luteal,
        cycleDay: 21,
        familiarity: 4 / 14,
        recentlyPetted: true,
      ),
    );

    expect(disposition.mood, CyclePetMood.affectionate);
    expect(disposition.closeness, greaterThanOrEqualTo(0.86));
  });

  test('one first-day pet does not instantly rewrite the cat personality', () {
    final disposition = cyclePetDisposition(
      const CyclePetSignals(
        phase: CyclePhase.luteal,
        cycleDay: 21,
        familiarity: 1 / 14,
        recentlyPetted: true,
      ),
    );

    expect(disposition.mood, CyclePetMood.calm);
  });

  test('rough-day logs still outrank relationship warmth', () {
    final disposition = cyclePetDisposition(
      const CyclePetSignals(
        phase: CyclePhase.follicular,
        cycleDay: 10,
        familiarity: 1,
        recentlyPetted: true,
        severities: {'cramps': 3},
      ),
    );

    expect(disposition.mood, CyclePetMood.gentle);
    expect(disposition.closeness, greaterThan(0.9));
  });

  test('positive logs still outrank affection and remain playful', () {
    final disposition = cyclePetDisposition(
      const CyclePetSignals(
        phase: CyclePhase.luteal,
        cycleDay: 24,
        familiarity: 1,
        recentlyPetted: true,
        values: {'energy': 'high'},
        moods: {'happy'},
      ),
    );

    expect(disposition.mood, CyclePetMood.playful);
  });
}
