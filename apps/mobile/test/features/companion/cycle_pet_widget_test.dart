import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyla/core/theme/nyla_theme.dart';
import 'package:nyla/features/companion/cycle_pet.dart';
import 'package:nyla/features/companion/cycle_pet_state.dart';

void main() {
  const disposition = CyclePetDisposition(
    mood: CyclePetMood.playful,
    energy: 0.92,
    closeness: 0.62,
    variant: 1,
  );

  Widget app({bool reduceMotion = false}) => MaterialApp(
        theme: NylaTheme.light,
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: const Scaffold(
            body: Center(
              child: CyclePetNook(disposition: disposition),
            ),
          ),
        ),
      );

  testWidgets('pet accepts a nod tap and a horizontal pet stroke', (tester) async {
    await tester.pumpWidget(app());
    final target = find.byKey(const ValueKey('cycle-pet-touch-target'));
    expect(target, findsOneWidget);

    await tester.tap(target);
    await tester.pump(const Duration(milliseconds: 120));
    expect(tester.takeException(), isNull);

    final gesture = await tester.startGesture(tester.getCenter(target));
    await gesture.moveBy(const Offset(42, 0));
    await tester.pump(const Duration(milliseconds: 80));
    await gesture.moveBy(const Offset(-70, 0));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 700));

    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion stays interactive without autonomous animation', (tester) async {
    await tester.pumpWidget(app(reduceMotion: true));
    final target = find.byKey(const ValueKey('cycle-pet-touch-target'));

    await tester.tap(target);
    await tester.pump();
    final gesture = await tester.startGesture(tester.getCenter(target));
    await gesture.moveBy(const Offset(50, 0));
    await gesture.up();
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('disposing the pet cancels its idle lifecycle cleanly', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 8));

    expect(tester.takeException(), isNull);
  });
}
