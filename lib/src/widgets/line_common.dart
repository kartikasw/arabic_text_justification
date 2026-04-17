import 'package:flutter/widgets.dart';

import '../bundled_fonts.dart';
import '../ffi/native_api.dart';
import '../models/models.dart';

typedef ResolvedActiveState = ({double progress, bool whole});

/// Fields the mixin reads off the owning widget. Both [JustifiedArabicLine]
/// and [JustifiedArabicBitmapLine] implement this.
abstract interface class JustifiedArabicLineConfig {
  List<String> get words;

  bool get justify;

  String? get fontPath;

  double? get fontSize;

  String? get verseMarker;

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
    if (cfg.words != oldCfg.words ||
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

  /// Routes a word tap to either [JustifiedArabicLineConfig.onWordTap] or
  /// [JustifiedArabicLineConfig.onMarkerTap]. A marker is a word whose text
  /// contains [JustifiedArabicLineConfig.verseMarker] (non-null, non-empty).
  void dispatchTap(int wordIndex) {
    final cfg = _cfg;
    if (wordIndex < 0 || wordIndex >= cfg.words.length) return;

    final word = cfg.words[wordIndex];
    final marker = cfg.verseMarker;
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
