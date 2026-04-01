import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../providers/design_provider.dart';
import '../models/drawing_element.dart';
import 'package:provider/provider.dart';

/// Canvas widget for freehand drawing on the wrap design.
class DrawingCanvas extends StatefulWidget {
  final double width;
  final double height;

  const DrawingCanvas({
    super.key,
    required this.width,
    required this.height,
  });

  @override
  State<DrawingCanvas> createState() => _DrawingCanvasState();
}

class _DrawingCanvasState extends State<DrawingCanvas> {
  List<Offset> _currentPoints = [];
  bool _isDrawing = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DesignProvider>();

    return GestureDetector(
      onPanStart: (details) {
        if (provider.activeTool != 'draw') return;
        final offset = details.localPosition;
        setState(() {
          _isDrawing = true;
          _currentPoints = [offset];
        });
      },
      onPanUpdate: (details) {
        if (provider.activeTool != 'draw' || !_isDrawing) return;
        setState(() {
          _currentPoints.add(details.localPosition);
        });
      },
      onPanEnd: (details) {
        if (provider.activeTool != 'draw' || !_isDrawing) return;
        final stroke = DrawingStroke(
          id: 'stroke_${DateTime.now().millisecondsSinceEpoch}',
          points: List.from(_currentPoints),
          color: provider.isEraser ? 0xFF000000 : provider.drawColor.value,
          strokeWidth: provider.drawStrokeWidth,
          isEraser: provider.isEraser,
        );
        provider.addDrawingStroke(stroke);
        setState(() {
          _isDrawing = false;
          _currentPoints = [];
        });
      },
      child: CustomPaint(
        size: Size(widget.width, widget.height),
        painter: _DrawingPainter(
          strokes: provider.drawingStrokes,
          currentPoints: _currentPoints,
          currentColor: provider.isEraser
              ? 0xFF000000
              : provider.drawColor.value,
          currentStrokeWidth: provider.drawStrokeWidth,
          isEraser: provider.isEraser,
        ),
      ),
    );
  }
}

class _DrawingPainter extends CustomPainter {
  final List<DrawingStroke> strokes;
  final List<Offset> currentPoints;
  final int currentColor;
  final double currentStrokeWidth;
  final bool isEraser;

  _DrawingPainter({
    required this.strokes,
    required this.currentPoints,
    required this.currentColor,
    required this.currentStrokeWidth,
    required this.isEraser,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Draw saved strokes
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

    // Draw current stroke
    if (currentPoints.length >= 2) {
      paint
        ..color = Color(currentColor)
        ..strokeWidth = currentStrokeWidth
        ..blendMode = isEraser ? BlendMode.clear : BlendMode.srcOver;

      final path = Path();
      path.moveTo(currentPoints[0].dx, currentPoints[0].dy);

      for (int i = 1; i < currentPoints.length - 1; i++) {
        final mid = Offset(
          (currentPoints[i].dx + currentPoints[i + 1].dx) / 2,
          (currentPoints[i].dy + currentPoints[i + 1].dy) / 2,
        );
        path.quadraticBezierTo(
          currentPoints[i].dx,
          currentPoints[i].dy,
          mid.dx,
          mid.dy,
        );
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_DrawingPainter oldDelegate) => true;
}
