import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../ffi/native_api.dart';
import '../models/models.dart';
import 'line_common.dart';

class JustifiedArabicBitmapLine extends StatefulWidget
    implements JustifiedArabicLineConfig {
  @override
  final List<String> words;

  @override
  final bool justify;

  final Color color;

  final Set<int>? highlightedWordIndices;

  final Color highlightColor;

  @override
  final WordProgress? wordProgress;

  /// Substring that identifies a word as a verse marker (e.g. '۝').
  /// When set, taps on a word containing this substring fire [onMarkerTap]
  /// instead of [onWordTap].
  @override
  final String? verseMarker;

  @override
  final void Function(int index, String word)? onWordTap;

  @override
  final void Function(int index, String word)? onMarkerTap;

  /// If null, the bundled DigitalKhatt font is loaded automatically.
  @override
  final String? fontPath;

  /// If null, the size is auto-calculated to fill the available width.
  @override
  final double? fontSize;

  final EdgeInsetsGeometry? padding;

  /// Alignment of the line within the available width. When null the widget
  /// reports its intrinsic size (tight to content for `justify=false`), so
  /// the caller picks the position via a parent (Row, Column, Align, etc).
  /// Set this when you want the widget itself to fill the width and place
  /// the content at the given alignment (e.g. [Alignment.centerRight]).
  final AlignmentGeometry? alignment;

  const JustifiedArabicBitmapLine({
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
  State<JustifiedArabicBitmapLine> createState() =>
      _JustifiedArabicBitmapLineState();
}

class _JustifiedArabicBitmapLineState extends State<JustifiedArabicBitmapLine>
    with JustifiedLineStateMixin<JustifiedArabicBitmapLine> {
  RenderResult? _result;

  @override
  void didUpdateWidget(JustifiedArabicBitmapLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    handleConfigChange(oldWidget);
  }

  @override
  void resetRender() => _result = null;

  Future<void> _render(double width) async {
    final fontPath = this.fontPath;
    if (fontPath == null) return;

    final dpr = MediaQuery.devicePixelRatioOf(context);
    final nativeWidth = width * dpr;
    final text = widget.words.join(' ');

    final fontSize = resolveFontSize(nativeWidth: nativeWidth, dpr: dpr);

    final result = await ArabicTextJustification.renderLine(
      fontPath,
      text,
      fontSize,
      nativeWidth,
      justify: widget.justify,
    );
    if (result == null || !mounted) return;

    setState(() {
      _result = result;
      renderedWidth = width;
    });
  }

  void _handleTap(
    Offset localPosition,
    RenderResult result,
    double imageLeft,
    double displayWidth,
  ) {
    if (displayWidth <= 0) return;

    final sx = result.bmpWidth / displayWidth;
    final nativeX = (localPosition.dx - imageLeft) * sx;
    final hidden = widget.wordProgress?.hiddenWordIndices;

    for (int i = 0; i < result.wordRects.length; i++) {
      if (hidden != null && hidden.contains(i)) continue;
      final r = result.wordRects[i];
      if (r.width <= 0) continue;
      if (nativeX >= r.x && nativeX <= r.x + r.width) {
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

        if (_result == null || renderedWidth != contentWidth) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _render(contentWidth);
          });
          if (_result == null) return const SizedBox.shrink();
        }

        final result = _result!;

        final double displayWidth;
        final double displayHeight;
        if (widget.justify) {
          final scale = contentWidth / result.bmpWidth;
          displayWidth = contentWidth;
          displayHeight = result.bmpHeight * scale;
        } else {
          final dpr = MediaQuery.devicePixelRatioOf(context);
          final naturalScale = 1 / dpr;
          final fitScale = contentWidth / result.bmpWidth;
          final scale = naturalScale < fitScale ? naturalScale : fitScale;
          displayWidth = result.bmpWidth * scale;
          displayHeight = result.bmpHeight * scale;
        }

        final widgetWidth =
            widget.justify ? outerWidth : displayWidth + insets.horizontal;
        final widgetHeight = displayHeight + insets.vertical;
        final imageLeft = insets.left;
        final imageTop = insets.top;

        final sx = displayWidth / result.bmpWidth;

        final hidden = widget.wordProgress?.hiddenWordIndices;

        final hiddenRects = <Rect>[];
        if (hidden != null && hidden.isNotEmpty) {
          for (final i in hidden) {
            if (i < 0 || i >= result.wordRects.length) continue;
            final r = result.wordRects[i];
            if (r.width <= 0) continue;
            hiddenRects.add(Rect.fromLTWH(
              imageLeft + r.x * sx,
              imageTop,
              r.width * sx,
              displayHeight,
            ));
          }
        }

        final highlights = <Rect>[];
        final indices = widget.highlightedWordIndices;
        if (indices != null) {
          for (final i in indices) {
            if (i < 0 || i >= result.wordRects.length) continue;
            if (hidden != null && hidden.contains(i)) continue;
            final r = result.wordRects[i];
            if (r.width <= 0) continue;
            highlights.add(Rect.fromLTWH(
              imageLeft + r.x * sx,
              0,
              r.width * sx,
              widgetHeight,
            ));
          }
        }

        final progress = widget.wordProgress;
        final passedRects = <Rect>[];
        Rect? activeRect;
        double activeProgress = 0;
        bool activeWhole = false;
        Color? passedColor;
        Color? passedHighlightColor;
        Color? activeColor;
        Color? activeHighlightColor;

        if (progress != null) {
          passedColor = progress.passedColor;
          passedHighlightColor = progress.passedHighlightColor;
          activeColor = progress.activeColor;
          activeHighlightColor = progress.activeHighlightColor;
          final active = activeState;
          activeWhole = active.whole;
          activeProgress = active.progress;

          final passed = progress.passedWordIndices;
          if (passed != null &&
              (passedHighlightColor != null || passedColor != null)) {
            for (final i in passed) {
              if (i < 0 || i >= result.wordRects.length) continue;
              if (hidden != null && hidden.contains(i)) continue;
              final r = result.wordRects[i];
              if (r.width <= 0) continue;
              passedRects.add(Rect.fromLTWH(
                imageLeft + r.x * sx,
                imageTop,
                r.width * sx,
                displayHeight,
              ));
            }
          }

          final activeIdx = progress.activeWordIndex;
          if (activeIdx != null &&
              activeIdx >= 0 &&
              activeIdx < result.wordRects.length &&
              !(hidden?.contains(activeIdx) ?? false)) {
            final r = result.wordRects[activeIdx];
            if (r.width > 0) {
              activeRect = Rect.fromLTWH(
                imageLeft + r.x * sx,
                imageTop,
                r.width * sx,
                displayHeight,
              );
            }
          }
        }

        final imageDst = Rect.fromLTWH(
          imageLeft,
          imageTop,
          displayWidth,
          displayHeight,
        );

        Widget content = CustomPaint(
          painter: _BitmapWordPainter(
            image: result.image,
            imageDst: imageDst,
            color: widget.color,
            highlights: highlights,
            highlightColor: widget.highlightColor,
            passedRects: passedRects,
            passedHighlightColor: passedHighlightColor,
            passedColor: passedColor,
            activeRect: activeRect,
            activeProgress: activeProgress,
            activeWhole: activeWhole,
            activeHighlightColor: activeHighlightColor,
            activeColor: activeColor,
            hiddenRects: hiddenRects,
          ),
        );

        if (widget.onWordTap != null || widget.onMarkerTap != null) {
          content = GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) => _handleTap(
              details.localPosition,
              result,
              imageLeft,
              displayWidth,
            ),
            child: content,
          );
        }

        final boundary = RepaintBoundary(
          child: SizedBox(
            width: widgetWidth,
            height: widgetHeight,
            child: content,
          ),
        );
        return widget.alignment == null
            ? boundary
            : Align(alignment: widget.alignment!, child: boundary);
      },
    );
  }
}

