import 'dart:ui' as ui;
import 'package:flutter/widgets.dart' show CustomPainter;

class ArabicOutlinePainter extends CustomPainter {
  final List<ui.Path> paths;
  final List<ui.Rect> highlights;
  final List<ui.Rect> passedRects;
  final ui.Rect? activeRect;
  final double activeProgress;
  final ui.Color color;
  final ui.Color highlightColor;
  final ui.Color passedColor;
  final ui.Color activeColor;
  final double scaleX;
  final double scaleY;
  final double offsetX;
  final double offsetY;

  ArabicOutlinePainter({
    required this.paths,
    this.highlights = const [],
    this.passedRects = const [],
    this.activeRect,
    this.activeProgress = 0,
    this.color = const ui.Color(0xFFFFFFFF),
    this.highlightColor = const ui.Color(0x00000000),
    this.passedColor = const ui.Color(0x00000000),
    this.activeColor = const ui.Color(0x00000000),
    this.scaleX = 1.0,
    this.scaleY = 1.0,
    this.offsetX = 0.0,
    this.offsetY = 0.0,
  });

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    // Overlay layers are supplied in canvas (pre-transform) coords so they
    // can extend past the glyph area (e.g. over vertical padding).
    if (highlights.isNotEmpty) {
      final p = ui.Paint()..color = highlightColor;
      for (final r in highlights) {
        canvas.drawRect(r, p);
      }
    }

    if (passedRects.isNotEmpty) {
      final p = ui.Paint()..color = passedColor;
      for (final r in passedRects) {
        canvas.drawRect(r, p);
      }
    }

    final ar = activeRect;
    if (ar != null && activeProgress > 0) {
      final fillW = ar.width * activeProgress;
      // RTL: fill from the right edge leftward.
      canvas.drawRect(
        ui.Rect.fromLTWH(ar.right - fillW, ar.top, fillW, ar.height),
        ui.Paint()..color = activeColor,
      );
    }

    canvas.save();
    canvas.translate(offsetX, offsetY);
    canvas.scale(scaleX, scaleY);

    final paint = ui.Paint()
      ..color = color
      ..style = ui.PaintingStyle.fill;
    for (final path in paths) {
      canvas.drawPath(path, paint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(ArabicOutlinePainter oldDelegate) =>
      !identical(paths, oldDelegate.paths) ||
      !_rectsEqual(highlights, oldDelegate.highlights) ||
      !_rectsEqual(passedRects, oldDelegate.passedRects) ||
      activeRect != oldDelegate.activeRect ||
      activeProgress != oldDelegate.activeProgress ||
      color != oldDelegate.color ||
      highlightColor != oldDelegate.highlightColor ||
      passedColor != oldDelegate.passedColor ||
      activeColor != oldDelegate.activeColor ||
      scaleX != oldDelegate.scaleX ||
      scaleY != oldDelegate.scaleY ||
      offsetX != oldDelegate.offsetX ||
      offsetY != oldDelegate.offsetY;

  static bool _rectsEqual(List<ui.Rect> a, List<ui.Rect> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
