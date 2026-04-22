import 'package:flutter/material.dart';
import 'package:arabic_text_justification/arabic_text_justification.dart';

import 'constants/constants.dart';
import 'constants/tajweed.dart';
import 'main.dart';
import 'mixins/debounced_slider_mixin.dart';
import 'widgets/labeled_switch_row.dart';
import 'widgets/scrollable_page.dart';
import 'widgets/slider_header.dart';
import 'widgets/tajweed_legend.dart';

class TajweedPage extends StatefulWidget {
  const TajweedPage({super.key});

  @override
  State<TajweedPage> createState() => _TajweedPageState();
}

class _TajweedPageState extends State<TajweedPage>
    with DebouncedSliderMixin<TajweedPage> {
  late final List<List<WordColorSpan>> _spansByLine =
      buildTajweedSpans(page3Lines);

  bool _tajweedOn = true;

  @override
  double get initialSliderValue => 20;

  @override
  Widget build(BuildContext context) {
    return ScrollablePage(
      padding: scrollablePagePadding,
      header: SliderHeader(
        label: 'Font size',
        value: sliderValue,
        min: 8,
        max: 64,
        onChanged: onSliderChanged,
      ),
      extras: [
        LabeledSwitchRow(
          label: 'Tajweed',
          value: _tajweedOn,
          onChanged: (v) => setState(() => _tajweedOn = v),
        ),
        if (_tajweedOn) const TajweedLegend(),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (int i = 0; i < page3Lines.length; i++)
            JustifiedArabicLine(
              words: page3Lines[i].words,
              justify: page3Lines[i].justify,
              fontSize: renderedValue,
              padding: linePadding,
              colorSpans: _tajweedOn ? _spansByLine[i] : null,
            ),
        ],
      ),
    );
  }
}
