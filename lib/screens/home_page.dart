import 'package:flutter/material.dart';
import 'studio_page.dart';
import '../models/tesla_model.dart';
import '../services/vehicle_service.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final vehicles = VehicleService.getVehicles();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'TESLA WRAP STUDIO',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {},
            child: const Text('GALLERY', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 10),
          TextButton(
            onPressed: () {},
            child: const Text('STUDIO', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 20),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFeaturedSection(context, vehicles),
            const Padding(
              padding: EdgeInsets.fromLTRB(32, 64, 32, 24),
              child: Text(
                'CHOOSE YOUR CANVAS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ),
            _buildModelSelection(context, vehicles),
            const Padding(
              padding: EdgeInsets.fromLTRB(32, 64, 32, 24),
              child: Text(
                'COMMUNITY GALLERY',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ),
            _buildGallerySection(context, vehicles),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedSection(BuildContext context, List<TeslaModel> vehicles) {
    return Container(
      width: double.infinity,
      height: 600,
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        image: const DecorationImage(
          image: AssetImage('assets/images/paint-shop-wraps-ct.png'),
          fit: BoxFit.cover,
          opacity: 0.5,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black,
              Colors.black.withAlpha(76),
              Colors.transparent,
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'DESIGN WITHOUT LIMITS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 60,
                fontWeight: FontWeight.w900,
                letterSpacing: 6,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            const Text(
              'Generate unique Tesla wraps using state-of-the-art AI.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 22,
                letterSpacing: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    if (vehicles.isNotEmpty) {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => StudioPage(vehicle: vehicles[0])));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: const Text(
                    'GET STARTED',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                const SizedBox(width: 24),
                OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white, width: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: const Text(
                    'VIEW GALLERY',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModelSelection(BuildContext context, List<TeslaModel> vehicles) {
    return SizedBox(
      height: 450,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        scrollDirection: Axis.horizontal,
        itemCount: vehicles.length,
        itemBuilder: (context, index) {
          final vehicle = vehicles[index];
          return Container(
            width: 400,
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF121212),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      image: DecorationImage(
                        image: AssetImage(vehicle.imagePath),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vehicle.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Text(
                            vehicle.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => StudioPage(vehicle: vehicle))),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white10,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('CUSTOMIZE'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGallerySection(BuildContext context, List<TeslaModel> vehicles) {
    final List<String> galleryImages = [
      'assets/cybertruck/example/Camo_Stealth.png',
      'assets/cybertruck/example/Gradient_Sunburst.png',
      'assets/cybertruck/example/Rust.png',
      'assets/model3/example/Acid_Drip.png',
      'assets/model3/example/Cosmic_Burst.png',
      'assets/model3/example/Sakura.png',
      'assets/modely/example/Pixel_Art.png',
      'assets/modely/example/Vintage_Stripes.png',
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 24,
          mainAxisSpacing: 24,
          childAspectRatio: 1.0,
        ),
        itemCount: galleryImages.length,
        itemBuilder: (context, index) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  galleryImages[index],
                  fit: BoxFit.cover,
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withAlpha(153),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                const Positioned(
                  bottom: 12,
                  left: 12,
                  child: Icon(Icons.favorite_border, color: Colors.white70),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
