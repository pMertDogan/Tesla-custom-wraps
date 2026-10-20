import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tesla_custom_wraps/main.dart';
import 'package:tesla_custom_wraps/screens/gallery_page.dart';
import 'package:tesla_custom_wraps/screens/studio_page.dart';
import 'package:tesla_custom_wraps/services/ai_service.dart';
import 'package:tesla_custom_wraps/services/vehicle_service.dart';
import 'package:tesla_custom_wraps/state/app_scope.dart';
import 'package:tesla_custom_wraps/state/app_state.dart';

/// Wraps a screen in the scope the app provides at runtime.
Widget _host(Widget child) {
  return AppScope(
    state: AppState(aiService: AiService()),
    child: MaterialApp(home: child),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App boots and shows the home page', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const TeslaWrapStudioApp());
    await tester.pumpAndSettle();

    expect(find.text('TESLA WRAP STUDIO'), findsOneWidget);
    expect(find.text('GET STARTED'), findsOneWidget);
    expect(find.text('CHOOSE YOUR CANVAS'), findsOneWidget);
  });

  testWidgets('Studio page renders for a real vehicle', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final vehicle = VehicleService.getVehicles().first;
    await tester.pumpWidget(_host(StudioPage(vehicle: vehicle)));
    await tester.pumpAndSettle();

    expect(find.text('STUDIO: ${vehicle.name.toUpperCase()}'), findsOneWidget);
    expect(find.text('AI DESIGNER'), findsOneWidget);
    expect(find.text('GENERATE WRAP'), findsOneWidget);
    expect(find.text('PROMPT'), findsOneWidget);
  });

  testWidgets('Gallery page lists Tesla example designs', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_host(const GalleryPage()));
    await tester.pumpAndSettle();

    expect(find.text('WRAP GALLERY'), findsOneWidget);
    expect(find.byType(Image), findsWidgets);
  });

  testWidgets('Every vehicle in the catalog can open the studio', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final vehicle in VehicleService.getVehicles()) {
      await tester.pumpWidget(_host(StudioPage(vehicle: vehicle)));
      await tester.pumpAndSettle();
      expect(
        find.text('STUDIO: ${vehicle.name.toUpperCase()}'),
        findsOneWidget,
        reason: 'Studio should render for ${vehicle.id}',
      );
    }
  });
}
