import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'bitmap_page.dart';
import 'outline_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

enum LineAlignment { justify, center, left, right }

// Page 3 data: each line with its words
class PageLine {
  final List<String> words;
  final LineAlignment alignment;
  PageLine(this.words, {this.alignment = LineAlignment.justify});

  String get text => words.join(' ');
}

final List<PageLine> page3Lines = [
  PageLine(['بِسْمِ', 'ٱللَّهِ', 'ٱلرَّحْمَٰنِ', 'ٱلرَّحِيمِ'], alignment: LineAlignment.center),
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
  PageLine(['ٱلْحَمْدُ', 'لِلَّهِ', 'رَبِّ', 'ٱلْعَٰلَمِينَ'], alignment: LineAlignment.right),
];

Map<int, List<(int, int)>> buildAyahIndex(List<PageLine> lines) {
  final index = <int, List<(int, int)>>{};
  int currentAyah = 5;
  for (int l = 0; l < lines.length; l++) {
    for (int w = 0; w < lines[l].words.length; w++) {
      final word = lines[l].words[w];
      if (word.contains('۝')) {
        index.putIfAbsent(currentAyah, () => []).add((l, w));
        currentAyah++;
      } else {
        index.putIfAbsent(currentAyah, () => []).add((l, w));
      }
    }
  }
  return index;
}

Future<String> copyFontToFilesystem() async {
  final dir = await getApplicationSupportDirectory();
  final fontFile = File('${dir.path}/digitalkhatt.otf');
  if (!await fontFile.exists()) {
    final data = await rootBundle
        .load('packages/arabic_text_justification/assets/digitalkhatt.otf');
    await fontFile.writeAsBytes(data.buffer.asUint8List());
  }
  return fontFile.path;
}

class _MyAppState extends State<MyApp> {
  String? _fontPath;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _loadFont();
  }

  Future<void> _loadFont() async {
    final path = await copyFontToFilesystem();
    setState(() => _fontPath = path);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFFFDF5E6),
        appBar: AppBar(
          title: Text(_currentPage == 0
              ? 'Page 3 - Bitmap'
              : 'Page 3 - Vector Outline'),
          backgroundColor: const Color(0xFF2E7D32),
          foregroundColor: Colors.white,
        ),
        body: _fontPath == null
            ? const Center(child: CircularProgressIndicator())
            : IndexedStack(
                index: _currentPage,
                children: [
                  BitmapPage(fontPath: _fontPath!),
                  OutlinePage(fontPath: _fontPath!),
                ],
              ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentPage,
          onTap: (i) => setState(() => _currentPage = i),
          selectedItemColor: const Color(0xFF2E7D32),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.image),
              label: 'Bitmap',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.draw),
              label: 'Vector Outline',
            ),
          ],
        ),
      ),
    );
  }
}
