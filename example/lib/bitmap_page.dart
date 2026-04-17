import 'package:flutter/material.dart';
import 'package:arabic_text_justification/arabic_text_justification.dart';

import 'constants/constants.dart';
import 'main.dart';
import 'mixins/ayah_selection_mixin.dart';
import 'mixins/debounced_slider_mixin.dart';
import 'widgets/scrollable_page.dart';
import 'widgets/slider_header.dart';

class BitmapPage extends StatefulWidget {
  const BitmapPage({super.key});

  @override
  State<BitmapPage> createState() => _BitmapPageState();
}

class _BitmapPageState extends State<BitmapPage>
    with AyahSelectionMixin<BitmapPage>, DebouncedSliderMixin<BitmapPage> {
  @override
  double get initialSliderValue => 24;

  @override
  Widget build(BuildContext context) {
    return ScrollablePage(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      header: SliderHeader(
        label: 'Font size',
        value: sliderValue,
        min: 8,
        max: 64,
        onChanged: onSliderChanged,
        selectedAyah: selectedAyah,
        selectedWord: selectedWord,
      ),
      child: Column(
        children: [
          for (int i = 0; i < page3Lines.length; i++)
            JustifiedArabicBitmapLine(
              words: page3Lines[i].words,
              justify: page3Lines[i].justify,
              fontSize: renderedValue,
              marker: ayahMarker,
              highlightedWordIndices: highlightsFor(i),
              onWordTap: (idx, w) => onWordTap(i, idx, w),
              onMarkerTap: (idx, w) => onMarkerTap(i, idx, w),
            ),
        ],
      ),
    );
  }
}
