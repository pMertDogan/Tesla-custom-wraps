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

AiSettings _settings({
  String providerId = 'gemini-3-pro-image',
  String? baseUrl,
}) {
  return AiSettings(
    providerId: providerId,
    apiKey: 'test-key',
    baseUrlOverride: baseUrl,
  );
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

  group('AiService with OpenRouter', () {
    AiSettings openRouterSettings() =>
        _settings(providerId: 'openrouter-flux-3-image-klein');

    test('posts to the OpenRouter image endpoint with a bearer token',
        () async {
      late Uri sentUri;
      late Map<String, dynamic> sentBody;
      late String? sentAuth;

      final service = AiService(
        client: MockClient((request) async {
          sentUri = request.url;
          sentAuth = request.headers['Authorization'];
          sentBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'data': [
                {'b64_json': _tinyPngBase64, 'media_type': 'image/png'},
              ],
              'usage': {'cost': 0.008},
            }),
            200,
          );
        }),
      );

      final result = await service.generate(
        provider: AiProviderCatalog.openRouterFluxKlein,
        settings: openRouterSettings(),
        prompt: 'red flames',
        aspectRatio: '4:3',
      );

      expect(sentUri.toString(),
          'https://openrouter.ai/api/v1/images');
      expect(sentAuth, 'Bearer test-key');
      expect(sentBody['model'], 'black-forest-labs/flux-3-image-klein');
      expect(sentBody['prompt'], 'red flames');
      expect(sentBody['n'], 1);
      expect(sentBody.containsKey('output_format'), isFalse);
      expect(sentBody['aspect_ratio'], '4:3');
      expect(result.bytes, isNotEmpty);
      expect(result.mimeType, 'image/png');
      expect(result.cost, 0.008);
    });

    test('sends the template as an input reference', () async {
      late Map<String, dynamic> sentBody;

      final service = AiService(
        client: MockClient((request) async {
          sentBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'data': [
                {'b64_json': _tinyPngBase64, 'media_type': 'image/png'},
              ],
            }),
            200,
          );
        }),
      );

      await service.generate(
        provider: AiProviderCatalog.openRouterFluxKlein,
        settings: openRouterSettings(),
        prompt: 'red flames',
        referenceImage: Uint8List.fromList([1, 2, 3, 4]),
      );

      final references = sentBody['input_references'] as List;
      expect(references, hasLength(1));

      final reference = references.first as Map<String, dynamic>;
      expect(reference['type'], 'image_url');

      final imageUrl = (reference['image_url'] as Map<String, dynamic>)['url'];
      expect(imageUrl, startsWith('data:image/png;base64,'));
      expect(imageUrl, endsWith(base64Encode([1, 2, 3, 4])));
    });

    test('retries without the aspect ratio when the model rejects it',
        () async {
      var call = 0;
      late Map<String, dynamic> lastBody;

      final service = AiService(
        client: MockClient((request) async {
          call++;
          lastBody = jsonDecode(request.body) as Map<String, dynamic>;
          if (call == 1) {
            return http.Response(
              jsonEncode({
                'error': {'message': 'aspect_ratio 7:5 is not supported'},
              }),
              400,
            );
          }
          return http.Response(
            jsonEncode({
              'data': [
                {'b64_json': _tinyPngBase64, 'media_type': 'image/png'},
              ],
            }),
            200,
          );
        }),
      );

      final result = await service.generate(
        provider: AiProviderCatalog.openRouterFluxKlein,
        settings: openRouterSettings(),
        prompt: 'red flames',
        aspectRatio: '7:5',
      );

      expect(call, 2);
      expect(lastBody.containsKey('aspect_ratio'), isFalse);
      expect(result.bytes, isNotEmpty);
    });

    test('explains an exhausted OpenRouter credit balance', () async {
      final service = AiService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'error': {'message': 'Insufficient credits'},
            }),
            402,
          ),
        ),
      );

      expect(
        () => service.generate(
          provider: AiProviderCatalog.openRouterFluxKlein,
          settings: openRouterSettings(),
          prompt: 'red flames',
        ),
        throwsA(
          isA<AiException>().having(
            (error) => error.message,
            'message',
            contains('credit'),
          ),
        ),
      );
    });

    test('reports an unknown OpenRouter model', () async {
      final service = AiService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'error': {'message': 'No model found for "nope"'},
            }),
            404,
          ),
        ),
      );

      expect(
        () => service.generate(
          provider: AiProviderCatalog.openRouterFluxKlein,
          settings: openRouterSettings(),
          prompt: 'red flames',
        ),
        throwsA(
          isA<AiException>().having(
            (error) => error.message,
            'message',
            contains('not found'),
          ),
        ),
      );
    });
  });

  group('AiService with Cloudflare Workers AI', () {
    const accountId = '0123456789abcdef';
    const baseUrl =
        'https://api.cloudflare.com/client/v4/accounts/$accountId/ai/run';

    AiSettings cloudflareSettings() => _settings(
          providerId: 'cloudflare-flux-2-dev',
          baseUrl: baseUrl,
        );

    test('posts a multipart request with the template as a file', () async {
      late Uri sentUri;
      late Map<String, String> sentFields;
      late List<String?> sentFiles;
      late String? sentAuth;

      // The first attempt is answered with a rejection so the fallback
      // chain is exercised, the second one succeeds.
      var call = 0;
      final client = MockClient.streaming((request, bodyStream) async {
        call++;
        final multipart = request as http.MultipartRequest;
        sentUri = multipart.url;
        sentFields = Map<String, String>.from(multipart.fields);
        sentFiles = multipart.files.map((f) => f.filename).toList();
        sentAuth = multipart.headers['Authorization'];
        await bodyStream.toBytes();
        if (call == 1) {
          return http.StreamedResponse(
            Stream.value(
              utf8.encode(
                jsonEncode({
                  'errors': [
                    {
                      'code': 5006,
                      'message': "Additional or unevaluated properties '/seed' "
                          "at '/' not allowed",
                    },
                  ],
                }),
              ),
            ),
            400,
          );
        }
        return http.StreamedResponse(
          Stream.value(
            utf8.encode(
              jsonEncode({
                'result': {
                  'image': _tinyPngBase64,
                  'usage': {'neurons': 900.0},
                },
                'success': true,
              }),
            ),
          ),
          200,
        );
      });

      final service = AiService(client: client);
      final result = await service.generate(
        provider: AiProviderCatalog.cloudflareFlux2Dev,
        settings: cloudflareSettings(),
        prompt: 'red flames',
        referenceImage: Uint8List.fromList([1, 2, 3, 4]),
        width: 1024,
        height: 1024,
      );

      expect(sentUri.toString(),
          '$baseUrl/@cf/black-forest-labs/flux-2-dev');
      expect(sentAuth, 'Bearer test-key');
      expect(sentFields['prompt'], 'red flames');
      expect(sentFiles, contains('template.png'));
      expect(result.bytes, isNotEmpty);
      expect(result.units, '900.0');
    });

    test('explains that the daily free allowance is used up', () async {
      final service = AiService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'errors': [
                {
                  'code': 4006,
                  'message': 'you have used up your daily free allocation of '
                      '10,000 neurons',
                },
              ],
            }),
            429,
          ),
        ),
      );

      expect(
        () => service.generate(
          provider: AiProviderCatalog.cloudflareFlux2Dev,
          settings: cloudflareSettings(),
          prompt: 'red flames',
        ),
        throwsA(
          isA<AiException>().having(
            (error) => error.message,
            'message',
            contains('daily free allowance'),
          ),
        ),
      );
    });

    test('asks for a real account id before calling the API', () async {
      final service = AiService(
        client: MockClient(
          (_) async => http.Response('{}', 200),
        ),
      );

      expect(
        () => service.generate(
          provider: AiProviderCatalog.cloudflareFlux2Dev,
          settings: _settings(providerId: 'cloudflare-flux-2-dev'),
          prompt: 'red flames',
        ),
        throwsA(
          isA<AiException>().having(
            (error) => error.message,
            'message',
            contains('account id'),
          ),
        ),
      );
    });

    test('blames CORS when Cloudflare is called from a browser', () {
      final message = networkFailureMessage(
        AiProviderCatalog.cloudflareFlux2Dev,
        isWeb: true,
      );

      expect(message, contains('CORS'));
      expect(message, contains('proxy'));
    });

    test('blames the connection when Cloudflare is called from a device', () {
      final message = networkFailureMessage(
        AiProviderCatalog.cloudflareFlux2Dev,
        isWeb: false,
      );

      expect(message, contains('Could not reach'));
      expect(message, isNot(contains('CORS')));
    });

    test('keeps the connection wording for providers the browser can reach', () {
      final message = networkFailureMessage(
        AiProviderCatalog.openRouterFluxKlein,
        isWeb: true,
      );

      expect(message, contains('Could not reach'));
      expect(message, isNot(contains('CORS')));
    });
  });
}
