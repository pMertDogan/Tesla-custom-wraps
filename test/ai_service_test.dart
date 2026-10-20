import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tesla_custom_wraps/models/ai_provider.dart';
import 'package:tesla_custom_wraps/models/ai_settings.dart';
import 'package:tesla_custom_wraps/services/ai_service.dart';

/// A valid 1x1 PNG.
const String _tinyPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAE'
    'hQGAhKmMIQAAAABJRU5ErkJggg==';

AiSettings _settings({String providerId = 'gemini-3-pro-image'}) {
  return AiSettings(providerId: providerId, apiKey: 'test-key');
}

void main() {
  group('AiService', () {
    test('refuses to generate without an API key', () async {
      final service = AiService(
        client: MockClient((_) async => http.Response('{}', 200)),
      );

      expect(
        () => service.generate(
          provider: AiProviderCatalog.gemini3ProImage,
          settings: const AiSettings(providerId: 'gemini-3-pro-image', apiKey: ''),
          prompt: 'red flames',
        ),
        throwsA(
          isA<AiException>().having(
            (error) => error.message,
            'message',
            contains('No API key'),
          ),
        ),
      );
    });

    test('parses a Gemini image response', () async {
      final service = AiService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {
                        'inlineData': {
                          'mimeType': 'image/png',
                          'data': _tinyPngBase64,
                        },
                      },
                    ],
                  },
                },
              ],
            }),
            200,
          ),
        ),
      );

      final result = await service.generate(
        provider: AiProviderCatalog.gemini3ProImage,
        settings: _settings(),
        prompt: 'red flames',
      );

      expect(result.mimeType, 'image/png');
      expect(result.bytes, isNotEmpty);
    });

    test('sends the template as a reference image to Gemini', () async {
      late Map<String, dynamic> sentBody;
      late Uri sentUri;

      final service = AiService(
        client: MockClient((request) async {
          sentUri = request.url;
          sentBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {
                        'inlineData': {
                          'mimeType': 'image/png',
                          'data': _tinyPngBase64,
                        },
                      },
                    ],
                  },
                },
              ],
            }),
            200,
          );
        }),
      );

      await service.generate(
        provider: AiProviderCatalog.gemini3ProImage,
        settings: _settings(),
        prompt: 'red flames',
        referenceImage: Uint8List.fromList([1, 2, 3, 4]),
      );

      expect(sentUri.path, contains('gemini-3-pro-image:generateContent'));
      expect(sentUri.queryParameters['key'], 'test-key');

      final config =
          sentBody['generationConfig'] as Map<String, dynamic>;
      expect(config['responseModalities'], contains('IMAGE'));

      final contents = sentBody['contents'] as List;
      final parts = (contents.first as Map<String, dynamic>)['parts'] as List;
      final inline = parts
          .cast<Map<String, dynamic>>()
          .firstWhere((part) => part.containsKey('inlineData'));
      expect(
        ((inline['inlineData'] as Map<String, dynamic>)['data']),
        base64Encode([1, 2, 3, 4]),
      );
    });

    test('reports a rejected Gemini key', () async {
      final service = AiService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'error': {'code': 400, 'message': 'API key not valid'},
            }),
            400,
          ),
        ),
      );

      expect(
        () => service.generate(
          provider: AiProviderCatalog.gemini3ProImage,
          settings: _settings(),
          prompt: 'red flames',
        ),
        throwsA(
          isA<AiException>().having(
            (error) => error.message,
            'message',
            contains('API key not valid'),
          ),
        ),
      );
    });

    test('reports a Gemini refusal without an image', () async {
      final service = AiService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': <Map<String, dynamic>>[],
                  },
                },
              ],
              'promptFeedback': {'blockReason': 'SAFETY'},
            }),
            200,
          ),
        ),
      );

      expect(
        () => service.generate(
          provider: AiProviderCatalog.gemini3ProImage,
          settings: _settings(),
          prompt: 'red flames',
        ),
        throwsA(
          isA<AiException>().having(
            (error) => error.message,
            'message',
            contains('SAFETY'),
          ),
        ),
      );
    });

    test('parses an OpenAI base64 response', () async {
      late Uri sentUri;
      late Map<String, dynamic> sentBody;

      final service = AiService(
        client: MockClient((request) async {
          sentUri = request.url;
          sentBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'data': [
                {'b64_json': _tinyPngBase64},
              ],
            }),
            200,
          );
        }),
      );

      final result = await service.generate(
        provider: AiProviderCatalog.openAiGptImage,
        settings: _settings(providerId: 'openai-gpt-image-1'),
        prompt: 'red flames',
      );

      expect(sentUri.path, '/v1/images/generations');
      expect(sentBody['model'], 'gpt-image-1');
      expect(sentBody['size'], '1024x1024');
      expect(result.bytes, isNotEmpty);
    });

    test('asks DALL-E for a base64 response', () async {
      late Map<String, dynamic> sentBody;

      final service = AiService(
        client: MockClient((request) async {
          sentBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'data': [
                {'b64_json': _tinyPngBase64},
              ],
            }),
            200,
          );
        }),
      );

      await service.generate(
        provider: AiProviderCatalog.openAiDallE3,
        settings: _settings(providerId: 'openai-dall-e-3'),
        prompt: 'red flames',
      );

      expect(sentBody['response_format'], 'b64_json');
    });

    test('normalises a custom base URL', () async {
      late Uri sentUri;

      final service = AiService(
        client: MockClient((request) async {
          sentUri = request.url;
          return http.Response(
            jsonEncode({
              'data': [
                {'b64_json': _tinyPngBase64},
              ],
            }),
            200,
          );
        }),
      );

      await service.generate(
        provider: AiProviderCatalog.customOpenAi,
        settings: _settings(providerId: 'custom-openai').copyWith(
          baseUrlOverride: 'https://gateway.example.com/v1',
          modelOverride: 'my-image-model',
        ),
        prompt: 'red flames',
      );

      expect(sentUri.toString(), startsWith('https://gateway.example.com/v1/'));
      expect(sentUri.path, '/v1/images/generations');
    });

    test('maps provider errors onto readable messages', () async {
      final service = AiService(
        client: MockClient(
          (_) async => http.Response('{"error":{"message":"quota"}}', 429),
        ),
      );

      expect(
        () => service.generate(
          provider: AiProviderCatalog.gemini3ProImage,
          settings: _settings(),
          prompt: 'red flames',
        ),
        throwsA(
          isA<AiException>().having(
            (error) => error.message,
            'message',
            contains('rate limited'),
          ),
        ),
      );
    });
  });
}
