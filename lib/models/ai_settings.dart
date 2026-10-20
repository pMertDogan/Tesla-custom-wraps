/// User configurable AI settings.
class AiSettings {
  /// Id of the selected [AiProvider].
  final String providerId;

  /// API key used to authenticate against the provider.
  ///
  /// Held in memory by default. It is only written to disk when
  /// [persistApiKey] is enabled.
  final String apiKey;

  /// Overrides [AiProvider.baseUrl] when set.
  final String? baseUrlOverride;

  /// Overrides [AiProvider.model] when set.
  final String? modelOverride;

  /// Whether the API key is written to local storage.
  final bool persistApiKey;

  const AiSettings({
    required this.providerId,
    required this.apiKey,
    this.baseUrlOverride,
    this.modelOverride,
    this.persistApiKey = false,
  });

  /// Settings with no provider selected and no credentials.
  ///
  /// The default provider is the one that needs no account at all, so a fresh
  /// install can draw a wrap without the user hunting for an API key first.
  static const AiSettings empty = AiSettings(
    providerId: 'pollinations-flux',
    apiKey: '',
  );

  /// Whether an API key is available for requests.
  bool get hasApiKey => apiKey.trim().isNotEmpty;

  /// Whether a custom base URL was configured.
  bool get hasBaseUrlOverride =>
      baseUrlOverride != null && baseUrlOverride!.trim().isNotEmpty;

  /// Whether a custom model was configured.
  bool get hasModelOverride =>
      modelOverride != null && modelOverride!.trim().isNotEmpty;

  AiSettings copyWith({
    String? providerId,
    String? apiKey,
    String? baseUrlOverride,
    String? modelOverride,
    bool? persistApiKey,
    bool clearBaseUrlOverride = false,
    bool clearModelOverride = false,
  }) {
    return AiSettings(
      providerId: providerId ?? this.providerId,
      apiKey: apiKey ?? this.apiKey,
      baseUrlOverride: clearBaseUrlOverride
          ? null
          : (baseUrlOverride ?? this.baseUrlOverride),
      modelOverride: clearModelOverride
          ? null
          : (modelOverride ?? this.modelOverride),
      persistApiKey: persistApiKey ?? this.persistApiKey,
    );
  }

  @override
  String toString() => 'AiSettings(providerId: $providerId, '
      'hasApiKey: $hasApiKey)';
}
