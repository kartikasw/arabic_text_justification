import 'package:flutter/material.dart';
import 'package:arabic_text_justification/arabic_text_justification.dart';

import 'main.dart';

class OutlinePage extends StatefulWidget {
  final String fontPath;
  const OutlinePage({super.key, required this.fontPath});

  @override
  State<OutlinePage> createState() => _OutlinePageState();
}

class _OutlinePageState extends State<OutlinePage> {
  List<OutlineResult?> _lines = [];
  bool _loading = true;
  String? _error;
  int? _selectedAyah;
  late final Map<int, List<(int, int)>> _ayahIndex;
  bool _rendering = false;

  @override
  void initState() {
    super.initState();
    _ayahIndex = buildAyahIndex(page3Lines);
  }

  void _renderPage(double width) {
    if (_rendering) return;
    _rendering = true;
    try {
      final dpr = MediaQuery.of(context).devicePixelRatio;
      final nativeWidth = width * dpr;
      const kDigitalKhattLineRatio = 17.0;
      final fontSize = nativeWidth / kDigitalKhattLineRatio;

      final lines = <OutlineResult?>[];
      for (int i = 0; i < page3Lines.length; i++) {
        final result = ArabicTextJustification.getOutline(
          widget.fontPath,
          page3Lines[i].text,
          fontSize,
          nativeWidth,
          justify: page3Lines[i].alignment == LineAlignment.justify,
        );
        lines.add(result);
      }
      setState(() {
        _lines = lines;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  int? _findAyahForWord(int lineIndex, int wordIndex) {
    for (final entry in _ayahIndex.entries) {
      if (entry.value
          .any((pos) => pos.$1 == lineIndex && pos.$2 == wordIndex)) {
        return entry.key;
      }
    }
    return null;
  }

  void _onTapLine(
      int lineIndex, OutlineResult result, Offset localPosition, double scaleX, double scaleY, double offsetX) {
    final tapX = (localPosition.dx - offsetX) / scaleX;
    final tapY = localPosition.dy / scaleY;

    for (int w = 0; w < result.wordRects.length; w++) {
      final rect = result.wordRects[w];
      if (tapX >= rect.x &&
          tapX <= rect.x + rect.width &&
          tapY >= rect.y &&
          tapY <= rect.y + rect.height) {
        final word = page3Lines[lineIndex].words[w];

        if (word.contains('۝')) {
          final ayah = _findAyahForWord(lineIndex, w);
          setState(() {
            _selectedAyah = (ayah == _selectedAyah) ? null : ayah;
          });
        } else {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Word $w: $word',
                style: const TextStyle(fontSize: 18),
                textDirection: TextDirection.rtl,
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text('Error: $_error',
              style: const TextStyle(color: Colors.red)),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const padding = EdgeInsets.fromLTRB(8, 0, 8, 16);
        final contentWidth = constraints.maxWidth - padding.horizontal;
        final contentHeight = constraints.maxHeight - padding.vertical;

        if (_lines.isEmpty && !_rendering) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _renderPage(contentWidth);
          });
        }

        if (_loading || _lines.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        // Compute natural height per line (uniform scale from width).
        final naturalHeights = <double>[];
        for (final result in _lines) {
          if (result == null) {
            naturalHeights.add(0);
            continue;
          }
          final lineHeight = result.ascender - result.descender;
          final scaleX = contentWidth / result.totalWidth;
          naturalHeights.add(lineHeight * scaleX);
        }
        final totalNatural = naturalHeights.fold(0.0, (a, b) => a + b);
        final vFactor =
            totalNatural > contentHeight ? contentHeight / totalNatural : 1.0;

        return Padding(
          padding: padding,
          child: Column(
            children: List.generate(_lines.length, (lineIdx) {
              final result = _lines[lineIdx];
              if (result == null) return const SizedBox.shrink();

              final alignment = page3Lines[lineIdx].alignment;
              final lineHeight = result.ascender - result.descender;
              final scaleX = contentWidth / result.totalWidth;
              final scaleY = scaleX * vFactor;
              final displayHeight = lineHeight * scaleY;

              final renderedWidth = result.totalWidth * scaleX;
              final double offsetX = switch (alignment) {
                LineAlignment.justify => contentWidth - renderedWidth,
                LineAlignment.center => (contentWidth - renderedWidth) / 2,
                LineAlignment.left => 0.0,
                LineAlignment.right => contentWidth - renderedWidth,
              };

              final highlightIndices = <int>[];
              if (_selectedAyah != null) {
                for (final pos
                    in _ayahIndex[_selectedAyah!] ?? <(int, int)>[]) {
                  if (pos.$1 == lineIdx &&
                      pos.$2 < result.wordRects.length) {
                    highlightIndices.add(pos.$2);
                  }
                }
              }

              return GestureDetector(
                onTapUp: (details) {
                  _onTapLine(lineIdx, result, details.localPosition,
                      scaleX, scaleY, offsetX);
                },
                child: Container(
                  color: lineIdx % 2 == 0 ? Colors.amber : Colors.green,
                  child: CustomPaint(
                    size: Size(contentWidth, displayHeight),
                    painter: _ScaledOutlinePainter(
                      outline: result,
                      scaleX: scaleX,
                      scaleY: scaleY,
                      offsetX: offsetX,
                      highlightIndices: highlightIndices,
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

class _ScaledOutlinePainter extends CustomPainter {
  final OutlineResult outline;
  final double scaleX;
  final double scaleY;
  final double offsetX;
  final List<int> highlightIndices;

  _ScaledOutlinePainter({
    required this.outline,
    required this.scaleX,
    required this.scaleY,
    this.offsetX = 0,
    this.highlightIndices = const [],
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);

    if (highlightIndices.isNotEmpty) {
      final hlPaint = Paint()
        ..color = Colors.amber.withValues(alpha: 0.3);
      for (final w in highlightIndices) {
        final rect = outline.wordRects[w];
        canvas.drawRect(
          Rect.fromLTWH(
            offsetX + rect.x * scaleX,
            rect.y * scaleY,
            rect.width * scaleX,
            rect.height * scaleY,
          ),
          hlPaint,
        );
      }
    }

    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    final ascender = outline.ascender;

    canvas.translate(offsetX, 0);
    canvas.scale(scaleX, scaleY);

    for (final glyph in outline.glyphs) {
      final path = Path();
      for (final cmd in glyph.commands) {
        final x = glyph.offsetX + cmd.x;
        final y = ascender - (glyph.offsetY + cmd.y);
        switch (cmd.type) {
          case PathCommandType.moveTo:
            path.moveTo(x, y);
          case PathCommandType.lineTo:
            path.lineTo(x, y);
          case PathCommandType.quadTo:
            final cx = glyph.offsetX + cmd.x1;
            final cy = ascender - (glyph.offsetY + cmd.y1);
            path.quadraticBezierTo(cx, cy, x, y);
          case PathCommandType.cubicTo:
            final cx1 = glyph.offsetX + cmd.x1;
            final cy1 = ascender - (glyph.offsetY + cmd.y1);
            final cx2 = glyph.offsetX + cmd.x2;
            final cy2 = ascender - (glyph.offsetY + cmd.y2);
            path.cubicTo(cx1, cy1, cx2, cy2, x, y);
        }
      }
      path.close();
      canvas.drawPath(path, paint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_ScaledOutlinePainter oldDelegate) =>
      outline != oldDelegate.outline ||
      scaleX != oldDelegate.scaleX ||
      scaleY != oldDelegate.scaleY ||
      offsetX != oldDelegate.offsetX ||
      highlightIndices != oldDelegate.highlightIndices;
}
