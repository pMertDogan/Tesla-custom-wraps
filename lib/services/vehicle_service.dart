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
        exampleWraps: [
          'assets/modely/example/Pixel_Art.png',
          'assets/modely/example/Vintage_Stripes.png',
        ],
      ),
    ];
  }
}
