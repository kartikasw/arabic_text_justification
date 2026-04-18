import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../ffi/native_api.dart';
import '../models/models.dart';
import 'line_common.dart';
import 'painter.dart';

class JustifiedArabicLine extends StatefulWidget
    implements JustifiedArabicLineConfig {
  @override
  final List<String> words;

  @override
  final bool justify;

  final Color color;

  /// Word indices (into [words]) to render with a highlight background.
  final Set<int>? highlightedWordIndices;

  /// Background color for highlighted words.
  final Color highlightColor;

  @override
  final WordProgress? wordProgress;

  /// Per-character color spans. Each span paints the glyphs that belong
  /// to a character range inside a word. Takes priority over the widget's
  /// default [color] but is overridden by [WordProgress] passed/active
  /// glyph tints when both apply. Useful for tajweed coloring, etc.
  final List<WordColorSpan>? colorSpans;

  /// Text that identifies a word as a marker (e.g. '۝').
  /// When set, taps on a word containing this text fire [onMarkerTap]
  /// instead of [onWordTap].
  @override
  final String? marker;

  /// Called when the user taps a word that does not contain [marker].
  /// Arguments are the tapped word's index into [words] and its text.
  @override
  final void Function(int index, String word)? onWordTap;

  /// Called when the user taps a word that contains [marker].
  /// Arguments are the tapped word's index into [words] and its text.
  @override
  final void Function(int index, String word)? onMarkerTap;

  /// If null, the bundled DigitalKhatt font is loaded automatically.
  @override
  final String? fontPath;

  /// If null, the size is auto-calculated to fill the available width.
  @override
  final double? fontSize;

  /// When set, ignores [fontSize] and auto-fits the line to this height.
  final double? height;

  final EdgeInsetsGeometry? padding;

  /// Alignment of the line within the available width. When null the widget
  /// reports its intrinsic size (tight to content for `justify=false`), so
  /// the caller picks the position via a parent (Row, Column, Align, etc).
  /// Set this when you want the widget itself to fill the width and place
  /// the content at the given alignment (e.g. [Alignment.centerRight]).
  final AlignmentGeometry? alignment;

  const JustifiedArabicLine({
    super.key,
    required this.words,
    this.justify = true,
    this.color = Colors.black,
    this.highlightedWordIndices,
    this.highlightColor = const Color(0x332196F3),
    this.wordProgress,
    this.colorSpans,
    this.marker,
    this.onWordTap,
    this.onMarkerTap,
    this.fontPath,
    this.fontSize,
    this.height,
    this.padding,
    this.alignment,
  });

  @override
  State<JustifiedArabicLine> createState() => _JustifiedArabicLineState();
}

class _PreparedLine {
  final List<ui.Path> paths;
  final List<int> pathWordIndices;
  final List<int> pathByteInWord;
  final List<Rect> wordRects;
  final double minX;
  final double minY;
  final double width;
  final double height;

  const _PreparedLine({
    required this.paths,
    required this.pathWordIndices,
    required this.pathByteInWord,
    required this.wordRects,
    required this.minX,
    required this.minY,
    required this.width,
    required this.height,
  });
}

