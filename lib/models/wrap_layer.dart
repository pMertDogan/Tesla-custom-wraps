import 'dart:convert';
import 'dart:typed_data';

/// What a layer on the wrap canvas draws.
enum WrapLayerType {
  /// A line of text.
  text,

  /// An uploaded logo or badge.
  image,

  /// A freehand brush stroke.
  brush,
}

/// One editable layer drawn on top of the generated artwork.
///
/// Layers are stored in canvas-relative units (0..1 of the shorter edge for
/// position, of the width for size), so the same layer stack renders correctly
/// on a phone preview, on the 1024 px export and in the 3D texture.
class WrapLayer {
  /// Unique id inside the design.
  final String id;

  /// What the layer draws.
  final WrapLayerType type;

  /// Name shown in the layer list.
  final String name;

  /// Whether the layer is drawn at all.
  final bool visible;

  /// Opacity from 0 to 1.
  final double opacity;

  /// Horizontal centre, 0 (left edge) to 1 (right edge).
  final double x;

  /// Vertical centre, 0 (top edge) to 1 (bottom edge).
  final double y;

  /// Size as a fraction of the canvas width: the text height, the logo width
  /// or the brush thickness.
  final double scale;

  /// `0xAARRGGBB` colour for text and brush strokes.
  final int color;

  /// Text content, for [WrapLayerType.text].
  final String text;

  /// Encoded PNG/JPEG of the logo, for [WrapLayerType.image].
  final Uint8List? imageBytes;

  /// Stroke points as `x0, y0, x1, y1, ...` in canvas units, for
  /// [WrapLayerType.brush].
  final List<double> points;

  const WrapLayer({
    required this.id,
    required this.type,
    required this.name,
    this.visible = true,
    this.opacity = 1,
    this.x = 0.5,
    this.y = 0.5,
    this.scale = 0.1,
    this.color = 0xFFFFFFFF,
    this.text = '',
    this.imageBytes,
    this.points = const [],
  });

  /// Text layer with sensible defaults for a wrap.
  factory WrapLayer.text({
    required String id,
    required String text,
    int color = 0xFFFFFFFF,
    double scale = 0.14,
  }) {
    return WrapLayer(
      id: id,
      type: WrapLayerType.text,
      name: text.isEmpty ? 'Text' : text,
      text: text,
      color: color,
      scale: scale,
      y: 0.5,
    );
  }

  /// Image layer around [bytes].
  factory WrapLayer.image({
    required String id,
    required String name,
    required Uint8List bytes,
    double scale = 0.3,
  }) {
    return WrapLayer(
      id: id,
      type: WrapLayerType.image,
      name: name,
      imageBytes: bytes,
      scale: scale,
    );
  }

  /// Brush layer that grows as the user draws.
  factory WrapLayer.brush({
    required String id,
    required int color,
    double scale = 0.02,
  }) {
    return WrapLayer(
      id: id,
      type: WrapLayerType.brush,
      name: 'Brush',
      color: color,
      scale: scale,
    );
  }

  /// A copy with the given fields replaced.
  WrapLayer copyWith({
    String? name,
    bool? visible,
    double? opacity,
    double? x,
    double? y,
    double? scale,
    int? color,
    String? text,
    Uint8List? imageBytes,
    List<double>? points,
  }) {
    return WrapLayer(
      id: id,
      type: type,
      name: name ?? this.name,
      visible: visible ?? this.visible,
      opacity: opacity ?? this.opacity,
      x: x ?? this.x,
      y: y ?? this.y,
      scale: scale ?? this.scale,
      color: color ?? this.color,
      text: text ?? this.text,
      imageBytes: imageBytes ?? this.imageBytes,
      points: points ?? this.points,
    );
  }

  /// Whether the layer currently draws something.
  bool get isEmpty {
    switch (type) {
      case WrapLayerType.text:
        return text.trim().isEmpty;
      case WrapLayerType.image:
        return imageBytes == null || imageBytes!.isEmpty;
      case WrapLayerType.brush:
        return points.length < 4;
    }
  }

  /// Compact JSON form, used to keep the layer stack across sessions.
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'name': name,
        'visible': visible,
        'opacity': opacity,
        'x': x,
        'y': y,
        'scale': scale,
        'color': color,
        'text': text,
        if (imageBytes != null) 'image': base64Encode(imageBytes!),
        if (points.isNotEmpty) 'points': points,
      };

  /// Reads a layer written by [toJson].
  ///
  /// Unknown or damaged entries come back as `null` so one bad layer cannot
  /// take the whole saved stack with it.
  static WrapLayer? fromJson(Map<String, dynamic> json) {
    final typeName = json['type'];
    final type = WrapLayerType.values
        .where((value) => value.name == typeName)
        .firstOrNull;
    final id = json['id'];
    if (type == null || id is! String) return null;

    Uint8List? image;
    final encoded = json['image'];
    if (encoded is String && encoded.isNotEmpty) {
      try {
        image = base64Decode(encoded);
      } on FormatException {
        image = null;
      }
    }

    final rawPoints = json['points'];
    return WrapLayer(
      id: id,
      type: type,
      name: json['name'] is String ? json['name'] as String : 'Layer',
      visible: json['visible'] is bool ? json['visible'] as bool : true,
      opacity: _toDouble(json['opacity']) ?? 1,
      x: _toDouble(json['x']) ?? 0.5,
      y: _toDouble(json['y']) ?? 0.5,
      scale: _toDouble(json['scale']) ?? 0.1,
      color: json['color'] is int ? json['color'] as int : 0xFFFFFFFF,
      text: json['text'] is String ? json['text'] as String : '',
      imageBytes: image,
      points: rawPoints is List
          ? [
              for (final value in rawPoints)
                if (value is num) value.toDouble(),
            ]
          : const [],
    );
  }

  static double? _toDouble(Object? value) =>
      value is num ? value.toDouble() : null;
}
