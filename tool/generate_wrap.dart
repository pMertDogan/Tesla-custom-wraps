// Command line wrapper around the studio's wrap pipeline.
//
// Generates a wrap for a vehicle with an AI provider and writes a Tesla ready
// PNG to disk. It runs exactly the same code the Flutter app runs, so it is
// also a convenient smoke test for a provider key.
//
//   dart run tool/generate_wrap.dart \
//     --model model3-2024-base \
//     --prompt "midnight blue carbon fibre with cyan racing stripes" \
//     --out build/wraps/
//
// The API key is read from GEMINI_API_KEY (or OPENAI_API_KEY for the
// OpenAI-compatible providers).
import 'dart:io';
import 'dart:typed_data';

import 'package:tesla_custom_wraps/models/ai_provider.dart';
import 'package:tesla_custom_wraps/models/ai_settings.dart';
import 'package:tesla_custom_wraps/services/ai_service.dart';
import 'package:tesla_custom_wraps/services/export_service.dart';
import 'package:tesla_custom_wraps/services/prompt_builder.dart';
import 'package:tesla_custom_wraps/services/template_masker.dart';
import 'package:tesla_custom_wraps/services/vehicle_service.dart';

Future<void> main(List<String> arguments) async {
  final options = _parse(arguments);

  if (options.containsKey('help')) {
    stdout.writeln(_usage);
    return;
  }

  final vehicleId = options['model'] ?? 'model3-2024-base';
  final vehicle = VehicleService.findById(vehicleId);
  if (vehicle == null) {
    stderr.writeln('Unknown vehicle "$vehicleId".');
    stderr.writeln('Known vehicles:');
    for (final known in VehicleService.getVehicles()) {
      stderr.writeln('  ${known.id}  (${known.name})');
    }
    exitCode = 64;
    return;
  }

  final provider = AiProviderCatalog.byId(options['provider'] ?? 'gemini-3-pro-image');

  final prompt = WrapPromptBuilder.build(
    concept: options['prompt'] ?? 'a striking wrap',
    vehicleName: vehicle.name,
    style: WrapStyle.byId(options['style'] ?? 'vector').hint,
    hasReferenceTemplate: true,
    flatPatternOnly: !provider.followsReferenceLayout,
  );

  final templateBytes = File(vehicle.templatePath).readAsBytesSync();
  stdout.writeln('Vehicle : ${vehicle.name}');

  final sourceFile = options['from'];
  if (sourceFile != null) {
    await _conformExisting(
      sourceFile: sourceFile,
      vehicleId: vehicleId,
      templateBytes: templateBytes,
      outputDir: options['out'] ?? 'build/wraps',
      name: options['name'],
    );
    return;
  }

  final apiKey = _resolveApiKey(provider);
  if (provider.requiresApiKey && apiKey == null) {
    stderr.writeln(
      'No API key found. Set ${_apiKeyEnvName(provider) ?? 'WRAP_API_KEY'}.',
    );
    exitCode = 64;
    return;
  }

  stdout.writeln('Provider: ${provider.label} (${provider.model})');
  stdout.writeln('Generating...');

  final settings = AiSettings(
    providerId: provider.id,
    apiKey: apiKey ?? '',
    baseUrlOverride: options['base-url'],
    modelOverride: options['model-id'],
  );

  try {
    final service = AiService();
    final result = await service.generate(
      provider: provider,
      settings: settings,
      prompt: prompt,
      referenceImage: templateBytes,
      aspectRatio: vehicle.aspectRatio,
      width: vehicle.templateWidth,
      height: vehicle.templateHeight,
    );

    stdout.writeln('Received ${result.bytes.length} bytes (${result.mimeType}).');
    if (result.cost != null) {
      stdout.writeln('Cost   : \$${result.cost!.toStringAsFixed(4)}');
    }
    if (result.units != null) {
      stdout.writeln('Usage  : ${result.units} Cloudflare neurons');
    }

    final mask = TemplateMasker.buildMask(templateBytes);
    final cropped = WrapExporter.coverCropToTemplate(
      result.bytes,
      templateWidth: vehicle.templateWidth,
      templateHeight: vehicle.templateHeight,
    );
    if (cropped == null) {
      stderr.writeln('The generated image could not be read.');
      exitCode = 1;
      return;
    }

    final wrap = WrapExporter.buildPng(
      cropped,
      templateWidth: vehicle.templateWidth,
      templateHeight: vehicle.templateHeight,
      fileName: options['name'] ?? '${vehicle.id}_wrap',
      mask: mask,
    );

    final outputDir = Directory(options['out'] ?? 'build/wraps');
    outputDir.createSync(recursive: true);
    final outputFile = File('${outputDir.path}/${wrap.fileNameWithExtension}');
    outputFile.writeAsBytesSync(wrap.bytes);

    stdout.writeln('');
    stdout.writeln('Saved  : ${outputFile.path}');
    stdout.writeln('Size   : ${wrap.width}x${wrap.height}, '
        '${wrap.sizeInMegabytes.toStringAsFixed(3)} MB');
    stdout.writeln('Mask   : ${mask == null ? 'not applied' : 'applied '
        '(${(mask.coverage * 100).toStringAsFixed(1)}% of the atlas)'}');
    stdout.writeln('Name   : ${wrap.fileNameWithExtension} '
        '(valid: ${WrapExporter.isValidFileName(wrap.fileName)})');
  } on AiException catch (error) {
    stderr.writeln('Generation failed: ${error.message}');
    if (error.detail != null) {
      stderr.writeln('Detail: ${error.detail}');
    }
    exitCode = 1;
  } on ExportException catch (error) {
    stderr.writeln('Export failed: ${error.message}');
    exitCode = 1;
  }
}

