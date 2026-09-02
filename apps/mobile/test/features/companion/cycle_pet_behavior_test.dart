import 'package:flutter_test/flutter_test.dart';
import 'package:nyla/features/companion/cycle_pet_behavior.dart';
import 'package:nyla/features/companion/cycle_pet_state.dart';

void main() {
  CyclePetDisposition pet(
    CyclePetMood mood, {
    double familiarity = 0,
    bool recentlyPetted = false,
  }) =>
      CyclePetDisposition(
        mood: mood,
        energy: 0.5,
        closeness: 0.6,
        variant: 0,
        familiarity: familiarity,
        recentlyPetted: recentlyPetted,
      );

  test('playful cats can roam and use the active ledge repertoire', () {
    final profile = cyclePetBehavior(pet(CyclePetMood.playful));

    expect(profile.roaming, greaterThan(0.8));
    expect(profile.idleActions, contains(CyclePetAction.hopLeft));
    expect(profile.idleActions, contains(CyclePetAction.hopRight));
    expect(profile.idleActions, contains(CyclePetAction.paw));
    expect(profile.idleActions, contains(CyclePetAction.tailFlick));
    expect(profile.idleActions, contains(CyclePetAction.peek));
    expect(profile.idleActions, contains(CyclePetAction.earFlick));
    expect(profile.idleActions, contains(CyclePetAction.sniff));
  });

  test('drowsy cats prefer quiet grounded motion', () {
    final profile = cyclePetBehavior(pet(CyclePetMood.drowsy));

    expect(profile.roaming, lessThan(0.1));
    expect(profile.idleActions, contains(CyclePetAction.yawn));
    expect(profile.idleActions, contains(CyclePetAction.slowBlink));
    expect(profile.idleActions, contains(CyclePetAction.loaf));
    expect(profile.idleActions, contains(CyclePetAction.settle));
    expect(profile.idleActions, isNot(contains(CyclePetAction.hopLeft)));
    expect(profile.idleActions, isNot(contains(CyclePetAction.hopRight)));
  });

  test('curious cats investigate rather than act generically playful', () {
    final profile = cyclePetBehavior(pet(CyclePetMood.curious));

    expect(profile.idleActions, contains(CyclePetAction.peek));
    expect(profile.idleActions, contains(CyclePetAction.sniff));
    expect(profile.idleActions, contains(CyclePetAction.paw));
    expect(profile.roaming, greaterThan(0.5));
  });

  test('affectionate cats can knead and slow blink', () {
    final profile = cyclePetBehavior(pet(CyclePetMood.affectionate));

    expect(profile.idleActions, contains(CyclePetAction.knead));
    expect(profile.idleActions, contains(CyclePetAction.slowBlink));
    expect(profile.idleActions, contains(CyclePetAction.loaf));
    expect(profile.tapActions, contains(CyclePetAction.knead));
  });

  test('familiarity adds affection without deleting the base personality', () {
    final fresh = cyclePetBehavior(pet(CyclePetMood.calm));
    final familiar = cyclePetBehavior(
      pet(
        CyclePetMood.calm,
        familiarity: 0.8,
        recentlyPetted: true,
      ),
    );

    expect(familiar.idleActions, containsAll(fresh.idleActions));
    expect(familiar.idleActions, contains(CyclePetAction.nuzzle));
    expect(familiar.idleActions, contains(CyclePetAction.purr));
    expect(familiar.idleActions, contains(CyclePetAction.knead));
    expect(familiar.tapActions.first, CyclePetAction.nuzzle);
  });

  test('slow expressive actions get time to read as real gestures', () {
    expect(
      cyclePetActionDuration(CyclePetAction.groom),
      greaterThan(cyclePetActionDuration(CyclePetAction.nod)),
    );
    expect(
      cyclePetActionDuration(CyclePetAction.knead),
      greaterThan(const Duration(seconds: 1)),
    );
    expect(
      cyclePetActionDuration(CyclePetAction.loaf),
      greaterThan(cyclePetActionDuration(CyclePetAction.earFlick)),
    );
    expect(
      cyclePetActionDuration(CyclePetAction.landing),
      lessThan(const Duration(seconds: 1)),
    );
    expect(
      cyclePetActionDuration(CyclePetAction.hopLeft),
      lessThan(const Duration(seconds: 1)),
    );
  });
}
