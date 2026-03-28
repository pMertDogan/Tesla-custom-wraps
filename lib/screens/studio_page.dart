import 'package:flutter/material.dart';
import '../models/tesla_model.dart';

class StudioPage extends StatefulWidget {
  final TeslaModel vehicle;

  const StudioPage({super.key, required this.vehicle});

  @override
  State<StudioPage> createState() => _StudioPageState();
}

class _StudioPageState extends State<StudioPage> {
  final TextEditingController _promptController = TextEditingController();
  String _selectedProvider = 'DALL-E 3';
  final List<String> _providers = [
    'DALL-E 3',
    'Midjourney v6',
    'Stable Diffusion XL',
    'Adobe Firefly',
    'Custom OpenAI',
    'Custom Anthropic',
    'Custom Gemini',
    'Mistral AI',
    'Leonardo.ai',
    'Groq Cloud'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text('STUDIO: ${widget.vehicle.name.toUpperCase()}'),
        actions: [
          Tooltip(
            message: 'Settings',
            child: Semantics(
              label: 'Open settings',
              button: true,
              child: IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => _showSettings(context),
              ),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.download),
            label: const Text('EXPORT WRAP'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
            ),
          ),
          const SizedBox(width: 20),
        ],
      ),
      body: Row(
        children: [
          _buildSidebar(context),
          Expanded(
            child: _buildPreviewArea(context),
          ),
          _buildRightSidebar(context),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Container(
      width: 350,
      decoration: const BoxDecoration(
        color: Color(0xFF141414),
        border: Border(right: BorderSide(color: Colors.white10)),
      ),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'AI DESIGNER',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          const Text('AI PROVIDER', style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(13),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedProvider,
                isExpanded: true,
                dropdownColor: const Color(0xFF1E1E1E),
                items: _providers.map((p) => DropdownMenuItem(
                  value: p,
                  child: Text(p, style: const TextStyle(color: Colors.white)),
                )).toList(),
                onChanged: (val) => setState(() => _selectedProvider = val!),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('PROMPT', style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 8),
          TextField(
            controller: _promptController,
            maxLines: 4,
            maxLength: 1000,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Describe your wrap design...',
              hintStyle: const TextStyle(color: Colors.white24),
              filled: true,
              fillColor: Colors.white.withAlpha(13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('GENERATE WRAP', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const Divider(height: 48, color: Colors.white10),
          const Text(
            'MANUAL CONTROLS',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          _buildControlSlider('Opacity', 0.8),
          _buildControlSlider('Metallic', 0.2),
          _buildControlSlider('Roughness', 0.5),
        ],
      ),
    );
  }

  Widget _buildPreviewArea(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.asset(
                    widget.vehicle.imagePath,
                    width: 800,
                    fit: BoxFit.contain,
                  ),
                  const Positioned(
                    top: 40,
                    child: Chip(
                      label: Text('3D VIEW PLACEHOLDER', style: TextStyle(color: Colors.white70)),
                      backgroundColor: Colors.white12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: 60,
              color: Colors.white.withAlpha(5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Tooltip(
                    message: 'Rotate Left',
                    child: Semantics(
                      label: 'Rotate vehicle left',
                      button: true,
                      child: IconButton(icon: const Icon(Icons.rotate_left, color: Colors.white), onPressed: () {}),
                    ),
                  ),
                  Tooltip(
                    message: 'Rotate Right',
                    child: Semantics(
                      label: 'Rotate vehicle right',
                      button: true,
                      child: IconButton(icon: const Icon(Icons.rotate_right, color: Colors.white), onPressed: () {}),
                    ),
                  ),
                  const VerticalDivider(color: Colors.white10, width: 40),
                  Tooltip(
                    message: 'Zoom In',
                    child: Semantics(
                      label: 'Zoom in on vehicle',
                      button: true,
                      child: IconButton(icon: const Icon(Icons.zoom_in, color: Colors.white), onPressed: () {}),
                    ),
                  ),
                  Tooltip(
                    message: 'Zoom Out',
                    child: Semantics(
                      label: 'Zoom out from vehicle',
                      button: true,
                      child: IconButton(icon: const Icon(Icons.zoom_out, color: Colors.white), onPressed: () {}),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRightSidebar(BuildContext context) {
    return Container(
      width: 100,
      decoration: const BoxDecoration(
        color: Color(0xFF141414),
        border: Border(left: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          _buildSidebarAction(Icons.brush, 'Draw'),
          _buildSidebarAction(Icons.text_fields, 'Text'),
          _buildSidebarAction(Icons.image, 'Logo'),
          _buildSidebarAction(Icons.layers, 'Layers'),
        ],
      ),
    );
  }

  Widget _buildSidebarAction(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Icon(icon, color: Colors.white70, size: 28),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.white38)),
        ],
      ),
    );
  }

  Widget _buildControlSlider(String label, double value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
              Text('${(value * 100).toInt()}%', style: const TextStyle(fontSize: 12, color: Colors.white)),
            ],
          ),
          Slider(
            value: value,
            onChanged: (val) {},
            activeColor: Colors.blueAccent,
            inactiveColor: Colors.white12,
          ),
        ],
      ),
    );
  }

  void _showSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('API SETTINGS', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              maxLength: 512,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'API KEY',
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              maxLength: 512,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'CUSTOM BASE URL (Optional)',
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('SAVE')),
        ],
      ),
    );
  }
}
