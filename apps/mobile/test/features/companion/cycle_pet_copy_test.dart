import 'package:flutter_test/flutter_test.dart';
import 'package:nyla/features/companion/cycle_pet_state.dart';

void main() {
  test('pet semantics describe its demeanor without judging the user', () {
    for (final mood in CyclePetMood.values) {
      final disposition = CyclePetDisposition(
        mood: mood,
        energy: 0.5,
        closeness: 0.5,
        variant: 0,
      );
      final copy = disposition.semantics.toLowerCase();
      expect(copy, isNot(contains('hormone')));
      expect(copy, isNot(contains('pms')));
      expect(copy, isNot(contains('sad')));
      expect(copy, isNot(contains('moody')));
      expect(copy, isNot(contains('bad day')));
      expect(copy, isNot(contains('you feel')));
      expect(copy, isNot(contains('your mood')));
    }
  });
}
