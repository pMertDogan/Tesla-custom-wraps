import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Binary mask describing which pixels of a wrap texture belong to a body
/// panel.
///
/// Tesla's UV templates are line art: black strokes mark the panel borders and
/// the panel interiors are white. A finished wrap keeps that exact layout, the
/// artwork is clipped to the panels and the gaps in between stay empty.
///
/// The mask is derived by flooding the white background of the template from
/// the image border. Everything the flood cannot reach is inside a closed
/// panel outline and therefore paintable.
class PanelMask {
  /// Mask width in pixels.
  final int width;

  /// Mask height in pixels.
  final int height;

  /// One byte per pixel, `1` when the pixel belongs to a body panel.
  final Uint8List paintable;

  /// Creates a mask.
  const PanelMask({
    required this.width,
    required this.height,
    required this.paintable,
  });

  /// Fraction of the canvas that is paintable.
  double get coverage {
    if (paintable.isEmpty) return 0;
    var filled = 0;
    for (final value in paintable) {
      if (value != 0) filled++;
    }
    return filled / paintable.length;
  }
}

/// Builds and applies panel masks for Tesla's wrap templates.
class TemplateMasker {
  const TemplateMasker._();

  /// Luminance below which a template pixel counts as a stroke.
  static const int strokeThreshold = 140;

  /// How many pixels the strokes are grown by before flooding.
  ///
  /// Growing the strokes seals the hairline gaps anti-aliased line art can
  /// leave behind, which would otherwise let the flood leak into a panel.
  static const int strokeDilation = 2;

  /// Derives the panel mask of a template.
  ///
  /// Returns `null` when the template cannot be decoded.
  static PanelMask? buildMask(Uint8List templatePng) {
    final template = img.decodeImage(templatePng);
    if (template == null) return null;

    final width = template.width;
    final height = template.height;
    final rgba = template.getBytes(order: img.ChannelOrder.rgba);
    final pixelCount = width * height;

    final strokes = Uint8List(pixelCount);
    for (var i = 0; i < pixelCount; i++) {
      final offset = i * 4;
      final luminance = (0.299 * rgba[offset] +
              0.587 * rgba[offset + 1] +
              0.114 * rgba[offset + 2])
          .round();
      strokes[i] = luminance < strokeThreshold ? 1 : 0;
    }

    final sealed = _dilate(strokes, width, height, strokeDilation);
    final background = _floodFromBorder(sealed, width, height);

    final paintable = Uint8List(pixelCount);
    var paintableCount = 0;
    for (var i = 0; i < pixelCount; i++) {
      if (sealed[i] == 0 && background[i] == 0) {
        paintable[i] = 1;
        paintableCount++;
      }
    }

    // A flood that reached almost everything means the outlines were not
    // closed. Rather than returning an empty mask, hand back a mask that
    // keeps the whole canvas so the raw design survives untouched.
    if (paintableCount < pixelCount * 0.02) {
      return PanelMask(
        width: width,
        height: height,
        paintable: Uint8List.fromList(
          List<int>.filled(pixelCount, 1, growable: false),
        ),
      );
    }

    return PanelMask(
      width: width,
      height: height,
      paintable: paintable,
    );
  }

  /// Clips a generated design to the panel layout of [mask].
  ///
  /// Pixels outside a body panel are replaced with white, matching the way
  /// Tesla's own example wraps are built. Returns `null` when the artwork
  /// cannot be decoded.
  static Uint8List? applyMask(Uint8List artworkPng, PanelMask mask) {
    final artwork = img.decodeImage(artworkPng);
    if (artwork == null) return null;
    return img.encodePng(applyMaskToImage(artwork, mask), level: 6);
  }

  /// Clips an already decoded design to the panel layout of [mask].
  static img.Image applyMaskToImage(img.Image artwork, PanelMask mask) {
    final width = artwork.width;
    final height = artwork.height;
    final rgba = artwork.getBytes(order: img.ChannelOrder.rgba);

    final maskWidth = mask.width;
    final maskHeight = mask.height;

    for (var y = 0; y < height; y++) {
      final maskY = maskHeight == height ? y : (y * maskHeight) ~/ height;
      for (var x = 0; x < width; x++) {
        final maskX = maskWidth == width ? x : (x * maskWidth) ~/ width;
        final inside = mask.paintable[maskY * maskWidth + maskX] != 0;
        if (inside) continue;
        final offset = (y * width + x) * 4;
        rgba[offset] = 255;
        rgba[offset + 1] = 255;
        rgba[offset + 2] = 255;
        rgba[offset + 3] = 255;
      }
    }

    return img.Image.fromBytes(
      width: width,
      height: height,
      bytes: rgba.buffer,
      bytesOffset: rgba.offsetInBytes,
      numChannels: 4,
    );
  }

  /// Grows the stroke mask so hairline gaps in the line art are closed.
  static Uint8List _dilate(
    Uint8List strokes,
    int width,
    int height,
    int radius,
  ) {
    var current = strokes;
    for (var pass = 0; pass < radius; pass++) {
      final next = Uint8List(current.length);
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          var hit = 0;
          for (var dy = -1; dy <= 1 && hit == 0; dy++) {
            final ny = y + dy;
            if (ny < 0 || ny >= height) continue;
            for (var dx = -1; dx <= 1; dx++) {
              final nx = x + dx;
              if (nx < 0 || nx >= width) continue;
              if (current[ny * width + nx] != 0) {
                hit = 1;
                break;
              }
            }
          }
          next[y * width + x] = hit;
        }
      }
      current = next;
    }
    return current;
  }

  /// Marks every pixel reachable from the border without crossing a stroke.
  static Uint8List _floodFromBorder(
    Uint8List strokes,
    int width,
    int height,
  ) {
    final reached = Uint8List(width * height);
    final queue = Int32List(width * height);
    var head = 0;
    var tail = 0;

    void visit(int x, int y) {
      final index = y * width + x;
      if (reached[index] != 0) return;
      if (strokes[index] != 0) return;
      reached[index] = 1;
      queue[tail++] = index;
    }

    for (var x = 0; x < width; x++) {
      visit(x, 0);
      visit(x, height - 1);
    }
    for (var y = 0; y < height; y++) {
      visit(0, y);
      visit(width - 1, y);
    }

    while (head < tail) {
      final index = queue[head++];
      final x = index % width;
      final y = index ~/ width;

      if (x > 0) visit(x - 1, y);
      if (x < width - 1) visit(x + 1, y);
      if (y > 0) visit(x, y - 1);
      if (y < height - 1) visit(x, y + 1);
    }

    return reached;
  }
}
