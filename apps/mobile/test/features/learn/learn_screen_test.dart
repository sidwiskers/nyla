import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_content/health_content.dart';
import 'package:nyla/core/theme/nyla_theme.dart';
import 'package:nyla/features/learn/learn_screen.dart';

void main() {
  testWidgets('flashcard front is useful before opening references', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
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

    final first = healthTips.first;
    expect(find.text(first.title).hitTestable(), findsOneWidget);
    expect(find.text(first.flash).hitTestable(), findsOneWidget);
    expect(find.text('THE TAKEAWAY').hitTestable(), findsOneWidget);
    expect(find.text('Turn card').hitTestable(), findsOneWidget);
    expect(find.textContaining('References · reviewed').hitTestable(), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('turning a flashcard keeps the complete explanation in the deck', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
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

    final turn = find.text('Turn card').hitTestable();
    expect(turn, findsOneWidget);
    await tester.tap(turn);
    await tester.pumpAndSettle();

    final first = healthTips.first;
    expect(find.text(first.flash).hitTestable(), findsOneWidget);
    for (final paragraph in first.details) {
      expect(find.text(paragraph), findsOneWidget);
    }
    expect(find.byIcon(Icons.close_rounded).hitTestable(), findsOneWidget);
    expect(find.textContaining('References · reviewed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('flashcard front remains immediately usable on a compact-height phone', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
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

    final first = healthTips.first;
    expect(find.text(first.title).hitTestable(), findsOneWidget);
    expect(find.text(first.flash).hitTestable(), findsOneWidget);
    expect(find.text('THE TAKEAWAY').hitTestable(), findsOneWidget);
    expect(find.text('Turn card').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
