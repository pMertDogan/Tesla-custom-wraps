import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/design_provider.dart';
import '../models/gallery_item.dart';
import '../services/vehicle_service.dart';

/// Gallery page showing community wrap designs.
class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key});

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  String _filter = 'all';
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final vehicles = VehicleService.getVehicles();

    // Build gallery items from example wraps
    final List<GalleryItem> allItems = [];
    for (final vehicle in vehicles) {
      for (int i = 0; i < vehicle.exampleWraps.length; i++) {
        allItems.add(
          GalleryItem(
            id: '${vehicle.id}_example_$i',
            vehicleModelId: vehicle.id,
            vehicleName: vehicle.name,
            designName: vehicle.exampleWraps[i].split('/').last.replaceAll('.png', '').replaceAll('_', ' '),
            authorName: 'Tesla Studio',
            thumbnailPath: vehicle.exampleWraps[i],
            designPath: vehicle.exampleWraps[i],
            likes: (i + 1) * 42,
          ),
        );
      }
    }

    // Add saved designs
    final provider = context.watch<DesignProvider>();
    for (final design in provider.savedDesigns) {
      allItems.add(
        GalleryItem(
          id: design.id,
          vehicleModelId: design.vehicleModelId,
          vehicleName: design.vehicleName,
          designName: design.prompt ?? 'Custom Design',
          authorName: 'You',
          likes: 0,
          isLiked: design.isFavorite,
        ),
      );
    }

    // Filter
    final filteredItems = allItems.where((item) {
      if (_filter != 'all' && item.vehicleModelId != _filter) return false;
      if (_searchQuery.isNotEmpty &&
          !item.designName.toLowerCase().contains(_searchQuery.toLowerCase()) &&
          !item.vehicleName.toLowerCase().contains(_searchQuery.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'COMMUNITY GALLERY',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite),
            onPressed: () {
              setState(() => _filter = _filter == 'favorites' ? 'all' : 'favorites');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search designs...',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: Colors.white.withAlpha(13),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),

          // Filter chips
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildFilterChip('All', 'all'),
                ...vehicles.map((v) => _buildFilterChip(v.name, v.id)),
                _buildFilterChip('Favorites', 'favorites'),
              ],
            ),
          ),

          const Divider(color: Colors.white10),

          // Gallery grid
          Expanded(
            child: filteredItems.isEmpty
                ? const Center(
                    child: Text(
                      'No designs found.',
                      style: TextStyle(color: Colors.white54, fontSize: 16),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.0,
                      ),
                      itemCount: filteredItems.length,
                      itemBuilder: (context, index) {
                        return _buildGalleryItem(context, filteredItems[index]);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => setState(() => _filter = value),
        backgroundColor: Colors.white10,
        selectedColor: Colors.blueAccent,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.white70,
        ),
      ),
    );
  }

  Widget _buildGalleryItem(BuildContext context, GalleryItem item) {
    return GestureDetector(
      onTap: () => _showDesignDetail(context, item),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (item.thumbnailPath != null)
              Image.asset(item.thumbnailPath!, fit: BoxFit.cover)
            else
              Container(
                color: const Color(0xFF2A2A2A),
                child: const Icon(Icons.image, size: 48, color: Colors.white24),
              ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withAlpha(200),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.designName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Text(
                        item.vehicleName,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.favorite, color: Colors.redAccent, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '${item.likes}',
                        style: const TextStyle(color: Colors.white70, fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDesignDetail(BuildContext context, GalleryItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  item.designName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    item.isLiked ? Icons.favorite : Icons.favorite_border,
                    color: item.isLiked ? Colors.redAccent : Colors.white70,
                  ),
                  onPressed: () {
                    if (item.id.startsWith('design_')) {
                      context.read<DesignProvider>().toggleFavorite(item.id);
                    }
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Vehicle: ${item.vehicleName}',
              style: const TextStyle(color: Colors.white70),
            ),
            if (item.prompt != null) ...[
              const SizedBox(height: 8),
              const Text('Prompt:', style: TextStyle(color: Colors.white54)),
              Text(
                item.prompt!,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
            const SizedBox(height: 16),
            if (item.thumbnailPath != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(item.thumbnailPath!, fit: BoxFit.cover),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('USE THIS DESIGN'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
