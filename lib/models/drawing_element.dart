import 'dart:ui';

/// Represents a text element that can be added to a wrap design.
class TextElement {
  final String id;
  final String content;
  final double x;
  final double y;
  final double fontSize;
  final String fontFamily;
  final int color; // ARGB int
  final double rotation; // in radians
  final bool isBold;
  final bool isItalic;

  TextElement({
    required this.id,
    required this.content,
    required this.x,
    required this.y,
    this.fontSize = 24.0,
    this.fontFamily = 'Roboto',
    this.color = 0xFFFFFFFF,
    this.rotation = 0.0,
    this.isBold = false,
    this.isItalic = false,
  });

  TextElement copyWith({
    String? id,
    String? content,
    double? x,
    double? y,
    double? fontSize,
    String? fontFamily,
    int? color,
    double? rotation,
    bool? isBold,
    bool? isItalic,
  }) {
    return TextElement(
      id: id ?? this.id,
      content: content ?? this.content,
      x: x ?? this.x,
      y: y ?? this.y,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      color: color ?? this.color,
      rotation: rotation ?? this.rotation,
      isBold: isBold ?? this.isBold,
      isItalic: isItalic ?? this.isItalic,
    );
  }
}

/// Represents a logo/image element that can be added to a wrap design.
class LogoElement {
  final String id;
  final String imagePath; // Asset path or file path
  final double x;
  final double y;
  final double width;
  final double height;
  final double rotation; // in radians
  final double opacity;

  LogoElement({
    required this.id,
    required this.imagePath,
    required this.x,
    required this.y,
    this.width = 100.0,
    this.height = 100.0,
    this.rotation = 0.0,
    this.opacity = 1.0,
  });

  LogoElement copyWith({
    String? id,
    String? imagePath,
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
    double? opacity,
  }) {
    return LogoElement(
      id: id ?? this.id,
      imagePath: imagePath ?? this.imagePath,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      rotation: rotation ?? this.rotation,
      opacity: opacity ?? this.opacity,
    );
  }
}

/// Represents a freehand drawing stroke.
class DrawingStroke {
  final String id;
  final List<Offset> points;
  final int color; // ARGB int
  final double strokeWidth;
  final bool isEraser;

  DrawingStroke({
    required this.id,
    required this.points,
    this.color = 0xFFFFFFFF,
    this.strokeWidth = 3.0,
    this.isEraser = false,
  });
}