/// Runs an existing design through the crop, mask and export stages.
///
/// Useful to re-mask a design that was drawn elsewhere, and to verify the
/// pipeline without spending provider credits.
Future<void> _conformExisting({
  required String sourceFile,
  required String vehicleId,
  required Uint8List templateBytes,
  required String outputDir,
  String? name,
}) async {
  final vehicle = VehicleService.findById(vehicleId)!;
  final source = File(sourceFile);
  if (!source.existsSync()) {
    stderr.writeln('Source file "$sourceFile" does not exist.');
    exitCode = 66;
    return;
  }

  stdout.writeln('Source  : ${source.path}');

  final mask = TemplateMasker.buildMask(templateBytes);
  final cropped = WrapExporter.coverCropToTemplate(
    source.readAsBytesSync(),
    templateWidth: vehicle.templateWidth,
    templateHeight: vehicle.templateHeight,
  );
  if (cropped == null) {
    stderr.writeln('The source image could not be read.');
    exitCode = 1;
    return;
  }

  final wrap = WrapExporter.buildPng(
    cropped,
    templateWidth: vehicle.templateWidth,
    templateHeight: vehicle.templateHeight,
    fileName: name ?? '${vehicle.id}_wrap',
    mask: mask,
  );

  final directory = Directory(outputDir);
  directory.createSync(recursive: true);
  final outputFile = File('${directory.path}/${wrap.fileNameWithExtension}');
  outputFile.writeAsBytesSync(wrap.bytes);

  stdout.writeln('');
  stdout.writeln('Saved  : ${outputFile.path}');
  stdout.writeln('Size   : ${wrap.width}x${wrap.height}, '
      '${wrap.sizeInMegabytes.toStringAsFixed(3)} MB');
  stdout.writeln('Mask   : ${mask == null ? 'not applied' : 'applied '
      '(${(mask.coverage * 100).toStringAsFixed(1)}% of the atlas)'}');
  stdout.writeln('Name   : ${wrap.fileNameWithExtension} '
      '(valid: ${WrapExporter.isValidFileName(wrap.fileName)})');
}

Map<String, String> _parse(List<String> arguments) {
  final options = <String, String>{};

  for (var i = 0; i < arguments.length; i++) {
    final argument = arguments[i];
    if (!argument.startsWith('--')) continue;

    final name = argument.substring(2);
    if (name == 'help' || name == 'h') {
      options['help'] = 'true';
      continue;
    }

    final value = i + 1 < arguments.length ? arguments[i + 1] : '';
    if (value.startsWith('--')) {
      options[name] = 'true';
    } else {
      options[name] = value;
      i++;
    }
  }

  return options;
}

String? _resolveApiKey(AiProvider provider) {
  final fromArgs = Platform.environment['WRAP_API_KEY'];
  if (fromArgs != null && fromArgs.trim().isNotEmpty) return fromArgs.trim();

  final names = switch (provider.kind) {
    AiProviderKind.gemini => ['GEMINI_API_KEY', 'GOOGLE_API_KEY'],
    AiProviderKind.openRouterImages => ['OPENROUTER_API_KEY'],
    AiProviderKind.openaiImages => ['OPENAI_API_KEY'],
    AiProviderKind.cloudflareWorkersAi => ['CLOUDFLARE_API_TOKEN'],
    AiProviderKind.pollinations => const <String>[],
  };

  for (final name in names) {
    final value = Platform.environment[name];
    if (value != null && value.trim().isNotEmpty) return value.trim();
  }
  return null;
}

/// Environment variable that holds the key for [provider].
String? _apiKeyEnvName(AiProvider provider) => switch (provider.kind) {
      AiProviderKind.gemini => 'GEMINI_API_KEY',
      AiProviderKind.openRouterImages => 'OPENROUTER_API_KEY',
      AiProviderKind.openaiImages => 'OPENAI_API_KEY',
      AiProviderKind.cloudflareWorkersAi => 'CLOUDFLARE_API_TOKEN',
      AiProviderKind.pollinations => null,
    };

const String _usage = '''
Generate a Tesla wrap with an AI provider.

Usage:
  dart run tool/generate_wrap.dart [options]

Options:
  --model <id>        Vehicle id (default: model3-2024-base)
  --from <path>       Process an existing image instead of generating one
  --prompt <text>     Design description
  --style <id>        Style preset id (default: vector)
  --provider <id>     Provider id (default: gemini-3-pro-image)
  --model-id <id>     Override the provider model
  --base-url <url>    Override the provider base URL
  --name <name>       Output file name (without extension)
  --out <dir>         Output directory (default: build/wraps)
  --help              Show this text

Providers without a key:
  pollinations-flux    Free, no account, no API key. Draws a flat pattern and
                       clips it to the vehicle panels.

Environment:
  GEMINI_API_KEY        Key for the Gemini providers
  OPENAI_API_KEY        Key for the OpenAI compatible providers
  OPENROUTER_API_KEY    Key for the OpenRouter providers
  CLOUDFLARE_API_TOKEN  Key for the Cloudflare Workers AI providers
  WRAP_API_KEY          Overrides all of them
''';
