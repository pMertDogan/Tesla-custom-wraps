import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/main.dart';
import 'package:app/screens/studio_page.dart';
import 'package:app/screens/gallery_page.dart';
import 'package:app/services/vehicle_service.dart';
import 'package:app/providers/design_provider.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const SizedBox(width: 2000, height: 2000, child: MyApp()),
    );

    expect(find.text('TESLA WRAP STUDIO'), findsOneWidget);
  });

  testWidgets('StudioPage settings dialog has obscured API key field', (
    WidgetTester tester,
  ) async {
    final vehicle = VehicleService.getVehicles().first;

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => DesignProvider(),
        child: MaterialApp(home: StudioPage(vehicle: vehicle)),
      ),
    );

    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();

    expect(find.text('API SETTINGS'), findsOneWidget);

    final apiKeyTextField = find.ancestor(
      of: find.text('API KEY'),
      matching: find.byType(TextField),
    );

    expect(apiKeyTextField, findsOneWidget);

    final TextField textFieldWidget = tester.widget(apiKeyTextField);
    expect(textFieldWidget.obscureText, isTrue);
    expect(textFieldWidget.autocorrect, isFalse);
    expect(textFieldWidget.enableSuggestions, isFalse);
  });

  testWidgets('StudioPage TextFields have security enhancements', (
    WidgetTester tester,
  ) async {
    final vehicle = VehicleService.getVehicles().first;

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => DesignProvider(),
        child: MaterialApp(home: StudioPage(vehicle: vehicle)),
      ),
    );

    final promptTextFieldFinder = find.byType(TextField).first;
    final TextField promptTextField = tester.widget(promptTextFieldFinder);
    expect(promptTextField.maxLength, 1000);

    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();

    final apiKeyTextFieldFinder = find.ancestor(
      of: find.text('API KEY'),
      matching: find.byType(TextField),
    );
    final TextField apiKeyTextField = tester.widget(apiKeyTextFieldFinder);

    expect(apiKeyTextField.autocorrect, isFalse);
    expect(apiKeyTextField.enableSuggestions, isFalse);
    expect(apiKeyTextField.maxLength, 512);

    final baseUrlTextFieldFinder = find.ancestor(
      of: find.text('CUSTOM BASE URL (Optional)'),
      matching: find.byType(TextField),
    );
    final TextField baseUrlTextField = tester.widget(baseUrlTextFieldFinder);

    expect(baseUrlTextField.maxLength, 512);
  });

  testWidgets('StudioPage has save button and export button', (
    WidgetTester tester,
  ) async {
    final vehicle = VehicleService.getVehicles().first;

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => DesignProvider(),
        child: MaterialApp(home: StudioPage(vehicle: vehicle)),
      ),
    );

    expect(find.byIcon(Icons.save), findsOneWidget);
    expect(find.text('EXPORT'), findsOneWidget);
  });

  testWidgets('GalleryPage can be navigated to', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => DesignProvider(),
        child: const MaterialApp(home: GalleryPage()),
      ),
    );

    expect(find.text('COMMUNITY GALLERY'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget); // Search bar
  });

  testWidgets('DesignProvider manages state correctly', (WidgetTester tester) async {
    final provider = DesignProvider();

    expect(provider.layers, isEmpty);
    expect(provider.drawingStrokes, isEmpty);
    expect(provider.isGenerating, isFalse);
    expect(provider.opacity, 0.8);
    expect(provider.metallic, 0.2);
    expect(provider.roughness, 0.5);

    provider.setOpacity(0.5);
    expect(provider.opacity, 0.5);

    provider.setMetallic(0.7);
    expect(provider.metallic, 0.7);

    provider.setRoughness(0.3);
    expect(provider.roughness, 0.3);

    provider.setActiveTool('draw');
    expect(provider.activeTool, 'draw');

    provider.setActiveTool('select');
    expect(provider.activeTool, 'select');
  });
}
