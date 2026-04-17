import 'dart:ui' as ui;
import 'package:flutter/widgets.dart' show CustomPainter;

class ArabicOutlinePainter extends CustomPainter {
  final List<ui.Path> paths;
  final ui.Color color;
  final double scaleX;
  final double scaleY;
  final double offsetX;
  final double offsetY;

  ArabicOutlinePainter({
    required this.paths,
    this.color = const ui.Color(0xFFFFFFFF),
    this.scaleX = 1.0,
    this.scaleY = 1.0,
    this.offsetX = 0.0,
    this.offsetY = 0.0,
  });

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final paint = ui.Paint()
      ..color = color
      ..style = ui.PaintingStyle.fill;

    canvas.translate(offsetX, offsetY);
    canvas.scale(scaleX, scaleY);

    for (final path in paths) {
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(ArabicOutlinePainter oldDelegate) =>
      !identical(paths, oldDelegate.paths) ||
      color != oldDelegate.color ||
      scaleX != oldDelegate.scaleX ||
      scaleY != oldDelegate.scaleY ||
      offsetX != oldDelegate.offsetX ||
      offsetY != oldDelegate.offsetY;
}
