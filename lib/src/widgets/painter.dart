import 'dart:ui' as ui;
import 'package:flutter/widgets.dart' show CustomPainter;

class ArabicOutlinePainter extends CustomPainter {
  final List<ui.Path> paths;
  final List<ui.Rect> highlights;
  final ui.Color color;
  final ui.Color highlightColor;
  final double scaleX;
  final double scaleY;
  final double offsetX;
  final double offsetY;

  ArabicOutlinePainter({
    required this.paths,
    this.highlights = const [],
    this.color = const ui.Color(0xFFFFFFFF),
    this.highlightColor = const ui.Color(0x00000000),
    this.scaleX = 1.0,
    this.scaleY = 1.0,
    this.offsetX = 0.0,
    this.offsetY = 0.0,
  });

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    // Highlights are supplied in canvas (pre-transform) coords so they can
    // extend past the glyph area (e.g. over the widget's vertical padding).
    if (highlights.isNotEmpty) {
      final hPaint = ui.Paint()..color = highlightColor;
      for (final r in highlights) {
        canvas.drawRect(r, hPaint);
      }
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
      !_listEquals(highlights, oldDelegate.highlights) ||
      color != oldDelegate.color ||
      highlightColor != oldDelegate.highlightColor ||
      scaleX != oldDelegate.scaleX ||
      scaleY != oldDelegate.scaleY ||
      offsetX != oldDelegate.offsetX ||
      offsetY != oldDelegate.offsetY;

  static bool _listEquals(List<ui.Rect> a, List<ui.Rect> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
