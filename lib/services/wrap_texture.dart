import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Turns the exported wrap atlas into the texture the 3D preview paints.
///
/// The wrap file is a UV atlas: opaque islands where Tesla's panels are, and
/// transparent gaps everywhere else. Painted straight onto a model the gaps
/// become holes, so the preview needs the artwork with those gaps closed.
///
/// Closing them by fading to a flat colour - or worse, by cropping the middle
/// of the atlas - is what made the 3D preview look wrong. This instead grows
/// every panel colour outwards, one pixel at a time, until the whole image is
/// covered: each gap takes the colour of the panel nearest to it, so the seams
/// between panels disappear and the design stays where the artist put it.
class WrapTexture {
  const WrapTexture._();

  /// Largest edge the preview texture keeps.
  ///
  /// The atlas is at most 1024 px and it travels through the DOM bridge, so
  /// this is a size the browser can upload without a stall.
  static const int maxEdge = 1024;

  /// Builds the preview texture from the exported [artwork].
  ///
  /// Returns the original bytes when they cannot be decoded, so a caller
  /// always has something to paint with.
  static Uint8List build(Uint8List artwork, {int maxEdge = WrapTexture.maxEdge}) {
    final decoded = img.decodeImage(artwork);
    if (decoded == null) return artwork;

    final largest = decoded.width > decoded.height ? decoded.width : decoded.height;
    final resized = largest > maxEdge
        ? img.copyResize(
            decoded,
            width: decoded.width >= decoded.height ? maxEdge : null,
            height: decoded.height > decoded.width ? maxEdge : null,
            interpolation: img.Interpolation.average,
          )
        : decoded;

    final rgba = resized.convert(numChannels: 4);
    _fillGaps(rgba);

    return img.encodePng(rgba, level: 6);
  }

  /// Replaces transparent pixels with the nearest opaque one.
  ///
  /// A breadth first flood from every opaque pixel at once, so the cost is
  /// linear in the number of pixels rather than one pass per gap.
  static void _fillGaps(img.Image image) {
    final width = image.width;
    final height = image.height;
    final total = width * height;

    final red = Uint8List(total);
    final green = Uint8List(total);
    final blue = Uint8List(total);
    final alpha = Uint8List(total);
    final filled = Uint8List(total);

    var opaque = 0;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final pixel = image.getPixel(x, y);
        final index = y * width + x;
        red[index] = pixel.r.toInt();
        green[index] = pixel.g.toInt();
        blue[index] = pixel.b.toInt();
        alpha[index] = pixel.a.toInt();
        if (pixel.a > 8) {
          filled[index] = 1;
          opaque++;
        }
      }
    }

    // Nothing painted at all: leave the artwork as it is instead of inventing
    // a colour for the whole image.
    if (opaque == 0) return;

    final queue = Uint32List(total);
    var head = 0;
    var tail = 0;
    for (var index = 0; index < total; index++) {
      if (filled[index] == 1) queue[tail++] = index;
    }

    while (head < tail) {
      final index = queue[head++];
      final x = index % width;
      final y = index ~/ width;
      final r = red[index];
      final g = green[index];
      final b = blue[index];

      void visit(int nx, int ny) {
        if (nx < 0 || ny < 0 || nx >= width || ny >= height) return;
        final neighbour = ny * width + nx;
        if (filled[neighbour] == 1) return;
        filled[neighbour] = 1;
        red[neighbour] = r;
        green[neighbour] = g;
        blue[neighbour] = b;
        alpha[neighbour] = 255;
        queue[tail++] = neighbour;
      }

      visit(x + 1, y);
      visit(x - 1, y);
      visit(x, y + 1);
      visit(x, y - 1);
    }

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final index = y * width + x;
        image.setPixelRgba(x, y, red[index], green[index], blue[index], 255);
      }
    }
  }
}
