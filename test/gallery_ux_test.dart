import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tesla_custom_wraps/screens/home_page.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

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

    // The gallery sits below the hero and the vehicle carousel, so it has to
    // be scrolled into view before the lazily built tiles exist.
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -1600));
    await tester.pumpAndSettle();

    // Check Like buttons in gallery
    expect(find.byTooltip('Like this design'), findsAtLeastNWidgets(1));
    expect(find.bySemanticsLabel('Like design'), findsAtLeastNWidgets(1));

    // Test SnackBar on click
    await tester.tap(find.byTooltip('Like this design').first);
    await tester.pumpAndSettle();

    expect(find.text('Added to your favorites!'), findsOneWidget);

    handle.dispose();
  });
}
