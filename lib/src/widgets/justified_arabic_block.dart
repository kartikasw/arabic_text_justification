import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../bundled_fonts.dart';
import '../ffi/native_api.dart';
import '../models/models.dart';
import 'justified_arabic_line.dart';

typedef BlockWordTap = void Function(
    int lineIndex, int wordIndex, String word);

/// Per-line configuration for [JustifiedArabicBlock]. Mirrors the subset
/// of [JustifiedArabicLine] props that are line-specific. Block-level
/// settings (marker, tap callbacks, font path, padding, spacing, font size)
/// are shared across every line.
class JustifiedArabicLineSpec {
  final List<String> words;

  /// When null, inherits from the block's [JustifiedArabicBlock.justify].
  final bool? justify;

  /// When null, inherits from the block's [JustifiedArabicBlock.color].
  final Color? color;

  final Set<int>? highlightedWordIndices;

  /// When null, inherits from the block's
  /// [JustifiedArabicBlock.highlightColor].
  final Color? highlightColor;

  final List<WordColorSpan>? colorSpans;

  final WordProgress? wordProgress;

  /// Alignment of a non-justified line within the block width. Honored only
  /// when the effective [justify] is false.
  final AlignmentGeometry? alignment;

  const JustifiedArabicLineSpec({
    required this.words,
    this.justify,
    this.color,
    this.highlightedWordIndices,
    this.highlightColor,
    this.colorSpans,
    this.wordProgress,
    this.alignment,
  });
}

/// Multi-line justified Arabic block.
///
/// The block picks one shared font size across all lines so every row has
/// the same height, even when word content differs. Each line is then
/// rendered independently with its own [JustifiedArabicLineSpec] —
/// justify on/off, highlights, color spans, word progress, per-line color
/// and alignment are all configurable per line.
///
/// Lines are pre-split by the caller. The standard mushaf layout already
/// assigns specific words to specific lines (so every printed copy matches
/// page-for-page); this widget preserves that control instead of running a
/// line-break algorithm.
class JustifiedArabicBlock extends StatefulWidget {
  /// One spec per rendered row.
  final List<JustifiedArabicLineSpec> lines;

  /// Default justify value for specs that don't override it.
  final bool justify;

  /// Default color for specs that don't override it.
  final Color color;

  /// Default highlight background for specs that don't override it.
  final Color highlightColor;

  /// Shared font size across all lines. When null, the block auto-fits:
  /// picks the size at which the *widest* natural line fills the available
  /// width; shorter lines get kashida-stretched (or rendered at their
  /// natural width if their spec has [JustifiedArabicLineSpec.justify]
  /// false).
  final double? fontSize;

  /// Vertical gap between adjacent lines.
  final double lineSpacing;

  final EdgeInsetsGeometry? padding;

  final String? fontPath;

  /// Text that identifies a word as a marker (e.g. '۝'). Routed to
  /// [onMarkerTap] when tapped, otherwise to [onWordTap].
  final String? marker;

  final BlockWordTap? onWordTap;

  final BlockWordTap? onMarkerTap;

  const JustifiedArabicBlock({
    super.key,
    required this.lines,
    this.justify = true,
    this.color = Colors.black,
    this.highlightColor = const Color(0x332196F3),
    this.fontSize,
    this.lineSpacing = 0,
    this.padding,
    this.fontPath,
    this.marker,
    this.onWordTap,
    this.onMarkerTap,
  });

  @override
  State<JustifiedArabicBlock> createState() => _JustifiedArabicBlockState();
}

class _JustifiedArabicBlockState extends State<JustifiedArabicBlock> {
  String? _fontPath;
  double? _resolvedDisplaySize;
  double? _resolvedForWidth;
  double? _resolvedForHeight;

  // Cached per-line tap adapters. Allocated once per (onWordTap,
  // onMarkerTap, lines.length) change so we don't churn closures on every
  // rebuild (e.g. ValueListenableBuilder ticks during playback).
  List<void Function(int, String)?>? _wordTapAdapters;
  List<void Function(int, String)?>? _markerTapAdapters;

