import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:tesla_custom_wraps/services/template_masker.dart';

/// Builds a template-like image: white field with a hollow black rectangle.
///
/// The rectangle mirrors Tesla's line art, where the panel is enclosed by a
/// stroke and the inside of the panel stays white.
Uint8List _templateWithPanel(int size) {
  final image = img.Image(width: size, height: size);
  img.fill(image, color: img.ColorRgb8(255, 255, 255));

  final outer = size ~/ 4;
  final inner = outer + 2;
  final end = (size * 3) ~/ 4;

  img.fillRect(
    image,
    x1: outer,
    y1: outer,
    x2: end,
    y2: end,
    color: img.ColorRgb8(0, 0, 0),
  );
  img.fillRect(
    image,
    x1: inner,
    y1: inner,
    x2: end - 2,
    y2: end - 2,
    color: img.ColorRgb8(255, 255, 255),
  );

  return img.encodePng(image);
}

void main() {
  group('TemplateMasker', () {
    test('marks the inside of a closed outline as paintable', () {
      final mask = TemplateMasker.buildMask(_templateWithPanel(64));
      expect(mask, isNotNull);

      // Inside the panel.
      expect(mask!.paintable[32 * 64 + 32], 1);
      // Outside the panel.
      expect(mask.paintable[2 * 64 + 2], 0);
      // On the stroke itself.
      expect(mask.paintable[18 * 64 + 32], 0);
    });

    test('covers a sensible part of the canvas', () {
      final mask = TemplateMasker.buildMask(_templateWithPanel(64))!;
      // The rectangle covers roughly a quarter of the field.
      expect(mask.coverage, greaterThan(0.15));
      expect(mask.coverage, lessThan(0.45));
    });

    test('keeps the whole canvas when the outlines are not closed', () {
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
      expect(mask.coverage, greaterThan(0.10));
      expect(mask.coverage, lessThan(0.95));
    });
  });
}
