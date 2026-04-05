import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:arabic_text_justification/arabic_text_justification.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

// Page 3 data: each line with its words
class PageLine {
  final List<String> words;
  PageLine(this.words);

  String get text => words.join(' ');
}

final List<PageLine> page3Lines = [
  PageLine(['إِنَّ', 'ٱلَّذِينَ', 'كَفَرُوا۟', 'سَوَآءٌ', 'عَلَيْهِمْ', 'ءَأَنذَرْتَهُمْ', 'أَمْ', 'لَمْ', 'تُنذِرْهُمْ']),
  PageLine(['لَا', 'يُؤْمِنُونَ', '۝٦', 'خَتَمَ', 'ٱللَّهُ', 'عَلَىٰ', 'قُلُوبِهِمْ', 'وَعَلَىٰ', 'سَمْعِهِمْۖ', 'وَعَلَىٰٓ']),
  PageLine(['أَبْصَٰرِهِمْ', 'غِشَٰوَةۖ', 'وَلَهُمْ', 'عَذَابٌ', 'عَظِيم', '۝٧', 'وَمِنَ', 'ٱلنَّاسِ']),
  PageLine(['مَن', 'يَقُولُ', 'ءَامَنَّا', 'بِٱللَّهِ', 'وَبِٱلْيَوْمِ', 'ٱلْـَٔاخِرِ', 'وَمَا', 'هُم', 'بِمُؤْمِنِينَ', '۝٨']),
  PageLine(['يُخَٰدِعُونَ', 'ٱللَّهَ', 'وَٱلَّذِينَ', 'ءَامَنُوا۟', 'وَمَا', 'يَخْدَعُونَ', 'إِلَّآ', 'أَنفُسَهُمْ']),
  PageLine(['وَمَا', 'يَشْعُرُونَ', '۝٩', 'فِي', 'قُلُوبِهِم', 'مَّرَض', 'فَزَادَهُمُ', 'ٱللَّهُ', 'مَرَضاۖ']),
  PageLine(['وَلَهُمْ', 'عَذَابٌ', 'أَلِيمُۢ', 'بِمَا', 'كَانُوا۟', 'يَكْذِبُونَ', '۝١٠', 'وَإِذَا', 'قِيلَ', 'لَهُمْ']),
  PageLine(['لَا', 'تُفْسِدُوا۟', 'فِي', 'ٱلْأَرْضِ', 'قَالُوٓا۟', 'إِنَّمَا', 'نَحْنُ', 'مُصْلِحُونَ', '۝١١']),
  PageLine(['أَلَآ', 'إِنَّهُمْ', 'هُمُ', 'ٱلْمُفْسِدُونَ', 'وَلَٰكِن', 'لَّا', 'يَشْعُرُونَ', '۝١٢', 'وَإِذَا', 'قِيلَ']),
  PageLine(['لَهُمْ', 'ءَامِنُوا۟', 'كَمَآ', 'ءَامَنَ', 'ٱلنَّاسُ', 'قَالُوٓا۟', 'أَنُؤْمِنُ', 'كَمَآ', 'ءَامَنَ', 'ٱلسُّفَهَآءُۗ']),
  PageLine(['أَلَآ', 'إِنَّهُمْ', 'هُمُ', 'ٱلسُّفَهَآءُ', 'وَلَٰكِن', 'لَّا', 'يَعْلَمُونَ', '۝١٣', 'وَإِذَا', 'لَقُوا۟']),
  PageLine(['ٱلَّذِينَ', 'ءَامَنُوا۟', 'قَالُوٓا۟', 'ءَامَنَّا', 'وَإِذَا', 'خَلَوْا۟', 'إِلَىٰ', 'شَيَٰطِينِهِمْ', 'قَالُوٓا۟', 'إِنَّا']),
  PageLine(['مَعَكُمْ', 'إِنَّمَا', 'نَحْنُ', 'مُسْتَهْزِءُونَ', '۝١٤', 'ٱللَّهُ', 'يَسْتَهْزِئُ', 'بِهِمْ', 'وَيَمُدُّهُمْ']),
  PageLine(['فِي', 'طُغْيَٰنِهِمْ', 'يَعْمَهُونَ', '۝١٥', 'أُو۟لَٰٓئِكَ', 'ٱلَّذِينَ', 'ٱشْتَرَوُا۟', 'ٱلضَّلَٰلَةَ']),
  PageLine(['بِٱلْهُدَىٰ', 'فَمَا', 'رَبِحَت', 'تِّجَٰرَتُهُمْ', 'وَمَا', 'كَانُوا۟', 'مُهْتَدِينَ', '۝١٦']),
];

