import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;

import '../models/ai_provider.dart';
import '../models/ai_settings.dart';
import 'platform_support.dart';

/// Raised when a generation request cannot be completed.
///
/// [message] is safe to show to the user; [detail] carries the raw provider
/// error for the console and for tests.
class AiException implements Exception {
  /// User facing explanation.
  final String message;

  /// HTTP status code, when the failure came from a response.
  final int? statusCode;

  /// Raw provider error, kept out of the user facing message.
  final String? detail;

  const AiException(this.message, {this.statusCode, this.detail});

  @override
  String toString() => message;
}

/// An image returned by a provider.
class GeneratedImage {
  /// Encoded image bytes.
  final Uint8List bytes;

  /// MIME type of [bytes].
  final String mimeType;

  /// What the provider charged for this image, in USD.
  ///
  /// Only providers that report a price (OpenRouter) fill this in. It lets
  /// the studio show what a generation cost.
  final double? cost;

  /// The provider's own unit of consumption, when it does not report a
  /// price. Cloudflare counts "neurons" per generation.
  final String? units;

  const GeneratedImage(
    this.bytes,
    this.mimeType, {
    this.cost,
    this.units,
  });
}

/// Explains a request that never produced a response.
///
/// Cloudflare's AI endpoint answers `405` to the CORS preflight that a browser
/// sends before a multipart request with an `Authorization` header, so on the
/// web build the request dies before it leaves the browser. The generic
/// "check your connection" wording sends people down the wrong path, so the
/// web build gets the real reason instead.
///
/// [isWeb] defaults to the platform the app runs on; tests pass it directly.
String networkFailureMessage(AiProvider provider, {bool? isWeb}) {
  final web = isWeb ?? isWebPlatform;
  if (web && provider.kind == AiProviderKind.cloudflareWorkersAi) {
    return 'Cloudflare blocks browser requests (CORS). Open the app on '
        'mobile or desktop, or point the base URL in Settings at a proxy.';
  }
  return 'Could not reach ${provider.label}. Check your connection and try '
      'again.';
}

/// Talks to text-to-image providers and turns them into wrap textures.
class AiService {
  /// Creates a service.
  ///
  /// [client] is injectable so tests can supply a `MockClient`.
  AiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// How long a single generation request may take.
  static const Duration requestTimeout = Duration(seconds: 180);

  /// Generates a wrap texture.
  ///
  /// [prompt] should already contain the wrap contract, see
  /// `WrapPromptBuilder`. [referenceImage] is Tesla's UV template for the
  /// vehicle; it is only sent to providers that support reference images.
  /// [aspectRatio] is the template's aspect ratio (for example `4:3`); it is
  /// only used by providers that expose a ratio control.
  Future<GeneratedImage> generate({
    required AiProvider provider,
    required AiSettings settings,
    required String prompt,
    Uint8List? referenceImage,
    String referenceMimeType = 'image/png',
    String? aspectRatio,
    int? width,
    int? height,
  }) async {
    if (!settings.hasApiKey) {
      throw const AiException(
        'No API key configured. Open Settings and add a key for your provider.',
      );
    }

    final effectiveReference =
        provider.supportsReferenceImage ? referenceImage : null;

    switch (provider.kind) {
      case AiProviderKind.gemini:
        return _generateWithGemini(
          provider: provider,
          settings: settings,
          prompt: prompt,
          referenceImage: effectiveReference,
          referenceMimeType: referenceMimeType,
        );
      case AiProviderKind.openaiImages:
        return _generateWithOpenAi(
          provider: provider,
          settings: settings,
          prompt: prompt,
        );
      case AiProviderKind.openRouterImages:
        return _generateWithOpenRouter(
          provider: provider,
          settings: settings,
          prompt: prompt,
          referenceImage: effectiveReference,
          referenceMimeType: referenceMimeType,
          aspectRatio: aspectRatio,
        );
      case AiProviderKind.cloudflareWorkersAi:
        return _generateWithCloudflare(
          provider: provider,
          settings: settings,
          prompt: prompt,
          referenceImage: effectiveReference,
          referenceMimeType: referenceMimeType,
          width: width,
          height: height,
        );
    }
  }

