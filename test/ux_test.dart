import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
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

    // The 3D preview is not live yet, so the studio must not show camera
    // controls that do nothing.
    expect(find.byTooltip('Rotate Left'), findsNothing);
    expect(find.bySemanticsLabel('Rotate vehicle left'), findsNothing);
    expect(find.byTooltip('Rotate Right'), findsNothing);
    expect(find.bySemanticsLabel('Rotate vehicle right'), findsNothing);

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

  testWidgets('Studio generates without an API key for a keyless provider', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'ai.provider_id': 'pollinations-flux',
    });

    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = AiService(
      client: MockClient(
        (_) async => http.Response.bytes(_solidPng(), 200),
      ),
    );

    final state = AppState(aiService: service);
    await state.load();

    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(
          home: StudioPage(vehicle: VehicleService.getVehicles().first),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The studio tells the user that this provider needs no key.
    expect(
      find.text(
        'No API key needed. Draws a flat pattern and clips it to the panels. '
        'One free image every 45 seconds.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.bySemanticsLabel('Generate wrap design'));
    await tester.pumpAndSettle();

    // The request went straight out instead of stopping at the settings
    // dialog, and the design landed in the session history.
    expect(find.text('AI SETTINGS'), findsNothing);
    expect(state.history, hasLength(1));
  });
}

/// A plain PNG the fake provider can hand back.
List<int> _solidPng() {
  final image = img.Image(width: 256, height: 256);
  img.fill(image, color: img.ColorRgb8(20, 90, 160));
  return img.encodePng(image);
}
