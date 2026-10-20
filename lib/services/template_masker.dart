import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Binary mask describing which pixels of a wrap texture belong to a body
/// panel.
///
/// Tesla's UV templates are line art: black strokes mark the panel borders and
/// the panel interiors are white. A finished wrap keeps that exact layout, the
/// artwork is clipped to the panels and the gaps in between stay empty.
///
/// The mask is derived from the alpha channel of the template. Transparent
/// pixels are the space around and between the panels, every opaque pixel
/// carries artwork.
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
///
/// Tesla's templates are RGBA line art with two distinct kinds of pixel:
///
/// - **transparent** — the empty space around and between the body panels,
/// - **opaque** — everything that belongs to the wrap: the inside of a body
///   panel and the cut lines between them.
///
/// Tesla's own example wraps paint the cut lines as well, the artwork runs
/// across the seams from one panel to the next. The cut line is a black
/// stroke in the template only so the installer knows where to slice the
/// vinyl, it is not an area that stays unpainted. The mask therefore follows
/// the alpha channel: opaque in, transparent out.
class TemplateMasker {
  const TemplateMasker._();

  /// Alpha below which a template pixel counts as empty space.
  static const int alphaThreshold = 128;

  /// Derives the panel mask of a template.
  ///
  /// Returns `null` when the template cannot be decoded.
  static PanelMask? buildMask(Uint8List templatePng) {
    final template = img.decodeImage(templatePng);
    if (template == null) return null;

    final width = template.width;
    final height = template.height;
    final pixelCount = width * height;

    final source = template.numChannels == 4
        ? template
        : template.convert(numChannels: 4);
    final rgba = source.getBytes(order: img.ChannelOrder.rgba);

    final paintable = Uint8List(pixelCount);
    var paintableCount = 0;

    for (var i = 0; i < pixelCount; i++) {
      // Empty space carries no alpha and never takes paint.
      if (rgba[i * 4 + 3] < alphaThreshold) continue;

      paintable[i] = 1;
      paintableCount++;
    }

    // A template without a single panel pixel is not a template. Rather than
    // handing back an empty mask, keep the whole canvas so the raw design
    // survives untouched.
    if (paintableCount == 0) {
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
    final source =
        artwork.numChannels == 4 ? artwork : artwork.convert(numChannels: 4);
    final rgba = source.getBytes(order: img.ChannelOrder.rgba);

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
}
