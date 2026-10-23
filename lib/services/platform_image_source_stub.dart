import 'image_source.dart';

/// Opens the platform's image picker.
///
/// The browser build has an `<input type="file">`; the other targets do not
/// ship a picker yet, so the studio reports that instead of failing.
Future<PickedImage?> pickImageImplementation() async => null;
