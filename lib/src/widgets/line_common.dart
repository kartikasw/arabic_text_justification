import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/widgets.dart';

import '../bundled_fonts.dart';
import '../ffi/native_api.dart';
import '../models/models.dart';

typedef ResolvedActiveState = ({double progress, bool whole});

class DisplayTransform {
  final double scale;
  final double offsetX;
  final double top;
  final double height;
  final Set<int>? excluding;

  const DisplayTransform({
    required this.scale,
    required this.offsetX,
    required this.top,
    required this.height,
    this.excluding,
  });

  Rect? mapSingle(int index, List<Rect> wordRects) {
    if (index < 0 || index >= wordRects.length) return null;
    if (excluding != null && excluding!.contains(index)) return null;
    final r = wordRects[index];
    if (r.width <= 0) return null;
    return Rect.fromLTWH(
      offsetX + scale * r.left,
      top,
      scale * r.width,
      height,
    );
  }

  List<Rect> mapAll(Iterable<int> indices, List<Rect> wordRects) {
    final out = <Rect>[];
    for (final i in indices) {
      final rect = mapSingle(i, wordRects);
      if (rect != null) out.add(rect);
    }
    return out;
  }
}

/// Fields the mixin reads off the owning widget. Both [JustifiedArabicLine]
/// and [JustifiedArabicBitmapLine] implement this.
abstract interface class JustifiedArabicLineConfig {
  List<String> get words;

  bool get justify;

  String? get fontPath;

  double? get fontSize;

  String? get marker;

  void Function(int index, String word)? get onWordTap;

  void Function(int index, String word)? get onMarkerTap;

  WordProgress? get wordProgress;
}

/// Shared lifecycle and helpers for the line widgets: resolves the font path
/// (bundled or user-supplied), invalidates the render when inputs change,
/// and routes taps to the caller's callbacks. Subclasses implement
/// [resetRender] to drop their cached render result.
mixin JustifiedLineStateMixin<T extends StatefulWidget> on State<T> {
  String? fontPath;
  double? renderedWidth;

  JustifiedArabicLineConfig get _cfg => widget as JustifiedArabicLineConfig;

  @override
  void initState() {
    super.initState();
    final fp = _cfg.fontPath;
    if (fp != null) {
      fontPath = fp;
    } else {
      _loadBundledFont();
    }
  }

  /// Call from [didUpdateWidget] with the old widget (which must implement
  /// [JustifiedArabicLineConfig]).
  void handleConfigChange(JustifiedArabicLineConfig oldCfg) {
    final cfg = _cfg;
    if (cfg.fontPath != oldCfg.fontPath) {
      fontPath = cfg.fontPath;
      renderedWidth = null;
      resetRender();
      if (fontPath == null) _loadBundledFont();
    }
    if (!listEquals(cfg.words, oldCfg.words) ||
        cfg.justify != oldCfg.justify ||
        cfg.fontSize != oldCfg.fontSize) {
      renderedWidth = null;
      resetRender();
    }
  }

  /// Resolves the native font size: either the caller's [fontSize] scaled
  /// by [dpr], or auto-fit to [nativeWidth] via shaping.
  double resolveFontSize({
    required double nativeWidth,
    required double dpr,
  }) {
    final fp = fontPath!;
    final fs = _cfg.fontSize;
    if (fs != null) return fs * dpr;
    return ArabicTextJustification.fontSizeForWidth(
      fp,
      _cfg.words.join(' '),
      nativeWidth,
    );
  }

  double? resolveNativeSize({
    required double nativeWidth,
    required double dpr,
    required double? height,
    required EdgeInsets insets,
  }) {
    if (height == null) {
      return resolveFontSize(nativeWidth: nativeWidth, dpr: dpr);
    }
    final nativeHeightBudget = (height - insets.vertical) * dpr;
    if (nativeHeightBudget <= 0) return null;

    const refSize = 100.0;
    final refOutline = ArabicTextJustification.getOutline(
      fontPath!,
      _cfg.words.join(' '),
      refSize,
      nativeWidth,
      justify: false,
    );
    if (refOutline == null) return null;
    final metricRef = refOutline.ascender - refOutline.descender;
    if (metricRef <= 0) return null;

    var nativeSize = nativeHeightBudget * refSize / metricRef;
    final minNative = 8 * dpr;
    if (nativeSize < minNative) nativeSize = minNative;
    return nativeSize;
  }

  /// Routes a word tap to either [JustifiedArabicLineConfig.onWordTap] or
  /// [JustifiedArabicLineConfig.onMarkerTap]. A marker is a word whose text
  /// contains [JustifiedArabicLineConfig.marker] (non-null, non-empty).
  void dispatchTap(int wordIndex) {
    final cfg = _cfg;
    if (wordIndex < 0 || wordIndex >= cfg.words.length) return;

    final word = cfg.words[wordIndex];
    final marker = cfg.marker;
    final isMarker =
        marker != null && marker.isNotEmpty && word.contains(marker);

    if (isMarker) {
      cfg.onMarkerTap?.call(wordIndex, word);
    } else {
      cfg.onWordTap?.call(wordIndex, word);
    }
  }

  ResolvedActiveState get activeState {
    final p = _cfg.wordProgress;
    if (p == null) return (progress: 0.0, whole: false);
    final whole = p.style == WordProgressStyle.whole;
    final progress = switch (p.style) {
      WordProgressStyle.whole => p.activeWordIndex != null ? 1.0 : 0.0,
      WordProgressStyle.sweep => p.activeProgress.clamp(0.0, 1.0),
    };
    return (progress: progress, whole: whole);
  }

  /// Drop the cached render so the next layout pass re-renders.
  @protected
  void resetRender();

  Future<void> _loadBundledFont() async {
    final path = await JustificationFont.digitalKhatt.load();
    if (mounted) setState(() => fontPath = path);
  }
}
