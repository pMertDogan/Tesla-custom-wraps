import '../models/tesla_model.dart';

class VehicleService {
  static List<TeslaModel> getVehicles() {
    return [
      TeslaModel(
        id: 'cybertruck',
        name: 'Cybertruck',
        description: 'Futuristic design, built for any planet.',
        imagePath: 'assets/cybertruck/vehicle_image.png',
        templatePath: 'assets/cybertruck/template.png',
        glbPath: 'assets/models/tesla_cybertruck.glb',
        exampleWraps: [
          'assets/cybertruck/example/Camo_Stealth.png',
          'assets/cybertruck/example/Gradient_Sunburst.png',
          'assets/cybertruck/example/Rust.png',
        ],
      ),
      TeslaModel(
        id: 'model3',
        name: 'Model 3',
        description: 'The best-selling electric sedan.',
        imagePath: 'assets/model3/vehicle_image.png',
        templatePath: 'assets/model3/template.png',
        glbPath: 'assets/models/tesla_m3_model.glb',
        exampleWraps: [
          'assets/model3/example/Acid_Drip.png',
          'assets/model3/example/Cosmic_Burst.png',
          'assets/model3/example/Sakura.png',
        ],
      ),
      TeslaModel(
        id: 'modely',
        name: 'Model Y',
        description: 'Versatile electric SUV.',
        imagePath: 'assets/modely/vehicle_image.png',
        templatePath: 'assets/modely/template.png',
        glbPath: 'assets/models/2025_tesla_model_y.glb',
        exampleWraps: [
          'assets/modely/example/Pixel_Art.png',
          'assets/modely/example/Vintage_Stripes.png',
        ],
      ),
      TeslaModel(
        id: 'modely-2021',
        name: 'Model Y (2021)',
        description: 'Classic Model Y design.',
        imagePath: 'assets/modely/vehicle_image.png',
        templatePath: 'assets/modely/template.png',
        glbPath: 'assets/models/2021_tesla_model_y.glb',
        exampleWraps: [
          'assets/modely/example/Acid_Drip.png',
          'assets/modely/example/Camo.png',
        ],
      ),
      TeslaModel(
        id: 'modely-2026-perf',
        name: 'Model Y Performance (2026)',
        description: 'High performance SUV of the future.',
        imagePath: 'assets/modely/vehicle_image.png',
        templatePath: 'assets/modely/template.png',
        glbPath: 'assets/models/2026_tesla_model_y_performance.glb',
        exampleWraps: [
          'assets/modely/example/Cosmic_Burst.png',
          'assets/modely/example/Leopard.png',
        ],
      ),
    ];
  }
}
