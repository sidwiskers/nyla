import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_content/health_content.dart';
import 'package:nyla/core/theme/nyla_theme.dart';
import 'package:nyla/features/learn/learn_screen.dart';

void main() {
  Future<void> pumpLearn(
    WidgetTester tester, {
    Size size = const Size(360, 800),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: NylaTheme.light,
        home: const Scaffold(body: LearnScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder firstCard() => find.byKey(
        ValueKey('learn-card-tap-${healthTips.first.id}'),
      );

  testWidgets('front card is useful without source clutter', (tester) async {
    await pumpLearn(tester);

    final first = healthTips.first;
    expect(firstCard(), findsOneWidget);
    expect(find.text(first.title).hitTestable(), findsOneWidget);
    expect(find.text(first.flash).hitTestable(), findsOneWidget);
    expect(find.text('Tap to flip').hitTestable(), findsOneWidget);
    expect(find.text('Reviewed sources'), findsNothing);
    expect(find.text('World Health Organization'), findsNothing);
    expect(find.text('Body'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a card flips to its full explanation', (tester) async {
    await pumpLearn(tester);

    await tester.tap(firstCard());
    await tester.pump(const Duration(milliseconds: 360));

    final first = healthTips.first;
    expect(find.text('Flip back'), findsOneWidget);
    expect(find.text(first.flash), findsOneWidget);
    for (final paragraph in first.details) {
      expect(find.text(paragraph), findsOneWidget);
    }
    expect(find.text('Reviewed sources'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact phone card remains reachable without overflow', (
    tester,
  ) async {
    await pumpLearn(tester, size: const Size(360, 640));

    expect(firstCard(), findsOneWidget);
    await tester.ensureVisible(firstCard());
    await tester.pumpAndSettle();

    expect(firstCard().hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tablet layout keeps the deck constrained and clean', (tester) async {
    await pumpLearn(tester, size: const Size(900, 1200));

    expect(find.text('Learn'), findsOneWidget);
    expect(firstCard().hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
