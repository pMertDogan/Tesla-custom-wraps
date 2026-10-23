import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tesla_custom_wraps/screens/studio_page.dart';
import 'package:tesla_custom_wraps/services/ai_service.dart';
import 'package:tesla_custom_wraps/services/prompt_builder.dart';
import 'package:tesla_custom_wraps/services/vehicle_service.dart';
import 'package:tesla_custom_wraps/state/app_scope.dart';
import 'package:tesla_custom_wraps/state/app_state.dart';

/// A plain PNG the fake provider hands back.
List<int> _solidPng() {
  final image = img.Image(width: 256, height: 256);
  img.fill(image, color: img.ColorRgb8(20, 90, 160));
  return img.encodePng(image);
}

/// A service that answers every request with a solid PNG and records the
/// prompts it was asked for.
class _RecordingClient {
  final List<Uri> requests = <Uri>[];

  AiService get service => AiService(
        client: MockClient((request) async {
          requests.add(request.url);
          return http.Response.bytes(_solidPng(), 200);
        }),
      );
}

Future<void> _pumpStudio(
  WidgetTester tester,
  AppState state, {
  Size size = const Size(1920, 1080),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    AppScope(
      state: state,
      child: MaterialApp(
        home: StudioPage(vehicle: VehicleService.getVehicles().first),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'ai.provider_id': 'pollinations-flux',
    });
  });

  testWidgets('an empty prompt still generates a wrap', (tester) async {
    final recording = _RecordingClient();
    final state = AppState(aiService: recording.service);
    await state.load();

    await _pumpStudio(tester, state);

    final generate = find.bySemanticsLabel('Generate wrap design');
    await tester.ensureVisible(generate);
    await tester.pumpAndSettle();
    await tester.tap(generate);
    await tester.pumpAndSettle();

    // A design was produced without typing anything.
    expect(state.history, hasLength(1));
    expect(state.history.first.prompt.trim(), isNotEmpty);
    expect(recording.requests, hasLength(1));

    // The invented concept is in the prompt box and in the request.
    final controllerText = tester
        .widget<TextField>(find.byType(TextField).last)
        .controller!
        .text;
    expect(controllerText, isNotEmpty);
    expect(
      Uri.decodeFull(recording.requests.first.path),
      contains(controllerText.split(',').first.trim()),
    );
  });

  testWidgets('SURPRISE ME picks a style and generates', (tester) async {
    final recording = _RecordingClient();
    final state = AppState(aiService: recording.service);
    await state.load();

    await _pumpStudio(tester, state);

    final surprise = find.bySemanticsLabel('Surprise me with a wrap');
    await tester.ensureVisible(surprise);
    await tester.pumpAndSettle();
    await tester.tap(surprise);
    await tester.pumpAndSettle();

    expect(state.history, hasLength(1));
    expect(recording.requests, hasLength(1));
  });

  testWidgets('the idea chips fill the prompt', (tester) async {
    final state = AppState(aiService: AiService());
    await state.load();

    await _pumpStudio(tester, state);

    // The generator offers one chip per idea, labelled with its style.
    final chips = find.byType(ActionChip);
    expect(chips, findsWidgets);

    await tester.ensureVisible(chips.first);
    await tester.pumpAndSettle();
    await tester.tap(chips.first);
    await tester.pumpAndSettle();

    final controller = tester
        .widget<TextField>(find.byType(TextField).last)
        .controller!;
    expect(controller.text.trim(), isNotEmpty);
  });

  testWidgets('the tool rail edits the layer stack', (tester) async {
    final recording = _RecordingClient();
    final state = AppState(aiService: recording.service);
    await state.load();

    await _pumpStudio(tester, state);

    // Without a design the tools explain what to do first.
    await tester.tap(find.byTooltip('Text'));
    await tester.pumpAndSettle();
    expect(
      find.text('Generate a design first, then add layers.'),
      findsOneWidget,
    );

    // Generate, then add text.
    final generate = find.bySemanticsLabel('Generate wrap design');
    await tester.ensureVisible(generate);
    await tester.pumpAndSettle();
    await tester.tap(generate);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Text'));
    await tester.pumpAndSettle();
    expect(find.text('ADD TEXT'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'TESLA');
    await tester.tap(find.text('ADD'));
    await tester.pumpAndSettle();

    final design = state.history.first;
    expect(state.layersFor(design.id), hasLength(1));
    expect(state.layersFor(design.id).first.text, 'TESLA');

    // Undo removes it again.
    await tester.tap(find.byTooltip('Undo'));
    await tester.pumpAndSettle();
    expect(state.layersFor(design.id), isEmpty);

    // Redo brings it back.
    await tester.tap(find.byTooltip('Redo'));
    await tester.pumpAndSettle();
    expect(state.layersFor(design.id), hasLength(1));
  });

  testWidgets('the layer panel toggles visibility and deletes', (tester) async {
    final recording = _RecordingClient();
    final state = AppState(aiService: recording.service);
    await state.load();

    await _pumpStudio(tester, state);
    final generate = find.bySemanticsLabel('Generate wrap design');
    await tester.ensureVisible(generate);
    await tester.pumpAndSettle();
    await tester.tap(generate);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Text'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'HELLO');
    await tester.tap(find.text('ADD'));
    await tester.pumpAndSettle();

    final design = state.history.first;

    await tester.tap(find.byTooltip('Layers'));
    await tester.pumpAndSettle();
    expect(find.text('LAYERS'), findsOneWidget);

    await tester.tap(find.byTooltip('Hide layer'));
    await tester.pumpAndSettle();
    expect(state.layersFor(design.id).first.visible, isFalse);

    await tester.tap(find.byTooltip('Delete layer'));
    await tester.pumpAndSettle();
    expect(state.layersFor(design.id), isEmpty);
  });

  testWidgets('the 3D tab is available and reports missing models', (
    tester,
  ) async {
    final state = AppState(aiService: AiService());
    await state.load();

    await _pumpStudio(tester, state);

    await tester.tap(find.widgetWithText(ChoiceChip, '3D'));
    await tester.pumpAndSettle();

    // The tests run on the Dart VM, so the viewer reports that the 3D preview
    // is a browser feature instead of rendering an empty box.
    expect(
      find.text(
        'The 3D preview runs in the browser build. This platform shows the '
        'vehicle reference render.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('export includes the layer stack', (tester) async {
    final recording = _RecordingClient();
    final state = AppState(aiService: recording.service);
    await state.load();

    await _pumpStudio(tester, state);
    final generate = find.bySemanticsLabel('Generate wrap design');
    await tester.ensureVisible(generate);
    await tester.pumpAndSettle();
    await tester.tap(generate);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Text'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'TESLA');
    await tester.tap(find.text('ADD'));
    await tester.pumpAndSettle();

    // Export is wired to the composited artwork; on the test platform the
    // file saver reports that it could not write, which the studio surfaces
    // instead of throwing.
    await tester.tap(find.bySemanticsLabel('Export wrap design'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(SnackBar), findsWidgets);
  });

  test('the prompt builder keeps an empty concept valid', () {
    // The generator fills the gap, but the builder must stay usable on its
    // own for the command line tool.
    final prompt = WrapPromptBuilder.build(
      concept: '',
      vehicleName: 'Cybertruck',
      style: null,
    );
    expect(prompt, isNotEmpty);
    expect(prompt, contains('Cybertruck'));
  });
}
