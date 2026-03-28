import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/screens/studio_page.dart';
import 'package:app/models/tesla_model.dart';

void main() {
  testWidgets('StudioPage has Tooltips and Semantics for icon buttons', (WidgetTester tester) async {
    final vehicle = TeslaModel(
      id: 'm3',
      name: 'Model 3',
      description: 'Test description',
      imagePath: 'assets/model3/vehicle_image.png',
      templatePath: 'assets/model3/template.png',
      exampleWraps: [],
    );

    // Enable semantics for the test
    final SemanticsHandle handle = tester.ensureSemantics();

    await tester.pumpWidget(MaterialApp(
      home: StudioPage(vehicle: vehicle),
    ));

    // Check Settings button
    expect(find.byTooltip('Settings'), findsOneWidget);
    expect(find.bySemanticsLabel('Open settings'), findsOneWidget);

    // Check Rotate Left button
    expect(find.byTooltip('Rotate Left'), findsOneWidget);
    expect(find.bySemanticsLabel('Rotate vehicle left'), findsOneWidget);

    // Check Zoom In button
    expect(find.byTooltip('Zoom In'), findsOneWidget);
    expect(find.bySemanticsLabel('Zoom in on vehicle'), findsOneWidget);

    handle.dispose();
  });
}
