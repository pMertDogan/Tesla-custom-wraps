import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/screens/studio_page.dart';
import 'package:app/models/tesla_model.dart';

void main() {
  testWidgets('StudioPage has Tooltips and Semantics for icon buttons', (
    WidgetTester tester,
  ) async {
    final vehicle = TeslaModel(
      id: 'm3',
      name: 'Model 3',
      description: 'Test description',
      imagePath: 'assets/model3/vehicle_image.png',
      templatePath: 'assets/model3/template.png',
      exampleWraps: [],
    );

    // Increase screen size to avoid overflows and ensure all widgets are in view
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Enable semantics for the test
    final SemanticsHandle handle = tester.ensureSemantics();

    await tester.pumpWidget(MaterialApp(home: StudioPage(vehicle: vehicle)));
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

    // Check Manual Control Sliders
    expect(find.byTooltip('Adjust Opacity'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Opacity')), findsOneWidget);

    expect(find.byTooltip('Adjust Metallic'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Metallic')), findsOneWidget);

    expect(find.byTooltip('Adjust Roughness'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Roughness')), findsOneWidget);

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
}
