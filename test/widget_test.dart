import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/main.dart';
import 'package:app/screens/studio_page.dart';
import 'package:app/services/vehicle_service.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('TESLA WRAP STUDIO'), findsOneWidget);
  });

  testWidgets('StudioPage displays ModelViewer', (WidgetTester tester) async {
    final vehicle = VehicleService.getVehicles().first;
    // We can't easily test ModelViewer in unit tests because of WebView platform dependency.
    // However, we can check if the widget exists in the tree before it tries to initialize the platform part.
    await tester.pumpWidget(MaterialApp(
      home: StudioPage(vehicle: vehicle),
    ));

    expect(find.byType(ModelViewer), findsOneWidget);
  });
}
