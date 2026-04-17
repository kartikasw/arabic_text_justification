import 'dart:ui' as ui;

export 'word_progress.dart';

class GlyphInfo {
  final int glyphId;
  final double xOffset;
  final double yOffset;
  final double xAdvance;

  GlyphInfo({
    required this.glyphId,
    required this.xOffset,
    required this.yOffset,
    required this.xAdvance,
  });
}

class ShapeResult {
  final List<GlyphInfo> glyphs;
  final double totalWidth;

  ShapeResult({required this.glyphs, required this.totalWidth});
}

class WordRect {
  final double x;
  final double y;
  final double width;
  final double height;

  WordRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  ui.Rect toRect() => ui.Rect.fromLTWH(x, y, width, height);
}

class RenderResult {
  final ui.Image image;
  final int bmpWidth;
  final int bmpHeight;
  final List<WordRect> wordRects;

  RenderResult({
    required this.image,
    required this.bmpWidth,
    required this.bmpHeight,
    required this.wordRects,
  });
}

enum PathCommandType { moveTo, lineTo, quadTo, cubicTo }

class PathCommand {
  final PathCommandType type;
  final double x, y;
  final double x1, y1;
  final double x2, y2;

  PathCommand({
    required this.type,
    required this.x,
    required this.y,
    this.x1 = 0,
    this.y1 = 0,
    this.x2 = 0,
    this.y2 = 0,
  });
}

class GlyphOutline {
  final List<PathCommand> commands;
  final double offsetX;
  final double offsetY;
  final int wordIndex;

  GlyphOutline({
    required this.commands,
    required this.offsetX,
    required this.offsetY,
    required this.wordIndex,
  });
}

class OutlineResult {
  final List<GlyphOutline> glyphs;
  final List<WordRect> wordRects;
  final double ascender;
  final double descender;
  final double totalWidth;

  OutlineResult({
    required this.glyphs,
    required this.wordRects,
    required this.ascender,
    required this.descender,
    required this.totalWidth,
  });
}
