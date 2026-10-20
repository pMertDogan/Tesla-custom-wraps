import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:tesla_custom_wraps/services/template_masker.dart';

/// Reports, per example wrap, how much artwork the mask would throw away.
void main(List<String> args) {
  final vehicle = args.first;
  final mask = TemplateMasker.buildMask(
    File('$vehicle/template.png').readAsBytesSync(),
  )!;

  final examples = Directory('$vehicle/example')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.toLowerCase().endsWith('.png'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  for (final example in examples) {
    final decoded = img.decodeImage(example.readAsBytesSync());
    if (decoded == null) continue;

    final sizeMatches =
        decoded.width == mask.width && decoded.height == mask.height;
    final image = decoded.convert(format: img.Format.uint8, numChannels: 4);
    final rgba = image.getBytes(order: img.ChannelOrder.rgba);

    var painted = 0;
    var lost = 0;
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final offset = (y * image.width + x) * 4;
        final alpha = rgba[offset + 3];
        final luminance = (0.299 * rgba[offset] +
                0.587 * rgba[offset + 1] +
                0.114 * rgba[offset + 2])
            .round();
        if (alpha < 128 || luminance >= 235) continue;
        painted++;

        if (!sizeMatches) continue;
        final my = (y * mask.height) ~/ image.height;
        final mx = (x * mask.width) ~/ image.width;
        if (mask.paintable[my * mask.width + mx] == 0) lost++;
      }
    }

    stdout.writeln(
      '${example.path.split(RegExp(r"[\\/]")).last.padRight(26)} '
      '${image.width}x${image.height} '
      '${sizeMatches ? "match " : "DIFFER"} '
      'painted=$painted lost=${painted == 0 ? 0 : (lost * 100 / painted).toStringAsFixed(1)}%',
    );
  }
}
