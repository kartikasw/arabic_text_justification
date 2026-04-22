import 'package:flutter/material.dart';

import 'bitmap_page.dart';
import 'block_page.dart';
import 'constants/constants.dart';
import 'hidden_page.dart';
import 'mushaf_page.dart';
import 'tajweed_page.dart';
import 'word_progress_page.dart';
import 'widget_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class PageLine {
  final List<String> words;
  final bool justify;

  PageLine(this.words, {this.justify = true});

  String get text => words.join(' ');
}

final List<PageLine> page3Lines = [
  PageLine(['بِسْمِ', 'ٱللَّهِ', 'ٱلرَّحْمَٰنِ', 'ٱلرَّحِيمِ'], justify: false),
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

final List<PageLine> page5Lines = [
  PageLine(['بِسْمِ', 'ٱللَّهِ', 'ٱلرَّحْمَٰنِ', 'ٱلرَّحِيمِ'], justify: false),
  PageLine(['وَبَشِّرِ', 'ٱلَّذِينَ', 'ءَامَنُوا۟', 'وَعَمِلُوا۟', 'ٱلصَّٰلِحَٰتِ', 'أَنَّ', 'لَهُمْ', 'جَنَّٰتٍ']),
  PageLine(['تَجْرِي', 'مِن', 'تَحْتِهَا', 'ٱلْأَنْهَٰرُۖ', 'كُلَّمَا', 'رُزِقُوا۟', 'مِنْهَا', 'مِن', 'ثَمَرَةٍ']),
  PageLine(['رِّزْقًا', 'قَالُوا۟', 'هَٰذَا', 'ٱلَّذِي', 'رُزِقْنَا', 'مِن', 'قَبْلُۖ', 'وَأُتُوا۟', 'بِهِۦ', 'مُتَشَٰبِهًاۖ']),
  PageLine(['وَلَهُمْ', 'فِيهَآ', 'أَزْوَٰجٌ', 'مُّطَهَّرَةٌۖ', 'وَهُمْ', 'فِيهَا', 'خَٰلِدُونَ', '۝٢٥', '۞إِنَّ']),
  PageLine(['ٱللَّهَ', 'لَا', 'يَسْتَحْيِۦٓ', 'أَن', 'يَضْرِبَ', 'مَثَلًا', 'مَّا', 'بَعُوضَةً', 'فَمَا', 'فَوْقَهَاۚ', 'فَأَمَّا']),
  PageLine(['ٱلَّذِينَ', 'ءَامَنُوا۟', 'فَيَعْلَمُونَ', 'أَنَّهُ', 'ٱلْحَقُّ', 'مِن', 'رَّبِّهِمْۖ', 'وَأَمَّا']),
  PageLine(['ٱلَّذِينَ', 'كَفَرُوا۟', 'فَيَقُولُونَ', 'مَاذَآ', 'أَرَادَ', 'ٱللَّهُ', 'بِهَٰذَا', 'مَثَلًاۘ']),
  PageLine(['يُضِلُّ', 'بِهِۦ', 'كَثِيرًا', 'وَيَهْدِي', 'بِهِۦ', 'كَثِيرًاۚ', 'وَمَا', 'يُضِلُّ', 'بِهِۦٓ']),
  PageLine(['إِلَّا', 'ٱلْفَٰسِقِينَ', '۝٢٦', 'ٱلَّذِينَ', 'يَنقُضُونَ', 'عَهْدَ', 'ٱللَّهِ', 'مِنۢ', 'بَعْدِ']),
  PageLine(['مِيثَٰقِهِۦ', 'وَيَقْطَعُونَ', 'مَآ', 'أَمَرَ', 'ٱللَّهُ', 'بِهِۦٓ', 'أَن', 'يُوصَلَ', 'وَيُفْسِدُونَ']),
  PageLine(['فِي', 'ٱلْأَرْضِۚ', 'أُو۟لَٰٓئِكَ', 'هُمُ', 'ٱلْخَٰسِرُونَ', '۝٢٧', 'كَيْفَ']),
  PageLine(['تَكْفُرُونَ', 'بِٱللَّهِ', 'وَكُنتُمْ', 'أَمْوَٰتًا', 'فَأَحْيَٰكُمْۖ', 'ثُمَّ', 'يُمِيتُكُمْ']),
  PageLine(['ثُمَّ', 'يُحْيِيكُمْ', 'ثُمَّ', 'إِلَيْهِ', 'تُرْجَعُونَ', '۝٢٨', 'هُوَ', 'ٱلَّذِي', 'خَلَقَ']),
  PageLine(['لَكُم', 'مَّا', 'فِي', 'ٱلْأَرْضِ', 'جَمِيعًا', 'ثُمَّ', 'ٱسْتَوَىٰٓ', 'إِلَى', 'ٱلسَّمَآءِ']),
  PageLine(['فَسَوَّىٰهُنَّ', 'سَبْعَ', 'سَمَٰوَٰتٍۚ', 'وَهُوَ', 'بِكُلِّ', 'شَيْءٍ', 'عَلِيمٌ', '۝٢٩']),
];

Map<int, List<(int, int)>> buildAyahIndex(List<PageLine> lines) {
  final index = <int, List<(int, int)>>{};
  final pending = <(int, int)>[];
  // Skip line 0 (basmalah).
  for (int l = 1; l < lines.length; l++) {
    for (int w = 0; w < lines[l].words.length; w++) {
      final word = lines[l].words[w];
      final ayah = _ayahNumberIn(word);
      if (ayah != null) {
        final list = index.putIfAbsent(ayah, () => []);
        list.addAll(pending);
        list.add((l, w));
        pending.clear();
      } else {
        pending.add((l, w));
      }
    }
  }
  return index;
}

int? _ayahNumberIn(String word) {
  final match = RegExp(r'۝([\u0660-\u0669]+)').firstMatch(word);
  if (match == null) return null;
  var n = 0;
  for (final c in match.group(1)!.codeUnits) {
    n = n * 10 + (c - 0x0660);
  }
  return n;
}

class _MyAppState extends State<MyApp> {
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFFFDF5E6),
        appBar: AppBar(
          title: Text(const [
            'Widget',
            'Word Progress',
            'Reveal',
            'Tajweed',
            'Bitmap',
            'Block',
          ][_currentPage]),
          backgroundColor: appGreen,
          foregroundColor: Colors.white,
          actions: [
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu_book),
                tooltip: 'Mushaf',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MushafPage()),
                ),
              ),
            ),
          ],
        ),
        body: IndexedStack(
          index: _currentPage,
          children: const [
            WidgetPage(),
            WordProgressPage(),
            HiddenPage(),
            TajweedPage(),
            BitmapPage(),
            BlockPage(),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _currentPage,
          onTap: (i) => setState(() => _currentPage = i),
          selectedItemColor: appGreen,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.widgets),
              label: 'Widget',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.mic),
              label: 'Progress',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.visibility_off),
              label: 'Reveal',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.palette),
              label: 'Tajweed',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.image),
              label: 'Bitmap',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.view_agenda),
              label: 'Block',
            ),
          ],
        ),
      ),
    );
  }
}
