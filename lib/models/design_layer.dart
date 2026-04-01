import 'dart:ui';

/// Represents a single layer in the wrap design.
enum LayerType { wrapImage, drawing, text, logo }

class DesignLayer {
  final String id;
  final LayerType type;
  final String name;
  final String? imagePath; // For wrapImage and logo types
  final String? textContent; // For text type
  final double opacity; // 0.0 - 1.0
  final double metallic; // 0.0 - 1.0
  final double roughness; // 0.0 - 1.0
  final BlendMode blendMode;
  final Offset position; // For drawing, text, logo
  final double scale; // For text, logo
  final Color? color; // For text and drawing
  final double fontSize; // For text
  final List<Offset>? drawingPoints; // For drawing type
  final double strokeWidth; // For drawing type
  final bool isVisible;
  final bool isLocked;

  DesignLayer({
    required this.id,
    required this.type,
    required this.name,
    this.imagePath,
    this.textContent,
    this.opacity = 1.0,
    this.metallic = 0.0,
    this.roughness = 0.5,
    this.blendMode = BlendMode.srcOver,
    this.position = Offset.zero,
    this.scale = 1.0,
    this.color,
    this.fontSize = 24.0,
    this.drawingPoints,
    this.strokeWidth = 3.0,
    this.isVisible = true,
    this.isLocked = false,
  });

  DesignLayer copyWith({
    String? id,
    LayerType? type,
    String? name,
    String? imagePath,
    String? textContent,
    double? opacity,
    double? metallic,
    double? roughness,
    BlendMode? blendMode,
    Offset? position,
    double? scale,
    Color? color,
    double? fontSize,
    List<Offset>? drawingPoints,
    double? strokeWidth,
    bool? isVisible,
    bool? isLocked,
  }) {
    return DesignLayer(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      imagePath: imagePath ?? this.imagePath,
      textContent: textContent ?? this.textContent,
      opacity: opacity ?? this.opacity,
      metallic: metallic ?? this.metallic,
      roughness: roughness ?? this.roughness,
      blendMode: blendMode ?? this.blendMode,
      position: position ?? this.position,
      scale: scale ?? this.scale,
      color: color ?? this.color,
      fontSize: fontSize ?? this.fontSize,
      drawingPoints: drawingPoints ?? this.drawingPoints,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      isVisible: isVisible ?? this.isVisible,
      isLocked: isLocked ?? this.isLocked,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.toString(),
      'name': name,
      'imagePath': imagePath,
      'textContent': textContent,
      'opacity': opacity,
      'metallic': metallic,
      'roughness': roughness,
      'blendMode': blendMode.toString(),
      'position': {'dx': position.dx, 'dy': position.dy},
      'scale': scale,
      'color': color?.value,
      'fontSize': fontSize,
      'drawingPoints': drawingPoints
          ?.map((p) => {'dx': p.dx, 'dy': p.dy})
          .toList(),
      'strokeWidth': strokeWidth,
      'isVisible': isVisible,
      'isLocked': isLocked,
    };
  }

  factory DesignLayer.fromJson(Map<String, dynamic> json) {
    final pos = json['position'] as Map<String, dynamic>?;
    final points = json['drawingPoints'] as List<dynamic>?;

    return DesignLayer(
      id: json['id'] as String,
      type: LayerType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => LayerType.wrapImage,
      ),
      name: json['name'] as String,
      imagePath: json['imagePath'] as String?,
      textContent: json['textContent'] as String?,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      metallic: (json['metallic'] as num?)?.toDouble() ?? 0.0,
      roughness: (json['roughness'] as num?)?.toDouble() ?? 0.5,
      blendMode: BlendMode.values.firstWhere(
        (e) => e.toString() == json['blendMode'],
        orElse: () => BlendMode.srcOver,
      ),
      position: pos != null
          ? Offset(pos['dx'] as double, pos['dy'] as double)
          : Offset.zero,
      scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
      color: json['color'] != null ? Color(json['color'] as int) : null,
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 24.0,
      drawingPoints: points
          ?.map((p) => Offset(
                (p as Map<String, dynamic>)['dx'] as double,
                p['dy'] as double,
              ))
          .toList(),
      strokeWidth: (json['strokeWidth'] as num?)?.toDouble() ?? 3.0,
      isVisible: json['isVisible'] as bool? ?? true,
      isLocked: json['isLocked'] as bool? ?? false,
    );
  }
}
