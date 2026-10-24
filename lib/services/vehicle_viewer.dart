import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/tesla_model.dart';
import 'glb_texture_patch.dart';
import 'wrap_texture.dart';
import 'model_viewer_stub.dart'
    if (dart.library.js_interop) 'model_viewer_web.dart';

/// Builds the URL the 3D view loads the vehicle model from.
///
/// The compressed models live in `web/models/` rather than in the asset
/// bundle: the originals are 117 MB, the compressed set is 8 MB, and only the
/// browser build has a viewer. Every platform reaches them through the same
/// relative URL.
String? vehicleModelUrl(TeslaModel model) {
  final path = model.glbPath;
  if (path == null || path.isEmpty) return null;
  return 'models/${path.split('/').last}';
}

/// Whether this build can embed the 3D viewer at all.
///
/// The viewer is a `<model-viewer>` element, so it needs the web build. The
/// mobile and desktop builds keep the reference render and say so instead of
/// showing an empty box.
bool get has3dViewer => viewerPlatformSupportsModel;

/// Loads and prepares the 3D scene of [vehicle].
///
/// Returns the patched model bytes: the vehicle GLB with [design] applied to
/// its painted body. [design] is the wrap artwork, or `null` for the car's own
/// paint.
///
/// Nothing here throws: a model that cannot be downloaded or patched comes
/// back as `null`, and the caller falls back to the reference render.
Future<Uint8List?> loadVehicleScene(
  TeslaModel vehicle, {
  Uint8List? design,
  http.Client? client,
}) async {
  final url = vehicleModelUrl(vehicle);
  if (url == null) return null;

  try {
    final response = await (client ?? http.Client()).get(Uri.parse(url));
    if (response.statusCode != 200 || response.bodyBytes.isEmpty) return null;

    if (design == null) return response.bodyBytes;

    final texture = WrapTexture.build(design);
    return GlbMaterialOverride.applyWrapTexture(
      response.bodyBytes,
      texture: texture,
      mimeType: 'image/png',
    );
  } on Object catch (error) {
    debugPrint('3D vehicle could not be prepared: $error');
    return null;
  }
}

/// Renders a vehicle in 3D, or explains why this build cannot.
class VehicleViewer extends StatelessWidget {
  /// Vehicle the scene belongs to, used by the reference render fallback.
  final TeslaModel vehicle;

  /// Patched GLB bytes, or `null` while loading or when unavailable.
  final Uint8List? modelBytes;

  /// Height the viewer takes.
  final double? height;

  /// Creates the viewer.
  const VehicleViewer({
    super.key,
    required this.vehicle,
    required this.modelBytes,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final bytes = modelBytes;

    if (!has3dViewer) {
      return _ViewerFallback(
        vehicle: vehicle,
        height: height,
        message: 'The 3D preview runs in the browser build. This platform '
            'shows the vehicle reference render.',
      );
    }

    if (bytes == null) {
      return _ViewerFallback(
        vehicle: vehicle,
        height: height,
        message: vehicleModelUrl(vehicle) == null
            ? 'Tesla publishes no 3D model for the ${vehicle.name}. The '
                'reference render is shown instead.'
            : 'Loading the 3D model...',
      );
    }

    return buildModelViewer(modelBytes: bytes, height: height);
  }
}

/// Reference render with a short explanation, used when 3D is not available.
class _ViewerFallback extends StatelessWidget {
  const _ViewerFallback({
    required this.vehicle,
    required this.height,
    required this.message,
  });

  final TeslaModel vehicle;
  final double? height;
  final String message;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: Image.asset(vehicle.imagePath, fit: BoxFit.contain),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
