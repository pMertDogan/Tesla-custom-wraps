import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/design_layer.dart';
import '../models/wrap_design.dart';
import '../models/drawing_element.dart';

/// DesignProvider manages the application state using Provider pattern.
class DesignProvider extends ChangeNotifier {
  // Current design state
  final List<DesignLayer> _layers = [];
  final List<DrawingStroke> _drawingStrokes = [];
  final List<TextElement> _textElements = [];
  final List<LogoElement> _logoElements = [];

  // Vehicle info
  String? _currentVehicleId;
  String? _currentVehicleName;

  // AI settings
  String? _apiKey;
  String? _baseUrl;
  String _selectedProviderId = 'dalle3';

  // Manual controls
  double _opacity = 0.8;
  double _metallic = 0.2;
  double _roughness = 0.5;

  // Generated wrap image (base64 or URL)
  String? _generatedWrapImage;

  // UI state
  bool _isGenerating = false;
  String? _errorMessage;
  bool _show3DView = false;
  double _zoomLevel = 1.0;
  double _rotationAngle = 0.0;

  // Saved designs
  final List<WrapDesign> _savedDesigns = [];

  // Active tool
  String _activeTool = 'select'; // select, draw, text, logo, layers

  // Drawing state
  Color _drawColor = Colors.white;
  double _drawStrokeWidth = 3.0;
  bool _isEraser = false;

  // Getters
  List<DesignLayer> get layers => List.unmodifiable(_layers);
  List<DrawingStroke> get drawingStrokes => List.unmodifiable(_drawingStrokes);
  List<TextElement> get textElements => List.unmodifiable(_textElements);
  List<LogoElement> get logoElements => List.unmodifiable(_logoElements);
  String? get currentVehicleId => _currentVehicleId;
  String? get currentVehicleName => _currentVehicleName;
  String? get apiKey => _apiKey;
  String? get baseUrl => _baseUrl;
  String get selectedProviderId => _selectedProviderId;
  double get opacity => _opacity;
  double get metallic => _metallic;
  double get roughness => _roughness;
  String? get generatedWrapImage => _generatedWrapImage;
  bool get isGenerating => _isGenerating;
  String? get errorMessage => _errorMessage;
  bool get show3DView => _show3DView;
  double get zoomLevel => _zoomLevel;
  double get rotationAngle => _rotationAngle;
  List<WrapDesign> get savedDesigns => List.unmodifiable(_savedDesigns);
  String get activeTool => _activeTool;
  Color get drawColor => _drawColor;
  double get drawStrokeWidth => _drawStrokeWidth;
  bool get isEraser => _isEraser;

  // --- Vehicle ---
  void setCurrentVehicle(String id, String name) {
    _currentVehicleId = id;
    _currentVehicleName = name;
    notifyListeners();
  }

  // --- AI Settings ---
  void setApiKey(String key) {
    _apiKey = key;
    _saveSettings();
    notifyListeners();
  }

  void setBaseUrl(String url) {
    _baseUrl = url;
    _saveSettings();
    notifyListeners();
  }

  void setSelectedProvider(String providerId) {
    _selectedProviderId = providerId;
    notifyListeners();
  }

  // --- Manual Controls ---
  void setOpacity(double value) {
    _opacity = value;
    notifyListeners();
  }

  void setMetallic(double value) {
    _metallic = value;
    notifyListeners();
  }

  void setRoughness(double value) {
    _roughness = value;
    notifyListeners();
  }

  // --- Generation ---
  void setGenerating(bool value) {
    _isGenerating = value;
    notifyListeners();
  }

  void setWrapImage(String? imageData) {
    _generatedWrapImage = imageData;
    if (imageData != null) {
      _layers.removeWhere((l) => l.type == LayerType.wrapImage);
      _layers.insert(
        0,
        DesignLayer(
          id: 'wrap_${DateTime.now().millisecondsSinceEpoch}',
          type: LayerType.wrapImage,
          name: 'AI Generated Wrap',
          imagePath: imageData,
          opacity: _opacity,
          metallic: _metallic,
          roughness: _roughness,
        ),
      );
    }
    notifyListeners();
  }

