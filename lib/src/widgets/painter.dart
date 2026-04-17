import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show listEquals, setEquals;
import 'package:flutter/widgets.dart' show CustomPainter;

class ArabicOutlinePainter extends CustomPainter {
  final List<ui.Path> paths;
  final List<int> pathWordIndices;
  final Set<int>? hiddenWordIndices;
  final List<ui.Rect> highlights;
  final ui.Color highlightColor;
  final ui.Color color;
  final Set<int>? passedWordIndices;
  final List<ui.Rect> passedRects;
  final ui.Color? passedHighlightColor;
  final ui.Color? passedColor;
  final int? activeWordIndex;
  final ui.Rect? activeRect;
  final double activeProgress;
  final ui.Color? activeHighlightColor;
  final ui.Color? activeColor;
  final bool activeWhole;
  final double scaleX;
  final double scaleY;
  final double offsetX;
  final double offsetY;

  ArabicOutlinePainter({
    required this.paths,
    this.pathWordIndices = const [],
    this.hiddenWordIndices,
    this.highlights = const [],
    this.highlightColor = const ui.Color(0x00000000),
    this.color = const ui.Color(0xFFFFFFFF),
    this.passedWordIndices,
    this.passedRects = const [],
    this.passedHighlightColor,
    this.passedColor,
    this.activeWordIndex,
    this.activeRect,
    this.activeProgress = 0,
    this.activeHighlightColor,
    this.activeColor,
    this.activeWhole = false,
    this.scaleX = 1.0,
    this.scaleY = 1.0,
    this.offsetX = 0.0,
    this.offsetY = 0.0,
  });

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    // Tap highlights — always drawn when provided, regardless of progress.
    if (highlights.isNotEmpty) {
      final p = ui.Paint()..color = highlightColor;
      for (final r in highlights) {
        canvas.drawRect(r, p);
      }
    }

    // Passed-word background highlight (optional).
    if (passedHighlightColor != null && passedRects.isNotEmpty) {
      final p = ui.Paint()..color = passedHighlightColor!;
      for (final r in passedRects) {
        canvas.drawRect(r, p);
      }
    }

    // Active-word background highlight (optional).
    final ar = activeRect;
    if (activeHighlightColor != null && ar != null) {
      if (activeWhole) {
        canvas.drawRect(ar, ui.Paint()..color = activeHighlightColor!);
      } else if (activeProgress > 0) {
        final fillW = ar.width * activeProgress;
        canvas.drawRect(
          ui.Rect.fromLTWH(ar.right - fillW, ar.top, fillW, ar.height),
          ui.Paint()..color = activeHighlightColor!,
        );
      }
    }

    final paintDefault = ui.Paint()
      ..color = color
      ..style = ui.PaintingStyle.fill;
    final paintPassed = passedColor == null
        ? paintDefault
        : (ui.Paint()
          ..color = passedColor!
          ..style = ui.PaintingStyle.fill);
    final paintActiveFull = activeColor == null
        ? paintDefault
        : (ui.Paint()
          ..color = activeColor!
          ..style = ui.PaintingStyle.fill);

    final hasWordMap = pathWordIndices.length == paths.length;
    final hidden = hiddenWordIndices;
    final passed = passedWordIndices;

    // Pass 1: every non-hidden glyph in its base color.
    canvas.save();
    canvas.translate(offsetX, offsetY);
    canvas.scale(scaleX, scaleY);
    for (int i = 0; i < paths.length; i++) {
      final wIdx = hasWordMap ? pathWordIndices[i] : -1;
      if (hidden != null && hidden.contains(wIdx)) continue;

      ui.Paint p;
      if (passed != null && passed.contains(wIdx) && passedColor != null) {
        p = paintPassed;
      } else if (activeWordIndex != null &&
          wIdx == activeWordIndex &&
          activeWhole &&
          activeColor != null) {
        p = paintActiveFull;
      } else {
        p = paintDefault;
      }
      canvas.drawPath(paths[i], p);
    }
    canvas.restore();

    // Pass 2: sweep-mode glyph overlay — only needed when a glyph tint
    // is requested (activeColor != null). The background sweep was already
    // drawn above.
    if (!activeWhole &&
        ar != null &&
        activeProgress > 0 &&
        activeWordIndex != null &&
        activeColor != null) {
      final fillW = ar.width * activeProgress;
      final clipRect = ui.Rect.fromLTWH(
        ar.right - fillW,
        ar.top,
        fillW,
        ar.height,
      );
      canvas.save();
      canvas.clipRect(clipRect);
      canvas.translate(offsetX, offsetY);
      canvas.scale(scaleX, scaleY);
      for (int i = 0; i < paths.length; i++) {
        if (!hasWordMap) break;
        if (pathWordIndices[i] != activeWordIndex) continue;
        if (hidden != null && hidden.contains(pathWordIndices[i])) continue;
        canvas.drawPath(paths[i], paintActiveFull);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(ArabicOutlinePainter old) =>
      !identical(paths, old.paths) ||
      !identical(pathWordIndices, old.pathWordIndices) ||
      !setEquals(hiddenWordIndices, old.hiddenWordIndices) ||
      !setEquals(passedWordIndices, old.passedWordIndices) ||
      !listEquals(highlights, old.highlights) ||
      !listEquals(passedRects, old.passedRects) ||
      highlightColor != old.highlightColor ||
      color != old.color ||
      passedColor != old.passedColor ||
      passedHighlightColor != old.passedHighlightColor ||
      activeColor != old.activeColor ||
      activeHighlightColor != old.activeHighlightColor ||
      activeWordIndex != old.activeWordIndex ||
      activeRect != old.activeRect ||
      activeProgress != old.activeProgress ||
      activeWhole != old.activeWhole ||
      scaleX != old.scaleX ||
      scaleY != old.scaleY ||
      offsetX != old.offsetX ||
      offsetY != old.offsetY;
}
