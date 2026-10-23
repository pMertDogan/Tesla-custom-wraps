import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../core/theme.dart';
import '../models/ai_provider.dart';
import '../models/tesla_model.dart';
import '../models/wrap_design.dart';
import '../models/wrap_layer.dart';
import '../services/ai_service.dart';
import '../services/export_service.dart';
import '../services/image_source.dart';
import '../services/prompt_builder.dart';
import '../services/template_masker.dart';
import '../services/vehicle_viewer.dart';
import '../services/wrap_compositor.dart';
import '../services/wrap_ideas.dart';
import '../services/wrap_saver.dart';
import '../state/app_scope.dart';
import '../state/app_state.dart';
import '../widgets/layer_canvas.dart';
import '../widgets/settings_dialog.dart';

/// What the preview area is showing.
enum PreviewMode {
  /// The generated texture, exactly as it will be exported.
  design,

  /// Tesla's UV template for the vehicle.
  template,

  /// The reference render of the vehicle.
  vehicle,

  /// The vehicle model with the design on its body.
  model3d,
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
  /// Width at which the studio switches from the three column desktop layout
  /// to the stacked one used on phones and small tablets.
  static const double _wideLayoutBreakpoint = 1100;

  /// Width of the prompt sidebar in the desktop layout.
  static const double _sidebarWidth = 350;

  /// Colours offered for text and brush layers.
  static const List<int> _layerColors = [
    0xFFFFFFFF,
    0xFF111111,
    0xFFE31937,
    0xFF3D7BFF,
    0xFFF5C542,
    0xFF22C55E,
  ];

  final TextEditingController _promptController = TextEditingController();
  final WrapIdeaGenerator _ideas = WrapIdeaGenerator();

  WrapDesign? _design;
  Uint8List? _templateBytes;
  PanelMask? _mask;

  /// Unmasked provider output for every design in the session, keyed by
  /// design id.
  ///
  /// The exporter applies the panel mask itself, so it needs the artwork as
  /// the provider returned it. Keeping the bytes per design means picking an
  /// older design from the history strip exports that design and not the one
  /// that happened to be generated last.
  final Map<String, Uint8List> _rawArtwork = <String, Uint8List>{};

  /// Undo history of the layer stack of the selected design.
  final List<List<WrapLayer>> _undo = <List<WrapLayer>>[];
  final List<List<WrapLayer>> _redo = <List<WrapLayer>>[];

  /// The design the layer stack widgets are showing.
  String? _layersDesignId;
  List<WrapLayer> _layers = <WrapLayer>[];

  bool _isGenerating = false;
  bool _isExporting = false;
  bool _isMasking = false;

  /// Whether the next drag on the canvas paints a brush stroke.
  bool _drawing = false;
  int _brushColor = 0xFFFFFFFF;
  double _brushSize = 0.025;

  String _styleId = WrapStyle.presets.first.id;
  PreviewMode _mode = PreviewMode.design;
  double _overlayOpacity = 1;
  double _zoom = 1;

  /// Ideas offered under the prompt box.
  late List<WrapIdea> _suggestions = _ideas.ideas();

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

