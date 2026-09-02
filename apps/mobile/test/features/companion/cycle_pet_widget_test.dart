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

  Widget app({
    bool reduceMotion = false,
    bool tickerEnabled = true,
    VoidCallback? onPetted,
  }) =>
      MaterialApp(
        theme: NylaTheme.light,
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: TickerMode(
            enabled: tickerEnabled,
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 360,
                  child: CyclePetLedge(
                    disposition: disposition,
                    onPetted: onPetted,
                    child: Container(
                      key: const ValueKey('cycle-card'),
                      height: 180,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(27),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  testWidgets('cat sits on the card instead of taking a full separate block',
      (tester) async {
    await tester.pumpWidget(app());

    final pet = find.byKey(const ValueKey('cycle-pet-touch-target'));
    final card = find.byKey(const ValueKey('cycle-card'));
    expect(pet, findsOneWidget);
    expect(card, findsOneWidget);

    final petRect = tester.getRect(pet);
    final cardRect = tester.getRect(card);
    expect(petRect.bottom, greaterThan(cardRect.top));
    expect(petRect.bottom - cardRect.top, lessThan(18));
    expect(cardRect.top - petRect.top, lessThan(100));
  });

  testWidgets('pet accepts a tap and a horizontal stroke', (tester) async {
    var pets = 0;
    await tester.pumpWidget(app(onPetted: () => pets++));
    final target = find.byKey(const ValueKey('cycle-pet-touch-target'));

    await tester.tap(target);
    await tester.pump(const Duration(milliseconds: 120));
    expect(pets, 0, reason: 'A tap is acknowledgement, not a recorded pet.');
    expect(tester.takeException(), isNull);

    final gesture = await tester.startGesture(tester.getCenter(target));
    await gesture.moveBy(const Offset(42, 0));
    await tester.pump(const Duration(milliseconds: 80));
    await gesture.moveBy(const Offset(-70, 0));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 1300));

    expect(pets, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('holding the cat is a deliberate cuddle interaction', (tester) async {
    var pets = 0;
    await tester.pumpWidget(app(onPetted: () => pets++));
    final target = find.byKey(const ValueKey('cycle-pet-touch-target'));

    await tester.longPress(target);
    await tester.pump(const Duration(milliseconds: 1300));

    expect(pets, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion stays interactive without autonomous animation',
      (tester) async {
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

  testWidgets('ticker suspension resets an in-flight reaction cleanly',
      (tester) async {
    await tester.pumpWidget(app());
    final target = find.byKey(const ValueKey('cycle-pet-touch-target'));

    await tester.tap(target);
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pumpWidget(app(tickerEnabled: false));
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(app());
    await tester.pump(const Duration(seconds: 8));
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposing the pet cancels its idle lifecycle cleanly',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 8));

    expect(tester.takeException(), isNull);
  });
}
