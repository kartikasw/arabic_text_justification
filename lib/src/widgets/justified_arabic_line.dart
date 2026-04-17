import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../ffi/native_api.dart';
import '../bundled_fonts.dart';
import '../models/models.dart';
import 'painter.dart';

class JustifiedArabicLine extends StatefulWidget {
  final List<String> words;

  final bool justify;

  final Color color;

  /// If null, the bundled DigitalKhatt font is loaded automatically.
  final String? fontPath;

  /// If null, the size is auto-calculated to fill the available width.
  final double? fontSize;

  const JustifiedArabicLine({
    super.key,
    required this.words,
    this.justify = true,
    this.color = Colors.black,
    this.fontPath,
    this.fontSize,
  });

  @override
  State<JustifiedArabicLine> createState() => _JustifiedArabicLineState();
}

class _PreparedLine {
  final List<ui.Path> paths;
  final double minX;
  final double minY;
  final double width;
  final double height;

  const _PreparedLine({
    required this.paths,
    required this.minX,
    required this.minY,
    required this.width,
    required this.height,
  });
}

class _JustifiedArabicLineState extends State<JustifiedArabicLine> {
  String? _fontPath;
  _PreparedLine? _prepared;
  double? _renderedWidth;

  @override
  void initState() {
    super.initState();
    if (widget.fontPath != null) {
      _fontPath = widget.fontPath;
    } else {
      _loadFont();
    }
  }

  @override
  void didUpdateWidget(JustifiedArabicLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.fontPath != oldWidget.fontPath) {
      _fontPath = widget.fontPath;
      _prepared = null;
      _renderedWidth = null;
      if (_fontPath == null) _loadFont();
    }
    if (widget.words != oldWidget.words ||
        widget.justify != oldWidget.justify ||
        widget.fontSize != oldWidget.fontSize) {
      _prepared = null;
      _renderedWidth = null;
    }
  }

  Future<void> _loadFont() async {
    final path = await JustificationFont.digitalKhatt.load();
    if (mounted) setState(() => _fontPath = path);
  }

  void _render(double width) {
    final fontPath = _fontPath;
    if (fontPath == null) return;

    final dpr = MediaQuery.of(context).devicePixelRatio;
    final nativeWidth = width * dpr;
    final text = widget.words.join(' ');

    final double fontSize;
    if (widget.fontSize != null) {
      fontSize = widget.fontSize! * dpr;
    } else {
      fontSize = ArabicTextJustification.fontSizeForWidth(
        fontPath,
        text,
        nativeWidth,
      );
    }

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
      _renderedWidth = width;
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

    if (maxX <= minX || maxY <= minY) {
      return const _PreparedLine(
        paths: [], minX: 0, minY: 0, width: 0, height: 0,
      );
    }
    return _PreparedLine(
      paths: paths,
      minX: minX,
      minY: minY,
      width: maxX - minX,
      height: maxY - minY,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_fontPath == null) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        if (_prepared == null || _renderedWidth != width) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _render(width);
          });
          if (_prepared == null) return const SizedBox.shrink();
        }

        final prepared = _prepared!;
        if (prepared.paths.isEmpty) return const SizedBox.shrink();

        final dpr = MediaQuery.of(context).devicePixelRatio;

        final double scale;
        final double displayWidth;
        if (widget.justify) {
          scale = width / prepared.width;
          displayWidth = width;
        } else {
          final naturalScale = 1 / dpr;
          final fitScale = width / prepared.width;
          scale = naturalScale < fitScale ? naturalScale : fitScale;
          displayWidth = prepared.width * scale;
        }
        final displayHeight = prepared.height * scale;

        final offsetX = -prepared.minX * scale;
        final offsetY = -prepared.minY * scale;

        return Align(
          alignment: Alignment.centerRight,
          child: RepaintBoundary(
            child: CustomPaint(
              size: Size(displayWidth, displayHeight),
              painter: ArabicOutlinePainter(
                paths: prepared.paths,
                color: widget.color,
                scaleX: scale,
                scaleY: scale,
                offsetX: offsetX,
                offsetY: offsetY,
              ),
            ),
          ),
        );
      },
    );
  }
}
