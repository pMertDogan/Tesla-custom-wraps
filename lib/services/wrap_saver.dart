import 'package:file_saver/file_saver.dart';

import 'export_service.dart';

/// Writes a finished wrap to disk.
///
/// On the web this triggers a browser download, on desktop and mobile it
/// writes the file through the platform file saver.
class WrapSaver {
  const WrapSaver._();

  /// Saves a wrap and returns the path or file name the platform reported.
  static Future<String> save(ExportedWrap wrap) async {
    try {
      return await FileSaver.instance.saveFile(
        name: wrap.fileName,
        bytes: wrap.bytes,
        fileExtension: 'png',
        mimeType: MimeType.png,
      );
    } on Exception catch (error) {
      throw ExportException('The wrap could not be saved: $error');
    }
  }
}