  Future<GeneratedImage> _generateWithGemini({
    required AiProvider provider,
    required AiSettings settings,
    required String prompt,
    Uint8List? referenceImage,
    String referenceMimeType = 'image/png',
  }) async {
    final baseUrl = _effectiveBaseUrl(provider, settings);
    final model = _effectiveModel(provider, settings);
    final apiKey = settings.apiKey.trim();

    final uri = Uri.parse('$baseUrl/models/$model:generateContent')
        .replace(queryParameters: {'key': apiKey});

    final parts = <Map<String, dynamic>>[
      {'text': prompt},
    ];
    if (referenceImage != null) {
      parts.add({
        'inlineData': {
          'mimeType': referenceMimeType,
          'data': base64Encode(referenceImage),
        },
      });
    }

    final body = <String, dynamic>{
      'contents': [
        {'role': 'user', 'parts': parts},
      ],
      'generationConfig': {
        'responseModalities': ['IMAGE'],
        'imageConfig': {'aspectRatio': '1:1'},
      },
    };

    final http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(requestTimeout);
    } on Exception catch (error) {
      throw AiException(
        _networkFailureMessage(provider),
        detail: error.toString(),
      );
    }

    final decoded = _decodeBody(response.body);

    if (response.statusCode != 200) {
      throw AiException(
        _describeProviderError(
          provider,
          response.statusCode,
          decoded,
          model: model,
        ),
        statusCode: response.statusCode,
        detail: response.body,
      );
    }

