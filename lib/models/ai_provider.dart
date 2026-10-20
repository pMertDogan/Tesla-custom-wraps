/// How a provider expects image generation requests to be shaped.
enum AiProviderKind {
  /// Google Gemini `generateContent` with `responseModalities: ["IMAGE"]`.
  gemini,

  /// OpenAI-compatible `POST /v1/images/generations`.
  openaiImages,

  /// OpenRouter dedicated Image API `POST /api/v1/images`.
  ///
  /// OpenRouter speaks its own dialect: it accepts the UV template as an
  /// `input_references` entry, which is what keeps the generated artwork
  /// aligned with the vehicle panels.
  openRouterImages,

  /// Cloudflare Workers AI `POST /accounts/{id}/ai/run/{model}`.
  ///
  /// Cloudflare gives every account a free daily neuron allowance, so this
  /// is the only provider that can generate a wrap without paying. The
  /// request is a multipart form and the template travels as a file.
  cloudflareWorkersAi,

  /// Pollinations `GET /prompt/{text}`.
  ///
  /// No account and no API key: the studio can draw a wrap the moment it
  /// is opened. The service is slower than the others and puts a small
  /// watermark in the corner, but the panel mask crops that away.
  pollinations,
}

/// How the request body has to be encoded for a provider.
///
/// Workers AI is not consistent about this: the FLUX 2 models only accept a
/// multipart form, while FLUX 1 schnell only accepts JSON and rejects a
/// multipart body outright.
enum AiBodyFormat {
  /// A JSON object.
  json,

  /// A multipart form with the reference image as a file part.
  multipart,
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

  /// How the request body is encoded.
  ///
  /// Only Workers AI cares: its FLUX 2 models want a multipart form, its
  /// FLUX 1 models want JSON. Everything else speaks JSON.
  final AiBodyFormat bodyFormat;

  /// Whether the provider needs an API key.
  ///
  /// Pollinations serves images without an account, so the studio can draw
  /// a wrap without asking for anything.
  final bool requiresApiKey;

  /// Whether the provider actually reproduces the reference layout.
  ///
  /// Most models copy the panel outlines of the UV template they are given.
  /// Pollinations only uses the template as a general colour and texture
  /// cue, so the studio asks it for a flat pattern instead and lets the panel
  /// mask do the alignment.
  final bool followsReferenceLayout;

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
    this.bodyFormat = AiBodyFormat.json,
    this.requiresApiKey = true,
    this.followsReferenceLayout = true,
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

  /// OpenRouter with FLUX 3 Image Klein, the cheapest model on the platform.
  static const AiProvider openRouterFluxKlein = AiProvider(
    id: 'openrouter-flux-3-image-klein',
    label: 'OpenRouter FLUX 3 Klein',
    vendor: 'OpenRouter',
    description: 'Cheapest OpenRouter image model (about \$0.008 per image). '
        'Sends the UV template as a reference image.',
    kind: AiProviderKind.openRouterImages,
    baseUrl: 'https://openrouter.ai/api/v1',
    model: 'black-forest-labs/flux-3-image-klein',
    supportsReferenceImage: true,
    docsUrl: 'https://openrouter.ai/keys',
  );

  /// OpenRouter with Qwen Image 2.1 Turbo.
  static const AiProvider openRouterQwenTurbo = AiProvider(
    id: 'openrouter-qwen-image-2.1-turbo',
    label: 'OpenRouter Qwen Image 2.1 Turbo',
    vendor: 'OpenRouter',
    description: 'Fast and inexpensive OpenRouter model (about \$0.018 per '
        'image). Sends the UV template as a reference image.',
    kind: AiProviderKind.openRouterImages,
    baseUrl: 'https://openrouter.ai/api/v1',
    model: 'qwen/qwen-image-2.1-turbo',
    supportsReferenceImage: true,
    docsUrl: 'https://openrouter.ai/keys',
  );

  /// OpenRouter with Google Nano Banana 2.1.
  static const AiProvider openRouterNanoBanana = AiProvider(
    id: 'openrouter-nano-banana-2.1',
    label: 'OpenRouter Nano Banana 2.1',
    vendor: 'OpenRouter',
    description: 'Latest Nano Banana generation through OpenRouter. Sends the '
        'UV template as a reference image.',
    kind: AiProviderKind.openRouterImages,
    baseUrl: 'https://openrouter.ai/api/v1',
    model: 'google/gemini-nano-banana-2.1',
    supportsReferenceImage: true,
    docsUrl: 'https://openrouter.ai/keys',
  );

  /// OpenRouter with Gemini 3 Pro Image, the highest quality option.
  static const AiProvider openRouterGemini3Pro = AiProvider(
    id: 'openrouter-gemini-3-pro-image',
    label: 'OpenRouter Gemini 3 Pro Image',
    vendor: 'OpenRouter',
    description: 'Highest quality model on OpenRouter. Sends the UV template '
        'as a reference image.',
    kind: AiProviderKind.openRouterImages,
    baseUrl: 'https://openrouter.ai/api/v1',
    model: 'google/gemini-3-pro-image',
    supportsReferenceImage: true,
    docsUrl: 'https://openrouter.ai/keys',
  );

