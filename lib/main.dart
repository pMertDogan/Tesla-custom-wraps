import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'screens/home_page.dart';
import 'services/ai_service.dart';
import 'state/app_scope.dart';
import 'state/app_state.dart';

void main() {
  // A release build must not die silently. Framework errors keep their debug
  // presentation, and an error raised outside the framework (an image that
  // fails to decode in the background, a storage write that is refused) is
  // reported instead of taking the whole app down.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('Flutter error: ${details.exception}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught error: $error\n$stack');
    return true;
  };

  runApp(const TeslaWrapStudioApp());
}

/// Root widget of the studio.
class TeslaWrapStudioApp extends StatefulWidget {
  /// Creates the app.
  const TeslaWrapStudioApp({super.key});

  @override
  State<TeslaWrapStudioApp> createState() => _TeslaWrapStudioAppState();
}

class _TeslaWrapStudioAppState extends State<TeslaWrapStudioApp> {
  late final AppState _state = AppState(aiService: AiService());

  @override
  void initState() {
    super.initState();
    _state.load();
  }

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: _state,
      child: MaterialApp(
        title: 'Tesla Wrap Studio',
        debugShowCheckedModeBanner: false,
        theme: buildStudioTheme(),
        home: const HomePage(),
      ),
    );
  }
}
