import 'dart:ui' as ui;
import 'package:flutter/widgets.dart' show CustomPainter;

import 'models.dart';

class ArabicOutlinePainter extends CustomPainter {
  final OutlineResult outline;
  final ui.Color color;

  ArabicOutlinePainter({
    required this.outline,
    this.color = const ui.Color(0xFFFFFFFF),
  });

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final paint = ui.Paint()
      ..color = color
      ..style = ui.PaintingStyle.fill;

    final ascender = outline.ascender;

    for (final glyph in outline.glyphs) {
      final path = ui.Path();
      for (final cmd in glyph.commands) {
        final x = glyph.offsetX + cmd.x;
        final y = ascender - (glyph.offsetY + cmd.y);
        switch (cmd.type) {
          case PathCommandType.moveTo:
            path.moveTo(x, y);
          case PathCommandType.lineTo:
            path.lineTo(x, y);
          case PathCommandType.quadTo:
            final cx = glyph.offsetX + cmd.x1;
            final cy = ascender - (glyph.offsetY + cmd.y1);
            path.quadraticBezierTo(cx, cy, x, y);
          case PathCommandType.cubicTo:
            final cx1 = glyph.offsetX + cmd.x1;
            final cy1 = ascender - (glyph.offsetY + cmd.y1);
            final cx2 = glyph.offsetX + cmd.x2;
            final cy2 = ascender - (glyph.offsetY + cmd.y2);
            path.cubicTo(cx1, cy1, cx2, cy2, x, y);
        }
      }
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(ArabicOutlinePainter oldDelegate) =>
      outline != oldDelegate.outline || color != oldDelegate.color;
}
