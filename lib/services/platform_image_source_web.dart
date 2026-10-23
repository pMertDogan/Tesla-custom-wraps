import 'dart:convert';
import 'dart:js_interop';

import 'image_source.dart';

@JS('studioFiles.pickImage')
external JSPromise<JSAny?> _pickImage(bool anyFile);

/// Opens the browser's file picker and reads the chosen logo.
///
/// The file is read in `web/files.js`, which resolves with `{name, base64}`
/// rather than a `File`, so nothing but plain data crosses into Dart.
Future<PickedImage?> pickImageImplementation() async {
  try {
    final result = await _pickImage(false).toDart;
    if (result == null || result.isUndefinedOrNull) return null;

    final map = (result as JSObject).dartify();
    if (map is! Map) return null;

    final base64Data = map['base64'];
    if (base64Data is! String || base64Data.isEmpty) return null;

    final bytes = base64Decode(base64Data);
    if (bytes.length > maxLogoBytes) return null;

    final name = map['name'];
    return PickedImage(
      bytes: bytes,
      name: name is String && name.trim().isNotEmpty
          ? _withoutExtension(name)
          : 'Logo',
    );
  } on Object {
    return null;
  }
}

/// Drops the file extension and path, and the characters a layer name does not
/// need.
String _withoutExtension(String fileName) {
  final base = fileName.split('/').last.split('\\').last;
  final dot = base.lastIndexOf('.');
  return (dot > 0 ? base.substring(0, dot) : base).trim();
}