  /// Every selectable provider, in menu order.
  ///
  /// The keyless provider comes first: it is the only one that works without
  /// an account, and burying it under fifteen other entries meant nobody
  /// found it.
  static const List<AiProvider> all = [
    pollinationsFlux,
    gemini3ProImage,
    geminiNanoBanana21,
    gemini25FlashImage,
    gemini31FlashImage,
    openAiGptImage,
    openAiDallE3,
    openRouterFluxKlein,
    openRouterQwenTurbo,
    openRouterNanoBanana,
    openRouterGemini3Pro,
    cloudflareFlux2Dev,
    cloudflareFlux2Klein,
    cloudflareFlux2Klein4b,
    cloudflareFlux1Schnell,
    customOpenAi,
  ];

  /// Cloudflare Workers AI with FLUX 2 dev, the strongest free option.
  static const AiProvider cloudflareFlux2Dev = AiProvider(
    id: 'cloudflare-flux-2-dev',
    label: 'Cloudflare FLUX 2 dev',
    vendor: 'Cloudflare',
    description: 'Free on the Cloudflare daily allowance (about 900 neurons '
        'per image, roughly 11 images a day). Sends the UV template as a '
        'reference image.',
    kind: AiProviderKind.cloudflareWorkersAi,
    baseUrl: 'https://api.cloudflare.com/client/v4/accounts/'
        'YOUR_ACCOUNT_ID/ai/run',
    model: '@cf/black-forest-labs/flux-2-dev',
    supportsReferenceImage: true,
    bodyFormat: AiBodyFormat.multipart,
    docsUrl: 'https://dash.cloudflare.com/profile/api-tokens',
  );

  /// Cloudflare Workers AI with FLUX 2 Klein 9B.
  static const AiProvider cloudflareFlux2Klein = AiProvider(
    id: 'cloudflare-flux-2-klein-9b',
    label: 'Cloudflare FLUX 2 Klein 9B',
    vendor: 'Cloudflare',
    description: 'Free on the Cloudflare daily allowance (about 1,545 '
        'neurons per image, roughly 6 images a day). Sends the UV template '
        'as a reference image.',
    kind: AiProviderKind.cloudflareWorkersAi,
    baseUrl: 'https://api.cloudflare.com/client/v4/accounts/'
        'YOUR_ACCOUNT_ID/ai/run',
    model: '@cf/black-forest-labs/flux-2-klein-9b',
    supportsReferenceImage: true,
    bodyFormat: AiBodyFormat.multipart,
    docsUrl: 'https://dash.cloudflare.com/profile/api-tokens',
  );

  /// Cloudflare Workers AI with FLUX 2 Klein 4B.
  ///
  /// The distilled 4B sibling of the 9B model: it still takes the UV
  /// template as a reference image, but it costs a fraction of the neurons,
  /// so the daily allowance buys far more wraps.
  static const AiProvider cloudflareFlux2Klein4b = AiProvider(
    id: 'cloudflare-flux-2-klein-4b',
    label: 'Cloudflare FLUX 2 Klein 4B',
    vendor: 'Cloudflare',
    description: 'Free on the Cloudflare daily allowance (about 130 neurons '
        'per image, roughly 75 images a day). Sends the UV template as a '
        'reference image.',
    kind: AiProviderKind.cloudflareWorkersAi,
    baseUrl: 'https://api.cloudflare.com/client/v4/accounts/'
        'YOUR_ACCOUNT_ID/ai/run',
    model: '@cf/black-forest-labs/flux-2-klein-4b',
    supportsReferenceImage: true,
    bodyFormat: AiBodyFormat.multipart,
    docsUrl: 'https://dash.cloudflare.com/profile/api-tokens',
  );

  /// Cloudflare Workers AI with FLUX 1 schnell, the cheapest of all.
  ///
  /// This one is text only, so the studio has to describe the layout
  /// instead of showing the template. It also wants a JSON body, unlike the
  /// FLUX 2 models.
  static const AiProvider cloudflareFlux1Schnell = AiProvider(
    id: 'cloudflare-flux-1-schnell',
    label: 'Cloudflare FLUX 1 schnell',
    vendor: 'Cloudflare',
    description: 'Cheapest option anywhere (about 58 neurons per image, '
        'roughly 170 images a day) but text only, so the layout is described '
        'instead of shown.',
    kind: AiProviderKind.cloudflareWorkersAi,
    baseUrl: 'https://api.cloudflare.com/client/v4/accounts/'
        'YOUR_ACCOUNT_ID/ai/run',
    model: '@cf/black-forest-labs/flux-1-schnell',
    supportsReferenceImage: false,
    docsUrl: 'https://dash.cloudflare.com/profile/api-tokens',
  );

  /// Pollinations with FLUX, the one provider that needs no account at all.
  ///
  /// It ignores the request shape and draws from the prompt alone, so the
  /// studio asks for a flat pattern instead of a car, and the panel mask
  /// clips the result onto the real body panels. The free tier answers one
  /// image every 45 seconds per address.
  static const AiProvider pollinationsFlux = AiProvider(
    id: 'pollinations-flux',
    label: 'Pollinations FLUX (no key)',
    vendor: 'Pollinations',
    description: 'Free and no API key needed. Draws a flat pattern that the '
        'panel mask clips onto the car. The free tier allows one image every '
        '45 seconds.',
    kind: AiProviderKind.pollinations,
    baseUrl: 'https://image.pollinations.ai',
    model: 'flux',
    supportsReferenceImage: false,
    requiresApiKey: false,
    followsReferenceLayout: false,
    docsUrl: 'https://pollinations.ai',
  );

  /// Looks a provider up by id, falling back to [gemini3ProImage].
  static AiProvider byId(String id) {
    for (final provider in all) {
      if (provider.id == id) return provider;
    }
    return gemini3ProImage;
  }
}
