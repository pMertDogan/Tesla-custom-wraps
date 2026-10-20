import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:tesla_custom_wraps/services/template_masker.dart';

/// Builds a template-like image in Tesla's format: an empty transparent
/// field, a hollow black cut line and an opaque white panel inside it.
Uint8List _templateWithPanel(int size) {
  final image = img.Image(width: size, height: size, numChannels: 4);

  final outer = size ~/ 4;
  final inner = outer + 2;
  final end = (size * 3) ~/ 4;

  // The cut line.
  img.fillRect(
    image,
    x1: outer,
    y1: outer,
    x2: end,
    y2: end,
    color: img.ColorRgba8(0, 0, 0, 255),
  );
  // The panel inside it.
  img.fillRect(
    image,
    x1: inner,
    y1: inner,
    x2: end - 2,
    y2: end - 2,
    color: img.ColorRgba8(255, 255, 255, 255),
  );

  return img.encodePng(image);
}

/// Builds a template whose panel runs past the edge of the atlas, the way
/// the Cybertruck's top and bottom bands do.
Uint8List _templateWithOpenPanel(int size) {
  final image = img.Image(width: size, height: size, numChannels: 4);

  // A band that touches the top edge and is closed at the bottom.
  img.fillRect(
    image,
    x1: size ~/ 8,
    y1: 0,
    x2: (size * 7) ~/ 8,
    y2: size ~/ 2,
    color: img.ColorRgba8(255, 255, 255, 255),
  );
  img.fillRect(
    image,
    x1: size ~/ 8,
    y1: size ~/ 2,
    x2: (size * 7) ~/ 8,
    y2: size ~/ 2 + 2,
    color: img.ColorRgba8(0, 0, 0, 255),
  );

  return img.encodePng(image);
}

/// Every vehicle that ships a template.
List<String> _vehicles() => Directory('.')
    .listSync()
    .whereType<Directory>()
    .where((d) => File('${d.path}/template.png').existsSync())
    .map((d) => d.path.replaceAll('\\', '/'))
    .toList()
  ..sort();

/// The outcome of comparing one example wrap with the mask.
class _ExampleResult {
  _ExampleResult({
    required this.isWrap,
    required this.painted,
    required this.lost,
  });

  /// Tesla ships a few reference sheets next to the real wraps, for example
  /// `Alpha_Mask.png` which is a black and white mask of the body panels and
  /// `Graffiti_back.png` which is a full bleed backdrop. Those files paint
  /// far outside the silhouette of the car, a real wrap never does.
  final bool isWrap;

  /// Pixels the example painted.
  final int painted;

  /// Pixels the example painted that the mask throws away.
  final int lost;
}

/// Compares one example wrap with the mask of its vehicle.
_ExampleResult _compare(Uint8List paintable, int width, int height, String path) {
  final decoded = img.decodeImage(File(path).readAsBytesSync());
  if (decoded == null) {
    return _ExampleResult(isWrap: false, painted: 0, lost: 0);
  }

  final image = decoded.convert(format: img.Format.uint8, numChannels: 4);
  final rgba = image.getBytes(order: img.ChannelOrder.rgba);

  var painted = 0;
  var lost = 0;
  var inside = 0;

  for (var y = 0; y < image.height; y++) {
    final my = (y * height) ~/ image.height;
    for (var x = 0; x < image.width; x++) {
      final offset = (y * image.width + x) * 4;
      final alpha = rgba[offset + 3];
      final luminance = (0.299 * rgba[offset] +
              0.587 * rgba[offset + 1] +
              0.114 * rgba[offset + 2])
          .round();
      if (alpha < 128 || luminance >= 235) continue;

      painted++;
      final mx = (x * width) ~/ image.width;
      if (paintable[my * width + mx] != 0) {
        inside++;
      } else {
        lost++;
      }
    }
  }

  // A wrap keeps its artwork inside the silhouette of the car. A reference
  // sheet paints the whole canvas instead.
  final isWrap = painted > 0 && inside / painted >= 0.90;

  return _ExampleResult(isWrap: isWrap, painted: painted, lost: lost);
}

