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
    // The landing page is the first thing a phone sees: below 640 logical
    // pixels the labels in the app bar no longer fit next to the title.
    final compact = MediaQuery.sizeOf(context).width < 640;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          'TESLA WRAP STUDIO',
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: compact ? 16 : null,
            letterSpacing: compact ? 1 : 2,
          ),
        ),
        actions: compact
            ? [
                IconButton(
                  tooltip: 'Gallery',
                  icon: const Icon(Icons.grid_view, color: Colors.white),
                  onPressed: () => _openGallery(context),
                ),
                IconButton(
                  tooltip: 'Studio',
                  icon: const Icon(Icons.brush, color: Colors.white),
                  onPressed: () => _openStudio(context, vehicles.first),
                ),
                const SizedBox(width: 4),
              ]
            : [
                TextButton(
                  onPressed: () => _openGallery(context),
                  child: const Text(
                    'GALLERY',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 10),
                TextButton(
                  onPressed: () => _openStudio(context, vehicles.first),
                  child: const Text(
                    'STUDIO',
                    style: TextStyle(color: Colors.white),
                  ),
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
    final compact = MediaQuery.sizeOf(context).width < 700;

    return Container(
      width: double.infinity,
      height: compact ? 520 : 600,
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
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 20 : 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'DESIGN WITHOUT LIMITS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 32 : 60,
                  fontWeight: FontWeight.w900,
                  letterSpacing: compact ? 1.5 : 6,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: compact ? 16 : 24),
              Text(
                'Generate unique Tesla wraps using state-of-the-art AI.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: compact ? 15 : 22,
                  letterSpacing: compact ? 0.4 : 1.2,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: compact ? 28 : 48),
              // A `Row` overflows as soon as the two buttons no longer fit
              // side by side; `Wrap` moves the second one to its own line.
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 24,
                runSpacing: 16,
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
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 32 : 48,
                        vertical: compact ? 18 : 24,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: Text(
                      'GET STARTED',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: compact ? 15 : 18,
                      ),
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () => _openGallery(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white, width: 2),
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 32 : 48,
                        vertical: compact ? 18 : 24,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: Text(
                      'VIEW GALLERY',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: compact ? 15 : 18,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModelSelection(BuildContext context, List<TeslaModel> vehicles) {
    final compact = MediaQuery.sizeOf(context).width < 700;

    return SizedBox(
      height: compact ? 440 : 520,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        scrollDirection: Axis.horizontal,
        itemCount: vehicles.length,
        itemBuilder: (context, index) {
          final vehicle = vehicles[index];
          return Container(
            width: compact ? 300 : 400,
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
              const Flexible(
                child: Text(
                  'COMMUNITY GALLERY',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Four tiles across on a desktop, two on a phone. A fixed
              // count squeezes the tiles into unreadable slivers on narrow
              // screens.
              final width = constraints.maxWidth;
              final columns = width >= 1040 ? 4 : (width >= 520 ? 3 : 2);

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 24,
                  mainAxisSpacing: 24,
                  childAspectRatio: 1,
                ),
                itemCount: galleryImages.length,
                itemBuilder: (context, index) =>
                    _buildGalleryTile(context, galleryImages[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGalleryTile(BuildContext context, String assetPath) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(assetPath, fit: BoxFit.cover),
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
  }
}

/// Convenience re-export so the accent colour stays in one place.
const Color homeAccent = StudioColors.accent;
