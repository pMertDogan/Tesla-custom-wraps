import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Binary mask describing which pixels of a wrap texture belong to a body
/// panel, plus the alpha channel the finished wrap has to carry.
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

  /// The alpha channel of the template, one byte per pixel.
  ///
  /// This is the alpha channel every finished wrap carries. Tesla's own
  /// example wraps are byte for byte identical to the alpha channel of their
  /// template, so the exporter copies these values instead of inventing its
  /// own.
  final Uint8List alpha;

  Uint8List? _paintable;

  /// Creates a mask.
  PanelMask({
    required this.width,
    required this.height,
    required this.alpha,
  });

  /// One byte per pixel, `1` when the pixel belongs to a body panel.
  ///
  /// A pixel counts as paintable from [alphaThreshold] upwards. The softer
  /// edge of an anti-aliased cut line still carries vinyl, it just carries
  /// less of it.
  Uint8List get paintable =>
      _paintable ??= _derivePaintable();

  /// Fraction of the canvas that is paintable.
  double get coverage {
    final paintable = this.paintable;
    if (paintable.isEmpty) return 0;
    var filled = 0;
    for (final value in paintable) {
      if (value != 0) filled++;
    }
    return filled / paintable.length;
  }

  /// Alpha below which a template pixel counts as empty space.
  static const int alphaThreshold = 128;

  Uint8List _derivePaintable() {
    final result = Uint8List(alpha.length);
    for (var i = 0; i < alpha.length; i++) {
      if (alpha[i] >= alphaThreshold) result[i] = 1;
    }
    return result;
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
/// Tesla's own example wraps carry the alpha channel of their template, byte
/// for byte, and they never paint a single pixel outside of it. The mask
/// therefore does two things at once: it clips the artwork to the panels and
/// it gives the finished file the alpha channel Tesla expects.
class TemplateMasker {
  const TemplateMasker._();

  /// Alpha below which a template pixel counts as empty space.
  static const int alphaThreshold = PanelMask.alphaThreshold;

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

    final alpha = Uint8List(pixelCount);
    var paintableCount = 0;

    for (var i = 0; i < pixelCount; i++) {
      final value = rgba[i * 4 + 3];
      alpha[i] = value;

      // Empty space carries no alpha and never takes paint.
      if (value < alphaThreshold) continue;
      paintableCount++;
    }

    // A template without a single panel pixel is not a template. Rather than
    // handing back an empty mask, keep the whole canvas so the raw design
    // survives untouched.
    if (paintableCount == 0) {
      return PanelMask(
        width: width,
        height: height,
        alpha: Uint8List.fromList(List<int>.filled(pixelCount, 255)),
      );
    }

    return PanelMask(
      width: width,
      height: height,
      alpha: alpha,
    );
  }

  /// Clips a generated design to the panel layout of [mask].
  ///
  /// The artwork is cut back to the body panels and the file carries the
  /// alpha channel of the template, exactly like Tesla's own example wraps.
  /// Returns `null` when the artwork cannot be decoded.
  static Uint8List? applyMask(Uint8List artworkPng, PanelMask mask) {
    final artwork = img.decodeImage(artworkPng);
    if (artwork == null) return null;
    return img.encodePng(applyMaskToImage(artwork, mask), level: 6);
  }

  /// Clips an already decoded design to the panel layout of [mask].
  ///
  /// Two things happen here, and they are the same thing Tesla does when it
  /// hands out a wrap:
  ///
  /// - the artwork is cut back to the body panels, everything around and
  ///   between them is dropped,
  /// - the alpha channel of the template is copied onto the result, soft cut
  ///   line edges included.
  static img.Image applyMaskToImage(img.Image artwork, PanelMask mask) {
    final width = artwork.width;
    final height = artwork.height;

    // Work on a copy: the caller's image may be reused further down the
    // pipeline.
    final source = artwork.convert(numChannels: 4);
    final rgba = Uint8List.fromList(
      source.getBytes(order: img.ChannelOrder.rgba),
    );
    final templateAlpha = _alphaAtSize(mask, width, height);

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final offset = (y * width + x) * 4;
        final alpha = templateAlpha[y * width + x];

        if (alpha == 0) {
          // Empty space: no vinyl, and no artwork left behind either.
          rgba[offset] = 0;
          rgba[offset + 1] = 0;
          rgba[offset + 2] = 0;
          rgba[offset + 3] = 0;
          continue;
        }

        // Inside a panel the artwork keeps its colour and takes the opacity
        // of the template, so the soft edge of a cut line stays soft.
        rgba[offset + 3] = alpha;
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

  /// The alpha channel of [mask] scaled to [width] x [height].
  ///
  /// A wrap that had to be shrunk to fit the file size budget gets the alpha
  /// channel of the template with it, resampled the same way. The average
  /// keeps a one pixel cut line alive instead of dropping it between two
  /// pixels.
  static Uint8List _alphaAtSize(PanelMask mask, int width, int height) {
    if (mask.width == width && mask.height == height) return mask.alpha;

    final source = mask.alpha;
    final result = Uint8List(width * height);

    for (var y = 0; y < height; y++) {
      final y0 = (y * mask.height) ~/ height;
      final y1 = _end(y0, (y + 1) * mask.height ~/ height, mask.height);

      for (var x = 0; x < width; x++) {
        final x0 = (x * mask.width) ~/ width;
        final x1 = _end(x0, (x + 1) * mask.width ~/ width, mask.width);

        var sum = 0;
        var count = 0;
        for (var sy = y0; sy < y1; sy++) {
          for (var sx = x0; sx < x1; sx++) {
            sum += source[sy * mask.width + sx];
            count++;
          }
        }

        result[y * width + x] = count == 0 ? 0 : (sum / count).round();
      }
    }

    return result;
  }

  /// The last source pixel of a resampled span, always at least one past
  /// [start] so a span never collapses.
  static int _end(int start, int stop, int limit) {
    if (stop <= start) stop = start + 1;
    if (stop > limit) stop = limit;
    return stop;
  }
}
