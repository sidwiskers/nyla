import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nyla/navigation/motion.dart';

void main() {
  group('navigation spatial model', () {
    test('maps bottom sections in their visual order', () {
      expect(nylaSectionIndex('/today'), 0);
      expect(nylaSectionIndex('/calendar'), 1);
      expect(nylaSectionIndex('/log'), 2);
      expect(nylaSectionIndex('/log?day=2026-09-02'), 2);
      expect(nylaSectionIndex('/insights'), 3);
      expect(nylaSectionIndex('/learn'), 4);
    });

    test('derives travel direction from section order', () {
      expect(nylaTravelDirection(from: 0, to: 4), 1);
      expect(nylaTravelDirection(from: 4, to: 1), -1);
      expect(nylaTravelDirection(from: 2, to: 2), 0);
    });

    test('section pages suppress navigator-level animation', () {
      final page = nylaSectionPage(
        key: const ValueKey('today'),
        child: const SizedBox(),
      );
      expect(page, isA<NoTransitionPage<void>>());
    });

    test('depth pages use Nyla custom transitions', () {
      final page = nylaDepthPage(
        key: const ValueKey('settings'),
        child: const SizedBox(),
        modal: true,
      );
      expect(page, isA<CustomTransitionPage<void>>());
    });
  });

  group('NylaSectionMotion', () {
    testWidgets('settles on only the latest section after rapid changes',
        (tester) async {
      await tester.pumpWidget(_harness('/today', 1, 'Today'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(_harness('/calendar', 1, 'Calendar'));
      await tester.pump(const Duration(milliseconds: 70));

      await tester.pumpWidget(_harness('/learn', 1, 'Learn'));
      await tester.pump(const Duration(milliseconds: 65));

      await tester.pumpWidget(_harness('/today', -1, 'Today'));
      await tester.pumpAndSettle();

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Calendar'), findsNothing);
      expect(find.text('Learn'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reduced motion swaps sections immediately', (tester) async {
      await tester.pumpWidget(
        _harness('/today', 1, 'Today', reduceMotion: true),
      );
      expect(find.text('Today'), findsOneWidget);

      await tester.pumpWidget(
        _harness('/calendar', 1, 'Calendar', reduceMotion: true),
      );

      expect(find.text('Today'), findsNothing);
      expect(find.text('Calendar'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

Widget _harness(
  String identity,
  int direction,
  String label, {
  bool reduceMotion = false,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: SizedBox.expand(
        child: NylaSectionMotion(
          identity: identity,
          direction: direction,
          reduceMotion: reduceMotion,
          child: ColoredBox(
            color: Colors.white,
            child: Center(child: Text(label)),
          ),
        ),
      ),
    ),
  );
}
