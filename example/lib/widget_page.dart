import 'package:flutter/material.dart';
import 'package:arabic_text_justification/arabic_text_justification.dart';

import 'common.dart';
import 'main.dart';

const _verseMarker = '۝';

class WidgetPage extends StatefulWidget {
  const WidgetPage({super.key});

  @override
  State<WidgetPage> createState() => _WidgetPageState();
}

class _WidgetPageState extends State<WidgetPage>
    with AyahSelectionMixin<WidgetPage>, FontSizeMixin<WidgetPage> {
  @override
  Widget build(BuildContext context) {
    return Column(
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
                JustifiedArabicLine(
                  words: page3Lines[0].words,
                  justify: page3Lines[0].justify,
                  fontSize: renderedFontSize,
                  padding: const EdgeInsets.symmetric(vertical: 2),
                ),
                for (int i = 1; i < page3Lines.length; i++)
                  JustifiedArabicLine(
                    words: page3Lines[i].words,
                    justify: page3Lines[i].justify,
                    fontSize: renderedFontSize,
                    verseMarker: _verseMarker,
                    padding: const EdgeInsets.symmetric(vertical: 2),
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
