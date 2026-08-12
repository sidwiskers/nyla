import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_content/health_content.dart';
import 'package:nyla/core/theme/nyla_theme.dart';
import 'package:nyla/features/learn/learn_screen.dart';

void main() {
  testWidgets('flashcard shows useful content before any source link', (tester) async {
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
    expect(find.text(first.title), findsOneWidget);
    expect(find.text(first.flash), findsOneWidget);
    expect(find.text('THE TAKEAWAY'), findsOneWidget);
    expect(find.text('Read the full card'), findsOneWidget);
    expect(find.text('Reviewed sources'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opening a flashcard keeps the full explanation inside the card', (tester) async {
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

    await tester.tap(find.text('Read the full card'));
    await tester.pumpAndSettle();

    final first = healthTips.first;
    expect(find.text(first.flash), findsOneWidget);
    for (final paragraph in first.details) {
      expect(find.text(paragraph), findsOneWidget);
    }
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the deck remains usable on a compact-height phone', (tester) async {
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

    expect(find.text('Read the full card'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