void main() {
  group('TemplateMasker', () {
    test('marks the inside of a closed outline as paintable', () {
      final mask = TemplateMasker.buildMask(_templateWithPanel(64));
      expect(mask, isNotNull);

      // Inside the panel.
      expect(mask!.paintable[32 * 64 + 32], 1);
      // On the cut line, Tesla paints the seams as well.
      expect(mask.paintable[16 * 64 + 32], 1);
      // In the empty space between the panels.
      expect(mask.paintable[2 * 64 + 2], 0);
    });

    test('covers a sensible part of the canvas', () {
      final mask = TemplateMasker.buildMask(_templateWithPanel(64))!;
      // The rectangle covers roughly a third of the field.
      expect(mask.coverage, greaterThan(0.15));
      expect(mask.coverage, lessThan(0.45));
    });

    test('keeps a panel that runs past the edge of the atlas', () {
      final mask = TemplateMasker.buildMask(_templateWithOpenPanel(64))!;

      // The open band is paintable even though it touches the border.
      expect(mask.paintable[8 * 64 + 32], 1);
      // The cut line below it belongs to the wrap too.
      expect(mask.paintable[33 * 64 + 32], 1);
      // The empty space under it is not.
      expect(mask.paintable[56 * 64 + 32], 0);
      expect(mask.coverage, greaterThan(0.20));
    });

    test('keeps the whole canvas when the template has no panels', () {
      final image = img.Image(width: 32, height: 32);
      img.fill(image, color: img.ColorRgb8(255, 255, 255));

      final mask = TemplateMasker.buildMask(img.encodePng(image))!;
      expect(mask.coverage, greaterThan(0.95));
    });

    test('clips artwork to the panels and whitens the rest', () {
      final mask = TemplateMasker.buildMask(_templateWithPanel(64))!;

      final artwork = img.Image(width: 64, height: 64);
      img.fill(artwork, color: img.ColorRgb8(255, 0, 0));

      final masked = TemplateMasker.applyMask(img.encodePng(artwork), mask);
      expect(masked, isNotNull);

      final result = img.decodePng(masked!)!;
      // Panel interior keeps the artwork.
      expect(result.getPixel(32, 32).r, 255);
      expect(result.getPixel(32, 32).g, 0);
      // Everything else is white.
      expect(result.getPixel(2, 2).r, 255);
      expect(result.getPixel(2, 2).g, 255);
      expect(result.getPixel(2, 2).b, 255);
    });

    test('works on the real Tesla templates', () {
      final template = File('model3-2024-base/template.png');
      expect(template.existsSync(), isTrue);

      final mask = TemplateMasker.buildMask(
        template.readAsBytesSync(),
      );

      expect(mask, isNotNull);
      expect(mask!.width, 1024);
      expect(mask.height, 1024);
      // A car body covers a meaningful slice of the atlas but not all of it.
      expect(mask.coverage, greaterThan(0.10));
      expect(mask.coverage, lessThan(0.95));
    });

    test('handles the 4:3 Cybertruck template', () {
      final template = File('cybertruck/template.png');
      expect(template.existsSync(), isTrue);

      final mask = TemplateMasker.buildMask(template.readAsBytesSync())!;
      expect(mask.width, 1024);
      expect(mask.height, 768);
      // The Cybertruck's body covers a lot of the atlas: the top band, the
      // bottom band and the four side strips.
      expect(mask.coverage, greaterThan(0.40));
      expect(mask.coverage, lessThan(0.65));
    });

    test('every template keeps the artwork Tesla painted on it', () {
      // Tesla's example wraps are the ground truth: whatever Tesla painted
      // belongs on the car, so the mask may not throw it away.
      for (final vehicle in _vehicles()) {
        final mask = TemplateMasker.buildMask(
          File('$vehicle/template.png').readAsBytesSync(),
        );
        expect(mask, isNotNull, reason: vehicle);

        final examples = Directory('$vehicle/example')
            .listSync()
            .whereType<File>()
            .where((f) => f.path.toLowerCase().endsWith('.png'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

        var wraps = 0;
        var painted = 0;
        var lost = 0;

        for (final example in examples) {
          final decoded = img.decodeImage(example.readAsBytesSync());
          if (decoded == null) continue;
          if (decoded.width != mask!.width || decoded.height != mask.height) {
            // Not every example has the same size as the template.
            continue;
          }

          final result = _compare(
            mask.paintable,
            mask.width,
            mask.height,
            example.path,
          );

          if (!result.isWrap) {
            // A reference sheet, not a wrap.
            continue;
          }

          wraps++;
          painted += result.painted;
          lost += result.lost;
        }

        expect(wraps, greaterThan(10), reason: '$vehicle has no examples');
        expect(
          lost / painted,
          lessThan(0.02),
          reason: '$vehicle loses $lost of $painted painted pixels',
        );
      }
    });
  });
}
