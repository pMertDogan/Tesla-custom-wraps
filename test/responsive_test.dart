import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tesla_custom_wraps/screens/home_page.dart';
import 'package:tesla_custom_wraps/screens/studio_page.dart';
import 'package:tesla_custom_wraps/services/ai_service.dart';
import 'package:tesla_custom_wraps/services/vehicle_service.dart';
import 'package:tesla_custom_wraps/state/app_scope.dart';
import 'package:tesla_custom_wraps/state/app_state.dart';

/// Hosts a screen in the scope the app provides at runtime.
Widget _host(Widget child) {
  return AppScope(
    state: AppState(aiService: AiService()),
    child: MaterialApp(home: child),
  );
}

/// Applies a logical screen size to the test window.
void _sizeWindow(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // The studio used to be a fixed three column row, which overflowed as soon
  // as the window was narrower than the columns. These tests pin the phone
  // and landscape layouts that replace it.

  testWidgets('the studio fits a portrait phone', (tester) async {
    _sizeWindow(tester, const Size(420, 860));

    await tester.pumpWidget(
      _host(StudioPage(vehicle: VehicleService.getVehicles().first)),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // The export action is still reachable, it just collapses into an icon.
    expect(find.byTooltip('Export your design'), findsOneWidget);
    expect(find.byTooltip('Settings'), findsOneWidget);
  });

  testWidgets('the studio fits a landscape phone', (tester) async {
    _sizeWindow(tester, const Size(844, 390));

    await tester.pumpWidget(
      _host(StudioPage(vehicle: VehicleService.getVehicles().first)),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('the landing page fits a portrait phone', (tester) async {
    _sizeWindow(tester, const Size(400, 800));

    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // The app bar labels collapse into icons on a narrow screen.
    expect(find.byTooltip('Gallery'), findsOneWidget);
    expect(find.text('GET STARTED'), findsOneWidget);
  });

  testWidgets('the landing page keeps the wide layout on a desktop', (
    tester,
  ) async {
    _sizeWindow(tester, const Size(1920, 1080));

    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    await tester.pumpAndSettle();

    expect(find.text('GALLERY'), findsOneWidget);
    expect(find.byTooltip('Gallery'), findsNothing);
  });
}
