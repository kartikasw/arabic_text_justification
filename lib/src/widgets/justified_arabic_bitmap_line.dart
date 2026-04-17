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

  /// Outer padding around the line. Useful for vertical spacing between
  /// consecutive lines, e.g. `EdgeInsets.symmetric(vertical: 4)`.
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

    for (int i = 0; i < result.wordRects.length; i++) {
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

        final highlights = <Rect>[];
        final indices = widget.highlightedWordIndices;
        if (indices != null) {
          for (final i in indices) {
            if (i < 0 || i >= result.wordRects.length) continue;
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
              if (i < 0 || i >= result.wordRects.length) continue;
              final r = result.wordRects[i];
              if (r.width <= 0) continue;
              passedRects.add(Rect.fromLTWH(
                imageLeft + r.x * sx,
                0,
                r.width * sx,
                widgetHeight,
              ));
            }
          }

          final activeIdx = progress.activeWordIndex;
          if (activeIdx != null &&
              activeIdx >= 0 &&
              activeIdx < result.wordRects.length) {
            final r = result.wordRects[activeIdx];
            if (r.width > 0) {
              activeRect = Rect.fromLTWH(
                imageLeft + r.x * sx,
                0,
                r.width * sx,
                widgetHeight,
              );
            }
          }
        }

        final hasOverlay = highlights.isNotEmpty ||
            passedRects.isNotEmpty ||
            (activeRect != null && activeProgress > 0);

        Widget content = Stack(
          children: [
            if (hasOverlay)
              Positioned.fill(
                child: CustomPaint(
                  painter: _HighlightPainter(
                    rects: highlights,
                    color: widget.highlightColor,
                    passedRects: passedRects,
                    passedColor: passedColor,
                    activeRect: activeRect,
                    activeProgress: activeProgress,
                    activeColor: activeColor,
                  ),
                ),
              ),
            Positioned(
              left: imageLeft,
              top: imageTop,
              width: displayWidth,
              height: displayHeight,
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(
                  widget.color,
                  BlendMode.srcIn,
                ),
                child: RawImage(
                  image: result.image,
                  fit: BoxFit.fill,
                  width: displayWidth,
                  height: displayHeight,
                ),
              ),
            ),
          ],
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

class _HighlightPainter extends CustomPainter {
  final List<Rect> rects;
  final Color color;
  final List<Rect> passedRects;
  final Color passedColor;
  final Rect? activeRect;
  final double activeProgress;
  final Color activeColor;

  _HighlightPainter({
    required this.rects,
    required this.color,
    this.passedRects = const [],
    this.passedColor = const Color(0x00000000),
    this.activeRect,
    this.activeProgress = 0,
    this.activeColor = const Color(0x00000000),
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (rects.isNotEmpty) {
      final paint = Paint()..color = color;
      for (final r in rects) {
        canvas.drawRect(r, paint);
      }
    }

    if (passedRects.isNotEmpty) {
      final paint = Paint()..color = passedColor;
      for (final r in passedRects) {
        canvas.drawRect(r, paint);
      }
    }

    final ar = activeRect;
    if (ar != null && activeProgress > 0) {
      final fillW = ar.width * activeProgress;
      canvas.drawRect(
        Rect.fromLTWH(ar.right - fillW, ar.top, fillW, ar.height),
        Paint()..color = activeColor,
      );
    }
  }

  @override
  bool shouldRepaint(_HighlightPainter old) {
    if (color != old.color ||
        passedColor != old.passedColor ||
        activeColor != old.activeColor ||
        activeRect != old.activeRect ||
        activeProgress != old.activeProgress) {
      return true;
    }
    if (!_eq(rects, old.rects)) return true;
    if (!_eq(passedRects, old.passedRects)) return true;
    return false;
  }

  static bool _eq(List<Rect> a, List<Rect> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
