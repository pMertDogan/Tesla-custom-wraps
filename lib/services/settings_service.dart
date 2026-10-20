import 'package:shared_preferences/shared_preferences.dart';

import '../models/ai_settings.dart';

/// Persists the AI settings between sessions.
///
/// The API key is only written to disk when the user explicitly opts in, so a
/// shared machine does not silently keep a credential around.
class SettingsService {
  const SettingsService();

  static const String _providerIdKey = 'ai.provider_id';
  static const String _baseUrlKey = 'ai.base_url';
  static const String _modelKey = 'ai.model';
  static const String _apiKeyKey = 'ai.api_key';
  static const String _persistApiKeyKey = 'ai.persist_api_key';

  /// Reads the stored settings.
  ///
  /// When the user did not opt into persisting the API key, the key is
  /// returned empty even if a stale value is still on disk.
  Future<AiSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final persistApiKey = prefs.getBool(_persistApiKeyKey) ?? false;
    final storedKey = prefs.getString(_apiKeyKey) ?? '';

    return AiSettings(
      providerId: prefs.getString(_providerIdKey) ?? AiSettings.empty.providerId,
      apiKey: persistApiKey ? storedKey : '',
      baseUrlOverride: _nullIfEmpty(prefs.getString(_baseUrlKey)),
      modelOverride: _nullIfEmpty(prefs.getString(_modelKey)),
      persistApiKey: persistApiKey,
    );
  }

  /// Writes the settings.
  ///
  /// When [AiSettings.persistApiKey] is false the stored key is removed.
  Future<void> save(AiSettings settings) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_providerIdKey, settings.providerId);
    await prefs.setBool(_persistApiKeyKey, settings.persistApiKey);

    final baseUrl = settings.baseUrlOverride?.trim() ?? '';
    if (baseUrl.isEmpty) {
      await prefs.remove(_baseUrlKey);
    } else {
      await prefs.setString(_baseUrlKey, baseUrl);
    }

    final model = settings.modelOverride?.trim() ?? '';
    if (model.isEmpty) {
      await prefs.remove(_modelKey);
    } else {
      await prefs.setString(_modelKey, model);
    }

    if (settings.persistApiKey) {
      await prefs.setString(_apiKeyKey, settings.apiKey.trim());
    } else {
      await prefs.remove(_apiKeyKey);
    }
  }

  /// Removes every stored setting.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_providerIdKey);
    await prefs.remove(_baseUrlKey);
    await prefs.remove(_modelKey);
    await prefs.remove(_apiKeyKey);
    await prefs.remove(_persistApiKeyKey);
  }

  static String? _nullIfEmpty(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
