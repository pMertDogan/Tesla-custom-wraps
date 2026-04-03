import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/screens/home_page.dart';

void main() {
  testWidgets('HomePage Gallery items have Tooltips and Semantics for Like action', (
    WidgetTester tester,
  ) async {
    // Increase screen size to avoid overflows and ensure all widgets are in view
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Enable semantics for the test
    final SemanticsHandle handle = tester.ensureSemantics();

    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    await tester.pumpAndSettle();

    // Check Like buttons in gallery
    expect(find.byTooltip('Like this design'), findsAtLeastNWidgets(1));
    expect(find.bySemanticsLabel('Like this design'), findsAtLeastNWidgets(1));

    // Scroll down manually to reveal the gallery
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -1000));
    await tester.pumpAndSettle();

    // Test SnackBar on click
    await tester.tap(find.byTooltip('Like this design').first);
    await tester.pump(); // Start animation
    await tester.pump(const Duration(milliseconds: 500)); // Wait for snackbar to appear

    expect(find.text('Added to your favorites!'), findsOneWidget);

    handle.dispose();
  });
}
