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
  const longPressRecognition = Duration(milliseconds: 580);

  Widget app({
    bool reduceMotion = false,
    bool tickerEnabled = true,
    double cardHeight = 180,
    VoidCallback? onPetted,
  }) =>
      MaterialApp(
        theme: NylaTheme.light,
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: TickerMode(
            enabled: tickerEnabled,
            child: Scaffold(
              body: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: 360,
                  child: CyclePetLedge(
                    disposition: disposition,
                    onPetted: onPetted,
                    enableDeviceMotion: false,
                    child: Container(
                      key: ValueKey('cycle-card-$cardHeight'),
                      height: cardHeight,
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

  Finder card(double height) => find.byKey(ValueKey('cycle-card-$height'));

  testWidgets('cat sits on the card instead of taking a full separate block',
      (tester) async {
    await tester.pumpWidget(app());

    final pet = find.byKey(const ValueKey('cycle-pet-touch-target'));
    final cycleCard = card(180);
    expect(pet, findsOneWidget);
    expect(cycleCard, findsOneWidget);

    final petRect = tester.getRect(pet);
    final cardRect = tester.getRect(cycleCard);
    expect(petRect.bottom, greaterThan(cardRect.top));
    expect(petRect.bottom - cardRect.top, lessThan(18));
    expect(cardRect.top - petRect.top, lessThan(100));
  });

  testWidgets('the card top stays pinned while its height grows and shrinks',
      (tester) async {
    await tester.pumpWidget(app(cardHeight: 180));
    await tester.pumpAndSettle();
    final ledgeTop = tester.getRect(card(180)).top;

    await tester.pumpWidget(app(cardHeight: 260));
    await tester.pump(const Duration(milliseconds: 120));
    expect(
      tester.getRect(card(260)).top,
      closeTo(ledgeTop, 0.5),
      reason: 'The cat ledge must not drift while card content grows.',
    );
    await tester.pumpAndSettle();
    expect(tester.getRect(card(260)).top, closeTo(ledgeTop, 0.5));

    await tester.pumpWidget(app(cardHeight: 180));
    await tester.pump(const Duration(milliseconds: 120));
    expect(
      tester.getRect(card(180)).top,
      closeTo(ledgeTop, 0.5),
      reason: 'The cat ledge must not drift while card content shrinks.',
    );
    await tester.pumpAndSettle();
    expect(tester.getRect(card(180)).top, closeTo(ledgeTop, 0.5));
    expect(tester.takeException(), isNull);
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
    await tester.pump(const Duration(milliseconds: 1400));

    expect(pets, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('holding without moving is a cuddle and produces love',
      (tester) async {
    var pets = 0;
    await tester.pumpWidget(app(onPetted: () => pets++));
    final target = find.byKey(const ValueKey('cycle-pet-touch-target'));

    await tester.longPress(target);
    await tester.pump(const Duration(milliseconds: 120));

    expect(pets, 1);
    expect(find.byKey(const ValueKey('cycle-pet-state-love')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hold then drag picks the cat up and carries her along the ledge',
      (tester) async {
    var pets = 0;
    await tester.pumpWidget(app(onPetted: () => pets++));
    final target = find.byKey(const ValueKey('cycle-pet-touch-target'));
    final startCenter = tester.getCenter(target);

    final gesture = await tester.startGesture(startCenter);
    await tester.pump(longPressRecognition);
    await gesture.moveBy(const Offset(0, -24));
    await tester.pump(const Duration(milliseconds: 40));

    expect(
      find.byKey(const ValueKey('cycle-pet-state-carrying')),
      findsOneWidget,
    );
    final liftedCenter = tester.getCenter(target);
    expect(liftedCenter.dy, lessThan(startCenter.dy - 8));

    await gesture.moveBy(const Offset(54, -4));
    await tester.pump(const Duration(milliseconds: 40));
    final carriedCenter = tester.getCenter(target);
    expect(carriedCenter.dx, greaterThan(liftedCenter.dx + 10));

    await gesture.up();
    await tester.pump(const Duration(milliseconds: 480));
    expect(
      find.byKey(const ValueKey('cycle-pet-state-carrying')),
      findsNothing,
    );
    expect(pets, 0, reason: 'Carrying is play, not relationship affection.');
    expect(tester.takeException(), isNull);
  });

  testWidgets('rapid pokes make the cat visibly annoyed, then she recovers',
      (tester) async {
    await tester.pumpWidget(app());
    final target = find.byKey(const ValueKey('cycle-pet-touch-target'));

    for (var i = 0; i < 4; i++) {
      await tester.tap(target);
      await tester.pump(const Duration(milliseconds: 110));
    }

    expect(
      find.byKey(const ValueKey('cycle-pet-state-annoyed')),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 1300));
    expect(
      find.byKey(const ValueKey('cycle-pet-state-annoyed')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('rapid taps retarget a reaction without stale completion',
      (tester) async {
    await tester.pumpWidget(app());
    final target = find.byKey(const ValueKey('cycle-pet-touch-target'));

    await tester.tap(target);
    await tester.pump(const Duration(milliseconds: 90));
    await tester.tap(target);
    await tester.pump(const Duration(milliseconds: 90));
    await tester.tap(target);
    await tester.pump(const Duration(seconds: 2));

    expect(target, findsOneWidget);
    expect(tester.takeException(), isNull);

    final gesture = await tester.startGesture(tester.getCenter(target));
    await gesture.moveBy(const Offset(55, 0));
    await gesture.moveBy(const Offset(-65, 0));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 1300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a cancelled pet gesture restores the cat to interactive state',
      (tester) async {
    var pets = 0;
    await tester.pumpWidget(app(onPetted: () => pets++));
    final target = find.byKey(const ValueKey('cycle-pet-touch-target'));

    final cancelled = await tester.startGesture(tester.getCenter(target));
    await cancelled.moveBy(const Offset(45, 0));
    await tester.pump(const Duration(milliseconds: 60));
    await cancelled.cancel();
    await tester.pump(const Duration(milliseconds: 100));
    expect(pets, 0, reason: 'A cancelled stroke must not count as affection.');

    final complete = await tester.startGesture(tester.getCenter(target));
    await complete.moveBy(const Offset(50, 0));
    await complete.moveBy(const Offset(-70, 0));
    await complete.up();
    await tester.pump(const Duration(milliseconds: 1300));

    expect(pets, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a cancelled pickup returns her to the ledge without affection',
      (tester) async {
    var pets = 0;
    await tester.pumpWidget(app(onPetted: () => pets++));
    final target = find.byKey(const ValueKey('cycle-pet-touch-target'));
    final start = tester.getCenter(target);

    final gesture = await tester.startGesture(start);
    await tester.pump(longPressRecognition);
    await gesture.moveBy(const Offset(26, -28));
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      find.byKey(const ValueKey('cycle-pet-state-carrying')),
      findsOneWidget,
    );

    await gesture.cancel();
    await tester.pump(const Duration(milliseconds: 420));
    expect(pets, 0);
    expect(
      find.byKey(const ValueKey('cycle-pet-state-carrying')),
      findsNothing,
    );
    expect(tester.getCenter(target).dy, closeTo(start.dy, 1.0));
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
