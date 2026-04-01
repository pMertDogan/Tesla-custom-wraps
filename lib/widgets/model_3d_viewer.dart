import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

/// 3D Model Viewer widget for displaying Tesla models in 3D.
class Model3DViewer extends StatelessWidget {
  final String modelPath;
  final double width;
  final double height;

  const Model3DViewer({
    super.key,
    required this.modelPath,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ModelViewer(
          src: modelPath,
          alt: '3D Tesla Model',
          autoRotate: true,
          cameraControls: true,
          shadowIntensity: 0.5,
          environmentImage: 'neutral',
          backgroundColor: const Color(0xFF1A1A1A),
          cameraOrbit: '45deg 55deg 2.5m',
          minCameraOrbit: 'auto auto 1.5m',
          maxCameraOrbit: 'auto auto 5m',
          fieldOfView: '45deg',
          exposure: 1.0,
          interactionPrompt: InteractionPrompt.auto,
          loading: Loading.eager,
        ),
      ),
    );
  }
}

/// Gets the appropriate 3D model path for a vehicle ID.
String getModelPathForVehicle(String vehicleId) {
  switch (vehicleId) {
    case 'cybertruck':
      return 'modelFiles/tesla_cybertruck.glb';
    case 'model3':
      return 'modelFiles/tesla_m3_model.glb';
    case 'modely':
    case 'modely-2025-base':
    case 'modely-2025-premium':
    case 'modely-2025-performance':
    case 'modely-l':
      return 'modelFiles/2021_tesla_model_y.glb';
    default:
      return 'modelFiles/2021_tesla_model_y.glb';
  }
}