  @override
  void initState() {
    super.initState();
    final fp = widget.fontPath;
    if (fp != null) {
      _fontPath = fp;
    } else {
      _loadBundledFont();
    }
  }

  @override
  void didUpdateWidget(JustifiedArabicBlock oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.fontPath != oldWidget.fontPath) {
      _fontPath = widget.fontPath;
      _invalidateSize();
      if (_fontPath == null) _loadBundledFont();
    }

    // Only *word content* and the explicit fontSize affect calibration.
    // Per-line style changes (color, highlights, justify, spans, progress)
    // rebuild the children automatically without re-running calibration.
    if (widget.fontSize != oldWidget.fontSize ||
        _wordsChanged(widget.lines, oldWidget.lines)) {
      _invalidateSize();
    }

    if (widget.onWordTap != oldWidget.onWordTap ||
        widget.onMarkerTap != oldWidget.onMarkerTap ||
        widget.lines.length != oldWidget.lines.length) {
      _wordTapAdapters = null;
      _markerTapAdapters = null;
    }
  }

  void _invalidateSize() {
    _resolvedDisplaySize = null;
    _resolvedForWidth = null;
    _resolvedForHeight = null;
  }

  static bool _wordsChanged(
      List<JustifiedArabicLineSpec> a, List<JustifiedArabicLineSpec> b) {
    if (a.length != b.length) return true;
    for (var i = 0; i < a.length; i++) {
      if (!listEquals(a[i].words, b[i].words)) return true;
    }
    return false;
  }

  Future<void> _loadBundledFont() async {
    final path = await JustificationFont.digitalKhatt.load();
    if (mounted) setState(() => _fontPath = path);
  }

  double? _computeSharedDisplaySize(
    double contentWidth,
    double contentHeight,
  ) {
    final explicit = widget.fontSize;
    if (explicit != null) return explicit;

    final fp = _fontPath;
    if (fp == null) return null;
    if (widget.lines.isEmpty) return null;

    final dpr = MediaQuery.devicePixelRatioOf(context);
    final nativeWidth = contentWidth * dpr;
    if (nativeWidth <= 0) return null;

    // Prefer height-based sizing when the slot has a bounded height:
    // row height is a pure function of fontSize and font metrics, so
    // every block with the same line count + height renders at the
    // exact same size. That's what makes PageView-of-blocks match
    // visually without any cross-block calibration.
    //
    // Width is handled per line by kashida. If a line's natural width
    // exceeds the slot at the chosen size, that's a content density
    // problem (tell the layout designer), not a sizing decision.
    if (contentHeight.isFinite && contentHeight > 0) {
      const refSize = 100.0;
      final refText = widget.lines.first.words.join(' ');
      final refOutline = ArabicTextJustification.getOutline(
        fp,
        refText,
        refSize,
        nativeWidth,
        justify: false,
      );
      if (refOutline != null) {
        final metricRef = refOutline.ascender - refOutline.descender;
        if (metricRef > 0) {
          final n = widget.lines.length;
          final nativeHeight = contentHeight * dpr;
          final nativeSpacing = widget.lineSpacing * dpr;
          // Reserve one display pixel per row as a safety buffer.
          // Subpixel rounding accumulates across N per-line heights and
          // can push a mathematically-exact fit a few pixels over the
          // slot; the buffer absorbs that without visibly changing
          // layout (1 px × dpr per row in native space).
          final safetyNative = n * dpr;
          final availForGlyphs =
              nativeHeight - (n - 1) * nativeSpacing - safetyNative;
          if (availForGlyphs > 0) {
            // metricRef scales linearly with fontSize, so size fitting
            // height is (available / N) / (metricRef / refSize).
            final heightNative =
                (availForGlyphs / n) * (refSize / metricRef);
            return heightNative / dpr;
          }
        }
      }
    }

    // Fallback: unbounded-height slot (e.g. inside a plain Column).
    // Pick the size that makes the widest natural line fill contentWidth.
    final texts = <String>[
      for (final spec in widget.lines)
        if (spec.justify ?? widget.justify) spec.words.join(' '),
    ];
    final calibrationTexts = texts.isNotEmpty
        ? texts
        : [for (final spec in widget.lines) spec.words.join(' ')];
    final widthNative = ArabicTextJustification.calibrateFontSize(
        fp, calibrationTexts, nativeWidth);
    return widthNative / dpr;
  }

  void _ensureTapAdapters() {
    final count = widget.lines.length;
    if (_wordTapAdapters != null &&
        _markerTapAdapters != null &&
        _wordTapAdapters!.length == count) {
      return;
    }
    final onWordTap = widget.onWordTap;
    final onMarkerTap = widget.onMarkerTap;
    _wordTapAdapters = List<void Function(int, String)?>.generate(
      count,
      (lineIndex) => onWordTap == null
          ? null
          : (wordIndex, word) => onWordTap(lineIndex, wordIndex, word),
      growable: false,
    );
    _markerTapAdapters = List<void Function(int, String)?>.generate(
      count,
      (lineIndex) => onMarkerTap == null
          ? null
          : (wordIndex, word) => onMarkerTap(lineIndex, wordIndex, word),
      growable: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_fontPath == null) return const SizedBox.shrink();
    if (widget.lines.isEmpty) return const SizedBox.shrink();

    final insets =
        widget.padding?.resolve(Directionality.of(context)) ?? EdgeInsets.zero;

    return LayoutBuilder(
      builder: (context, constraints) {
        final outerWidth = constraints.maxWidth;
        final contentWidth = (outerWidth - insets.horizontal).clamp(
          0.0,
          double.infinity,
        );
        final outerHeight = constraints.maxHeight;
        final contentHeight = outerHeight.isFinite
            ? (outerHeight - insets.vertical).clamp(0.0, double.infinity)
            : double.infinity;

        // Resolve the shared font size synchronously. Width- and
        // height-fitting both run as pure FFI calls — safe during build.
        // Caching avoids recomputing on every layout pass.
        if (_resolvedDisplaySize == null ||
            _resolvedForWidth != contentWidth ||
            _resolvedForHeight != contentHeight) {
          final size =
              _computeSharedDisplaySize(contentWidth, contentHeight);
          if (size == null) return const SizedBox.shrink();
          _resolvedDisplaySize = size;
          _resolvedForWidth = contentWidth;
          _resolvedForHeight = contentHeight;
        }

        final sharedSize = _resolvedDisplaySize!;
        _ensureTapAdapters();
        final wordTaps = _wordTapAdapters!;
        final markerTaps = _markerTapAdapters!;

        final rows = <Widget>[];
        for (var i = 0; i < widget.lines.length; i++) {
          if (i > 0 && widget.lineSpacing > 0) {
            rows.add(SizedBox(height: widget.lineSpacing));
          }
          final spec = widget.lines[i];
          // JustifiedArabicLine wraps its own output in a RepaintBoundary,
          // so per-line paint invalidation (e.g. word-progress ticks) is
          // already isolated from siblings — no outer boundary needed.
          rows.add(
            JustifiedArabicLine(
              words: spec.words,
              justify: spec.justify ?? widget.justify,
              color: spec.color ?? widget.color,
              highlightedWordIndices: spec.highlightedWordIndices,
              highlightColor: spec.highlightColor ?? widget.highlightColor,
              colorSpans: spec.colorSpans,
              wordProgress: spec.wordProgress,
              alignment: spec.alignment,
              fontSize: sharedSize,
              fontPath: _fontPath,
              marker: widget.marker,
              onWordTap: wordTaps[i],
              onMarkerTap: markerTaps[i],
            ),
          );
        }

        return Padding(
          padding: insets,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: rows,
          ),
        );
      },
    );
  }
}