class _BitmapWordPainter extends CustomPainter {
  final ui.Image image;
  final Rect imageDst;
  final Color color;

  final List<Rect> highlights;
  final Color highlightColor;

  final List<Rect> passedRects;
  final Color? passedHighlightColor;
  final Color? passedColor;

  final Rect? activeRect;
  final double activeProgress;
  final bool activeWhole;
  final Color? activeHighlightColor;
  final Color? activeColor;

  final List<Rect> hiddenRects;

  _BitmapWordPainter({
    required this.image,
    required this.imageDst,
    required this.color,
    this.highlights = const [],
    this.highlightColor = const Color(0x00000000),
    this.passedRects = const [],
    this.passedHighlightColor,
    this.passedColor,
    this.activeRect,
    this.activeProgress = 0,
    this.activeWhole = false,
    this.activeHighlightColor,
    this.activeColor,
    this.hiddenRects = const [],
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (highlights.isNotEmpty) {
      final p = Paint()..color = highlightColor;
      for (final r in highlights) {
        canvas.drawRect(r, p);
      }
    }

    if (passedHighlightColor != null && passedRects.isNotEmpty) {
      final p = Paint()..color = passedHighlightColor!;
      for (final r in passedRects) {
        canvas.drawRect(r, p);
      }
    }

    final ar = activeRect;
    if (activeHighlightColor != null && ar != null) {
      if (activeWhole) {
        canvas.drawRect(ar, Paint()..color = activeHighlightColor!);
      } else if (activeProgress > 0) {
        final fillW = ar.width * activeProgress;
        canvas.drawRect(
          Rect.fromLTWH(ar.right - fillW, ar.top, fillW, ar.height),
          Paint()..color = activeHighlightColor!,
        );
      }
    }

    canvas.save();
    if (hiddenRects.isNotEmpty) {
      final path = Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
      for (final r in hiddenRects) {
        path.addRect(r);
      }
      canvas.clipPath(path);
    }

    final src = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );

    canvas.drawImageRect(
      image,
      src,
      imageDst,
      Paint()..colorFilter = ColorFilter.mode(color, BlendMode.srcIn),
    );

    if (passedColor != null && passedRects.isNotEmpty) {
      final clip = Path();
      for (final r in passedRects) {
        clip.addRect(r);
      }
      canvas.save();
      canvas.clipPath(clip);
      canvas.drawImageRect(
        image,
        src,
        imageDst,
        Paint()..colorFilter = ColorFilter.mode(passedColor!, BlendMode.srcIn),
      );
      canvas.restore();
    }

    if (activeColor != null && ar != null && activeProgress > 0) {
      final clip = activeWhole
          ? ar
          : Rect.fromLTWH(
              ar.right - ar.width * activeProgress,
              ar.top,
              ar.width * activeProgress,
              ar.height,
            );
      canvas.save();
      canvas.clipRect(clip);
      canvas.drawImageRect(
        image,
        src,
        imageDst,
        Paint()..colorFilter = ColorFilter.mode(activeColor!, BlendMode.srcIn),
      );
      canvas.restore();
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_BitmapWordPainter old) =>
      image != old.image ||
      imageDst != old.imageDst ||
      color != old.color ||
      highlightColor != old.highlightColor ||
      passedHighlightColor != old.passedHighlightColor ||
      passedColor != old.passedColor ||
      activeHighlightColor != old.activeHighlightColor ||
      activeColor != old.activeColor ||
      activeRect != old.activeRect ||
      activeProgress != old.activeProgress ||
      activeWhole != old.activeWhole ||
      !listEquals(highlights, old.highlights) ||
      !listEquals(passedRects, old.passedRects) ||
      !listEquals(hiddenRects, old.hiddenRects);
}
