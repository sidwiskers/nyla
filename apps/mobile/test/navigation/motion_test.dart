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

  group('NylaBranchMotion', () {
    testWidgets('keeps every branch alive while only one is interactive',
        (tester) async {
      await tester.pumpWidget(_harness(0));

      for (final label in _labels) {
        expect(find.text(label), findsOneWidget);
      }

      expect(
        tester
            .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
            .map((widget) => widget.opacity)
            .toList(),
        [1, 0, 0, 0, 0],
      );
      expect(
        tester
            .widgetList<TickerMode>(find.byType(TickerMode))
            .map((widget) => widget.enabled)
            .toList(),
        [true, false, false, false, false],
      );
    });

    testWidgets('rapid retargeting settles without dropping branch state',
        (tester) async {
      await tester.pumpWidget(_harness(0));
      await tester.pumpAndSettle();

      await tester.pumpWidget(_harness(1));
      await tester.pump(const Duration(milliseconds: 70));

      await tester.pumpWidget(_harness(4));
      await tester.pump(const Duration(milliseconds: 65));

      await tester.pumpWidget(_harness(0));
      await tester.pumpAndSettle();

      for (final label in _labels) {
        expect(find.text(label), findsOneWidget);
      }
      expect(
        tester
            .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
            .map((widget) => widget.opacity)
            .toList(),
        [1, 0, 0, 0, 0],
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('reduced motion makes every branch animation immediate',
        (tester) async {
      await tester.pumpWidget(_harness(0, reduceMotion: true));
      await tester.pumpWidget(_harness(3, reduceMotion: true));

      expect(
        tester
            .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
            .every((widget) => widget.duration == Duration.zero),
        isTrue,
      );
      expect(
        tester
            .widgetList<AnimatedSlide>(find.byType(AnimatedSlide))
            .every((widget) => widget.duration == Duration.zero),
        isTrue,
      );
      expect(
        tester
            .widgetList<AnimatedScale>(find.byType(AnimatedScale))
            .every((widget) => widget.duration == Duration.zero),
        isTrue,
      );
      expect(
        tester
            .widgetList<TickerMode>(find.byType(TickerMode))
            .map((widget) => widget.enabled)
            .toList(),
        [false, false, false, true, false],
      );
      expect(tester.takeException(), isNull);
    });
  });
}

const _labels = ['Today', 'Calendar', 'Log', 'Insights', 'Learn'];

Widget _harness(int currentIndex, {bool reduceMotion = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: SizedBox.expand(
        child: NylaBranchMotion(
          currentIndex: currentIndex,
          reduceMotion: reduceMotion,
          children: [
            for (final label in _labels)
              ColoredBox(
                color: Colors.white,
                child: Center(child: Text(label)),
              ),
          ],
        ),
      ),
    ),
  );
}
