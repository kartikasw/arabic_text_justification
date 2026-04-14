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

  void _renderPage(double width, double height) {
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
      if (entry.value.any((pos) => pos.$1 == lineIndex && pos.$2 == wordIndex)) {
        return entry.key;
      }
    }
    return null;
  }

  void _onTapLine(int lineIndex, OutlineResult result, Offset localPosition,
      double displayWidth, double displayHeight) {
    final scaleX = displayWidth / result.totalWidth;
    final scaleY = displayHeight / (result.ascender - result.descender);

    final tapX = localPosition.dx / scaleX;
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
        const padding = EdgeInsets.fromLTRB(8, 8, 8, 16);
        final contentWidth = constraints.maxWidth - padding.horizontal;
        final contentHeight = constraints.maxHeight - padding.vertical;

        if (_lines.isEmpty && !_rendering) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _renderPage(contentWidth, contentHeight);
          });
        }

        if (_loading || _lines.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        return Padding(
          padding: padding,
          child: Column(
            children: List.generate(_lines.length, (lineIdx) {
              final result = _lines[lineIdx];
              if (result == null) {
                return const Expanded(child: SizedBox.shrink());
              }
              return Expanded(
                child: _buildInteractiveLine(lineIdx, result),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildInteractiveLine(int lineIdx, OutlineResult result) {
    final alignment = page3Lines[lineIdx].alignment;

    return LayoutBuilder(
      builder: (context, constraints) {
        final displayWidth = constraints.maxWidth;
        final displayHeight = constraints.maxHeight;
        final lineHeight = result.ascender - result.descender;

        // Uniform scale from height. Lines that overshoot the display
        // width after kashida features get horizontally compressed
        // (scaleX < scaleY) — Tarteel's "horizontal compression" for
        // extra-wide lines. Lines that fit use uniform scale.
        final scaleY = displayHeight / lineHeight;
        final uniformWidth = result.totalWidth * scaleY;
        final double scaleX = uniformWidth > displayWidth
            ? displayWidth / result.totalWidth
            : scaleY;
        final renderedWidth = result.totalWidth * scaleX;
        final double offsetX = switch (alignment) {
          LineAlignment.justify => displayWidth - renderedWidth,
          LineAlignment.center => (displayWidth - renderedWidth) / 2,
          LineAlignment.left => 0.0,
          LineAlignment.right => displayWidth - renderedWidth,
        };

        return GestureDetector(
          onTapUp: (details) {
            _onTapLine(lineIdx, result, details.localPosition,
                displayWidth, displayHeight);
          },
          child: SizedBox(
            width: displayWidth,
            height: displayHeight,
            child: Stack(
              children: [
                if (_selectedAyah != null)
                  for (final pos in _ayahIndex[_selectedAyah!] ?? <(int, int)>[])
                    if (pos.$1 == lineIdx && pos.$2 < result.wordRects.length)
                      Positioned(
                        left: offsetX + result.wordRects[pos.$2].x * scaleX,
                        top: result.wordRects[pos.$2].y * scaleY,
                        width: result.wordRects[pos.$2].width * scaleX,
                        height: result.wordRects[pos.$2].height * scaleY,
                        child: ColoredBox(
                          color: Colors.amber.withValues(alpha: 0.3),
                        ),
                      ),
                CustomPaint(
                  size: Size(displayWidth, displayHeight),
                  painter: _ScaledOutlinePainter(
                    outline: result,
                    scaleX: scaleX,
                    scaleY: scaleY,
                    offsetX: offsetX,
                  ),
                ),
              ],
            ),
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

  _ScaledOutlinePainter({
    required this.outline,
    required this.scaleX,
    required this.scaleY,
    this.offsetX = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    final ascender = outline.ascender;

    canvas.save();
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
      offsetX != oldDelegate.offsetX;
}
