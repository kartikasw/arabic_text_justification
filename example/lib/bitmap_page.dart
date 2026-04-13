import 'package:flutter/material.dart';
import 'package:arabic_text_justification/arabic_text_justification.dart';

import 'main.dart';

class BitmapPage extends StatefulWidget {
  final String fontPath;
  const BitmapPage({super.key, required this.fontPath});

  @override
  State<BitmapPage> createState() => _BitmapPageState();
}

class _BitmapPageState extends State<BitmapPage> {
  List<RenderResult?> _lines = [];
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

  Future<void> _renderPage(double width, double height) async {
    if (_rendering) return;
    _rendering = true;
    try {
      final dpr = MediaQuery.of(context).devicePixelRatio;
      final nativeWidth = width * dpr;
      // DigitalKhatt font is calibrated for a line width of 17 em
      // (PAGE_WIDTH=17000 / FONTSIZE=1000 in its source). Pick fontSize
      // from width so the font's kashida alternates have the capacity
      // they were designed for.
      const kDigitalKhattLineRatio = 17.0;
      final fontSize = nativeWidth / kDigitalKhattLineRatio;

      final lines = <RenderResult?>[];
      for (int i = 0; i < page3Lines.length; i++) {
        final result = await ArabicTextJustification.renderLine(
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

  void _onTapLine(int lineIndex, RenderResult result, Offset localPosition,
      double displayWidth) {
    final scale = result.bmpWidth / displayWidth;
    final bmpX = localPosition.dx * scale;
    final bmpY = localPosition.dy * scale;

    for (int w = 0; w < result.wordRects.length; w++) {
      final rect = result.wordRects[w];
      if (bmpX >= rect.x &&
          bmpX <= rect.x + rect.width &&
          bmpY >= rect.y &&
          bmpY <= rect.y + rect.height) {
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

  Widget _buildInteractiveLine(int lineIdx, RenderResult result) {
    final alignment = page3Lines[lineIdx].alignment;

    return LayoutBuilder(
      builder: (context, constraints) {
        final displayWidth = constraints.maxWidth;
        final displayHeight = constraints.maxHeight;

        // Uniform scale from height; if the line overshoots width after
        // kashida, shrink horizontally only (Tarteel-style horizontal
        // compression for extra-wide lines).
        final scaleY = displayHeight / result.bmpHeight;
        final uniformWidth = result.bmpWidth * scaleY;
        final bool overshoots = uniformWidth > displayWidth;
        final scaleX = overshoots
            ? displayWidth / result.bmpWidth
            : scaleY;
        final renderedWidth = result.bmpWidth * scaleX;

        // BoxFit.fill when overshooting (use the non-uniform scaleX to
        // compress). BoxFit.contain when fitting.
        final fit = overshoots ? BoxFit.fill : BoxFit.contain;
        final align = switch (alignment) {
          LineAlignment.justify => Alignment.centerRight,
          LineAlignment.center => Alignment.center,
          LineAlignment.left => Alignment.centerLeft,
          LineAlignment.right => Alignment.centerRight,
        };
        final double offsetX = switch (alignment) {
          LineAlignment.justify => displayWidth - renderedWidth,
          LineAlignment.center => (displayWidth - renderedWidth) / 2,
          LineAlignment.left => 0.0,
          LineAlignment.right => displayWidth - renderedWidth,
        };

        return GestureDetector(
          onTapUp: (details) {
            _onTapLine(lineIdx, result, details.localPosition, displayWidth);
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
                ColorFiltered(
                  colorFilter: const ColorFilter.mode(
                    Colors.black,
                    BlendMode.srcIn,
                  ),
                  child: RawImage(
                    image: result.image,
                    fit: fit,
                    alignment: align,
                    width: displayWidth,
                    height: displayHeight,
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