  void setErrorMessage(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  // --- 3D View ---
  void toggle3DView() {
    _show3DView = !_show3DView;
    notifyListeners();
  }

  void setShow3DView(bool value) {
    _show3DView = value;
    notifyListeners();
  }

  // --- Zoom & Rotation ---
  void setZoom(double value) {
    _zoomLevel = value.clamp(0.5, 3.0);
    notifyListeners();
  }

  void zoomIn() {
    _zoomLevel = (_zoomLevel + 0.1).clamp(0.5, 3.0);
    notifyListeners();
  }

  void zoomOut() {
    _zoomLevel = (_zoomLevel - 0.1).clamp(0.5, 3.0);
    notifyListeners();
  }

  void setRotation(double value) {
    _rotationAngle = value;
    notifyListeners();
  }

  void rotateLeft() {
    _rotationAngle -= 0.1;
    notifyListeners();
  }

  void rotateRight() {
    _rotationAngle += 0.1;
    notifyListeners();
  }

  // --- Active Tool ---
  void setActiveTool(String tool) {
    _activeTool = tool;
    notifyListeners();
  }

  // --- Drawing ---
  void setDrawColor(Color color) {
    _drawColor = color;
    notifyListeners();
  }

  void setDrawStrokeWidth(double width) {
    _drawStrokeWidth = width;
    notifyListeners();
  }

  void setEraser(bool value) {
    _isEraser = value;
    notifyListeners();
  }

  void addDrawingStroke(DrawingStroke stroke) {
    _drawingStrokes.add(stroke);
    notifyListeners();
  }

  void undoLastStroke() {
    if (_drawingStrokes.isNotEmpty) {
      _drawingStrokes.removeLast();
      notifyListeners();
    }
  }

  void clearDrawingStrokes() {
    _drawingStrokes.clear();
    notifyListeners();
  }

  // --- Text Elements ---
  void addTextElement(TextElement element) {
    _textElements.add(element);
    _layers.add(
      DesignLayer(
        id: 'text_${element.id}',
        type: LayerType.text,
        name: 'Text: ${element.content.substring(0, element.content.length > 10 ? 10 : element.content.length)}...',
        textContent: element.content,
        position: Offset(element.x, element.y),
        fontSize: element.fontSize,
        color: Color(element.color),
      ),
    );
    notifyListeners();
  }

  void removeTextElement(String id) {
    _textElements.removeWhere((e) => e.id == id);
    _layers.removeWhere((l) => l.type == LayerType.text && l.id == 'text_$id');
    notifyListeners();
  }

  // --- Logo Elements ---
  void addLogoElement(LogoElement element) {
    _logoElements.add(element);
    _layers.add(
      DesignLayer(
        id: 'logo_${element.id}',
        type: LayerType.logo,
        name: 'Logo: ${element.imagePath.split('/').last}',
        imagePath: element.imagePath,
        position: Offset(element.x, element.y),
        opacity: element.opacity,
      ),
    );
    notifyListeners();
  }

  void removeLogoElement(String id) {
    _logoElements.removeWhere((e) => e.id == id);
    _layers.removeWhere((l) => l.type == LayerType.logo && l.id == 'logo_$id');
    notifyListeners();
  }

  // --- Layers ---
  void addLayer(DesignLayer layer) {
    _layers.add(layer);
    notifyListeners();
  }

  void removeLayer(String id) {
    _layers.removeWhere((l) => l.id == id);
    notifyListeners();
  }

  void reorderLayer(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = _layers.removeAt(oldIndex);
    _layers.insert(newIndex, item);
    notifyListeners();
  }

  void updateLayer(String id, DesignLayer updatedLayer) {
    final index = _layers.indexWhere((l) => l.id == id);
    if (index != -1) {
      _layers[index] = updatedLayer;
      notifyListeners();
    }
  }

  void toggleLayerVisibility(String id) {
    final index = _layers.indexWhere((l) => l.id == id);
    if (index != -1) {
      _layers[index] = _layers[index].copyWith(
        isVisible: !_layers[index].isVisible,
      );
      notifyListeners();
    }
  }

  void clearAllLayers() {
    _layers.clear();
    _drawingStrokes.clear();
    _textElements.clear();
    _logoElements.clear();
    _generatedWrapImage = null;
    notifyListeners();
  }

  // --- Save/Load Designs ---
  Future<void> saveCurrentDesign(String designName, String prompt) async {
    if (_currentVehicleId == null) return;

    final design = WrapDesign(
      id: 'design_${DateTime.now().millisecondsSinceEpoch}',
      vehicleModelId: _currentVehicleId!,
      vehicleName: _currentVehicleName ?? 'Unknown',
      prompt: prompt,
      aiProvider: _selectedProviderId,
      layers: List.from(_layers),
    );

    _savedDesigns.add(design);
    await _saveDesigns();
    notifyListeners();
  }

  Future<void> loadDesign(WrapDesign design) async {
    _currentVehicleId = design.vehicleModelId;
    _currentVehicleName = design.vehicleName;
    _layers.clear();
    _layers.addAll(design.layers);
    notifyListeners();
  }

  Future<void> deleteDesign(String id) async {
    _savedDesigns.removeWhere((d) => d.id == id);
    await _saveDesigns();
    notifyListeners();
  }

  Future<void> toggleFavorite(String id) async {
    final index = _savedDesigns.indexWhere((d) => d.id == id);
    if (index != -1) {
      _savedDesigns[index] = _savedDesigns[index].copyWith(
        isFavorite: !_savedDesigns[index].isFavorite,
      );
      await _saveDesigns();
      notifyListeners();
    }
  }

  // --- Persistence ---
  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _apiKey = prefs.getString('api_key');
      _baseUrl = prefs.getString('base_url');
      _selectedProviderId = prefs.getString('selected_provider') ?? 'dalle3';
      _opacity = prefs.getDouble('opacity') ?? 0.8;
      _metallic = prefs.getDouble('metallic') ?? 0.2;
      _roughness = prefs.getDouble('roughness') ?? 0.5;

      // Load saved designs
      final designsJson = prefs.getString('saved_designs');
      if (designsJson != null) {
        final List<dynamic> designsList = jsonDecode(designsJson);
        _savedDesigns.clear();
        _savedDesigns.addAll(
          designsList.map((d) => WrapDesign.fromJson(d)).toList(),
        );
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('api_key', _apiKey ?? '');
      await prefs.setString('base_url', _baseUrl ?? '');
      await prefs.setString('selected_provider', _selectedProviderId);
      await prefs.setDouble('opacity', _opacity);
      await prefs.setDouble('metallic', _metallic);
      await prefs.setDouble('roughness', _roughness);
    } catch (e) {
      debugPrint('Error saving settings: $e');
    }
  }

  Future<void> _saveDesigns() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final designsJson = jsonEncode(
        _savedDesigns.map((d) => d.toJson()).toList(),
      );
      await prefs.setString('saved_designs', designsJson);
    } catch (e) {
      debugPrint('Error saving designs: $e');
    }
  }
}
