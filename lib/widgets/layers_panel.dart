import 'package:flutter/material.dart';
import '../providers/design_provider.dart';
import '../models/design_layer.dart';
import 'package:provider/provider.dart';

/// Layers Panel widget for managing design layers.
class LayersPanel extends StatelessWidget {
  const LayersPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DesignProvider>();
    final layers = provider.layers;

    if (layers.isEmpty) {
      return const Center(
        child: Text(
          'No layers yet.\nGenerate a wrap or add elements to create layers.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54, fontSize: 14),
        ),
      );
    }

    return ReorderableListView.builder(
      itemCount: layers.length,
      onReorder: (oldIndex, newIndex) {
        provider.reorderLayer(oldIndex, newIndex);
      },
      itemBuilder: (context, index) {
        final layer = layers[index];
        return _buildLayerTile(context, layer, index);
      },
    );
  }

  Widget _buildLayerTile(BuildContext context, DesignLayer layer, int index) {
    final provider = Provider.of<DesignProvider>(context, listen: false);

    return Container(
      key: ValueKey(layer.id),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: layer.isVisible ? Colors.white10 : Colors.white.withAlpha(5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: layer.isVisible ? Colors.white24 : Colors.white10,
        ),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(
          _getLayerIcon(layer.type),
          color: layer.isVisible ? Colors.white70 : Colors.white24,
          size: 24,
        ),
        title: Text(
          layer.name,
          style: TextStyle(
            color: layer.isVisible ? Colors.white : Colors.white38,
            fontSize: 12,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${(layer.opacity * 100).toInt()}%',
          style: const TextStyle(color: Colors.white54, fontSize: 10),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Tooltip(
              message: layer.isVisible ? 'Hide layer' : 'Show layer',
              child: IconButton(
                icon: Icon(
                  layer.isVisible ? Icons.visibility : Icons.visibility_off,
                  color: Colors.white70,
                  size: 18,
                ),
                onPressed: () => provider.toggleLayerVisibility(layer.id),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent, size: 18),
              onPressed: () => _confirmDelete(context, layer),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getLayerIcon(LayerType type) {
    switch (type) {
      case LayerType.wrapImage:
        return Icons.image;
      case LayerType.drawing:
        return Icons.brush;
      case LayerType.text:
        return Icons.text_fields;
      case LayerType.logo:
        return Icons.image;
    }
  }

  void _confirmDelete(BuildContext context, DesignLayer layer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Delete Layer', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete "${layer.name}"?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              Provider.of<DesignProvider>(context, listen: false)
                  .removeLayer(layer.id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }
}
