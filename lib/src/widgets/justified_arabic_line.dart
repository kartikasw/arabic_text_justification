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

  final WordProgress? wordProgress;

  /// Substring that identifies a word as a verse marker (e.g. '۝').
  /// When set, taps on a word containing this substring fire [onMarkerTap]
  /// instead of [onWordTap].
  @override
  final String? verseMarker;

  /// Called when the user taps a word that does not contain [verseMarker].
  /// Arguments are the tapped word's index into [words] and its text.
  @override
  final void Function(int index, String word)? onWordTap;

  /// Called when the user taps a word that contains [verseMarker].
  /// Arguments are the tapped word's index into [words] and its text.
  @override
  final void Function(int index, String word)? onMarkerTap;

  /// If null, the bundled DigitalKhatt font is loaded automatically.
  @override
  final String? fontPath;

  /// If null, the size is auto-calculated to fill the available width.
  @override
  final double? fontSize;

  /// Outer padding around the line. Useful for vertical spacing between
  /// consecutive lines, e.g. `EdgeInsets.symmetric(vertical: 4)`.
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
    this.verseMarker,
    this.onWordTap,
    this.onMarkerTap,
    this.fontPath,
    this.fontSize,
    this.padding,
    this.alignment,
  });

  @override
  State<JustifiedArabicLine> createState() => _JustifiedArabicLineState();
}

class _PreparedLine {
  final List<ui.Path> paths;
  final List<Rect> wordRects;
  final double minX;
  final double minY;
  final double width;
  final double height;

  const _PreparedLine({
    required this.paths,
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

  @override
  void didUpdateWidget(JustifiedArabicLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    handleConfigChange(oldWidget);
  }

  @override
  void resetRender() => _prepared = null;

  void _render(double width) {
    final fontPath = this.fontPath;
    if (fontPath == null) return;

    final dpr = MediaQuery.devicePixelRatioOf(context);
    final nativeWidth = width * dpr;
    final text = widget.words.join(' ');

    final fontSize = resolveFontSize(nativeWidth: nativeWidth, dpr: dpr);

    final outline = ArabicTextJustification.getOutline(
      fontPath,
      text,
      fontSize,
      nativeWidth,
      justify: widget.justify,
    );
    if (outline == null) return;

    final prepared = _prepare(outline);
    setState(() {
      _prepared = prepared;
      renderedWidth = width;
    });
  }

  static _PreparedLine _prepare(OutlineResult outline) {
    final ascender = outline.ascender;
    double minX = double.infinity, maxX = double.negativeInfinity;
    double minY = double.infinity, maxY = double.negativeInfinity;
    final paths = <ui.Path>[];

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
    }

    final wordRects = [
      for (final w in outline.wordRects)
        Rect.fromLTWH(w.x, w.y, w.width, w.height),
    ];

    if (maxX <= minX || maxY <= minY) {
      return _PreparedLine(
        paths: const [],
        wordRects: wordRects,
        minX: 0,
        minY: 0,
        width: 0,
        height: 0,
      );
    }
    return _PreparedLine(
      paths: paths,
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

    for (int i = 0; i < prepared.wordRects.length; i++) {
      final r = prepared.wordRects[i];
      if (r.width <= 0) continue;
      if (glyphX >= r.left && glyphX <= r.right) {
        dispatchTap(i);
        return;
      }
    }
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

        final highlights = <Rect>[];
        final indices = widget.highlightedWordIndices;
        if (indices != null) {
          for (final i in indices) {
            if (i < 0 || i >= prepared.wordRects.length) continue;
            final r = prepared.wordRects[i];
            if (r.width <= 0) continue;
            highlights.add(Rect.fromLTWH(
              offsetX + scale * r.left,
              0,
              scale * r.width,
              widgetHeight,
            ));
          }
        }

        final progress = widget.wordProgress;
        final passedRects = <Rect>[];
        Rect? activeRect;
        double activeProgress = 0;
        Color passedColor = const Color(0x00000000);
        Color activeColor = const Color(0x00000000);

        if (progress != null) {
          passedColor = progress.passedColor;
          activeColor = progress.activeColor;
          activeProgress = switch (progress.style) {
            WordProgressStyle.whole =>
              progress.activeWordIndex != null ? 1.0 : 0.0,
            WordProgressStyle.sweep => progress.activeProgress.clamp(0.0, 1.0),
          };

          final passed = progress.passedWordIndices;
          if (passed != null) {
            for (final i in passed) {
              if (i < 0 || i >= prepared.wordRects.length) continue;
              final r = prepared.wordRects[i];
              if (r.width <= 0) continue;
              passedRects.add(Rect.fromLTWH(
                offsetX + scale * r.left,
                0,
                scale * r.width,
                widgetHeight,
              ));
            }
          }

          final activeIdx = progress.activeWordIndex;
          if (activeIdx != null &&
              activeIdx >= 0 &&
              activeIdx < prepared.wordRects.length) {
            final r = prepared.wordRects[activeIdx];
            if (r.width > 0) {
              activeRect = Rect.fromLTWH(
                offsetX + scale * r.left,
                0,
                scale * r.width,
                widgetHeight,
              );
            }
          }
        }

        Widget child = CustomPaint(
          size: Size(widgetWidth, widgetHeight),
          painter: ArabicOutlinePainter(
            paths: prepared.paths,
            highlights: highlights,
            passedRects: passedRects,
            activeRect: activeRect,
            activeProgress: activeProgress,
            color: widget.color,
            highlightColor: widget.highlightColor,
            passedColor: passedColor,
            activeColor: activeColor,
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