  // ---------------------------------------------------------------------
  // Design and generation
  // ---------------------------------------------------------------------

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
    } on Object {
      // A missing asset throws a `FlutterError`, which is an `Error` and not
      // an `Exception`. Catching only `Exception` here would leave an
      // unhandled async error in the zone and take the release build down.
      //
      // Losing the template only costs the panel mask; the studio still
      // works with the raw design.
    }
  }

  /// Generates a wrap.
  ///
  /// An empty prompt is not an error: the studio invents a concept for the
  /// selected style, so pressing GENERATE WRAP always produces a design.
  Future<void> _generate({WrapIdea? idea}) async {
    final state = AppScope.read(context);
    final provider = state.provider;

    if (provider.requiresApiKey && !state.settings.hasApiKey) {
      _notify('Add your API key in Settings to generate a wrap.');
      await SettingsDialog.show(context);
      return;
    }

    var concept = _promptController.text.trim();
    var styleId = _styleId;
    WrapIdea? invented;

    if (idea != null) {
      concept = idea.concept;
      styleId = idea.style.id;
      invented = idea;
    } else if (concept.isEmpty) {
      final generated = _ideas.idea(style: WrapStyle.byId(_styleId));
      concept = generated.concept;
      styleId = generated.style.id;
      invented = generated;
    }

    if (invented != null && _promptController.text.trim().isEmpty) {
      _promptController.text = concept;
    }

    setState(() {
      _isGenerating = true;
      _styleId = styleId;
    });

    try {
      final prompt = WrapPromptBuilder.build(
        concept: concept,
        vehicleName: widget.vehicle.name,
        style: WrapStyle.byId(styleId).hint,
        hasReferenceTemplate: _templateBytes != null,
        flatPatternOnly: !provider.followsReferenceLayout,
      );

      final result = await state.aiService.generate(
        provider: provider,
        settings: state.settings,
        prompt: prompt,
        referenceImage: _templateBytes,
        aspectRatio: widget.vehicle.aspectRatio,
        width: widget.vehicle.templateWidth,
        height: widget.vehicle.templateHeight,
      );

      final design = await _conform(result.bytes, concept);

      state.addDesign(design);

      if (!mounted) return;
      setState(() {
        _design = design;
        _rawArtwork[design.id] = result.bytes;
        _layersDesignId = design.id;
        _layers = <WrapLayer>[];
        _undo.clear();
        _redo.clear();
        _mode = PreviewMode.design;
      });
      _notify(
        '${invented == null ? 'Wrap generated' : 'Wrap invented and generated'} '
        'with ${provider.label}.'
        '${result.cost == null ? '' : ' Cost: \$${result.cost!.toStringAsFixed(4)}'}'
        '${result.units == null ? '' : ' Usage: ${result.units} neurons'}',
      );
    } on AiException catch (error) {
      _notify(error.message);
    } on ExportException catch (error) {
      _notify(error.message);
    } on Object catch (error) {
      // Anything the pipeline did not anticipate (a corrupt payload, an
      // out of memory image) is reported instead of ending up as an
      // unhandled async error.
      _notify('The wrap could not be generated. Try again.');
      debugPrint('Wrap generation failed: $error');
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  /// Generates a wrap from a randomly invented style and concept.
  Future<void> _surpriseMe() async {
    final idea = _ideas.idea();
    setState(() {
      _suggestions = _ideas.ideas();
      _styleId = idea.style.id;
    });
    _promptController.text = idea.concept;
    await _generate(idea: idea);
  }

  /// Fills the prompt box with [idea] instead of generating straight away.
  void _applyIdea(WrapIdea idea) {
    setState(() => _styleId = idea.style.id);
    _promptController.text = idea.concept;
  }

  /// Crops the design to the vehicle template and clips it to the panels.
  Future<WrapDesign> _conform(Uint8List bytes, String concept) async {
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
      prompt: concept,
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

  // ---------------------------------------------------------------------
  // Layers
  // ---------------------------------------------------------------------

  /// Loads the stored stack of [design] into the editor.
  void _selectDesign(AppState state, WrapDesign design) {
    setState(() {
      _design = design;
      _mode = PreviewMode.design;
      _layersDesignId = design.id;
      _layers = List.of(state.layersFor(design.id));
      _undo.clear();
      _redo.clear();
      _drawing = false;
    });
  }

  /// Applies a layer stack change, keeping the undo history.
  void _updateLayers(List<WrapLayer> next) {
    final designId = _design?.id;
    if (designId == null) return;

    setState(() {
      _undo.add(List.of(_layers));
      if (_undo.length > 30) _undo.removeAt(0);
      _redo.clear();
      _layers = next;
    });
    AppScope.read(context).setLayers(designId, next);
  }

  void _undoLayers() {
    final designId = _design?.id;
    if (designId == null || _undo.isEmpty) return;
    setState(() {
      _redo.add(List.of(_layers));
      _layers = _undo.removeLast();
    });
    AppScope.read(context).setLayers(designId, _layers);
  }

  void _redoLayers() {
    final designId = _design?.id;
    if (designId == null || _redo.isEmpty) return;
    setState(() {
      _undo.add(List.of(_layers));
      _layers = _redo.removeLast();
    });
    AppScope.read(context).setLayers(designId, _layers);
  }

  Future<void> _addTextLayer() async {
    if (_design == null) {
      _notify('Generate a design first, then add layers.');
      return;
    }
    final layer = await _showTextDialog();
    if (layer == null) return;
    _updateLayers([..._layers, layer]);
  }

  Future<void> _addLogoLayer() async {
    if (_design == null) {
      _notify('Generate a design first, then add layers.');
      return;
    }
    final picked = await pickImage();
    if (!mounted) return;
    if (picked == null) {
      _notify(
        'No logo selected. The browser file picker is available in the web '
        'build.',
      );
      return;
    }
    _updateLayers([
      ..._layers,
      WrapLayer.image(
        id: 'logo_${DateTime.now().microsecondsSinceEpoch}',
        name: picked.name,
        bytes: layerImageBytes(picked.bytes),
      ),
    ]);
    _notify('Logo "${picked.name}" added to the wrap.');
  }

  void _onStrokeEnd(List<double> points) {
    if (points.length < 4) return;
    _updateLayers([
      ..._layers,
      WrapLayer.brush(
        id: 'brush_${DateTime.now().microsecondsSinceEpoch}',
        color: _brushColor,
        scale: _brushSize,
      ).copyWith(points: points),
    ]);
  }

  /// The design with its layers baked in, at the template size.
  ///
  /// The 3D texture and the export both start here, which keeps the preview,
  /// the model and the file in sync.
  Uint8List? _composedArtwork(WrapDesign design) {
    final base = _rawArtwork[design.id] ?? design.bytes;
    final layers = design.id == _layersDesignId
        ? _layers
        : AppScope.read(context).layersFor(design.id);
    return WrapCompositor.composite(
          base: base,
          layers: layers,
          width: widget.vehicle.templateWidth,
          height: widget.vehicle.templateHeight,
        ) ??
        base;
  }

  // ---------------------------------------------------------------------
  // Export
  // ---------------------------------------------------------------------

  Future<void> _export() async {
    final design = _design;
    if (design == null) {
      _notify('Generate a design first, then export it.');
      return;
    }

    setState(() => _isExporting = true);
    try {
      // Cropping, masking and PNG encoding all run on the UI isolate, which
      // is what Flutter gives you on the web. Yielding once lets the progress
      // state paint before the work starts, so a 1024 px export does not look
      // like a frozen page.
      await Future<void>.delayed(Duration.zero);

      final source = _composedArtwork(design) ??
          _rawArtwork[design.id] ??
          design.bytes;
      final wrap = WrapExporter.buildPng(
        source,
        templateWidth: widget.vehicle.templateWidth,
        templateHeight: widget.vehicle.templateHeight,
        fileName: _exportName(design),
        mask: _mask,
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
    } on Object catch (error) {
      _notify('The wrap could not be saved. Try again.');
      debugPrint('Wrap export failed: $error');
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  /// Name Tesla accepts, derived from the concept that produced [design].
  ///
  /// The prompt box may have been edited since the design was made, so the
  /// design's own prompt wins; the current text is only the fallback.
  String _exportName(WrapDesign design) {
    final prompt = design.prompt.trim().isNotEmpty
        ? design.prompt.trim()
        : _promptController.text.trim();
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

  // ---------------------------------------------------------------------
  // Layout
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final compact = MediaQuery.sizeOf(context).width < 700;

    // A design made in another studio tab, or restored from the session, has
    // to bring its layer stack with it.
    final design = _design;
    if (design != null && design.id != _layersDesignId) {
      _layersDesignId = design.id;
      _layers = List.of(state.layersFor(design.id));
    }

    return Scaffold(
      backgroundColor: StudioColors.background,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          'STUDIO: ${widget.vehicle.name.toUpperCase()}',
          overflow: TextOverflow.ellipsis,
          style: compact
              ? const TextStyle(fontSize: 14, letterSpacing: 0.5)
              : null,
        ),
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
          const SizedBox(width: 4),
          Tooltip(
            message: 'Export your design',
            child: Semantics(
              label: 'Export wrap design',
              button: true,
              // A phone has no room for the label, so it collapses into an
              // icon button.
              child: compact
                  ? IconButton(
                      onPressed: _isExporting ? null : _export,
                      icon: _isExporting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download),
                    )
                  : ElevatedButton.icon(
                      // The button stays live without a design so it can
                      // explain what is missing instead of sitting there
                      // dead.
                      onPressed: _isExporting ? null : _export,
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
          SizedBox(width: compact ? 4 : 20),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Below the breakpoint the three columns do not fit. The preview
          // stays on top and the designer moves into a scrollable panel
          // underneath it, so the studio is usable on a phone without a
          // single overflowing row.
          if (constraints.maxWidth < _wideLayoutBreakpoint) {
            // Give the designer between 240 and 420 pixels, but never at the
            // cost of the preview.
            var designerHeight = constraints.maxHeight * 0.45;
            if (designerHeight < 240) designerHeight = 240;
            if (designerHeight > 420) designerHeight = 420;
            if (designerHeight > constraints.maxHeight - 260) {
              designerHeight = constraints.maxHeight - 260;
              if (designerHeight < 160) designerHeight = 160;
            }
            return Column(
              children: [
                Expanded(child: _buildPreviewArea(context, state)),
                _buildToolStrip(horizontal: true),
                SizedBox(
                  height: designerHeight,
                  child: _buildSidebar(state, width: double.infinity),
                ),
              ],
            );
          }

          return Row(
            children: [
              _buildSidebar(state, width: _sidebarWidth),
              Expanded(child: _buildPreviewArea(context, state)),
              _buildToolStrip(horizontal: false),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Left sidebar: provider, style, prompt, ideas
  // ---------------------------------------------------------------------

  Widget _buildSidebar(AppState state, {required double width}) {
    final provider = state.provider;

    return Container(
      width: width,
      decoration: const BoxDecoration(
        color: StudioColors.surface,
        border: Border(right: BorderSide(color: Colors.white10)),
      ),
      // A scroll view rather than a lazy list: the sidebar is a fixed form,
      // and every control has to exist for keyboard and screen reader users
      // even when it is scrolled out of view.
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          // The template facts come first: they describe the canvas the user
          // designs for and the mask that clips the artwork to it.
          _buildTemplateInfo(),
          const SizedBox(height: 20),
          const Text(
            'AI DESIGNER',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'AI PROVIDER',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 8),
          _buildDropdown<String>(
            value: provider.id,
            items: [
              for (final item in AiProviderCatalog.all)
                (item.id, item.label),
            ],
            onChanged: (value) async {
              await state.updateSettings(
                state.settings.copyWith(providerId: value),
              );
            },
          ),
          const SizedBox(height: 6),
          Text(
            _providerHint(provider),
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
          const SizedBox(height: 20),
          const Text(
            'STYLE',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 8),
          _buildDropdown<String>(
            value: _styleId,
            items: [
              for (final item in WrapStyle.presets) (item.id, item.label),
            ],
            onChanged: (value) => setState(() => _styleId = value),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'PROMPT',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              Text(
                'OPTIONAL',
                style: TextStyle(
                  color: Colors.white.withAlpha(90),
                  fontSize: 10,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _promptController,
            maxLines: 4,
            maxLength: WrapPromptBuilder.maxConceptLength,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: provider.followsReferenceLayout
                  ? 'Describe your wrap design, or leave it empty and let the '
                      'studio invent one...'
                  : 'Describe the pattern, or leave it empty...',
              hintStyle: const TextStyle(color: Colors.white24),
              counterStyle: const TextStyle(color: Colors.white24),
            ),
          ),
          const SizedBox(height: 4),
          _buildIdeaChips(),
          const SizedBox(height: 12),
          Tooltip(
            message: 'Generate a new wrap design based on your prompt',
            child: Semantics(
              label: 'Generate wrap design',
              child: ElevatedButton(
                onPressed: _isGenerating ? null : () => _generate(),
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
          const SizedBox(height: 10),
          Tooltip(
            message: 'Invent a style and a concept, then generate',
            child: Semantics(
              label: 'Surprise me with a wrap',
              button: true,
              child: OutlinedButton.icon(
                onPressed: _isGenerating ? null : _surpriseMe,
                icon: const Icon(Icons.casino_outlined, size: 18),
                label: const Text('SURPRISE ME'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
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
          // Opacity only affects the generated artwork, so it is hidden in
          // the template and vehicle views instead of sitting there dead.
          if (_mode == PreviewMode.design)
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
        ],
        ),
      ),
    );
  }

  /// One line summary of what the selected provider does with the template.
  String _providerHint(AiProvider provider) {
    if (!provider.requiresApiKey) {
      return 'No API key needed. Draws a flat pattern and clips it to the '
          'panels. One free image every 45 seconds.';
    }
    if (!provider.supportsReferenceImage) {
      return 'Receives the panel layout as text only.';
    }
    if (!provider.followsReferenceLayout) {
      return 'Draws a flat pattern; the panel mask places it on the car.';
    }
    return 'Sends the UV template as a reference image.';
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
          const SizedBox(height: 4),
          const Text(
            'The export keeps the transparency of the template',
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }

  /// The idea chips under the prompt box.
  Widget _buildIdeaChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final idea in _suggestions)
              Tooltip(
                message: 'Use this idea: ${idea.concept}',
                child: ActionChip(
                  onPressed: _isGenerating ? null : () => _applyIdea(idea),
                  avatar: const Icon(Icons.auto_awesome, size: 14),
                  label: Text(
                    idea.style.label,
                    style: const TextStyle(fontSize: 11),
                  ),
                  backgroundColor: Colors.white10,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required List<(T, String)> items,
    required ValueChanged<T> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(13),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: StudioColors.surfaceHigh,
          items: [
            for (final (id, label) in items)
              DropdownMenuItem(
                value: id,
                child: Text(
                  label,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
          ],
          onChanged: (selected) {
            if (selected == null) return;
            onChanged(selected);
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Tools: draw, text, logo, layers
  // ---------------------------------------------------------------------

  Widget _buildToolStrip({required bool horizontal}) {
    return Container(
      width: horizontal ? double.infinity : 100,
      height: horizontal ? 64 : double.infinity,
      decoration: BoxDecoration(
        color: StudioColors.surface,
        border: horizontal
            ? const Border(top: BorderSide(color: Colors.white10))
            : const Border(left: BorderSide(color: Colors.white10)),
      ),
      child: Material(
        color: Colors.transparent,
        child: horizontal
            ? SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                children: [
                  _buildToolButton(Icons.brush, 'Draw', _toggleDrawing,
                      active: _drawing),
                  _buildToolButton(Icons.text_fields, 'Text', _addTextLayer),
                  _buildToolButton(Icons.image, 'Logo', _addLogoLayer),
                  _buildToolButton(Icons.layers, 'Layers', _showLayers),
                  _buildToolButton(Icons.undo, 'Undo', _undoLayers,
                      enabled: _undo.isNotEmpty),
                  _buildToolButton(Icons.redo, 'Redo', _redoLayers,
                      enabled: _redo.isNotEmpty),
                ],
                ),
              )
            : Column(
                children: [
                  const SizedBox(height: 16),
                  _buildToolButton(Icons.brush, 'Draw', _toggleDrawing,
                      active: _drawing),
                  _buildToolButton(Icons.text_fields, 'Text', _addTextLayer),
                  _buildToolButton(Icons.image, 'Logo', _addLogoLayer),
                  _buildToolButton(Icons.layers, 'Layers', _showLayers),
                  const Divider(height: 16, color: Colors.white10),
                  _buildToolButton(Icons.undo, 'Undo', _undoLayers,
                      enabled: _undo.isNotEmpty),
                  _buildToolButton(Icons.redo, 'Redo', _redoLayers,
                      enabled: _redo.isNotEmpty),
                ],
              ),
      ),
    );
  }

  Widget _buildToolButton(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool active = false,
    bool enabled = true,
  }) {
    final color = !enabled
        ? Colors.white12
        : active
            ? StudioColors.aiAccent
            : Colors.white70;

    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        button: true,
        enabled: enabled,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(fontSize: 10, color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _toggleDrawing() {
    if (_design == null) {
      _notify('Generate a design first, then draw on it.');
      return;
    }
    setState(() {
      _drawing = !_drawing;
      _mode = PreviewMode.design;
    });
    if (_drawing) {
      _notify('Drag on the preview to paint. Tap Draw again to stop.');
    }
  }

  Future<WrapLayer?> _showTextDialog() {
    final controller = TextEditingController(text: 'TESLA');
    var color = _layerColors.first;
    var size = 0.14;

    return showDialog<WrapLayer>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: StudioColors.surfaceHigh,
          title: const Text('ADD TEXT'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                maxLength: 40,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'TEXT'),
              ),
              const SizedBox(height: 12),
              const Text(
                'COLOUR',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 8),
              _buildColorRow(color, (value) => setDialogState(() => color = value)),
              const SizedBox(height: 16),
              const Text(
                'SIZE',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              Slider(
                value: size,
                min: 0.04,
                max: 0.4,
                divisions: 18,
                activeColor: StudioColors.aiAccent,
                label: '${(size * 100).round()}%',
                onChanged: (value) => setDialogState(() => size = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isEmpty) {
                  Navigator.of(context).pop();
                  return;
                }
                Navigator.of(context).pop(
                  WrapLayer.text(
                    id: 'text_${DateTime.now().microsecondsSinceEpoch}',
                    text: text,
                    color: color,
                    scale: size,
                  ),
                );
              },
              child: const Text('ADD'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorRow(int selected, ValueChanged<int> onSelected) {
    return Wrap(
      spacing: 8,
      children: [
        for (final color in _layerColors)
          GestureDetector(
            onTap: () => onSelected(color),
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Color(color),
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected == color
                      ? StudioColors.aiAccent
                      : Colors.white24,
                  width: selected == color ? 3 : 1,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _showLayers() async {
    if (_design == null) {
      _notify('Generate a design first, then add layers.');
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          void apply(List<WrapLayer> next) {
            _updateLayers(next);
            setDialogState(() {});
          }

          return AlertDialog(
            backgroundColor: StudioColors.surfaceHigh,
            title: const Text('LAYERS'),
            content: SizedBox(
              width: 420,
              height: 380,
              child: _layers.isEmpty
                  ? const Center(
                      child: Text(
                        'No layers yet.\nAdd text, a logo or a brush stroke.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white38),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _layers.length,
                      itemBuilder: (context, index) {
                        // The list shows the topmost layer first, the way a
                        // layer panel is expected to read.
                        final position = _layers.length - 1 - index;
                        final layer = _layers[position];
                        return _buildLayerTile(layer, position, apply);
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('CLOSE'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLayerTile(
    WrapLayer layer,
    int position,
    ValueChanged<List<WrapLayer>> apply,
  ) {
    void replace(WrapLayer updated) {
      final next = List<WrapLayer>.of(_layers);
      next[position] = updated;
      apply(next);
    }

    void move(int delta) {
      final target = position + delta;
      if (target < 0 || target >= _layers.length) return;
      final next = List<WrapLayer>.of(_layers);
      final moved = next.removeAt(position);
      next.insert(target, moved);
      apply(next);
    }

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: IconButton(
        tooltip: layer.visible ? 'Hide layer' : 'Show layer',
        icon: Icon(
          layer.visible ? Icons.visibility : Icons.visibility_off,
          color: Colors.white70,
        ),
        onPressed: () => replace(layer.copyWith(visible: !layer.visible)),
      ),
      title: Text(
        layer.name.isEmpty ? layer.type.name : layer.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white, fontSize: 13),
      ),
      subtitle: Slider(
        value: layer.opacity,
        activeColor: StudioColors.aiAccent,
        onChanged: (value) => replace(layer.copyWith(opacity: value)),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Move up',
            icon: const Icon(Icons.arrow_upward, size: 18),
            onPressed: () => move(1),
          ),
          IconButton(
            tooltip: 'Move down',
            icon: const Icon(Icons.arrow_downward, size: 18),
            onPressed: () => move(-1),
          ),
          IconButton(
            tooltip: 'Delete layer',
            icon: const Icon(Icons.delete_outline, size: 18),
            onPressed: () {
              final next = List<WrapLayer>.of(_layers)..removeAt(position);
              apply(next);
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Preview
  // ---------------------------------------------------------------------

  Widget _buildPreviewArea(BuildContext context, AppState state) {
    return Container(
      color: Colors.black,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // On a very short window the history strip and the viewport
          // controls would push the preview out of the screen. The image
          // matters more than the furniture around it.
          final cramped = constraints.maxHeight < 260;

          return Column(
            children: [
              _buildModeSwitcher(),
              Expanded(child: _buildPreviewBody()),
              if (!cramped) _buildHistoryStrip(state),
              if (!cramped) _buildViewportControls(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPreviewBody() {
    final design = _design;
    final displayWidth = 800.0;

    final body = switch (_mode) {
      PreviewMode.design when design != null => LayerCanvas(
          design: MemoryImage(design.bytes),
          layers: _layers,
          designOpacity: _overlayOpacity,
          drawing: _drawing,
          brushSize: _brushSize,
          brushColor: _brushColor,
          onStrokeEnd: _onStrokeEnd,
        ),
      PreviewMode.design => Image.asset(
          widget.vehicle.imagePath,
          width: displayWidth,
          fit: BoxFit.contain,
        ),
      PreviewMode.template => Image.asset(
          widget.vehicle.templatePath,
          width: displayWidth,
          fit: BoxFit.contain,
        ),
      PreviewMode.vehicle => Image.asset(
          widget.vehicle.imagePath,
          width: displayWidth,
          fit: BoxFit.contain,
        ),
      PreviewMode.model3d => _build3dPreview(design),
    };

    return Stack(
      alignment: Alignment.center,
      children: [
        Transform.scale(scale: _zoom, child: body),
        // The hint belongs to the design view only.
        if (design == null && _mode == PreviewMode.design)
          const Positioned(
            bottom: 20,
            child: Chip(
              label: Text(
                'GENERATE A DESIGN TO BEGIN',
                style: TextStyle(color: Colors.white70),
              ),
              backgroundColor: Colors.white12,
            ),
          ),
        if (_drawing)
          Positioned(
            bottom: 12,
            right: 12,
            child: Row(
              children: [
                _buildColorRow(_brushColor, (value) {
                  setState(() => _brushColor = value);
                }),
                const SizedBox(width: 12),
                SizedBox(
                  width: 120,
                  child: Slider(
                    value: _brushSize,
                    min: 0.005,
                    max: 0.08,
                    activeColor: StudioColors.aiAccent,
                    onChanged: (value) => setState(() => _brushSize = value),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _build3dPreview(WrapDesign? design) {
    if (vehicleModelUrl(widget.vehicle) == null) {
      return Image.asset(
        widget.vehicle.imagePath,
        width: 800,
        fit: BoxFit.contain,
      );
    }

    final key = 'model3d:${design?.id ?? 'stock'}:'
        '${identityHashCode(_layers)}:${_layers.length}';

    return _VehicleSceneView(
      key: ValueKey(key),
      vehicle: widget.vehicle,
      baseArtwork: design == null
          ? null
          : (_rawArtwork[design.id] ?? design.bytes),
      layers: List<WrapLayer>.of(_layers),
    );
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
          _modeChip('3D', PreviewMode.model3d),
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
        onSelected: (_) {
          setState(() {
            _mode = mode;
            if (mode != PreviewMode.design) _drawing = false;
          });
        },
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
    // The session history is shared by every studio tab, so a design made for
    // another vehicle would preview and export against the wrong template.
    // Only this vehicle's designs belong in this strip.
    final designs = state.history
        .where((design) => design.modelId == widget.vehicle.id)
        .toList();
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
              onTap: () => _selectDesign(state, design),
              child: Container(
                width: 76,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color:
                        selected ? StudioColors.aiAccent : Colors.white10,
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
            message: 'Zoom to fit',
            child: Semantics(
              label: 'Reset zoom',
              button: true,
              child: IconButton(
                icon: const Icon(Icons.fit_screen, color: Colors.white),
                onPressed: () => setState(() => _zoom = 1),
              ),
            ),
          ),
        ],
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

/// Loads the 3D scene of a vehicle in the background and hands it to the
/// platform viewer.
class _VehicleSceneView extends StatefulWidget {
  const _VehicleSceneView({
    super.key,
    required this.vehicle,
    this.baseArtwork,
    this.layers = const <WrapLayer>[],
  });

  final TeslaModel vehicle;

  /// Unmasked design the layers are drawn over, or `null` for a stock car.
  final Uint8List? baseArtwork;

  /// Layer stack to bake into the texture.
  final List<WrapLayer> layers;

  @override
  State<_VehicleSceneView> createState() => _VehicleSceneViewState();
}

class _VehicleSceneViewState extends State<_VehicleSceneView> {
  late Future<Uint8List?> _scene = _load();

  Future<Uint8List?> _load() async {
    final base = widget.baseArtwork;
    if (base == null) {
      return loadVehicleScene(widget.vehicle);
    }

    // The texture is the design with its layers baked in, so the 3D preview
    // shows exactly what the export will contain.
    final composed = WrapCompositor.composite(
      base: base,
      layers: widget.layers,
      width: 1024,
      height: 1024,
    );
    return loadVehicleScene(widget.vehicle, design: composed ?? base);
  }

  @override
  Widget build(BuildContext context) {
    if (!has3dViewer) {
      return VehicleViewer(vehicle: widget.vehicle, modelBytes: null);
    }

    return FutureBuilder<Uint8List?>(
      future: _scene,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(strokeWidth: 2),
                SizedBox(height: 12),
                Text(
                  'Preparing the 3D model...',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          );
        }

        final bytes = snapshot.data;
        if (bytes == null) {
          return VehicleViewer(vehicle: widget.vehicle, modelBytes: null);
        }
        return VehicleViewer(vehicle: widget.vehicle, modelBytes: bytes);
      },
    );
  }
}