    final image = _extractGeminiImage(decoded);
    if (image == null) {
      final reason = _extractGeminiBlockReason(decoded);
      throw AiException(
        reason == null
            ? '${provider.label} did not return an image. Try rephrasing your '
                'description.'
            : '${provider.label} declined the request ($reason). Try a '
                'different description.',
        detail: response.body,
      );
    }
    return image;
  }

  Future<GeneratedImage> _generateWithOpenAi({
    required AiProvider provider,
    required AiSettings settings,
    required String prompt,
  }) async {
    final baseUrl = _effectiveBaseUrl(provider, settings);
    final model = _effectiveModel(provider, settings);
    final apiKey = settings.apiKey.trim();

    final uri = _openAiImagesUri(baseUrl);

    final body = <String, dynamic>{
      'model': model,
      'prompt': prompt,
      'n': 1,
      'size': '1024x1024',
    };
    // gpt-image-1 always answers with base64 and rejects response_format.
    if (model.toLowerCase().startsWith('dall-e')) {
      body['response_format'] = 'b64_json';
    }

    final http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode(body),
          )
          .timeout(requestTimeout);
    } on Exception catch (error) {
      throw AiException(
        _networkFailureMessage(provider),
        detail: error.toString(),
      );
    }

    final decoded = _decodeBody(response.body);

    if (response.statusCode != 200) {
      throw AiException(
        _describeProviderError(
          provider,
          response.statusCode,
          decoded,
          model: model,
        ),
        statusCode: response.statusCode,
        detail: response.body,
      );
    }

    final data = decoded?['data'];
    if (data is! List || data.isEmpty) {
      throw const AiException(
        'The provider did not return an image. Try rephrasing your '
        'description.',
      );
    }

    final first = data.first;
    if (first is! Map) {
      throw const AiException('The provider returned an unexpected payload.');
    }

    final b64 = first['b64_json'];
    if (b64 is String && b64.isNotEmpty) {
      return GeneratedImage(base64Decode(b64), 'image/png');
    }

    final url = first['url'];
    if (url is String && url.isNotEmpty) {
      final downloaded = await _client.get(Uri.parse(url));
      if (downloaded.statusCode != 200) {
        throw AiException(
          'The generated image could not be downloaded.',
          statusCode: downloaded.statusCode,
        );
      }
      return GeneratedImage(downloaded.bodyBytes, 'image/png');
    }

    throw const AiException('The provider did not return an image.');
  }

  /// Generates a wrap through Cloudflare Workers AI.
  ///
  /// Cloudflare grants every account a free daily neuron allowance, which
  /// makes it the only provider here that can produce a wrap without
  /// paying. The endpoint is
  /// `POST /accounts/{account id}/ai/run/{model}`.
  ///
  /// Workers AI is not consistent about the request body. The FLUX 2 models
  /// only accept a multipart form, where the UV template travels as a file
  /// and the prompt as a field. FLUX 1 schnell only accepts JSON and even
  /// insists on a typed `steps` count, so the body format follows the
  /// provider.
  Future<GeneratedImage> _generateWithCloudflare({
    required AiProvider provider,
    required AiSettings settings,
    required String prompt,
    Uint8List? referenceImage,
    String referenceMimeType = 'image/png',
    int? width,
    int? height,
  }) async {
    final baseUrl = _effectiveBaseUrl(provider, settings);
    final model = _effectiveModel(provider, settings);
    final apiKey = settings.apiKey.trim();

    if (baseUrl.contains('YOUR_ACCOUNT_ID')) {
      throw const AiException(
        'Set the Cloudflare base URL in Settings to '
        'https://api.cloudflare.com/client/v4/accounts/<your account id>'
        '/ai/run',
      );
    }

    final uri = Uri.parse('${_stripTrailingSlash(baseUrl)}/$model');

    final response = provider.bodyFormat == AiBodyFormat.json
        ? await _postCloudflareJson(uri, apiKey, prompt, provider: provider)
        : await _postCloudflareMultipart(
            uri,
            apiKey,
            prompt,
            referenceImage: referenceImage,
            referenceMimeType: referenceMimeType,
            width: width,
            height: height,
            provider: provider,
          );

    final decoded = _decodeBody(response.body);

    if (response.statusCode != 200) {
      throw AiException(
        _describeProviderError(
          provider,
          response.statusCode,
          decoded,
          model: model,
        ),
        statusCode: response.statusCode,
        detail: response.body,
      );
    }

    final result = decoded?['result'];
    if (result is! Map) {
      throw const AiException(
        'Cloudflare did not return an image. Try rephrasing your description.',
      );
    }

    final image = result['image'];
    if (image is String && image.isNotEmpty) {
      final neurons = result['usage'] is Map
          ? (result['usage'] as Map)['neurons']
          : null;
      return GeneratedImage(
        base64Decode(image),
        'image/jpeg',
        cost: neurons is num ? neurons / 1000000 : null,
        units: neurons is num ? neurons.toStringAsFixed(1) : null,
      );
    }

    throw const AiException('Cloudflare did not return an image.');
  }

  /// Posts a JSON body to a Workers AI model.
  ///
  /// FLUX 1 schnell takes `prompt` and an integer `steps`, and nothing else:
  /// `num_steps`, `seed`, `width` and `height` are all rejected. A rejected
  /// request never spends neurons, so the call can be retried with fewer
  /// fields.
  Future<http.Response> _postCloudflareJson(
    Uri uri,
    String apiKey,
    String prompt, {
    required AiProvider provider,
  }) async {
    final attempts = <Map<String, dynamic>>[
      {'prompt': prompt, 'steps': 4},
      {'prompt': prompt},
    ];

    http.Response? lastResponse;
    for (final body in attempts) {
      lastResponse = await _postCloudflare(
        uri,
        apiKey,
        body: body,
        provider: provider,
      );
      if (lastResponse.statusCode != 400) break;
    }
    return lastResponse!;
  }

  /// Posts a multipart form to a Workers AI model.
  ///
  /// The FLUX 2 models disagree on which optional fields they accept, so the
  /// request is retried with a smaller body until one is understood. A
  /// rejected request never consumes neurons.
  Future<http.Response> _postCloudflareMultipart(
    Uri uri,
    String apiKey,
    String prompt, {
    Uint8List? referenceImage,
    String referenceMimeType = 'image/png',
    int? width,
    int? height,
    required AiProvider provider,
  }) async {
    final attempts = <Map<String, String>>[
      {
        'prompt': prompt,
        'num_steps': '4',
        if (width != null) 'width': '$width',
        if (height != null) 'height': '$height',
        'seed': '${DateTime.now().millisecondsSinceEpoch % 100000}',
      },
      {
        'prompt': prompt,
        'steps': '4',
      },
      {
        'prompt': prompt,
      },
    ];

    http.Response? lastResponse;
    for (final fields in attempts) {
      lastResponse = await _postCloudflare(
        uri,
        apiKey,
        fields: fields,
        referenceImage: referenceImage,
        referenceMimeType: referenceMimeType,
        provider: provider,
      );
      if (lastResponse.statusCode != 400) break;
    }
    return lastResponse!;
  }

  /// Sends one request to a Workers AI model.
  ///
  /// Pass [fields] for a multipart form or [body] for JSON, never both.
  Future<http.Response> _postCloudflare(
    Uri uri,
    String apiKey, {
    Map<String, String>? fields,
    Map<String, dynamic>? body,
    Uint8List? referenceImage,
    String referenceMimeType = 'image/png',
    required AiProvider provider,
  }) async {
    try {
      final http.BaseRequest request;
      if (body != null) {
        final jsonRequest = http.Request('POST', uri)
          ..headers['Content-Type'] = 'application/json'
          ..body = jsonEncode(body);
        request = jsonRequest;
      } else {
        final multipartRequest = http.MultipartRequest('POST', uri);
        (fields ?? const <String, String>{}).forEach(
          (key, value) => multipartRequest.fields[key] = value,
        );

        if (referenceImage != null) {
          multipartRequest.files.add(
            http.MultipartFile.fromBytes(
              'image',
              referenceImage,
              filename: 'template.png',
              contentType: MediaType.parse(referenceMimeType),
            ),
          );
        }
        request = multipartRequest;
      }

      request.headers['Authorization'] = 'Bearer $apiKey';

      // The request has to go through the injected client: `Request.send()`
      // would open its own connection and ignore the timeout.
      final streamed = await _client.send(request).timeout(requestTimeout);
      return await http.Response.fromStream(streamed);
    } on Exception catch (error) {
      throw AiException(
        _networkFailureMessage(provider),
        detail: error.toString(),
      );
    }
  }

  /// Explains a request that never produced a response.
  ///
  /// Cloudflare's AI endpoint answers `405` to the CORS preflight that a
  /// browser sends before a multipart request with an `Authorization` header,
  /// so on the web build the request dies before it leaves the browser. The
  /// generic "check your connection" wording sends people down the wrong
  /// path, so the web build gets the real reason.
  static String _networkFailureMessage(AiProvider provider) {
    return networkFailureMessage(provider);
  }

  static String _stripTrailingSlash(String value) {
    var result = value.trim();
    while (result.endsWith('/')) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  }

  /// Generates a wrap through OpenRouter's dedicated Image API.
  ///
  /// OpenRouter accepts the UV template as an `input_references` entry, so
  /// the artwork is laid out against the real panels instead of a text
  /// description of them. The endpoint is `POST /api/v1/images` and answers
  /// with `data[0].b64_json`.
  Future<GeneratedImage> _generateWithOpenRouter({
    required AiProvider provider,
    required AiSettings settings,
    required String prompt,
    Uint8List? referenceImage,
    String referenceMimeType = 'image/png',
    String? aspectRatio,
  }) async {
    final baseUrl = _effectiveBaseUrl(provider, settings);
    final model = _effectiveModel(provider, settings);
    final apiKey = settings.apiKey.trim();
    final uri = _openRouterImagesUri(baseUrl);

    final body = <String, dynamic>{
      'model': model,
      'prompt': prompt,
      'n': 1,
    };

    // `output_format` is deliberately left out: several OpenRouter models
    // reject it outright, and the exporter re-encodes the result to PNG
    // anyway.
    if (aspectRatio != null && aspectRatio.isNotEmpty) {
      body['aspect_ratio'] = aspectRatio;
    }

    if (referenceImage != null) {
      body['input_references'] = [
        {
          'type': 'image_url',
          'image_url': {
            'url': 'data:$referenceMimeType;base64,'
                '${base64Encode(referenceImage)}',
          },
        },
      ];
    }

    var response = await _postOpenRouter(
      uri,
      apiKey,
      body,
      provider: provider,
    );

    // Not every model accepts every ratio. When the ratio is rejected we
    // retry once without it and let the exporter crop to the template.
    if (response.statusCode == 400 &&
        aspectRatio != null &&
        body.containsKey('aspect_ratio')) {
      final retryBody = Map<String, dynamic>.of(body)..remove('aspect_ratio');
      response = await _postOpenRouter(
        uri,
        apiKey,
        retryBody,
        provider: provider,
      );
    }

    final decoded = _decodeBody(response.body);

    if (response.statusCode != 200) {
      throw AiException(
        _describeProviderError(
          provider,
          response.statusCode,
          decoded,
          model: model,
        ),
        statusCode: response.statusCode,
        detail: response.body,
      );
    }

    final data = decoded?['data'];
    if (data is! List || data.isEmpty) {
      throw const AiException(
        'OpenRouter did not return an image. Try rephrasing your description.',
      );
    }

    final first = data.first;
    if (first is! Map) {
      throw const AiException('OpenRouter returned an unexpected payload.');
    }

    final b64 = first['b64_json'];
    if (b64 is String && b64.isNotEmpty) {
      final mediaType = first['media_type'];
      return GeneratedImage(
        base64Decode(b64),
        mediaType is String && mediaType.isNotEmpty
            ? mediaType
            : 'image/png',
        cost: _extractCost(decoded),
      );
    }

    throw const AiException('OpenRouter did not return an image.');
  }

  /// Reads the USD cost OpenRouter reports for a generation.
  double? _extractCost(Map<String, dynamic>? decoded) {
    if (decoded == null) return null;
    final usage = decoded['usage'];
    if (usage is! Map) return null;
    final cost = usage['cost'];
    if (cost is num) return cost.toDouble();
    if (cost is String) return double.tryParse(cost);
    return null;
  }

  Future<http.Response> _postOpenRouter(
    Uri uri,
    String apiKey,
    Map<String, dynamic> body, {
    required AiProvider provider,
  }) async {
    try {
      return await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode(body),
          )
          .timeout(requestTimeout);
    } on Exception catch (error) {
      throw AiException(
        _networkFailureMessage(provider),
        detail: error.toString(),
      );
    }
  }

  /// Normalises a base URL into OpenRouter's image endpoint.
  Uri _openRouterImagesUri(String baseUrl) {
    var base = baseUrl.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    if (base.endsWith('/images')) {
      return Uri.parse(base);
    }
    if (base.endsWith('/v1')) {
      return Uri.parse('$base/images');
    }
    return Uri.parse('$base/v1/images');
  }

  String _effectiveBaseUrl(AiProvider provider, AiSettings settings) {
    final raw = settings.hasBaseUrlOverride
        ? settings.baseUrlOverride!.trim()
        : provider.baseUrl.trim();
    return raw.endsWith('/')
        ? raw.substring(0, raw.length - 1)
        : raw;
  }

  String _effectiveModel(AiProvider provider, AiSettings settings) =>
      settings.hasModelOverride
          ? settings.modelOverride!.trim()
          : provider.model;

  /// Normalises a user supplied base URL into an images endpoint.
  Uri _openAiImagesUri(String baseUrl) {
    var base = baseUrl.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    if (base.endsWith('/images/generations')) {
      return Uri.parse(base);
    }
    if (base.endsWith('/v1')) {
      return Uri.parse('$base/images/generations');
    }
    return Uri.parse('$base/v1/images/generations');
  }

  Map<String, dynamic>? _decodeBody(String body) {
    if (body.isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  GeneratedImage? _extractGeminiImage(Map<String, dynamic>? decoded) {
    if (decoded == null) return null;
    final candidates = decoded['candidates'];
    if (candidates is! List || candidates.isEmpty) return null;

    for (final candidate in candidates) {
      if (candidate is! Map) continue;
      final content = candidate['content'];
      if (content is! Map) continue;
      final parts = content['parts'];
      if (parts is! List) continue;

      for (final part in parts) {
        if (part is! Map) continue;
        final inline = part['inlineData'] ?? part['inline_data'];
        if (inline is! Map) continue;
        final data = inline['data'];
        if (data is! String || data.isEmpty) continue;
        final mimeType =
            inline['mimeType'] ?? inline['mime_type'] ?? 'image/png';
        return GeneratedImage(base64Decode(data), mimeType as String);
      }
    }
    return null;
  }

  String? _extractGeminiBlockReason(Map<String, dynamic>? decoded) {
    if (decoded == null) return null;
    final feedback = decoded['promptFeedback'];
    if (feedback is Map && feedback['blockReason'] is String) {
      return feedback['blockReason'] as String;
    }
    final candidates = decoded['candidates'];
    if (candidates is List && candidates.isNotEmpty) {
      final first = candidates.first;
      if (first is Map && first['finishReason'] is String) {
        return first['finishReason'] as String;
      }
    }
    return null;
  }

  String _describeProviderError(
    AiProvider provider,
    int statusCode,
    Map<String, dynamic>? decoded, {
    String? model,
  }) {
    final providerMessage = _extractProviderMessage(decoded);
    final lower = (providerMessage ?? '').toLowerCase();

    if (lower.contains('daily free allocation')) {
      return '${provider.label} used up the daily free allowance. It resets '
          'tomorrow.';
    }
    if (statusCode == 401 || statusCode == 403) {
      return 'Your API key was rejected by ${provider.label}. Check it in '
          'Settings.';
    }
    if (statusCode == 402) {
      return '${provider.label} has no credit left for image generation. Add '
          'credits to the account and try again.';
    }
    if (statusCode == 404) {
      final modelName = model ?? provider.model;
      return 'The model "$modelName" was not found on ${provider.label}. '
          'Check the model name in Settings.';
    }
    if (statusCode == 429) {
      return '${provider.label} rate limited this request. Wait a moment and '
          'try again.';
    }
    if (lower.contains('not allowed') || lower.contains('unevaluated')) {
      return '${provider.label} rejected the request shape for model '
          '"${model ?? provider.model}". Try another model.';
    }
    if (lower.contains('not valid json') ||
        lower.contains('required properties')) {
      return '${provider.label} expects a different request body for model '
          '"${model ?? provider.model}". Try another model.';
    }
    if (lower.contains('type mismatch')) {
      return '${provider.label} rejected a field type for model '
          '"${model ?? provider.model}". Try another model.';
    }
    if (providerMessage != null && providerMessage.trim().isNotEmpty) {
      return '${provider.label}: $providerMessage';
    }
    return '${provider.label} returned an error (HTTP $statusCode).';
  }

  /// Pulls the human readable message out of a provider error body.
  ///
  /// Providers disagree: OpenAI style bodies nest `error.message`, while
  /// Cloudflare uses an `errors` array.
  String? _extractProviderMessage(Map<String, dynamic>? decoded) {
    if (decoded == null) return null;

    final error = decoded['error'];
    if (error is Map) {
      final message = error['message'];
      if (message is String && message.trim().isNotEmpty) return message;
    }

    final errors = decoded['errors'];
    if (errors is List && errors.isNotEmpty) {
      final first = errors.first;
      if (first is Map) {
        final message = first['message'];
        if (message is String && message.trim().isNotEmpty) return message;
      }
    }

    return null;
  }
}
