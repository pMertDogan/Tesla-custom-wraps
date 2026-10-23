import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:tesla_custom_wraps/models/wrap_layer.dart';
import 'package:tesla_custom_wraps/services/wrap_compositor.dart';

/// A plain opaque canvas to draw the layers on.
Uint8List _canvas(int width, int height, {int r = 0, int g = 0, int b = 0}) {
  final image = img.Image(width: width, height: height, numChannels: 4);
  img.fill(image, color: img.ColorRgba8(r, g, b, 255));
  return img.encodePng(image);
}

void main() {
  group('WrapLayer', () {
    test('survives a JSON round trip', () {
      final original = WrapLayer.brush(
        id: 'brush_1',
        color: 0xFFE31937,
        scale: 0.03,
      ).copyWith(points: [0.1, 0.2, 0.3, 0.4], opacity: 0.5);

      final restored = WrapLayer.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
      );

      expect(restored, isNotNull);
      expect(restored!.id, original.id);
      expect(restored.type, WrapLayerType.brush);
      expect(restored.color, original.color);
      expect(restored.opacity, 0.5);
      expect(restored.points, original.points);
    });

    test('keeps logo bytes', () {
      final image = WrapLayer.image(
        id: 'logo_1',
        name: 'Badge',
        bytes: _canvas(8, 8),
      );
      final restored = WrapLayer.fromJson(image.toJson())!;
      expect(restored.imageBytes, isNotNull);
      expect(restored.imageBytes!.length, image.imageBytes!.length);
    });

    test('a damaged entry is skipped instead of throwing', () {
      expect(WrapLayer.fromJson({'type': 'unknown', 'id': 'x'}), isNull);
      expect(WrapLayer.fromJson({'type': 'text'}), isNull);
    });

    test('empty layers know they draw nothing', () {
      expect(WrapLayer.text(id: 'a', text: '  ').isEmpty, isTrue);
      expect(WrapLayer.text(id: 'a', text: 'TESLA').isEmpty, isFalse);
      expect(WrapLayer.brush(id: 'b', color: 0xFFFFFFFF).isEmpty, isTrue);
    });
  });

  group('WrapCompositor', () {
    test('returns the base untouched when there is nothing to draw', () {
      final base = _canvas(32, 32);
      final result = WrapCompositor.composite(
        base: base,
        layers: const [],
        width: 32,
        height: 32,
      );
      expect(result, same(base));
    });

    test('a hidden layer is not drawn', () {
      final base = _canvas(64, 64);
      final layer = WrapLayer.text(id: 't', text: 'TESLA')
          .copyWith(visible: false);

      final result = WrapCompositor.composite(
        base: base,
        layers: [layer],
        width: 64,
        height: 64,
      )!;

      final decoded = img.decodePng(result)!;
      final original = img.decodePng(base)!;
      expect(
        decoded.getBytes(order: img.ChannelOrder.rgba),
        original.getBytes(order: img.ChannelOrder.rgba),
      );
    });

    test('draws text onto the canvas', () {
      final result = WrapCompositor.composite(
        base: _canvas(256, 256),
        layers: [
          WrapLayer.text(id: 't', text: 'TESLA', scale: 0.2),
        ],
        width: 256,
        height: 256,
      )!;

      final decoded = img.decodePng(result)!;
      // The middle of the canvas is where the text is centred.
      var bright = 0;
      for (var y = 100; y < 160; y++) {
        for (var x = 60; x < 200; x++) {
          if (decoded.getPixel(x, y).r > 200) bright++;
        }
      }
      expect(bright, greaterThan(100));
    });

    test('paints brush strokes', () {
      final stroke = WrapLayer.brush(
        id: 'b',
        color: 0xFFFF0000,
        scale: 0.03,
      ).copyWith(points: [0.1, 0.5, 0.9, 0.5]);

      final result = WrapCompositor.composite(
        base: _canvas(200, 200),
        layers: [stroke],
        width: 200,
        height: 200,
      )!;

      final decoded = img.decodePng(result)!;
      final pixel = decoded.getPixel(100, 100);
      expect(pixel.r, greaterThan(180));
      expect(pixel.g, lessThan(80));
    });

    test('scales a logo to the layer size', () {
      final logo = _canvas(64, 64, r: 255, g: 255, b: 255);
      final result = WrapCompositor.composite(
        base: _canvas(256, 256),
        layers: [
          WrapLayer.image(id: 'l', name: 'logo', bytes: logo, scale: 0.5),
        ],
        width: 256,
        height: 256,
      )!;

      final decoded = img.decodePng(result)!;
      // 50% of the width, centred: the centre is inside the logo.
      expect(decoded.getPixel(128, 128).r, greaterThan(200));
      // Well outside it the base colour is untouched.
      expect(decoded.getPixel(4, 4).r, lessThan(50));
    });

    test('resizes the base to the export size', () {
      final result = WrapCompositor.composite(
        base: _canvas(40, 40),
        layers: [WrapLayer.text(id: 't', text: 'X')],
        width: 128,
        height: 96,
      )!;

      final decoded = img.decodePng(result)!;
      expect(decoded.width, 128);
      expect(decoded.height, 96);
    });

    test('reports an unreadable base instead of throwing', () {
      expect(
        WrapCompositor.composite(
          base: Uint8List.fromList([1, 2, 3]),
          layers: [WrapLayer.text(id: 't', text: 'X')],
          width: 64,
          height: 64,
        ),
        isNull,
      );
    });
  });
}