// Maps ayah number -> list of (lineIndex, wordIndex) for all its words
Map<int, List<(int, int)>> _buildAyahIndex(List<PageLine> lines) {
  final index = <int, List<(int, int)>>{};
  int currentAyah = 5; // page starts mid-ayah 5
  for (int l = 0; l < lines.length; l++) {
    for (int w = 0; w < lines[l].words.length; w++) {
      final word = lines[l].words[w];
      if (word.contains('۝')) {
        // marker itself belongs to the ayah it closes
        index.putIfAbsent(currentAyah, () => []).add((l, w));
        currentAyah++;
      } else {
        index.putIfAbsent(currentAyah, () => []).add((l, w));
      }
    }
  }
  return index;
}

class _MyAppState extends State<MyApp> {
  List<RenderResult?> _lines = [];
  bool _loading = true;
  String? _error;
  int? _selectedAyah;
  late final Map<int, List<(int, int)>> _ayahIndex;

  @override
  void initState() {
    super.initState();
    _ayahIndex = _buildAyahIndex(page3Lines);
    _loadFont();
  }

  Future<String> _copyFontToFilesystem() async {
    final dir = await getApplicationSupportDirectory();
    final fontFile = File('${dir.path}/digitalkhatt.otf');
    if (!await fontFile.exists()) {
      final data = await rootBundle
          .load('packages/arabic_text_justification/assets/digitalkhatt.otf');
      await fontFile.writeAsBytes(data.buffer.asUint8List());
    }
    return fontFile.path;
  }

  String? _fontPath;
  bool _rendering = false;

  Future<void> _loadFont() async {
    _fontPath = await _copyFontToFilesystem();
    setState(() {});
  }

  Future<void> _renderPage(double width, double height) async {
    if (_fontPath == null || _rendering) return;
    _rendering = true;
    try {
      final dpr = MediaQuery.of(context).devicePixelRatio;
      final nativeWidth = width * dpr;
      // Calculate font size: each line gets height/lineCount,
      // and bmp_height = ascender - descender ≈ fontSize * 1.3 (typical for Arabic)
      final lineHeight = height / page3Lines.length;
      final fontSize = lineHeight * dpr / 1.3;

      final lines = <RenderResult?>[];
      for (final line in page3Lines) {
        final result = await ArabicTextJustification.renderLine(
          _fontPath!,
          line.text,
          fontSize,
          nativeWidth,
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
          // Tapped an ayah marker — select the whole ayah
          final ayah = _findAyahForWord(lineIndex, w);
          setState(() {
            _selectedAyah = (ayah == _selectedAyah) ? null : ayah;
          });
        } else {
          // Tapped a regular word — show snackbar
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
    return MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFFFDF5E6),
        appBar: AppBar(
          title: const Text('Page 3 - Al-Baqarah'),
          backgroundColor: const Color(0xFF2E7D32),
          foregroundColor: Colors.white,
        ),
        body: _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text('Error: $_error',
                      style: const TextStyle(color: Colors.red)),
                ))
            : LayoutBuilder(
                builder: (context, constraints) {
                  const padding = EdgeInsets.fromLTRB(8, 8, 8, 16);
                  final contentWidth = constraints.maxWidth - padding.horizontal;
                  final contentHeight = constraints.maxHeight - padding.vertical;

                  if (_lines.isEmpty && _fontPath != null && !_rendering) {
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
              ),
      ),
    );
  }

  Widget _buildInteractiveLine(int lineIdx, RenderResult result) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final displayWidth = constraints.maxWidth;
        final displayHeight = constraints.maxHeight;
        final scaleX = displayWidth / result.bmpWidth;
        final scaleY = displayHeight / result.bmpHeight;

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
                        left: result.wordRects[pos.$2].x * scaleX,
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
                    fit: BoxFit.fill,
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
