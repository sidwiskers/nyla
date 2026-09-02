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

      for (var index = 0; index < _labels.length; index++) {
        expect(find.text(_labels[index]), findsOneWidget);
        expect(_branchOpacity(tester, index), index == 0 ? 1 : 0);
        expect(_branchTickerEnabled(tester, index), index == 0);
        expect(_branchIgnoring(tester, index), index != 0);
        expect(_branchFocusExcluded(tester, index), index != 0);
      }
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

      for (var index = 0; index < _labels.length; index++) {
        expect(find.text(_labels[index]), findsOneWidget);
        expect(_branchOpacity(tester, index), index == 0 ? 1 : 0);
        expect(_branchTickerEnabled(tester, index), index == 0);
        expect(_branchFocusExcluded(tester, index), index != 0);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('reduced motion makes every branch animation immediate',
        (tester) async {
      await tester.pumpWidget(_harness(0, reduceMotion: true));
      await tester.pumpWidget(_harness(3, reduceMotion: true));

      for (var index = 0; index < _labels.length; index++) {
        final branch = _branch(index);
        final opacity = tester.widget<AnimatedOpacity>(
          find.descendant(of: branch, matching: find.byType(AnimatedOpacity)),
        );
        final slide = tester.widget<AnimatedSlide>(
          find.descendant(of: branch, matching: find.byType(AnimatedSlide)),
        );
        final scale = tester.widget<AnimatedScale>(
          find.descendant(of: branch, matching: find.byType(AnimatedScale)),
        );

        expect(opacity.duration, Duration.zero);
        expect(slide.duration, Duration.zero);
        expect(scale.duration, Duration.zero);
        expect(_branchTickerEnabled(tester, index), index == 3);
        expect(_branchFocusExcluded(tester, index), index != 3);
      }
      expect(tester.takeException(), isNull);
    });
  });
}

const _labels = ['Today', 'Calendar', 'Log', 'Insights', 'Learn'];

Finder _branch(int index) => find.byKey(ValueKey('nyla-branch-$index'));

double _branchOpacity(WidgetTester tester, int index) {
  return tester
      .widget<AnimatedOpacity>(
        find.descendant(
          of: _branch(index),
          matching: find.byType(AnimatedOpacity),
        ),
      )
      .opacity;
}

bool _branchTickerEnabled(WidgetTester tester, int index) {
  return tester
      .widget<TickerMode>(
        find.descendant(
          of: _branch(index),
          matching: find.byType(TickerMode),
        ),
      )
      .enabled;
}

bool _branchIgnoring(WidgetTester tester, int index) {
  return tester
      .widget<IgnorePointer>(
        find.descendant(
          of: _branch(index),
          matching: find.byType(IgnorePointer),
        ),
      )
      .ignoring;
}

bool _branchFocusExcluded(WidgetTester tester, int index) {
  return tester
      .widget<ExcludeFocus>(
        find.descendant(
          of: _branch(index),
          matching: find.byType(ExcludeFocus),
        ),
      )
      .excluding;
}

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
