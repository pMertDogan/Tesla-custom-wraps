import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'screens/home_page.dart';
import 'services/ai_service.dart';
import 'state/app_scope.dart';
import 'state/app_state.dart';

void main() {
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
