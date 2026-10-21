import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'template_masker.dart';

/// Raised when a design cannot be turned into a Tesla ready wrap.
class ExportException implements Exception {
  /// User facing explanation.
  final String message;

  const ExportException(this.message);

  @override
  String toString() => message;
}

/// A wrap that satisfies every requirement of Tesla's Paint Shop.
class ExportedWrap {
  /// PNG bytes ready to be uploaded to the car.
  final Uint8List bytes;

  /// File name without extension.
  final String fileName;

  /// Final pixel width.
  final int width;

  /// Final pixel height.
  final int height;

  /// Whether the image had to be scaled down to fit the size budget.
  final bool downscaled;

  /// Number of colours the image was quantised to, when that was needed.
  final int? quantizedColors;

  const ExportedWrap({
    required this.bytes,
    required this.fileName,
    required this.width,
    required this.height,
    required this.downscaled,
    this.quantizedColors,
  });

  /// Size of the PNG in bytes.
  int get sizeInBytes => bytes.length;

  /// Size of the PNG in megabytes.
  double get sizeInMegabytes => bytes.length / (1024 * 1024);

  /// File name including the `.png` extension.
  String get fileNameWithExtension => '$fileName.png';
}

/// Turns a generated image into a wrap file Tesla accepts.
///
/// Tesla's Paint Shop requires PNG files that are 512x512 to 1024x1024 pixels,
/// no larger than 1 MB, named with at most 30 alphanumeric characters,
/// underscores, dashes or spaces.
class WrapExporter {
  const WrapExporter._();

  /// Largest allowed edge length.
  static const int maxDimension = 1024;

  /// Smallest allowed edge length.
  static const int minDimension = 512;

  /// Largest allowed file size.
  static const int maxBytes = 1024 * 1024;

  /// Longest allowed file name.
  static const int maxFileNameLength = 30;

  /// Steps used when shrinking an image to fit the size budget.
  static const List<int> _downscaleSteps = [896, 768, 640, 512];

  /// Colour counts tried when shrinking is not enough.
  static const List<int> _quantizeSteps = [256, 128, 64];

  /// Cleans a user supplied name into a name Tesla accepts.
  ///
  /// Everything outside `A-Z a-z 0-9 _ -` and space is dropped, runs of
  /// whitespace collapse into a single space and the result is clipped to
  /// [maxFileNameLength] characters.
  static String sanitizeFileName(String raw) {
    var name = raw.trim();
    name = name.replaceAll(RegExp(r'[^A-Za-z0-9_\- ]'), '');
    name = name.replaceAll(RegExp(r'\s+'), ' ');
    name = name.trim();
    if (name.length > maxFileNameLength) {
      name = name.substring(0, maxFileNameLength).trim();
    }
    if (name.isEmpty) {
      name = 'tesla_wrap';
    }
    return name;
  }

  /// Whether a file name is already valid for Tesla.
  static bool isValidFileName(String name) =>
      name.isNotEmpty &&
      name.length <= maxFileNameLength &&
      RegExp(r'^[A-Za-z0-9_\- ]+$').hasMatch(name) &&
      name.trim() == name;

  /// Centre crops an image to the aspect ratio of the UV template and scales
  /// it to the template size.
  ///
  /// Returns `null` when the image cannot be decoded.
  static Uint8List? coverCropToTemplate(
    Uint8List sourceBytes, {
    required int templateWidth,
    required int templateHeight,
  }) {
    final decoded = img.decodeImage(sourceBytes);
    if (decoded == null) return null;

    final cropped = _coverCrop(
      decoded,
      targetWidth: templateWidth,
      targetHeight: templateHeight,
    );

    final resized = img.copyResize(
      cropped,
      width: templateWidth,
      height: templateHeight,
      interpolation: img.Interpolation.average,
    );

    return img.encodePng(resized, level: 6);
  }

