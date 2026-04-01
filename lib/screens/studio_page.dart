import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import '../models/tesla_model.dart';
import '../models/ai_provider.dart';
import '../providers/design_provider.dart';
import '../services/ai_service.dart';
import '../widgets/drawing_canvas.dart';
import '../widgets/model_3d_viewer.dart';
import '../widgets/layers_panel.dart';
import '../models/drawing_element.dart';

class StudioPage extends StatefulWidget {
  final TeslaModel vehicle;

  const StudioPage({super.key, required this.vehicle});

  @override
  State<StudioPage> createState() => _StudioPageState();
}

class _StudioPageState extends State<StudioPage> {
  final TextEditingController _promptController = TextEditingController();
  final ScreenshotController _screenshotController = ScreenshotController();
  final AIService _aiService = AIService();

  // Provider-to-ID mapping
  final Map<String, String> _providerIdMap = {
    'DALL-E 3': 'dalle3',
    'Midjourney v6': 'midjourney',
    'Stable Diffusion XL': 'stability',
    'Adobe Firefly': 'adobe',
    'Custom OpenAI': 'custom_openai',
    'Custom Anthropic': 'custom_anthropic',
    'Custom Gemini': 'custom_gemini',
    'Mistral AI': 'mistral',
    'Leonardo.ai': 'leonardo',
    'Groq Cloud': 'groq',
  };

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
    'Groq Cloud',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<DesignProvider>();
      provider.setCurrentVehicle(widget.vehicle.id, widget.vehicle.name);
      provider.loadSettings();

