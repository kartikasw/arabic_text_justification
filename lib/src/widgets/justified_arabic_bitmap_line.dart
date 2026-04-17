import 'package:flutter/material.dart';

import '../ffi/native_api.dart';
import '../bundled_fonts.dart';
import '../models/models.dart';

class JustifiedArabicBitmapLine extends StatefulWidget {
  final List<String> words;

  final bool justify;

  final Color color;

  /// If null, the bundled DigitalKhatt font is loaded automatically.
  final String? fontPath;

  /// If null, the size is auto-calculated to fill the available width.
  final double? fontSize;

  const JustifiedArabicBitmapLine({
    super.key,
    required this.words,
    this.justify = true,
    this.color = Colors.black,
    this.fontPath,
    this.fontSize,
  });

  @override
  State<JustifiedArabicBitmapLine> createState() =>
      _JustifiedArabicBitmapLineState();
}

class _JustifiedArabicBitmapLineState extends State<JustifiedArabicBitmapLine> {
  String? _fontPath;
  RenderResult? _result;
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
  void didUpdateWidget(JustifiedArabicBitmapLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.fontPath != oldWidget.fontPath) {
      _fontPath = widget.fontPath;
      _result = null;
      _renderedWidth = null;
      if (_fontPath == null) _loadFont();
    }
    if (widget.words != oldWidget.words ||
        widget.justify != oldWidget.justify ||
        widget.color != oldWidget.color ||
        widget.fontSize != oldWidget.fontSize) {
      _result = null;
      _renderedWidth = null;
    }
  }

  Future<void> _loadFont() async {
    final path = await JustificationFont.digitalKhatt.load();
    if (mounted) setState(() => _fontPath = path);
  }

  Future<void> _render(double width) async {
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

    final result = await ArabicTextJustification.renderLine(
      fontPath,
      text,
      fontSize,
      nativeWidth,
      justify: widget.justify,
    );

    if (mounted) {
      setState(() {
        _result = result;
        _renderedWidth = width;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_fontPath == null) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        if (_result == null || _renderedWidth != width) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _render(width);
          });
          if (_result == null) return const SizedBox.shrink();
        }

        final result = _result!;
        final dpr = MediaQuery.of(context).devicePixelRatio;

        final double displayWidth;
        final double displayHeight;
        if (widget.justify) {
          final scale = width / result.bmpWidth;
          displayWidth = width;
          displayHeight = result.bmpHeight * scale;
        } else {
          final naturalScale = 1 / dpr;
          final fitScale = width / result.bmpWidth;
          final scale = naturalScale < fitScale ? naturalScale : fitScale;
          displayWidth = result.bmpWidth * scale;
          displayHeight = result.bmpHeight * scale;
        }

        return Align(
          alignment: Alignment.centerRight,
          child: RepaintBoundary(
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
        );
      },
    );
  }
}
