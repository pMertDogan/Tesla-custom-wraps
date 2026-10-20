/// How a provider expects image generation requests to be shaped.
enum AiProviderKind {
  /// Google Gemini `generateContent` with `responseModalities: ["IMAGE"]`.
  gemini,

  /// OpenAI-compatible `POST /v1/images/generations`.
  openaiImages,
}

/// A text-to-image provider the studio can talk to.
class AiProvider {
  /// Stable key persisted in settings.
  final String id;

  /// Label shown in the provider picker.
  final String label;

  /// Vendor name, shown as a subtitle.
  final String vendor;

  /// One line explanation of what this provider is good at.
  final String description;

  /// Request/response dialect used to reach the provider.
  final AiProviderKind kind;

  /// Default API base URL.
  final String baseUrl;

  /// Default image model id.
  final String model;

  /// Whether the provider accepts a reference image (the UV template)
  /// alongside the prompt. Providers without support still work, they just
  /// receive the layout described in text only.
  final bool supportsReferenceImage;

  /// Where users can obtain an API key.
  final String? docsUrl;

  const AiProvider({
    required this.id,
    required this.label,
    required this.vendor,
    required this.description,
    required this.kind,
    required this.baseUrl,
    required this.model,
    required this.supportsReferenceImage,
    this.docsUrl,
  });

  /// Whether the user is expected to override the base URL.
  bool get requiresCustomBaseUrl => id == AiProviderCatalog.customOpenAiId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is AiProvider && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'AiProvider($id)';
}

/// The built-in provider catalog.
class AiProviderCatalog {
  const AiProviderCatalog._();

  /// Id of the user-configured OpenAI-compatible provider.
  static const String customOpenAiId = 'custom-openai';

  /// Google Gemini "Nano Banana Pro".
  static const AiProvider gemini3ProImage = AiProvider(
    id: 'gemini-3-pro-image',
    label: 'Gemini 3 Pro Image',
    vendor: 'Google',
    description: 'Highest quality Nano Banana model. Sends the UV template '
        'as a reference image.',
    kind: AiProviderKind.gemini,
    baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
    model: 'gemini-3-pro-image',
    supportsReferenceImage: true,
    docsUrl: 'https://aistudio.google.com/apikey',
  );

  /// Google Gemini "Nano Banana".
  static const AiProvider gemini25FlashImage = AiProvider(
    id: 'gemini-2.5-flash-image',
    label: 'Gemini 2.5 Flash Image',
    vendor: 'Google',
    description: 'Fast and inexpensive Nano Banana model.',
    kind: AiProviderKind.gemini,
    baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
    model: 'gemini-2.5-flash-image',
    supportsReferenceImage: true,
    docsUrl: 'https://aistudio.google.com/apikey',
  );

  /// Google Gemini "Nano Banana 2.1".
  static const AiProvider geminiNanoBanana21 = AiProvider(
    id: 'gemini-nano-banana-2.1',
    label: 'Gemini Nano Banana 2.1',
    vendor: 'Google',
    description: 'Latest Nano Banana generation with reference image support.',
    kind: AiProviderKind.gemini,
    baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
    model: 'gemini-nano-banana-2.1',
    supportsReferenceImage: true,
    docsUrl: 'https://aistudio.google.com/apikey',
  );

  /// Google Gemini 3.1 Flash Image.
  static const AiProvider gemini31FlashImage = AiProvider(
    id: 'gemini-3.1-flash-image',
    label: 'Gemini 3.1 Flash Image',
    vendor: 'Google',
    description: 'Balanced Gemini image model.',
    kind: AiProviderKind.gemini,
    baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
    model: 'gemini-3.1-flash-image',
    supportsReferenceImage: true,
    docsUrl: 'https://aistudio.google.com/apikey',
  );

  /// OpenAI `gpt-image-1`.
  static const AiProvider openAiGptImage = AiProvider(
    id: 'openai-gpt-image-1',
    label: 'OpenAI gpt-image-1',
    vendor: 'OpenAI',
    description: 'Text-to-image model. Receives the layout in prompt text only.',
    kind: AiProviderKind.openaiImages,
    baseUrl: 'https://api.openai.com/v1',
    model: 'gpt-image-1',
    supportsReferenceImage: false,
    docsUrl: 'https://platform.openai.com/api-keys',
  );

  /// OpenAI `dall-e-3`.
  static const AiProvider openAiDallE3 = AiProvider(
    id: 'openai-dall-e-3',
    label: 'OpenAI DALL-E 3',
    vendor: 'OpenAI',
    description: 'Text-to-image model. Receives the layout in prompt text only.',
    kind: AiProviderKind.openaiImages,
    baseUrl: 'https://api.openai.com/v1',
    model: 'dall-e-3',
    supportsReferenceImage: false,
    docsUrl: 'https://platform.openai.com/api-keys',
  );

  /// Any OpenAI-compatible gateway (LiteLLM, OpenRouter, a local proxy...).
  static const AiProvider customOpenAi = AiProvider(
    id: customOpenAiId,
    label: 'Custom OpenAI-compatible',
    vendor: 'Self hosted',
    description: 'Point the studio at any gateway that speaks the OpenAI '
        'images API.',
    kind: AiProviderKind.openaiImages,
    baseUrl: 'https://api.openai.com/v1',
    model: 'gpt-image-1',
    supportsReferenceImage: false,
  );

  /// Every selectable provider, in menu order.
  static const List<AiProvider> all = [
    gemini3ProImage,
    geminiNanoBanana21,
    gemini25FlashImage,
    gemini31FlashImage,
    openAiGptImage,
    openAiDallE3,
    customOpenAi,
  ];

  /// Looks a provider up by id, falling back to [gemini3ProImage].
  static AiProvider byId(String id) {
    for (final provider in all) {
      if (provider.id == id) return provider;
    }
    return gemini3ProImage;
  }
}
