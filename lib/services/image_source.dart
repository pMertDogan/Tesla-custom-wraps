import 'platform_image_source_stub.dart'
    if (dart.library.js_interop) 'platform_image_source_web.dart';

/// Bytes of an image the user picked, plus the name to show in the layer list.
class PickedImage {
  /// Creates a picked image.
  const PickedImage({required this.bytes, required this.name});

  /// Encoded bytes (PNG, JPEG, WebP or GIF).
  final List<int> bytes;

  /// File name without its extension.
  final String name;
}

/// Opens the platform's image picker and returns what the user chose.
///
/// Returns `null` when the user cancels or when the platform cannot pick an
/// image at all, which the caller reports in the interface instead of failing.
Future<PickedImage?> pickImage() => pickImageImplementation();

/// Largest logo the studio accepts, in bytes.
const int maxLogoBytes = 4 * 1024 * 1024;
