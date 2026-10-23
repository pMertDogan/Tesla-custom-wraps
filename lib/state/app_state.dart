import 'package:flutter/foundation.dart';

import '../models/ai_provider.dart';
import '../models/ai_settings.dart';
import '../models/wrap_design.dart';
import '../services/ai_service.dart';
import '../services/settings_service.dart';

/// Shared application state: AI settings plus the designs generated so far.
///
/// Held as a [ChangeNotifier] so screens can rebuild without pulling in a
/// state management dependency.
class AppState extends ChangeNotifier {
  /// Creates the state and loads the persisted settings.
  AppState({
    required AiService aiService,
    SettingsService settingsService = const SettingsService(),
  })  : _aiService = aiService,
        _settingsService = settingsService,
        _settings = AiSettings.empty;

  /// How many generated designs are kept in the session history.
  static const int historyLimit = 12;

  final AiService _aiService;
  final SettingsService _settingsService;

  AiSettings _settings;
  final List<WrapDesign> _history = [];

  /// The AI service used for generation.
  AiService get aiService => _aiService;

  /// Current settings.
  AiSettings get settings => _settings;

  /// The currently selected provider.
  AiProvider get provider => AiProviderCatalog.byId(_settings.providerId);

  /// Designs generated during this session, newest first.
  List<WrapDesign> get history => List.unmodifiable(_history);

  /// Loads the persisted settings. Call once during startup.
  ///
  /// Storage can be unavailable (private browsing, a blocked local storage
  /// quota), and a first run has nothing stored yet. Neither is a reason to
  /// keep the studio from opening, so the defaults stay in place and the
  /// failure only costs the previously saved settings.
  Future<void> load() async {
    try {
      _settings = await _settingsService.load();
    } on Object catch (error) {
      debugPrint('Could not load the saved settings: $error');
    }
    notifyListeners();
  }

  /// Replaces the settings, persists them and notifies listeners.
  Future<void> updateSettings(AiSettings settings) async {
    _settings = settings;
    notifyListeners();
    try {
      await _settingsService.save(settings);
    } on Object catch (error) {
      // The settings are live for this session either way; only persistence
      // failed.
      debugPrint('Could not save the settings: $error');
    }
  }

  /// Adds a generated design to the session history.
  void addDesign(WrapDesign design) {
    _history.insert(0, design);
    if (_history.length > historyLimit) {
      _history.removeRange(historyLimit, _history.length);
    }
    notifyListeners();
  }

  /// Removes a design from the session history.
  void removeDesign(String id) {
    _history.removeWhere((design) => design.id == id);
    notifyListeners();
  }
}
