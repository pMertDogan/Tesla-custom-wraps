/// Whether the app is running inside a browser.
///
/// The studio runs on three different Dart targets: Flutter on mobile and
/// desktop, Flutter in a browser, and the plain Dart VM for the command line
/// tool. `package:flutter/foundation.dart` would answer the question, but it
/// pulls in `dart:ui`, which the command line tool cannot load. A conditional
/// import keeps the tool working without dragging the engine into it.
library;

export 'platform_support_stub.dart'
    if (dart.library.js_interop) 'platform_support_web.dart'
    if (dart.library.html) 'platform_support_web.dart';
