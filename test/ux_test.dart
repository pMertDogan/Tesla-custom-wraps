import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tesla_custom_wraps/screens/studio_page.dart';
import 'package:tesla_custom_wraps/services/ai_service.dart';
import 'package:tesla_custom_wraps/services/vehicle_service.dart';
import 'package:tesla_custom_wraps/state/app_scope.dart';
import 'package:tesla_custom_wraps/state/app_state.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('StudioPage has Tooltips and Semantics for icon buttons', (
    WidgetTester tester,
  ) async {
    final vehicle = VehicleService.getVehicles().first;

    // Increase screen size to avoid overflows and ensure all widgets are in view
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Enable semantics for the test
    final SemanticsHandle handle = tester.ensureSemantics();

    await tester.pumpWidget(
      AppScope(
        state: AppState(aiService: AiService()),
        child: MaterialApp(home: StudioPage(vehicle: vehicle)),
      ),
    );
    await tester.pumpAndSettle();

    // Check Settings button
    expect(find.byTooltip('Settings'), findsOneWidget);
    expect(find.bySemanticsLabel('Open settings'), findsOneWidget);

    // Check Export button
    expect(find.byTooltip('Export your design'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp(r'^Export wrap design')),
      findsOneWidget,
    );

    // Check Generate button
    expect(
      find.byTooltip('Generate a new wrap design based on your prompt'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Generate wrap design'), findsOneWidget);

    // Check preview control sliders.
    // Metallic and Roughness are 3D material properties and move to the 3D
    // preview milestone, so they are intentionally not on this screen.
    expect(find.byTooltip('Adjust Opacity'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Opacity')), findsOneWidget);

    expect(find.byTooltip('Adjust Zoom'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'Zoom level')), findsOneWidget);

    // Check Rotate Left button
    expect(find.byTooltip('Rotate Left'), findsOneWidget);
    expect(find.bySemanticsLabel('Rotate vehicle left'), findsOneWidget);

    // Check Zoom In button
    expect(find.byTooltip('Zoom In'), findsOneWidget);
    expect(find.bySemanticsLabel('Zoom in on vehicle'), findsOneWidget);

    // Check Sidebar Actions
    expect(find.byTooltip('Draw'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Draw')), findsAtLeastNWidgets(1));

    expect(find.byTooltip('Text'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Text')), findsAtLeastNWidgets(1));

    expect(find.byTooltip('Logo'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Logo')), findsAtLeastNWidgets(1));

    expect(find.byTooltip('Layers'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Layers')), findsAtLeastNWidgets(1));

    handle.dispose();
  });

  testWidgets('StudioPage shows the provider and style pickers', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      AppScope(
        state: AppState(aiService: AiService()),
        child: MaterialApp(
          home: StudioPage(vehicle: VehicleService.getVehicles().first),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AI PROVIDER'), findsOneWidget);
    expect(find.text('STYLE'), findsOneWidget);
    expect(find.text('PREVIEW CONTROLS'), findsOneWidget);
    expect(find.byType(DropdownButton<String>), findsNWidgets(2));
  });
}
