import 'package:flutter/material.dart';
import 'package:arabic_text_justification/arabic_text_justification.dart';

import 'common.dart';
import 'main.dart';

const _verseMarker = '۝';

class BitmapPage extends StatefulWidget {
  const BitmapPage({super.key});

  @override
  State<BitmapPage> createState() => _BitmapPageState();
}

class _BitmapPageState extends State<BitmapPage>
    with AyahSelectionMixin<BitmapPage>, FontSizeMixin<BitmapPage> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        FontSizeHeader(
          fontSize: fontSize,
          onChanged: onFontSizeChanged,
          selectedAyah: selectedAyah,
          selectedWord: selectedWord,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: [
                for (int i = 0; i < page3Lines.length; i++)
                  JustifiedArabicBitmapLine(
                    words: page3Lines[i].words,
                    justify: page3Lines[i].justify,
                    fontSize: renderedFontSize,
                    verseMarker: _verseMarker,
                    highlightedWordIndices: highlightsFor(i),
                    onWordTap: (idx, w) => onWordTap(i, idx, w),
                    onMarkerTap: (idx, w) => onMarkerTap(i, idx, w),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
