import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_content/health_content.dart';
import 'package:nyla/core/theme/nyla_theme.dart';
import 'package:nyla/features/learn/learn_screen.dart';

void main() {
  HealthTip firstVisibleTip() => healthTips.firstWhere((tip) => tip.category != TipCategory.seekCare);

  testWidgets('tips surface useful guidance before opening a detail sheet', (tester) async {
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

    final first = firstVisibleTip();
    expect(find.text('Tips').hitTestable(), findsOneWidget);
    expect(find.text('All').hitTestable(), findsOneWidget);
    expect(find.text(first.title).hitTestable(), findsOneWidget);
    expect(find.text(first.flash).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opening a tip keeps its complete explanation available', (tester) async {
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

    final first = firstVisibleTip();
    await tester.tap(find.text(first.title).hitTestable());
    await tester.pumpAndSettle();

    expect(find.text(first.title), findsWidgets);
    expect(find.text(first.flash), findsWidgets);
    expect(find.text(first.details.first), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tips remain usable on a compact-height phone', (tester) async {
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

    final first = firstVisibleTip();
    expect(find.text(first.title).hitTestable(), findsOneWidget);
    expect(find.text(first.flash).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
