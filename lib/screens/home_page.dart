import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/tesla_model.dart';
import '../services/vehicle_service.dart';
import 'gallery_page.dart';
import 'studio_page.dart';

/// Landing page: pick a vehicle, browse the gallery, start designing.
class HomePage extends StatelessWidget {
  /// Creates the home page.
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
            onPressed: () => _openGallery(context),
            child: const Text('GALLERY', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 10),
          TextButton(
            onPressed: () => _openStudio(context, vehicles.first),
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
            _buildGallerySection(context, vehicles),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  static void _openGallery(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const GalleryPage()),
    );
  }

  static void _openStudio(BuildContext context, TeslaModel vehicle) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => StudioPage(vehicle: vehicle)),
    );
  }

  Widget _buildFeaturedSection(
    BuildContext context,
    List<TeslaModel> vehicles,
  ) {
    return Container(
      width: double.infinity,
      height: 600,
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F0F),
        image: DecorationImage(
          image: AssetImage('images/paint-shop-wraps-ct.png'),
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
                      _openStudio(context, vehicles.first);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 48,
                      vertical: 24,
                    ),
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
                  onPressed: () => _openGallery(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white, width: 2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 48,
                      vertical: 24,
                    ),
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
      height: 520,
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
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      image: DecorationImage(
                        image: AssetImage(vehicle.imagePath),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 185,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vehicle.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: Text(
                            vehicle.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 48,
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => _openStudio(context, vehicle),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white10,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('CUSTOMIZE'),
                          ),
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
    final galleryImages = <String>[
      for (final vehicle in vehicles.take(3))
        ...vehicle.exampleWraps.take(3),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 64, 32, 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'COMMUNITY GALLERY',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              TextButton(
                onPressed: () => _openGallery(context),
                child: const Text('SEE ALL'),
              ),
            ],
          ),
        ),
        Padding(
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
                    Image.asset(galleryImages[index], fit: BoxFit.cover),
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
                    Positioned(
                      bottom: 4,
                      left: 4,
                      child: Tooltip(
                        message: 'Like this design',
                        child: Semantics(
                          label: 'Like design',
                          button: true,
                          child: IconButton(
                            icon: const Icon(
                              Icons.favorite_border,
                              color: Colors.white70,
                            ),
                            onPressed: () {
                              ScaffoldMessenger.of(context)
                                ..hideCurrentSnackBar()
                                ..showSnackBar(
                                  const SnackBar(
                                    content: Text('Added to your favorites!'),
                                    duration: Duration(seconds: 2),
                                    behavior: SnackBarBehavior.floating,
                                    width: 250,
                                  ),
                                );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Convenience re-export so the accent colour stays in one place.
const Color homeAccent = StudioColors.accent;
