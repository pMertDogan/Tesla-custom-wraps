import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../core/theme.dart';
import '../models/ai_provider.dart';
import '../models/tesla_model.dart';
import '../models/wrap_design.dart';
import '../services/ai_service.dart';
import '../services/export_service.dart';
import '../services/prompt_builder.dart';
import '../services/template_masker.dart';
import '../services/wrap_saver.dart';
import '../state/app_scope.dart';
import '../state/app_state.dart';
import '../widgets/settings_dialog.dart';

/// What the preview area is showing.
enum PreviewMode {
  /// The generated texture, exactly as it will be exported.
  design,

  /// Tesla's UV template for the vehicle.
  template,

  /// The reference render of the vehicle.
  vehicle,
}

/// The design screen: prompt in, Tesla ready wrap out.
class StudioPage extends StatefulWidget {
  /// The vehicle the wrap is designed for.
  final TeslaModel vehicle;

  /// Creates the studio.
  const StudioPage({super.key, required this.vehicle});

  @override
  State<StudioPage> createState() => _StudioPageState();
}

class _StudioPageState extends State<StudioPage> {
  final TextEditingController _promptController = TextEditingController();

  WrapDesign? _design;
  Uint8List? _templateBytes;
  PanelMask? _mask;

  bool _isGenerating = false;
  bool _isExporting = false;
  bool _isMasking = false;

  String _styleId = WrapStyle.presets.first.id;
  PreviewMode _mode = PreviewMode.design;
  double _overlayOpacity = 1;
  double _zoom = 1;
  double _cameraAzimuth = 0;

