import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/ai_provider.dart';
import '../models/ai_settings.dart';

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

  const GeneratedImage(this.bytes, this.mimeType);
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
  Future<GeneratedImage> generate({
    required AiProvider provider,
    required AiSettings settings,
    required String prompt,
    Uint8List? referenceImage,
    String referenceMimeType = 'image/png',
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
        'Could not reach ${provider.label}. Check your connection and try '
        'again.',
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
        'Could not reach ${provider.label}. Check your connection and try '
        'again.',
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
    final error = decoded?['error'];
    final providerMessage = error is Map ? error['message'] : null;

    if (statusCode == 401 || statusCode == 403) {
      return 'Your API key was rejected by ${provider.label}. Check it in '
          'Settings.';
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
    if (providerMessage is String && providerMessage.trim().isNotEmpty) {
      return '${provider.label}: $providerMessage';
    }
    return '${provider.label} returned an error (HTTP $statusCode).';
  }
}
