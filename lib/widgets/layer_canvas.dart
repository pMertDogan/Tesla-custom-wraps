import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/wrap_layer.dart';

/// Draws a wrap design with its editable layers on top.
///
/// The preview is a Flutter widget tree rather than a rasterised image: a
/// brush stroke has to appear while the finger is still moving, and
/// re-encoding a 1024 px PNG on every pointer event would make the canvas
/// unusable. The export runs the same stack through `WrapCompositor`, which
/// produces the pixels.
///
/// Layers use canvas-relative coordinates, so the preview and the export agree
/// no matter how large the window is.
class LayerCanvas extends StatefulWidget {
  /// The wrapped vehicle design, already clipped to the panel mask.
  final ImageProvider design;

  /// Layers to draw on top, oldest first.
  final List<WrapLayer> layers;

  /// Opacity applied to the design itself.
  final double designOpacity;

  /// Reports the points of the stroke being drawn, in canvas units.
  final ValueChanged<List<double>>? onStroke;

  /// Reports a finished stroke, so the caller can turn it into a layer.
  final ValueChanged<List<double>>? onStrokeEnd;

  /// Size of the brush, as a fraction of the canvas width.
  final double brushSize;

  /// Colour of the brush stroke.
  final int brushColor;

  /// Whether a drag paints a brush stroke.
  final bool drawing;

  /// Creates the canvas.
  const LayerCanvas({
    super.key,
    required this.design,
    required this.layers,
    this.designOpacity = 1,
    this.onStroke,
    this.onStrokeEnd,
    this.brushSize = 0.02,
    this.brushColor = 0xFFFFFFFF,
    this.drawing = false,
  });

  @override
  State<LayerCanvas> createState() => _LayerCanvasState();
}

class _LayerCanvasState extends State<LayerCanvas> {
  final List<double> _stroke = <double>[];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: widget.drawing ? (_) => _start(size) : null,
          onPanUpdate:
              widget.drawing ? (details) => _extend(size, details) : null,
          onPanEnd: widget.drawing ? (_) => _finish() : null,
          onPanCancel: widget.drawing ? _finish : null,
          child: Stack(
            fit: StackFit.expand,
            alignment: Alignment.center,
            children: [
              Center(
                child: Opacity(
                  opacity: widget.designOpacity,
                  child: Image(image: widget.design, fit: BoxFit.contain),
                ),
              ),
              for (final layer in widget.layers)
                if (layer.visible && !layer.isEmpty)
                  _positioned(size, layer),
              if (widget.drawing && _stroke.length >= 4)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: StrokePainter(
                        points: _stroke,
                        color: Color(widget.brushColor),
                        thickness: widget.brushSize * size.width,
                      ),
                    ),
                  ),
                ),
              if (widget.drawing)
                Positioned(
                  top: 8,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Center(
                      child: Chip(
                        avatar: const Icon(Icons.brush, size: 16),
                        label: const Text(
                          'DRAWING - DRAG ON THE WRAP',
                          style: TextStyle(fontSize: 11),
                        ),
                        backgroundColor: Colors.black87,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _start(Size size) {
    _stroke.clear();
    setState(() {});
  }

  void _extend(Size size, DragUpdateDetails details) {
    if (size.width <= 0 || size.height <= 0) return;
    setState(() {
      _stroke
        ..add((details.localPosition.dx / size.width).clamp(0.0, 1.0))
        ..add((details.localPosition.dy / size.height).clamp(0.0, 1.0));
    });
    widget.onStroke?.call(List<double>.of(_stroke));
  }

  void _finish() {
    if (_stroke.length >= 4) {
      widget.onStrokeEnd?.call(List<double>.of(_stroke));
    }
    setState(_stroke.clear);
  }

  /// Places one layer on the canvas.
  Widget _positioned(Size size, WrapLayer layer) {
    switch (layer.type) {
      case WrapLayerType.text:
        return Align(
          alignment: Alignment(layer.x * 2 - 1, layer.y * 2 - 1),
          child: Opacity(
            opacity: layer.opacity,
            child: Text(
              layer.text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(layer.color),
                fontSize: (layer.scale * size.width).clamp(6, 900),
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
        );

      case WrapLayerType.image:
        final bytes = layer.imageBytes;
        if (bytes == null) return const SizedBox.shrink();
        return Align(
          alignment: Alignment(layer.x * 2 - 1, layer.y * 2 - 1),
          child: Opacity(
            opacity: layer.opacity,
            child: Image.memory(
              layerImageBytes(bytes),
              width: layer.scale * size.width,
              fit: BoxFit.contain,
              gaplessPlayback: true,
            ),
          ),
        );

      case WrapLayerType.brush:
        return Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: StrokePainter(
                points: layer.points,
                color: Color(layer.color).withValues(alpha: layer.opacity),
                thickness: layer.scale * size.width,
              ),
            ),
          ),
        );
    }
  }
}

/// Paints a polyline of canvas-relative points.
class StrokePainter extends CustomPainter {
  /// Flat list of `x0, y0, x1, y1, ...` in canvas units.
  final List<double> points;

  /// Stroke colour.
  final Color color;

  /// Stroke width in pixels.
  final double thickness;

  /// Creates the painter.
  StrokePainter({
    required this.points,
    required this.color,
    required this.thickness,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 4) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness.clamp(1, 512)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(points[0] * size.width, points[1] * size.height);

    for (var i = 2; i + 1 < points.length; i += 2) {
      path.lineTo(points[i] * size.width, points[i + 1] * size.height);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(StrokePainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.color != color ||
      oldDelegate.thickness != thickness;
}

/// Encodes [bytes] as the `Uint8List` an `Image.memory` needs.
Uint8List layerImageBytes(List<int> bytes) =>
    bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