  @override
  void initState() {
    super.initState();
    _loadTemplate();
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _loadTemplate() async {
    try {
      final data = await rootBundle.load(widget.vehicle.templatePath);
      final bytes = data.buffer.asUint8List();
      final mask = TemplateMasker.buildMask(bytes);
      if (!mounted) return;
      setState(() {
        _templateBytes = bytes;
        _mask = mask;
      });
    } on Exception {
      // A missing template only costs us the panel mask, the studio still
      // works with the raw design.
    }
  }

  Future<void> _generate() async {
    final state = AppScope.read(context);

    if (!state.settings.hasApiKey) {
      _notify('Add your API key in Settings to generate a wrap.');
      await SettingsDialog.show(context);
      return;
    }

    setState(() => _isGenerating = true);

    try {
      final provider = state.provider;
      final prompt = WrapPromptBuilder.build(
        concept: _promptController.text,
        vehicleName: widget.vehicle.name,
        style: WrapStyle.byId(_styleId).hint,
        hasReferenceTemplate: _templateBytes != null,
      );

      final result = await state.aiService.generate(
        provider: provider,
        settings: state.settings,
        prompt: prompt,
        referenceImage: _templateBytes,
        aspectRatio: widget.vehicle.aspectRatio,
      );

      final design = await _conform(result.bytes);

      state.addDesign(design);

      if (!mounted) return;
      setState(() {
        _design = design;
        _mode = PreviewMode.design;
      });
      _notify(
        'Wrap generated with ${provider.label}.'
        '${result.cost == null ? '' : ' Cost: \$${result.cost!.toStringAsFixed(4)}'}',
      );
    } on AiException catch (error) {
      _notify(error.message);
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  /// Crops the design to the vehicle template and clips it to the panels.
  Future<WrapDesign> _conform(Uint8List bytes) async {
    final state = AppScope.read(context);
    var working = bytes;

    if (_mask != null) {
      setState(() => _isMasking = true);
      try {
        final masked = await _applyMask(working, _mask!);
        if (masked != null) working = masked;
      } finally {
        if (mounted) setState(() => _isMasking = false);
      }
    }

    return WrapDesign(
      id: 'wrap_${DateTime.now().microsecondsSinceEpoch}',
      modelId: widget.vehicle.id,
      prompt: _promptController.text.trim(),
      bytes: working,
      mimeType: 'image/png',
      providerId: state.provider.id,
      createdAt: DateTime.now(),
    );
  }

  Future<Uint8List?> _applyMask(Uint8List bytes, PanelMask mask) async {
    final cropped = WrapExporter.coverCropToTemplate(
      bytes,
      templateWidth: widget.vehicle.templateWidth,
      templateHeight: widget.vehicle.templateHeight,
    );
    if (cropped == null) return null;
    return TemplateMasker.applyMask(cropped, mask);
  }

  Future<void> _export() async {
    final design = _design;
    if (design == null) {
      _notify('Generate a design first, then export it.');
      return;
    }

    setState(() => _isExporting = true);
    try {
      final wrap = WrapExporter.buildPng(
        design.bytes,
        templateWidth: widget.vehicle.templateWidth,
        templateHeight: widget.vehicle.templateHeight,
        fileName: _exportName(),
      );
      final saved = await WrapSaver.save(wrap);
      if (!mounted) return;
      _notify(
        'Saved ${wrap.fileNameWithExtension} '
        '(${wrap.width}x${wrap.height}, ${wrap.sizeInMegabytes.toStringAsFixed(2)} MB)'
        '${saved.isEmpty ? '' : ' -> $saved'}',
      );
    } on ExportException catch (error) {
      _notify(error.message);
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  String _exportName() {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) return '${widget.vehicle.id}_wrap';
    return WrapExporter.sanitizeFileName(prompt);
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: StudioColors.surfaceHigh,
          duration: const Duration(seconds: 4),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);

    return Scaffold(
      backgroundColor: StudioColors.background,
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
                onPressed: () => SettingsDialog.show(context),
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
                onPressed: (_isExporting || _design == null) ? null : _export,
                icon: _isExporting
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Icon(Icons.download),
                label: const Text('EXPORT WRAP'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: Colors.white24,
                  disabledForegroundColor: Colors.black38,
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
        ],
      ),
      body: Row(
        children: [
          _buildSidebar(context, state),
          Expanded(child: _buildPreviewArea(context, state)),
          _buildRightSidebar(context),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context, AppState state) {
    final provider = state.provider;

    return Container(
      width: 350,
      decoration: const BoxDecoration(
        color: StudioColors.surface,
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
                value: provider.id,
                isExpanded: true,
                dropdownColor: StudioColors.surfaceHigh,
                items: AiProviderCatalog.all
                    .map(
                      (p) => DropdownMenuItem(
                        value: p.id,
                        child: Text(
                          p.label,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) async {
                  if (value == null) return;
                  await state.updateSettings(
                    state.settings.copyWith(providerId: value),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            provider.supportsReferenceImage
                ? 'Sends the UV template as a reference image.'
                : 'Receives the panel layout as text only.',
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
          const SizedBox(height: 20),
          const Text(
            'STYLE',
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
                value: _styleId,
                isExpanded: true,
                dropdownColor: StudioColors.surfaceHigh,
                items: WrapStyle.presets
                    .map(
                      (s) => DropdownMenuItem(
                        value: s.id,
                        child: Text(
                          s.label,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _styleId = value);
                },
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'PROMPT',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _promptController,
            maxLines: 4,
            maxLength: WrapPromptBuilder.maxConceptLength,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Describe your wrap design...',
              hintStyle: TextStyle(color: Colors.white24),
              counterStyle: TextStyle(color: Colors.white24),
            ),
          ),
          const SizedBox(height: 12),
          Tooltip(
            message: 'Generate a new wrap design based on your prompt',
            child: Semantics(
              label: 'Generate wrap design',
              child: ElevatedButton(
                onPressed: _isGenerating ? null : _generate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: StudioColors.aiAccent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: StudioColors.aiAccent.withAlpha(90),
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isGenerating
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _isMasking ? 'FINISHING...' : 'GENERATE WRAP',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ),
          const Divider(height: 48, color: Colors.white10),
          const Text(
            'PREVIEW CONTROLS',
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
            _overlayOpacity,
            (value) => setState(() => _overlayOpacity = value),
          ),
          _buildControlSlider(
            'Zoom',
            _zoom,
            (value) => setState(() => _zoom = value),
            min: 0.5,
            max: 3,
            divisions: 10,
            semanticLabel: 'Zoom level',
          ),
          const Divider(height: 40, color: Colors.white10),
          _buildTemplateInfo(),
        ],
      ),
    );
  }

  Widget _buildTemplateInfo() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TEMPLATE',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.2,
              color: Colors.white54,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${widget.vehicle.templateWidth} x ${widget.vehicle.templateHeight} px',
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            _mask == null
                ? 'Panel mask unavailable'
                : 'Panel mask active - artwork is clipped to the body panels',
            style: TextStyle(
              color: _mask == null ? Colors.orange : Colors.greenAccent,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Export: PNG, 512-1024 px, max 1 MB',
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewArea(BuildContext context, AppState state) {
    return Container(
      color: Colors.black,
      child: Column(
        children: [
          _buildModeSwitcher(),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Transform.scale(
                  scale: _zoom,
                  child: _buildPreviewImage(),
                ),
                if (_design == null)
                  const Positioned(
                    top: 40,
                    child: Chip(
                      label: Text(
                        'GENERATE A DESIGN TO BEGIN',
                        style: TextStyle(color: Colors.white70),
                      ),
                      backgroundColor: Colors.white12,
                    ),
                  ),
              ],
            ),
          ),
          _buildHistoryStrip(state),
          _buildViewportControls(),
        ],
      ),
    );
  }

  Widget _buildPreviewImage() {
    switch (_mode) {
      case PreviewMode.design:
        final design = _design;
        if (design == null) {
          return Image.asset(
            widget.vehicle.imagePath,
            width: 800,
            fit: BoxFit.contain,
          );
        }
        return Opacity(
          opacity: _overlayOpacity,
          child: Image.memory(design.bytes, width: 800, fit: BoxFit.contain),
        );
      case PreviewMode.template:
        return Image.asset(
          widget.vehicle.templatePath,
          width: 800,
          fit: BoxFit.contain,
        );
      case PreviewMode.vehicle:
        return Image.asset(
          widget.vehicle.imagePath,
          width: 800,
          fit: BoxFit.contain,
        );
    }
  }

  Widget _buildModeSwitcher() {
    return Container(
      height: 48,
      color: Colors.white.withAlpha(5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _modeChip('DESIGN', PreviewMode.design),
          _modeChip('TEMPLATE', PreviewMode.template),
          _modeChip('VEHICLE', PreviewMode.vehicle),
        ],
      ),
    );
  }

  Widget _modeChip(String label, PreviewMode mode) {
    final selected = _mode == mode;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _mode = mode),
        labelStyle: TextStyle(
          color: selected ? Colors.black : Colors.white70,
          fontSize: 11,
          letterSpacing: 1,
          fontWeight: FontWeight.bold,
        ),
        backgroundColor: Colors.white.withAlpha(10),
        selectedColor: Colors.white,
      ),
    );
  }

  Widget _buildHistoryStrip(AppState state) {
    final designs = state.history;
    if (designs.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 92,
      color: Colors.white.withAlpha(5),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: designs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final design = designs[index];
          final selected = design.id == _design?.id;
          return Tooltip(
            message: design.prompt.isEmpty ? design.id : design.prompt,
            child: InkWell(
              onTap: () => setState(() {
                _design = design;
                _mode = PreviewMode.design;
              }),
              child: Container(
                width: 76,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected
                        ? StudioColors.aiAccent
                        : Colors.white10,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.memory(design.bytes, fit: BoxFit.cover),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildViewportControls() {
    return Container(
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
                onPressed: () =>
                    setState(() => _cameraAzimuth -= 15),
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
                onPressed: () => setState(() => _cameraAzimuth += 15),
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
                onPressed: () => setState(() {
                  if (_zoom < 3) _zoom = (_zoom + 0.25).clamp(0.5, 3);
                }),
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
                onPressed: () => setState(() {
                  if (_zoom > 0.5) _zoom = (_zoom - 0.25).clamp(0.5, 3);
                }),
              ),
            ),
          ),
          const SizedBox(width: 24),
          Tooltip(
            message: '3D camera azimuth',
            child: Text(
              'Camera ${_cameraAzimuth.round()}°',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightSidebar(BuildContext context) {
    return Container(
      width: 100,
      decoration: const BoxDecoration(
        color: StudioColors.surface,
        border: Border(left: BorderSide(color: Colors.white10)),
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            const SizedBox(height: 20),
            _buildSidebarAction(Icons.brush, 'Draw'),
            _buildSidebarAction(Icons.text_fields, 'Text'),
            _buildSidebarAction(Icons.image, 'Logo'),
            _buildSidebarAction(Icons.layers, 'Layers'),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarAction(IconData icon, String label) {
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        button: true,
        child: InkWell(
          onTap: () {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(
                    '$label tool arrives in a later milestone',
                  ),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  width: 260,
                ),
              );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                children: [
                  Icon(icon, color: Colors.white38, size: 28),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white24,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'SOON',
                    style: TextStyle(
                      fontSize: 8,
                      letterSpacing: 1,
                      color: Color(0xFF3D7BFF),
                    ),
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
    ValueChanged<double> onChanged, {
    double min = 0,
    double max = 1,
    int divisions = 100,
    String? semanticLabel,
  }) {
    String format(double val) =>
        max <= 1 ? '${(val * 100).round()}%' : val.toStringAsFixed(2);

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
                format(value),
                style: const TextStyle(fontSize: 12, color: Colors.white),
              ),
            ],
          ),
          Tooltip(
            message: 'Adjust $label',
            child: Semantics(
              label: semanticLabel ?? label,
              child: Slider(
                value: value.clamp(min, max),
                onChanged: onChanged,
                divisions: divisions,
                label: format(value),
                semanticFormatterCallback: format,
                activeColor: StudioColors.aiAccent,
                inactiveColor: Colors.white12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
