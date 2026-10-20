import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/tesla_model.dart';
import '../services/vehicle_service.dart';
import 'studio_page.dart';

/// Browses the wrap designs Tesla ships with, grouped by vehicle.
class GalleryPage extends StatefulWidget {
  /// Creates the gallery.
  const GalleryPage({super.key});

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  String? _selectedVehicleId;

  @override
  Widget build(BuildContext context) {
    final vehicles = VehicleService.getVehicles();
    final selected = _selectedVehicleId == null
        ? null
        : VehicleService.findById(_selectedVehicleId!);

    final entries = selected == null
        ? <_GalleryEntry>[
            for (final vehicle in vehicles)
              for (final path in vehicle.exampleWraps)
                _GalleryEntry(vehicle: vehicle, assetPath: path),
          ]
        : <_GalleryEntry>[
            for (final path in selected.exampleWraps)
              _GalleryEntry(vehicle: selected, assetPath: path),
          ];

    return Scaffold(
      backgroundColor: StudioColors.background,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'WRAP GALLERY',
          style: TextStyle(letterSpacing: 2),
        ),
        actions: [
          if (selected != null)
            TextButton(
              onPressed: () => setState(() => _selectedVehicleId = null),
              child: const Text('SHOW ALL'),
            ),
          const SizedBox(width: 20),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _vehicleChip('ALL', null),
                for (final vehicle in vehicles)
                  _vehicleChip(vehicle.name, vehicle.id),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: entries.isEmpty
                ? const Center(
                    child: Text(
                      'No designs for this vehicle yet.',
                      style: TextStyle(color: Colors.white38),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(20),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 260,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return _GalleryTile(entry: entry);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _vehicleChip(String label, String? id) {
    final selected = _selectedVehicleId == id;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _selectedVehicleId = id),
        labelStyle: TextStyle(
          color: selected ? Colors.black : Colors.white70,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
        backgroundColor: Colors.white.withAlpha(10),
        selectedColor: Colors.white,
      ),
    );
  }
}

class _GalleryEntry {
  const _GalleryEntry({required this.vehicle, required this.assetPath});

  final TeslaModel vehicle;
  final String assetPath;
}

class _GalleryTile extends StatelessWidget {
  const _GalleryTile({required this.entry});

  final _GalleryEntry entry;

  @override
  Widget build(BuildContext context) {
    final fileName = entry.assetPath.split('/').last;

    return Tooltip(
      message: '${entry.vehicle.name} - $fileName',
      child: Semantics(
        label: '${entry.vehicle.name} wrap $fileName',
        button: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => StudioPage(vehicle: entry.vehicle),
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(entry.assetPath, fit: BoxFit.cover),
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
                  left: 10,
                  right: 10,
                  child: Text(
                    fileName.replaceAll('.png', '').replaceAll('_', ' '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
