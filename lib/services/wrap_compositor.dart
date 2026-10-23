import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../models/wrap_layer.dart';

/// Draws the layer stack over a wrap design.
///
/// The studio keeps the AI artwork untouched and stores text, logos and brush
/// strokes as layers. Rendering them into the pixels is this class' job, and it
/// happens at the export resolution so a logo is as sharp on the car as it is
/// in the preview.
///
/// Everything is drawn with the `image` package rather than the Flutter canvas:
/// the same code has to run in the browser (where Flutter rasterises to a
/// canvas, not to bytes), on the command line and in the tests.
class WrapCompositor {
  const WrapCompositor._();

  /// Renders [layers] over [base] at the given size.
  ///
  /// Returns [base] unchanged when nothing draws. Returns `null` when [base]
  /// cannot be decoded.
  static Uint8List? composite({
    required Uint8List base,
    required List<WrapLayer> layers,
    required int width,
    required int height,
  }) {
    final visible = layers.where((layer) => layer.visible && !layer.isEmpty);
    if (visible.isEmpty) return base;

    final decoded = img.decodeImage(base);
    if (decoded == null) return null;

    final canvas = decoded.width == width && decoded.height == height
        ? decoded.convert(numChannels: 4)
        : img.copyResize(
            decoded.convert(numChannels: 4),
            width: width,
            height: height,
            interpolation: img.Interpolation.average,
          );

    for (final layer in visible) {
      switch (layer.type) {
        case WrapLayerType.text:
          _drawText(canvas, layer);
        case WrapLayerType.image:
          _drawImage(canvas, layer);
        case WrapLayerType.brush:
          _drawBrush(canvas, layer);
      }
    }

    return img.encodePng(canvas, level: 6);
  }

  /// Draws a text layer centred on its position.
  static void _drawText(img.Image canvas, WrapLayer layer) {
    final desiredHeight = (layer.scale * canvas.width).clamp(6.0, 900.0);
    final font = _fontFor(desiredHeight);
    final color = _color(layer.color, layer.opacity);

    // The bitmap fonts are fixed size, so the text is drawn at the nearest
    // font size and then scaled to the layer's own size.
    final probe = img.Image(width: 8, height: 8);
    final textWidth = img.drawString(probe, layer.text, font: font);
    if (textWidth <= 0) return;

    final glyphs = img.Image(
      width: textWidth,
      height: font.lineHeight,
      numChannels: 4,
    );
    img.drawString(glyphs, layer.text, font: font, color: color);

    final factor = desiredHeight / font.lineHeight;
    final target = img.copyResize(
      glyphs,
      width: (textWidth * factor).round().clamp(1, 8192),
      height: (font.lineHeight * factor).round().clamp(1, 8192),
      interpolation: img.Interpolation.average,
    );

    img.compositeImage(
      canvas,
      target,
      dstX: (layer.x * canvas.width - target.width / 2).round(),
      dstY: (layer.y * canvas.height - target.height / 2).round(),
    );
  }

  /// Draws an image layer centred on its position.
  static void _drawImage(img.Image canvas, WrapLayer layer) {
    final bytes = layer.imageBytes;
    if (bytes == null) return;
    final logo = img.decodeImage(bytes);
    if (logo == null) return;

    final targetWidth = (layer.scale * canvas.width).round().clamp(1, 4096);
    final targetHeight =
        (logo.height * targetWidth / logo.width).round().clamp(1, 4096);
    var scaled = img.copyResize(
      logo,
      width: targetWidth,
      height: targetHeight,
      interpolation: img.Interpolation.average,
    );

    if (layer.opacity < 1) {
      scaled = _withOpacity(scaled, layer.opacity);
    }

    img.compositeImage(
      canvas,
      scaled,
      dstX: (layer.x * canvas.width - targetWidth / 2).round(),
      dstY: (layer.y * canvas.height - targetHeight / 2).round(),
    );
  }

  /// Draws the points of a brush layer as a polyline.
  static void _drawBrush(img.Image canvas, WrapLayer layer) {
    final points = layer.points;
    if (points.length < 4) return;

    final thickness = (layer.scale * canvas.width).round().clamp(1, 512);
    final color = _color(layer.color, layer.opacity);

    for (var i = 0; i + 3 < points.length; i += 2) {
      img.drawLine(
        canvas,
        x1: (points[i] * canvas.width).round(),
        y1: (points[i + 1] * canvas.height).round(),
        x2: (points[i + 2] * canvas.width).round(),
        y2: (points[i + 3] * canvas.height).round(),
        color: color,
        thickness: thickness,
        antialias: true,
      );
    }
  }

  /// The bitmap font closest to [pixelHeight].
  static img.BitmapFont _fontFor(double pixelHeight) {
    if (pixelHeight >= 40) return img.arial48;
    if (pixelHeight >= 22) return img.arial24;
    return img.arial14;
  }

  /// `0xAARRGGBB` with [opacity] folded into the alpha channel.
  static img.Color _color(int argb, double opacity) {
    final alpha = ((argb >> 24) & 0xFF) / 255;
    return img.ColorRgba8(
      (argb >> 16) & 0xFF,
      (argb >> 8) & 0xFF,
      argb & 0xFF,
      (alpha * opacity * 255).round().clamp(0, 255),
    );
  }

  /// Scales the alpha channel of [image] by [opacity].
  static img.Image _withOpacity(img.Image image, double opacity) {
    final result = image.convert(numChannels: 4);
    final rgba = result.getBytes(order: img.ChannelOrder.rgba);
    for (var i = 3; i < rgba.length; i += 4) {
      rgba[i] = (rgba[i] * opacity).round().clamp(0, 255);
    }
    return img.Image.fromBytes(
      width: result.width,
      height: result.height,
      bytes: rgba.buffer,
      bytesOffset: rgba.offsetInBytes,
      numChannels: 4,
    );
  }
}