  /// Builds a Tesla compliant PNG from a generated image.
  ///
  /// The image is centre cropped to the aspect ratio of the vehicle's UV
  /// template, scaled to the template size, clipped to the panel layout with
  /// [mask] when one is given and finally shrunk until it fits the 1 MB
  /// budget.
  ///
  /// The mask is applied last, on the finished artwork, so the alpha channel
  /// of the file is the alpha channel of the template. Tesla's own example
  /// wraps are byte for byte identical to it, and the car expects the same.
  ///
  /// [templateWidth] and [templateHeight] describe the target UV atlas.
  static ExportedWrap buildPng(
    Uint8List sourceBytes, {
    required int templateWidth,
    required int templateHeight,
    String fileName = 'tesla_wrap',
    PanelMask? mask,
  }) {
    final decoded = img.decodeImage(sourceBytes);
    if (decoded == null) {
      throw const ExportException(
        'The generated image could not be read. Try generating it again.',
      );
    }

    final cropped = _coverCrop(
      decoded,
      targetWidth: templateWidth,
      targetHeight: templateHeight,
    );

    // The artwork stays opaque while it is scaled. A transparent pixel would
    // drag the empty space into the panels and leave a dark rim along every
    // edge of the car.
    var working = img.copyResize(
      _flatten(cropped),
      width: templateWidth,
      height: templateHeight,
      interpolation: img.Interpolation.average,
    );

    var downscaled = false;
    int? quantizedColors;

    Uint8List encode() => img.encodePng(
          mask == null ? working : TemplateMasker.applyMaskToImage(working, mask),
          level: 6,
        );

    var encoded = encode();
    if (encoded.length > maxBytes) {
      downscaled = true;
      for (final step in _downscaleSteps) {
        final longest = _longestSide(working);
        final width = (working.width * step / longest).round();
        final height = (working.height * step / longest).round();
        if (width < minDimension || height < minDimension) {
          // Tesla rejects anything smaller than this, so there is nothing to
          // gain by going further down.
          break;
        }
        working = img.copyResize(
          working,
          width: width,
          height: height,
          interpolation: img.Interpolation.average,
        );
        encoded = encode();
        if (encoded.length <= maxBytes) break;
      }
    }

    if (encoded.length > maxBytes) {
      downscaled = true;
      for (final colors in _quantizeSteps) {
        working = img.quantize(
          working,
          numberOfColors: colors,
          method: img.QuantizeMethod.neuralNet,
          dither: img.DitherKernel.none,
        );
        encoded = encode();
        if (encoded.length <= maxBytes) {
          quantizedColors = colors;
          break;
        }
      }
    }

    if (encoded.length > maxBytes) {
      throw const ExportException(
        'This design is too detailed to fit into 1 MB. Try a simpler pattern.',
      );
    }

    return ExportedWrap(
      bytes: encoded,
      fileName: sanitizeFileName(fileName),
      width: working.width,
      height: working.height,
      downscaled: downscaled,
      quantizedColors: quantizedColors,
    );
  }

  /// Removes the transparency of an image.
  ///
  /// A wrap is opaque vinyl: only the panel layout of the template decides
  /// what stays empty. Flattening the artwork first keeps that layout from
  /// bleeding into the panels while the image is scaled.
  static img.Image _flatten(img.Image source) {
    final image = source.convert(numChannels: 4);
    final rgba = image.getBytes(order: img.ChannelOrder.rgba);
    for (var i = 3; i < rgba.length; i += 4) {
      rgba[i] = 255;
    }
    return img.Image.fromBytes(
      width: image.width,
      height: image.height,
      bytes: rgba.buffer,
      bytesOffset: rgba.offsetInBytes,
      numChannels: 4,
    );
  }

  /// Centre crops [source] so it covers [targetWidth] x [targetHeight].
  static img.Image _coverCrop(
    img.Image source, {
    required int targetWidth,
    required int targetHeight,
  }) {
    if (source.width == targetWidth && source.height == targetHeight) {
      return source;
    }

    final targetAspect = targetWidth / targetHeight;
    final sourceAspect = source.width / source.height;

    if ((sourceAspect - targetAspect).abs() < 0.001) {
      return source;
    }

    if (sourceAspect > targetAspect) {
      // Source is wider than the target: trim the sides.
      final newWidth = (source.height * targetAspect).round();
      return img.copyCrop(
        source,
        x: (source.width - newWidth) ~/ 2,
        y: 0,
        width: newWidth,
        height: source.height,
      );
    }

    // Source is taller than the target: trim the top and bottom.
    final newHeight = (source.width / targetAspect).round();
    return img.copyCrop(
      source,
      x: 0,
      y: (source.height - newHeight) ~/ 2,
      width: source.width,
      height: newHeight,
    );
  }

  static int _longestSide(img.Image image) =>
      image.width > image.height ? image.width : image.height;
}
