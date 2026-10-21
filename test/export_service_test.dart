import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:tesla_custom_wraps/services/export_service.dart';
import 'package:tesla_custom_wraps/services/template_masker.dart';

/// Builds a smooth PNG that compresses well.
Uint8List _smoothPng(int width, int height) {
  final image = img.Image(width: width, height: height);

  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixelRgba(
        x,
        y,
        (x * 255) ~/ width,
        (y * 255) ~/ height,
        128,
        255,
      );
    }
  }

  return img.encodePng(image, level: 6);
}

/// Builds a noisy PNG so the size budget has something to chew on.
Uint8List _noisyPng(int width, int height) {
  final image = img.Image(width: width, height: height);
  final random = Random(7);

  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixelRgba(
        x,
        y,
        random.nextInt(256),
        random.nextInt(256),
        random.nextInt(256),
        255,
      );
    }
  }

  return img.encodePng(image, level: 6);
}

/// Builds a template in Tesla's format: a transparent field, an opaque cut
/// line and the opaque panel inside it.
Uint8List _templateWithPanel(int size) {
  final image = img.Image(width: size, height: size, numChannels: 4);

  final outer = size ~/ 4;
  final inner = outer + 2;
  final end = (size * 3) ~/ 4;

  img.fillRect(
    image,
    x1: outer,
    y1: outer,
    x2: end,
    y2: end,
    color: img.ColorRgba8(0, 0, 0, 255),
  );
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

void main() {
  group('sanitizeFileName', () {
    test('drops characters Tesla does not accept', () {
      expect(
        WrapExporter.sanitizeFileName('Red/Flam*es?v1'),
        'RedFlamesv1',
      );
    });

    test('keeps letters, digits, underscores, dashes and spaces', () {
      expect(
        WrapExporter.sanitizeFileName('My_Wrap-2026 v2'),
        'My_Wrap-2026 v2',
      );
    });

    test('clips the name to 30 characters', () {
      final name = WrapExporter.sanitizeFileName('a' * 60);
      expect(name.length, WrapExporter.maxFileNameLength);
    });

    test('collapses runs of whitespace and trims', () {
      expect(WrapExporter.sanitizeFileName('  red   wrap  '), 'red wrap');
    });

    test('falls back to a default name when nothing is left', () {
      expect(WrapExporter.sanitizeFileName('///'), 'tesla_wrap');
    });

    test('isValidFileName agrees with the sanitizer', () {
      expect(WrapExporter.isValidFileName('Red_Wrap-01'), isTrue);
      expect(WrapExporter.isValidFileName('Red/Wrap'), isFalse);
      expect(WrapExporter.isValidFileName('a' * 31), isFalse);
      expect(WrapExporter.isValidFileName(''), isFalse);
    });
  });

  group('buildPng', () {
    test('produces a PNG at the template size', () {
      final wrap = WrapExporter.buildPng(
        _smoothPng(1024, 1024),
        templateWidth: 1024,
        templateHeight: 1024,
        fileName: 'my wrap',
      );

      expect(wrap.width, 1024);
      expect(wrap.height, 1024);
      expect(wrap.fileName, 'my wrap');
      expect(wrap.bytes.length, lessThanOrEqualTo(WrapExporter.maxBytes));
      expect(img.decodePng(wrap.bytes), isNotNull);
    });

    test('crops a square design to a 4:3 template', () {
      final wrap = WrapExporter.buildPng(
        _smoothPng(1024, 1024),
        templateWidth: 1024,
        templateHeight: 768,
      );

      expect(wrap.width, 1024);
      expect(wrap.height, 768);
    });

    test('keeps the file under 1 MB even for a noisy design', () {
      final wrap = WrapExporter.buildPng(
        _noisyPng(1024, 1024),
        templateWidth: 1024,
        templateHeight: 1024,
      );

      expect(wrap.bytes.length, lessThanOrEqualTo(WrapExporter.maxBytes));
      expect(wrap.downscaled, isTrue);
    });

    test('rejects an unreadable image', () {
      expect(
        () => WrapExporter.buildPng(
          Uint8List.fromList([1, 2, 3]),
          templateWidth: 1024,
          templateHeight: 1024,
        ),
        throwsA(isA<ExportException>()),
      );
    });

    test('clips the artwork to the panel mask', () {
      final mask = TemplateMasker.buildMask(_templateWithPanel(64));
      expect(mask, isNotNull);

      final artwork = img.Image(width: 64, height: 64);
      img.fill(artwork, color: img.ColorRgb8(255, 0, 0));

      final wrap = WrapExporter.buildPng(
        img.encodePng(artwork),
        templateWidth: 64,
        templateHeight: 64,
        mask: mask,
      );

      final result = img.decodePng(wrap.bytes)!;
      // Inside the panel the artwork survives.
      expect(result.getPixel(32, 32).r, 255);
      expect(result.getPixel(32, 32).g, 0);
      // Outside the panel nothing is painted and nothing is left behind.
      expect(result.getPixel(2, 2).a, 0);
      expect(result.getPixel(2, 2).r, 0);
      expect(result.getPixel(2, 2).g, 0);
      expect(result.getPixel(2, 2).b, 0);
    });

    test('exports a masked design exactly like the raw artwork', () {
      // The gallery keeps the masked design. Exporting it again has to give
      // the same file, not a second round of masking.
      final mask = TemplateMasker.buildMask(_templateWithPanel(64))!;

      final artwork = img.Image(width: 64, height: 64);
      img.fill(artwork, color: img.ColorRgb8(255, 0, 0));

      final raw = WrapExporter.buildPng(
        img.encodePng(artwork),
        templateWidth: 64,
        templateHeight: 64,
        mask: mask,
      );
      final masked = TemplateMasker.applyMask(img.encodePng(artwork), mask)!;
      final fromMasked = WrapExporter.buildPng(
        masked,
        templateWidth: 64,
        templateHeight: 64,
        mask: mask,
      );

      final a = img.decodePng(raw.bytes)!.getBytes(order: img.ChannelOrder.rgba);
      final b =
          img.decodePng(fromMasked.bytes)!.getBytes(order: img.ChannelOrder.rgba);

      expect(b.length, a.length);
      var differing = 0;
      for (var i = 0; i < a.length; i++) {
        if (a[i] != b[i]) differing++;
      }
      expect(differing, 0);
    });

    test('carries the alpha channel of the template', () {
      // Tesla's example wraps are byte for byte identical to the alpha
      // channel of their template. The export has to do the same, otherwise
      // the vinyl does not land where the car expects it.
      final template = File('cybertruck/template.png');
      expect(template.existsSync(), isTrue);

      final mask = TemplateMasker.buildMask(template.readAsBytesSync())!;
      final artwork = img.Image(width: 1024, height: 768);
      img.fill(artwork, color: img.ColorRgb8(20, 140, 220));

      final wrap = WrapExporter.buildPng(
        img.encodePng(artwork),
        templateWidth: 1024,
        templateHeight: 768,
        mask: mask,
      );

      final result = img
          .decodePng(wrap.bytes)!
          .convert(format: img.Format.uint8, numChannels: 4);
      final exported = result.getBytes(order: img.ChannelOrder.rgba);

      var mismatched = 0;
      var paintedOutside = 0;
      for (var i = 3; i < exported.length; i += 4) {
        if (exported[i] != mask.alpha[(i - 3) ~/ 4]) mismatched++;
        if (mask.alpha[(i - 3) ~/ 4] == 0 && exported[i] != 0) {
          paintedOutside++;
        }
      }

      expect(mismatched, 0);
      expect(paintedOutside, 0);
    });
  });

  group('coverCropToTemplate', () {
    test('returns null for an unreadable image', () {
      expect(
        WrapExporter.coverCropToTemplate(
          Uint8List.fromList([1, 2, 3]),
          templateWidth: 64,
          templateHeight: 64,
        ),
        isNull,
      );
    });

    test('returns a PNG at the template size', () {
      final result = WrapExporter.coverCropToTemplate(
        _smoothPng(512, 512),
        templateWidth: 256,
        templateHeight: 256,
      );

      expect(result, isNotNull);
      final decoded = img.decodePng(result!)!;
      expect(decoded.width, 256);
      expect(decoded.height, 256);
    });
  });
}
