import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Whether the platform can embed the `<model-viewer>` 3D element.
///
/// Only the browser build can; everywhere else the studio falls back to the
/// vehicle reference render.
const bool viewerPlatformSupportsModel = false;

/// Builds the 3D view.
///
/// This is the non-browser implementation and is never called: [VehicleViewer]
/// checks [viewerPlatformSupportsModel] first. Keeping the symbol means the
/// screen does not need a conditional import of its own.
Widget buildModelViewer({
  required Uint8List modelBytes,
  double? height,
}) {
  return SizedBox(
    height: height,
    child: const Center(
      child: Text(
        '3D preview is available in the browser build.',
        style: TextStyle(color: Colors.white38, fontSize: 12),
      ),
    ),
  );
}
