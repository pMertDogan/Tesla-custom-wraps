import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/ai_provider.dart';

/// AIService handles communication with various AI image generation providers.
class AIService {
  String? _apiKey;
  String? _baseUrl;
  AIProvider? _selectedProvider;

  void updateConfig({String? apiKey, String? baseUrl, AIProvider? provider}) {
    if (apiKey != null) _apiKey = apiKey;
    if (baseUrl != null) _baseUrl = baseUrl;
    if (provider != null) _selectedProvider = provider;
  }

  String? get apiKey => _apiKey;
  String? get baseUrl => _baseUrl;
  AIProvider? get selectedProvider => _selectedProvider;

  /// Generates a wrap image based on the prompt and selected provider.
  /// Returns the image as base64 encoded string or a URL.
  Future<String?> generateWrapImage(String prompt) async {
    try {
      if (_apiKey == null || _selectedProvider == null) {
        return null;
      }

      final provider = _selectedProvider!;

      switch (provider.id) {
        case 'dalle3':
        case 'custom_openai':
          return await _generateWithOpenAI(prompt);
        case 'stability':
          return await _generateWithStabilityAI(prompt);
        case 'custom_anthropic':
          return await _generateWithAnthropic(prompt);
        case 'custom_gemini':
          return await _generateWithGemini(prompt);
        case 'mistral':
          return await _generateWithMistral(prompt);
        default:
          // For providers without direct API support, use OpenAI-compatible endpoint
          return await _generateWithOpenAI(prompt);
      }
    } catch (e) {
      // Secure error handling
      return null;
    }
  }

  /// OpenAI DALL-E 3 compatible generation
  Future<String?> _generateWithOpenAI(String prompt) async {
    final url = _baseUrl != null && _baseUrl!.isNotEmpty
        ? Uri.parse(_baseUrl!)
        : Uri.parse('https://api.openai.com/v1/images/generations');

    // Enhanced prompt for vehicle wrap designs
    final enhancedPrompt =
        'A seamless vehicle wrap pattern/design: $prompt. '
        'High resolution, seamless tileable pattern, vibrant colors, '
        'professional automotive wrap design, no text or logos unless specified.';

    final response = await http
        .post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_apiKey',
          },
          body: jsonEncode({
            'model': 'dall-e-3',
            'prompt': enhancedPrompt,
            'n': 1,
            'size': '1024x1024',
            'response_format': 'b64_json',
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final images = data['data'] as List<dynamic>;
      if (images.isNotEmpty) {
        return images[0]['b64_json'] as String? ?? images[0]['url'] as String?;
      }
    }
    return null;
  }

  /// Stability AI (Stable Diffusion) generation
  Future<String?> _generateWithStabilityAI(String prompt) async {
    final url = _baseUrl != null && _baseUrl!.isNotEmpty
        ? Uri.parse(_baseUrl!)
        : Uri.parse(
            'https://api.stability.ai/v1/generation/stable-diffusion-xl-1024-v1-0/text-to-image',
          );

    final response = await http
        .post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_apiKey',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'text_prompts': [
              {
                'text':
                    'Seamless vehicle wrap pattern: $prompt. '
                    'High quality, tileable, automotive vinyl wrap design',
                'weight': 1.0,
              },
            ],
            'cfg_scale': 7,
            'width': 1024,
            'height': 1024,
            'samples': 1,
            'steps': 30,
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final artifacts = data['artifacts'] as List<dynamic>?;
      if (artifacts != null && artifacts.isNotEmpty) {
        return artifacts[0]['base64'] as String?;
      }
    }
    return null;
  }

  /// Anthropic Claude generation (via image generation if available)
  Future<String?> _generateWithAnthropic(String prompt) async {
    final url = _baseUrl != null && _baseUrl!.isNotEmpty
        ? Uri.parse(_baseUrl!)
        : Uri.parse('https://api.anthropic.com/v1/messages');

    // Anthropic doesn't have native image generation via API yet
    // This would need to be adapted when they release it
    return null;
  }

  /// Google Gemini generation
  Future<String?> _generateWithGemini(String prompt) async {
    final baseUrl = _baseUrl != null && _baseUrl!.isNotEmpty
        ? _baseUrl!
        : 'https://generativelanguage.googleapis.com/v1beta/models';

    final url = Uri.parse(
      '$baseUrl/imagen-3.0-generate-001:predict?key=$_apiKey',
    );

    final response = await http
        .post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'instances': [
              {
                'prompt':
                    'Vehicle wrap design: $prompt. Seamless pattern, high quality.',
              },
            ],
            'parameters': {
              'sampleCount': 1,
              'aspectRatio': '1:1',
            },
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final predictions = data['predictions'] as List<dynamic>?;
      if (predictions != null && predictions.isNotEmpty) {
        return predictions[0]['bytesBase64Encoded'] as String?;
      }
    }
    return null;
  }

  /// Mistral AI generation
  Future<String?> _generateWithMistral(String prompt) async {
    final url = _baseUrl != null && _baseUrl!.isNotEmpty
        ? Uri.parse(_baseUrl!)
        : Uri.parse('https://api.mistral.ai/v1/images/generations');

    final response = await http
        .post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_apiKey',
          },
          body: jsonEncode({
            'prompt':
                'Vehicle wrap design pattern: $prompt. Seamless, high quality, automotive vinyl.',
            'model': 'mistral-image-latest',
            'n': 1,
            'size': '1024x1024',
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final images = data['data'] as List<dynamic>?;
      if (images != null && images.isNotEmpty) {
        return images[0]['b64_json'] as String? ?? images[0]['url'] as String?;
      }
    }
    return null;
  }
}
