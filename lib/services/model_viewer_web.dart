import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Whether the platform can embed the `<model-viewer>` 3D element.
const bool viewerPlatformSupportsModel = true;

@JS('studioViewer.load')
external JSPromise<JSAny?> _loadViewer();

@JS('studioViewer.attach')
external void _attach(JSAny element, JSUint8Array bytes, JSString background);

/// Downloads the viewer bundle if it is not there yet.
Future<void> _ensureViewer() async {
  await _loadViewer().toDart;
}

/// Builds the 3D view with the `<model-viewer>` web component.
///
/// The element is created by the browser, because a custom element cannot be
/// instantiated from Dart, and `web/viewer.js` hands it the model through an
/// object URL. The first frame waits for the viewer bundle, which is fetched
/// on demand rather than shipped in `index.html`.
Widget buildModelViewer({
  required Uint8List modelBytes,
  double? height,
}) {
  return SizedBox(
    height: height,
    child: FutureBuilder<void>(
      future: _ensureViewer(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'The 3D viewer could not be loaded. Check your connection.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }
        return HtmlElementView.fromTagName(
          'model-viewer',
          onElementCreated: (Object element) {
            if (element is JSObject) {
              _attach(element, modelBytes.toJS, 'transparent'.toJS);
            }
          },
        );
      },
    ),
  );
}
