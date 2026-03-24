import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/main.dart';
import 'package:app/screens/studio_page.dart';
import 'package:app/services/vehicle_service.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    // Wrap in a large enough Container to avoid overflow in some test environments.
    await tester.pumpWidget(const SizedBox(
      width: 2000,
      height: 2000,
      child: MyApp(),
    ));

    // Verify that the title is present.
    expect(find.text('TESLA WRAP STUDIO'), findsOneWidget);
  });

  testWidgets('StudioPage settings dialog has obscured API key field', (WidgetTester tester) async {
    final vehicle = VehicleService.getVehicles().first;

    await tester.pumpWidget(MaterialApp(
      home: StudioPage(vehicle: vehicle),
    ));

    // Find and tap the settings button.
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();

    // Verify the dialog is shown.
    expect(find.text('API SETTINGS'), findsOneWidget);

    // Find the API KEY TextField.
    final apiKeyTextField = find.ancestor(
      of: find.text('API KEY'),
      matching: find.byType(TextField),
    );

    expect(apiKeyTextField, findsOneWidget);

    // Verify it has obscureText set to true.
    final TextField textFieldWidget = tester.widget(apiKeyTextField);
    expect(textFieldWidget.obscureText, isTrue);
  });
}