      // Configure AI service
      _aiService.updateConfig(
        apiKey: provider.apiKey,
        baseUrl: provider.baseUrl,
        provider: AIProvider(
          id: _providerIdMap[provider.selectedProviderId] ?? 'dalle3',
          name: provider.selectedProviderId,
          logoUrl: '',
        ),
      );
    });
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DesignProvider>(
      builder: (context, provider, child) {
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
              Tooltip(
                message: 'Save design',
                child: Semantics(
                  label: 'Save wrap design',
                  button: true,
                  child: IconButton(
                    icon: const Icon(Icons.save),
                    onPressed: () => _showSaveDialog(context),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Tooltip(
                message: 'Export your design',
                child: Semantics(
                  label: 'Export wrap design',
                  button: true,
                  child: ElevatedButton.icon(
                    onPressed: () => _exportDesign(context),
                    icon: const Icon(Icons.download),
                    label: const Text('EXPORT'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
            ],
          ),
          body: Row(
            children: [
              _buildSidebar(context, provider),
              Expanded(child: _buildPreviewArea(context, provider)),
              _buildRightSidebar(context, provider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSidebar(BuildContext context, DesignProvider provider) {
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
          const Text(
            'AI PROVIDER',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(13),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _providers.firstWhere(
                  (p) => _providerIdMap[p] == provider.selectedProviderId,
                  orElse: () => 'DALL-E 3',
                ),
                isExpanded: true,
                dropdownColor: const Color(0xFF1E1E1E),
                items: _providers
                    .map(
                      (p) => DropdownMenuItem(
                        value: p,
                        child: Text(
                          p,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    provider.setSelectedProvider(_providerIdMap[val] ?? 'dalle3');
                    _aiService.updateConfig(
                      apiKey: provider.apiKey,
                      baseUrl: provider.baseUrl,
                      provider: AIProvider(
                        id: _providerIdMap[val] ?? 'dalle3',
                        name: val,
                        logoUrl: '',
                      ),
                    );
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'PROMPT',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
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
          Tooltip(
            message: 'Generate a new wrap design based on your prompt',
            child: Semantics(
              label: 'Generate wrap design',
              child: ElevatedButton(
                onPressed: provider.isGenerating
                    ? null
                    : () => _generateWrap(context, provider),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: provider.isGenerating
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'GENERATE WRAP',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ),
          if (provider.errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withAlpha(26),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                provider.errorMessage!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),
          ],
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
          _buildControlSlider(
            'Opacity',
            provider.opacity,
            (val) => provider.setOpacity(val),
          ),
          _buildControlSlider(
            'Metallic',
            provider.metallic,
            (val) => provider.setMetallic(val),
          ),
          _buildControlSlider(
            'Roughness',
            provider.roughness,
            (val) => provider.setRoughness(val),
          ),
          const Divider(height: 48, color: Colors.white10),
          const Text(
            'DRAWING TOOLS',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Color:', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(width: 8),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: provider.drawColor,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.white24),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: () async {
                      final color = await showDialog<Color>(
                        context: context,
                        builder: (context) => const _ColorPickerDialog(),
                      );
                      if (color != null) {
                        provider.setDrawColor(color);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 16),
              const Text('Size:', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(width: 8),
              Expanded(
                child: Slider(
                  value: provider.drawStrokeWidth,
                  min: 1,
                  max: 20,
                  divisions: 19,
                  onChanged: (val) => provider.setDrawStrokeWidth(val),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => provider.setEraser(!provider.isEraser),
                  icon: Icon(provider.isEraser ? Icons.check : Icons.delete),
                  label: Text(provider.isEraser ? 'Eraser ON' : 'Eraser'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: provider.isEraser ? Colors.redAccent : Colors.white70,
                    side: BorderSide(
                      color: provider.isEraser ? Colors.redAccent : Colors.white24,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: provider.undoLastStroke,
                  icon: const Icon(Icons.undo),
                  label: const Text('Undo'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: provider.clearDrawingStrokes,
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Clear'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewArea(BuildContext context, DesignProvider provider) {
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
                  Screenshot(
                    controller: _screenshotController,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Base vehicle image
                        Image.asset(
                          widget.vehicle.imagePath,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 600,
                              height: 400,
                              color: const Color(0xFF1A1A1A),
                              child: Center(
                                child: Text(
                                  widget.vehicle.name,
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 24,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        // Generated wrap overlay
                        if (provider.generatedWrapImage != null)
                          Positioned.fill(
                            child: Opacity(
                              opacity: provider.opacity,
                              child: _buildWrapOverlay(provider.generatedWrapImage!),
                            ),
                          ),
                        // Drawing canvas
                        if (provider.activeTool == 'draw')
                          Positioned.fill(
                            child: DrawingCanvas(
                              width: 800,
                              height: 600,
                            ),
                          ),
                        // Drawing strokes overlay
                        if (provider.drawingStrokes.isNotEmpty)
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _DrawingStrokesPainter(
                                strokes: provider.drawingStrokes,
                              ),
                            ),
                          ),
                        // Text elements overlay
                        ...provider.textElements.map(
                          (e) => Positioned(
                            left: e.x,
                            top: e.y,
                            child: Transform.rotate(
                              angle: e.rotation,
                              child: Text(
                                e.content,
                                style: TextStyle(
                                  color: Color(e.color),
                                  fontSize: e.fontSize,
                                  fontWeight:
                                      e.isBold ? FontWeight.bold : FontWeight.normal,
                                  fontStyle:
                                      e.isItalic ? FontStyle.italic : FontStyle.normal,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Logo elements overlay
                        ...provider.logoElements.map(
                          (e) => Positioned(
                            left: e.x,
                            top: e.y,
                            child: Transform.rotate(
                              angle: e.rotation,
                              child: Opacity(
                                opacity: e.opacity,
                                child: Image.asset(
                                  e.imagePath,
                                  width: e.width,
                                  height: e.height,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: e.width,
                                      height: e.height,
                                      color: Colors.white24,
                                      child: const Icon(Icons.image, color: Colors.white54),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 3D view toggle
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Row(
                      children: [
                        ToggleButtons(
                          borderRadius: BorderRadius.circular(8),
                          selectedColor: Colors.white,
                          fillColor: Colors.blueAccent,
                          borderColor: Colors.white24,
                          selectedBorderColor: Colors.blueAccent,
                          isSelected: [provider.show3DView],
                          onPressed: (index) => provider.toggle3DView(),
                          children: const [
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Text('3D'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // 3D viewer overlay
                  if (provider.show3DView)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withAlpha(200),
                        child: Center(
                          child: Model3DViewer(
                            modelPath: getModelPathForVehicle(widget.vehicle.id),
                            width: 700,
                            height: 500,
                          ),
                        ),
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
                      child: IconButton(
                        icon: const Icon(Icons.rotate_left, color: Colors.white),
                        onPressed: () => provider.rotateLeft(),
                      ),
                    ),
                  ),
                  Tooltip(
                    message: 'Rotate Right',
                    child: Semantics(
                      label: 'Rotate vehicle right',
                      button: true,
                      child: IconButton(
                        icon: const Icon(Icons.rotate_right, color: Colors.white),
                        onPressed: () => provider.rotateRight(),
                      ),
                    ),
                  ),
                  const VerticalDivider(color: Colors.white10, width: 40),
                  Tooltip(
                    message: 'Zoom In',
                    child: Semantics(
                      label: 'Zoom in on vehicle',
                      button: true,
                      child: IconButton(
                        icon: const Icon(Icons.zoom_in, color: Colors.white),
                        onPressed: () => provider.zoomIn(),
                      ),
                    ),
                  ),
                  Tooltip(
                    message: 'Zoom Out',
                    child: Semantics(
                      label: 'Zoom out from vehicle',
                      button: true,
                      child: IconButton(
                        icon: const Icon(Icons.zoom_out, color: Colors.white),
                        onPressed: () => provider.zoomOut(),
                      ),
                    ),
                  ),
                  const VerticalDivider(color: Colors.white10, width: 40),
                  Text(
                    '${(provider.zoomLevel * 100).toInt()}%',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRightSidebar(BuildContext context, DesignProvider provider) {
    return Container(
      width: 100,
      decoration: const BoxDecoration(
        color: Color(0xFF141414),
        border: Border(left: BorderSide(color: Colors.white10)),
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            const SizedBox(height: 20),
            _buildSidebarAction(
              Icons.brush,
              'Draw',
              provider.activeTool == 'draw',
              () => provider.setActiveTool(
                provider.activeTool == 'draw' ? 'select' : 'draw',
              ),
            ),
            _buildSidebarAction(
              Icons.text_fields,
              'Text',
              false,
              () => _showAddTextDialog(context, provider),
            ),
            _buildSidebarAction(
              Icons.image,
              'Logo',
              false,
              () => _showAddLogoDialog(context, provider),
            ),
            _buildSidebarAction(
              Icons.layers,
              'Layers',
              provider.activeTool == 'layers',
              () => _showLayersPanel(context),
            ),
            const Spacer(),
            _buildSidebarAction(
              Icons.undo,
              'Undo',
              false,
              () => provider.undoLastStroke,
            ),
            _buildSidebarAction(
              Icons.delete_sweep,
              'Clear',
              false,
              () => provider.clearAllLayers(),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarAction(
    IconData icon,
    String label,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        button: true,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blueAccent.withAlpha(51) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      color: isSelected ? Colors.blueAccent : Colors.white70,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      color: isSelected ? Colors.blueAccent : Colors.white38,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlSlider(
    String label,
    double value,
    ValueChanged<double> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
              Text(
                '${(value * 100).toInt()}%',
                style: const TextStyle(fontSize: 12, color: Colors.white),
              ),
            ],
          ),
          Tooltip(
            message: 'Adjust $label',
            child: Semantics(
              label: label,
              child: Slider(
                value: value,
                onChanged: onChanged,
                divisions: 100,
                label: '${(value * 100).toInt()}%',
                semanticFormatterCallback: (double val) =>
                    '${(val * 100).toInt()}%',
                activeColor: Colors.blueAccent,
                inactiveColor: Colors.white12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWrapOverlay(String imageData) {
    // Handle both base64 and URL
    if (imageData.startsWith('http')) {
      return Image.network(
        imageData,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(color: Colors.transparent);
        },
      );
    } else {
      // Base64 encoded image
      return Image.memory(
        base64Decode(imageData),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(color: Colors.transparent);
        },
      );
    }
  }

  // --- Actions ---

  Future<void> _generateWrap(BuildContext context, DesignProvider provider) async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a prompt')),
      );
      return;
    }

    if (provider.apiKey == null || provider.apiKey!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please set your API key in Settings first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    provider.setGenerating(true);
    provider.setErrorMessage(null);

    try {
      final result = await _aiService.generateWrapImage(prompt);
      if (result != null) {
        provider.setWrapImage(result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Wrap design generated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        provider.setErrorMessage(
          'Failed to generate image. Check your API key and provider settings.',
        );
      }
    } catch (e) {
      provider.setErrorMessage('An error occurred during generation.');
    } finally {
      provider.setGenerating(false);
    }
  }

  Future<void> _exportDesign(BuildContext context) async {
    try {
      final screenshot = await _screenshotController.capture();
      if (screenshot != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Design exported successfully!'),
            backgroundColor: Colors.blueAccent,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to export design.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showSaveDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Save Design', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Design Name',
            labelStyle: TextStyle(color: Colors.white54),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white10),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.blueAccent),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                context.read<DesignProvider>().saveCurrentDesign(
                      controller.text,
                      _promptController.text,
                    );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Design saved!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }

  void _showAddTextDialog(BuildContext context, DesignProvider provider) {
    final controller = TextEditingController();
    double fontSize = 24;
    Color selectedColor = Colors.white;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('Add Text', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Text Content',
                  labelStyle: TextStyle(color: Colors.white54),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Size: ', style: TextStyle(color: Colors.white70)),
                  Expanded(
                    child: Slider(
                      value: fontSize,
                      min: 12,
                      max: 72,
                      divisions: 60,
                      onChanged: (val) => setDialogState(() => fontSize = val),
                    ),
                  ),
                  Text('${fontSize.toInt()}', style: const TextStyle(color: Colors.white)),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  provider.addTextElement(
                    TextElement(
                      id: 'text_${DateTime.now().millisecondsSinceEpoch}',
                      content: controller.text,
                      x: 100,
                      y: 100,
                      fontSize: fontSize,
                      color: selectedColor.value,
                    ),
                  );
                  Navigator.pop(context);
                }
              },
              child: const Text('ADD'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddLogoDialog(BuildContext context, DesignProvider provider) {
    // Show preset logos from assets
    final presetLogos = [
      'assets/images/logo.png',
      'assets/images/paint-shop-wraps-ct.png',
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Add Logo', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select a preset logo:',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: presetLogos.map((path) {
                  return GestureDetector(
                    onTap: () {
                      provider.addLogoElement(
                        LogoElement(
                          id: 'logo_${DateTime.now().millisecondsSinceEpoch}',
                          imagePath: path,
                          x: 100,
                          y: 100,
                          width: 100,
                          height: 100,
                        ),
                      );
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Image.asset(
                        path,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.image, color: Colors.white54);
                        },
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  // For web, you'd use file_picker; for now, add a placeholder
                  provider.addLogoElement(
                    LogoElement(
                      id: 'logo_${DateTime.now().millisecondsSinceEpoch}',
                      imagePath: 'assets/images/logo.png',
                      x: 150,
                      y: 150,
                      width: 120,
                      height: 120,
                    ),
                  );
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.upload_file),
                label: const Text('Upload Custom'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  void _showLayersPanel(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (context) => Container(
        height: 400,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'LAYERS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Expanded(child: LayersPanel()),
          ],
        ),
      ),
    );
  }

  void _showSettings(BuildContext context) {
    final provider = context.read<DesignProvider>();
    final apiKeyController = TextEditingController(text: provider.apiKey ?? '');
    final baseUrlController = TextEditingController(text: provider.baseUrl ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'API SETTINGS',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: apiKeyController,
              maxLength: 512,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'API KEY',
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blueAccent),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: baseUrlController,
              maxLength: 512,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'CUSTOM BASE URL (Optional)',
                labelStyle: TextStyle(color: Colors.white54),
                helperText: 'Use HTTPS for secure communication',
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blueAccent),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              provider.setApiKey(apiKeyController.text);
              provider.setBaseUrl(baseUrlController.text);
              _aiService.updateConfig(
                apiKey: provider.apiKey,
                baseUrl: provider.baseUrl,
                provider: AIProvider(
                  id: provider.selectedProviderId,
                  name: provider.selectedProviderId,
                  logoUrl: '',
                ),
              );
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Settings saved!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }
}

// --- Helper Widgets ---

class _ColorPickerDialog extends StatelessWidget {
  const _ColorPickerDialog();

  @override
  Widget build(BuildContext context) {
    final colors = [
      Colors.white,
      Colors.black,
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.yellow,
      Colors.orange,
      Colors.purple,
      Colors.cyan,
      Colors.pink,
      Colors.teal,
      Colors.amber,
    ];

    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: const Text('Pick Color', style: TextStyle(color: Colors.white)),
      content: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: colors.map((color) {
          return GestureDetector(
            onTap: () => Navigator.pop(context, color),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24),
              ),
            ),
          );
        }).toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
      ],
    );
  }
}

/// Custom painter for drawing strokes overlay.
class _DrawingStrokesPainter extends CustomPainter {
  final List<DrawingStroke> strokes;

  _DrawingStrokesPainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final stroke in strokes) {
      if (stroke.points.length < 2) continue;

      paint
        ..color = Color(stroke.color)
        ..strokeWidth = stroke.strokeWidth
        ..blendMode = stroke.isEraser ? BlendMode.clear : BlendMode.srcOver;

      final path = Path();
      path.moveTo(stroke.points[0].dx, stroke.points[0].dy);

      for (int i = 1; i < stroke.points.length - 1; i++) {
        final mid = Offset(
          (stroke.points[i].dx + stroke.points[i + 1].dx) / 2,
          (stroke.points[i].dy + stroke.points[i + 1].dy) / 2,
        );
        path.quadraticBezierTo(
          stroke.points[i].dx,
          stroke.points[i].dy,
          mid.dx,
          mid.dy,
        );
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_DrawingStrokesPainter oldDelegate) =>
      oldDelegate.strokes != strokes;
}