class _JustifiedArabicLineState extends State<JustifiedArabicLine>
    with JustifiedLineStateMixin<JustifiedArabicLine> {
  _PreparedLine? _prepared;

  _PreparedLine? _spanColorsPrepared;
  List<WordColorSpan>? _spanColorsInput;
  List<Color?>? _spanColorsCache;

  @override
  void didUpdateWidget(JustifiedArabicLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.height != oldWidget.height ||
        widget.padding != oldWidget.padding) {
      renderedWidth = null;
      _prepared = null;
      _invalidateSpanColors();
    }
    handleConfigChange(oldWidget);
  }

  @override
  void resetRender() {
    _prepared = null;
    _invalidateSpanColors();
  }

  void _invalidateSpanColors() {
    _spanColorsPrepared = null;
    _spanColorsInput = null;
    _spanColorsCache = null;
  }

  Future<void> _render(double width) async {
    final fontPath = this.fontPath;
    if (fontPath == null) return;

    final dpr = MediaQuery.devicePixelRatioOf(context);
    final nativeWidth = width * dpr;
    final text = widget.words.join(' ');

    final h = widget.height;
    OutlineResult? outline;
    if (h != null) {
      final insets = widget.padding?.resolve(Directionality.of(context)) ??
          EdgeInsets.zero;
      final nativeHeightBudget = (h - insets.vertical) * dpr;
      outline = await fitToBox<OutlineResult>(
        fontPath: fontPath,
        text: text,
        nativeWidth: nativeWidth,
        nativeHeightBudget: nativeHeightBudget,
        dpr: dpr,
        justify: widget.justify,
        render: (nativeSize) => ArabicTextJustification.getOutline(
          fontPath,
          text,
          nativeSize,
          nativeWidth,
          justify: widget.justify,
        ),
        measure: _envelope,
      );
    } else {
      final nativeSize = resolveFontSize(nativeWidth: nativeWidth, dpr: dpr);
      outline = ArabicTextJustification.getOutline(
        fontPath,
        text,
        nativeSize,
        nativeWidth,
        justify: widget.justify,
      );
    }
    if (outline == null || !mounted) return;

    final prepared = _prepare(outline, widget.words);
    setState(() {
      _prepared = prepared;
      renderedWidth = width;
    });
  }

  static LineMeasurement? _envelope(OutlineResult outline) {
    final ascender = outline.ascender;
    var minX = double.infinity, maxX = double.negativeInfinity;
    var minY = double.infinity, maxY = double.negativeInfinity;
    for (final g in outline.glyphs) {
      for (final cmd in g.commands) {
        final x = g.offsetX + cmd.x;
        final y = ascender - (g.offsetY + cmd.y);
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
        if (cmd.type == PathCommandType.quadTo ||
            cmd.type == PathCommandType.cubicTo) {
          final cx1 = g.offsetX + cmd.x1;
          final cy1 = ascender - (g.offsetY + cmd.y1);
          if (cx1 < minX) minX = cx1;
          if (cx1 > maxX) maxX = cx1;
          if (cy1 < minY) minY = cy1;
          if (cy1 > maxY) maxY = cy1;
        }
        if (cmd.type == PathCommandType.cubicTo) {
          final cx2 = g.offsetX + cmd.x2;
          final cy2 = ascender - (g.offsetY + cmd.y2);
          if (cx2 < minX) minX = cx2;
          if (cx2 > maxX) maxX = cx2;
          if (cy2 < minY) minY = cy2;
          if (cy2 > maxY) maxY = cy2;
        }
      }
    }
    final w = maxX > minX ? maxX - minX : 0.0;
    final h = maxY > minY ? maxY - minY : 0.0;
    if (w <= 0) return null;
    return LineMeasurement(w, h);
  }

  static _PreparedLine _prepare(OutlineResult outline, List<String> words) {
    final wordByteStart = <int>[];
    var cursor = 0;
    for (final w in words) {
      wordByteStart.add(cursor);
      cursor += _utf8ByteLen(w, w.length);
      cursor += 1;
    }

    final ascender = outline.ascender;
    double minX = double.infinity, maxX = double.negativeInfinity;
    double minY = double.infinity, maxY = double.negativeInfinity;
    final paths = <ui.Path>[];
    final pathWordIndices = <int>[];
    final pathByteInWord = <int>[];

    for (final glyph in outline.glyphs) {
      final path = ui.Path();
      for (final cmd in glyph.commands) {
        final x = glyph.offsetX + cmd.x;
        final y = ascender - (glyph.offsetY + cmd.y);
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
        switch (cmd.type) {
          case PathCommandType.moveTo:
            path.moveTo(x, y);
          case PathCommandType.lineTo:
            path.lineTo(x, y);
          case PathCommandType.quadTo:
            final cx = glyph.offsetX + cmd.x1;
            final cy = ascender - (glyph.offsetY + cmd.y1);
            if (cx < minX) minX = cx;
            if (cx > maxX) maxX = cx;
            if (cy < minY) minY = cy;
            if (cy > maxY) maxY = cy;
            path.quadraticBezierTo(cx, cy, x, y);
          case PathCommandType.cubicTo:
            final cx1 = glyph.offsetX + cmd.x1;
            final cy1 = ascender - (glyph.offsetY + cmd.y1);
            final cx2 = glyph.offsetX + cmd.x2;
            final cy2 = ascender - (glyph.offsetY + cmd.y2);
            if (cx1 < minX) minX = cx1;
            if (cx1 > maxX) maxX = cx1;
            if (cy1 < minY) minY = cy1;
            if (cy1 > maxY) maxY = cy1;
            if (cx2 < minX) minX = cx2;
            if (cx2 > maxX) maxX = cx2;
            if (cy2 < minY) minY = cy2;
            if (cy2 > maxY) maxY = cy2;
            path.cubicTo(cx1, cy1, cx2, cy2, x, y);
        }
      }
      path.close();
      paths.add(path);
      pathWordIndices.add(glyph.wordIndex);
      final wordStart =
          glyph.wordIndex >= 0 && glyph.wordIndex < wordByteStart.length
              ? wordByteStart[glyph.wordIndex]
              : 0;
      pathByteInWord.add(glyph.cluster - wordStart);
    }

    final wordRects = [
      for (final w in outline.wordRects)
        Rect.fromLTWH(w.x, w.y, w.width, w.height),
    ];

    if (maxX <= minX || maxY <= minY) {
      return _PreparedLine(
        paths: const [],
        pathWordIndices: const [],
        pathByteInWord: const [],
        wordRects: wordRects,
        minX: 0,
        minY: 0,
        width: 0,
        height: 0,
      );
    }
    return _PreparedLine(
      paths: paths,
      pathWordIndices: pathWordIndices,
      pathByteInWord: pathByteInWord,
      wordRects: wordRects,
      minX: minX,
      minY: minY,
      width: maxX - minX,
      height: maxY - minY,
    );
  }

  double _computeScale(double width, _PreparedLine prepared) {
    if (widget.justify) return width / prepared.width;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final naturalScale = 1 / dpr;
    final fitScale = width / prepared.width;
    return naturalScale < fitScale ? naturalScale : fitScale;
  }

  void _handleTap(Offset localPosition, double offsetX) {
    final prepared = _prepared;
    final width = renderedWidth;
    if (prepared == null || width == null) return;
    if (prepared.paths.isEmpty) return;

    final scale = _computeScale(width, prepared);
    final glyphX = (localPosition.dx - offsetX) / scale;
    final hidden = widget.wordProgress?.hiddenWordIndices;

    for (int i = 0; i < prepared.wordRects.length; i++) {
      if (hidden != null && hidden.contains(i)) continue;
      final r = prepared.wordRects[i];
      if (r.width <= 0) continue;
      if (glyphX >= r.left && glyphX <= r.right) {
        dispatchTap(i);
        return;
      }
    }
  }

  static int _utf8ByteLen(String word, int charCount) {
    var bytes = 0;
    var i = 0;
    while (i < charCount) {
      final cu = word.codeUnitAt(i);
      if (cu < 0x80) {
        bytes += 1;
      } else if (cu < 0x800) {
        bytes += 2;
      } else if (cu < 0xD800 || cu >= 0xE000) {
        bytes += 3;
      } else {
        bytes += 4;
        i++;
      }
      i++;
    }
    return bytes;
  }

  List<Color?>? _buildSpanColors(_PreparedLine prepared) {
    final spans = widget.colorSpans;
    if (identical(prepared, _spanColorsPrepared) &&
        identical(spans, _spanColorsInput)) {
      return _spanColorsCache;
    }
    _spanColorsPrepared = prepared;
    _spanColorsInput = spans;
    _spanColorsCache = _computeSpanColors(prepared, spans);
    return _spanColorsCache;
  }

  List<Color?>? _computeSpanColors(
    _PreparedLine prepared,
    List<WordColorSpan>? spans,
  ) {
    if (spans == null || spans.isEmpty || prepared.paths.isEmpty) return null;

    final byWord = <int, List<({int start, int end, Color color})>>{};
    for (final s in spans) {
      if (s.wordIndex < 0 || s.wordIndex >= widget.words.length) continue;
      final word = widget.words[s.wordIndex];
      final startClamped = s.start.clamp(0, word.length);
      final endClamped = s.end.clamp(startClamped, word.length);
      if (endClamped <= startClamped) continue;
      final startByte = _utf8ByteLen(word, startClamped);
      final endByte = _utf8ByteLen(word, endClamped);
      byWord
          .putIfAbsent(s.wordIndex, () => [])
          .add((start: startByte, end: endByte, color: s.color));
    }
    if (byWord.isEmpty) return null;

    final out = List<Color?>.filled(prepared.paths.length, null);
    var any = false;
    for (var i = 0; i < prepared.paths.length; i++) {
      final wIdx = prepared.pathWordIndices[i];
      final bucket = byWord[wIdx];
      if (bucket == null) continue;
      final byteInWord = prepared.pathByteInWord[i];
      for (final s in bucket) {
        if (byteInWord >= s.start && byteInWord < s.end) {
          out[i] = s.color;
          any = true;
          break;
        }
      }
    }
    return any ? out : null;
  }

  @override
  Widget build(BuildContext context) {
    if (fontPath == null) {
      return const SizedBox.shrink();
    }

    final insets =
        widget.padding?.resolve(Directionality.of(context)) ?? EdgeInsets.zero;

    return LayoutBuilder(
      builder: (context, constraints) {
        final outerWidth = constraints.maxWidth;
        final contentWidth = (outerWidth - insets.horizontal).clamp(
          0.0,
          double.infinity,
        );

        if (_prepared == null || renderedWidth != contentWidth) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _render(contentWidth);
          });
          if (_prepared == null) return const SizedBox.shrink();
        }

        final prepared = _prepared!;
        if (prepared.paths.isEmpty) return const SizedBox.shrink();

        final scale = _computeScale(contentWidth, prepared);
        final glyphW = widget.justify ? contentWidth : prepared.width * scale;
        final glyphH = prepared.height * scale;

        final widgetWidth =
            widget.justify ? outerWidth : glyphW + insets.horizontal;
        final widgetHeight = glyphH + insets.vertical;

        final offsetX = insets.left - prepared.minX * scale;
        final offsetY = insets.top - prepared.minY * scale;

        final hidden = widget.wordProgress?.hiddenWordIndices;

        final fullHeight = DisplayTransform(
          scale: scale,
          offsetX: offsetX,
          top: 0,
          height: widgetHeight,
          excluding: hidden,
        );

        final highlights = fullHeight.mapAll(
          widget.highlightedWordIndices ?? const <int>{},
          prepared.wordRects,
        );

        final progress = widget.wordProgress;
        var passedRects = const <Rect>[];
        Rect? activeRect;
        double activeProgress = 0;
        int? activeIdx;
        bool activeWhole = false;
        Set<int>? passedIndices;
        Color? passedColor;
        Color? passedHighlightColor;
        Color? activeColor;
        Color? activeHighlightColor;

        if (progress != null) {
          passedColor = progress.passedColor;
          passedHighlightColor = progress.passedHighlightColor;
          activeColor = progress.activeColor;
          activeHighlightColor = progress.activeHighlightColor;
          passedIndices = progress.passedWordIndices;
          final active = activeState;
          activeWhole = active.whole;
          activeProgress = active.progress;

          if (passedIndices != null && passedHighlightColor != null) {
            passedRects = fullHeight.mapAll(passedIndices, prepared.wordRects);
          }

          final ai = progress.activeWordIndex;
          if (ai != null) {
            final rect = fullHeight.mapSingle(ai, prepared.wordRects);
            if (rect != null) {
              activeIdx = ai;
              activeRect = rect;
            }
          }
        }

        final pathColors = _buildSpanColors(prepared);

        Widget child = CustomPaint(
          size: Size(widgetWidth, widgetHeight),
          painter: ArabicOutlinePainter(
            paths: prepared.paths,
            pathWordIndices: prepared.pathWordIndices,
            pathSpanColors: pathColors,
            hiddenWordIndices: hidden,
            highlights: highlights,
            highlightColor: widget.highlightColor,
            color: widget.color,
            passedWordIndices: passedIndices,
            passedRects: passedRects,
            passedHighlightColor: passedHighlightColor,
            passedColor: passedColor,
            activeWordIndex: activeIdx,
            activeRect: activeRect,
            activeProgress: activeProgress,
            activeHighlightColor: activeHighlightColor,
            activeColor: activeColor,
            activeWhole: activeWhole,
            scaleX: scale,
            scaleY: scale,
            offsetX: offsetX,
            offsetY: offsetY,
          ),
        );

        if (widget.onWordTap != null || widget.onMarkerTap != null) {
          child = GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) => _handleTap(details.localPosition, offsetX),
            child: child,
          );
        }

        final boundary = RepaintBoundary(child: child);
        return widget.alignment == null
            ? boundary
            : Align(alignment: widget.alignment!, child: boundary);
      },
    );
  }
}
