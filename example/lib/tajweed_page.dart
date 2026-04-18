import 'package:flutter/material.dart';
import 'package:arabic_text_justification/arabic_text_justification.dart';

import 'main.dart';
import 'constants/tajweed.dart';
import 'mixins/debounced_slider_mixin.dart';
import 'widgets/scrollable_page.dart';
import 'widgets/slider_header.dart';

class TajweedPage extends StatefulWidget {
  const TajweedPage({super.key});

  @override
  State<TajweedPage> createState() => _TajweedPageState();
}

class _TajweedPageState extends State<TajweedPage>
    with DebouncedSliderMixin<TajweedPage> {
  late final List<List<WordColorSpan>> _spansByLine = [
    for (final line in page3Lines)
      colorSpansFromRegex(words: line.words, rules: tajweedRegexRules),
  ];

  bool _tajweedOn = true;

  @override
  double get initialSliderValue => 20;

  @override
  Widget build(BuildContext context) {
    return ScrollablePage(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      header: SliderHeader(
        label: 'Font size',
        value: sliderValue,
        min: 8,
        max: 64,
        onChanged: onSliderChanged,
      ),
      extras: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Tajweed'),
              const SizedBox(width: 8),
              Transform.scale(
                scale: 0.75,
                child: Switch(
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  value: _tajweedOn,
                  onChanged: (v) => setState(() => _tajweedOn = v),
                ),
              ),
            ],
          ),
        ),
        if (_tajweedOn)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Wrap(
              spacing: 16,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: [
                for (final rule in TajweedRule.values)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: rule.color,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        rule.label,
                        style: TextStyle(color: rule.color, fontSize: 14),
                      ),
                    ],
                  ),
              ],
            ),
          ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (int i = 0; i < page3Lines.length; i++)
            JustifiedArabicLine(
              words: page3Lines[i].words,
              justify: page3Lines[i].justify,
              fontSize: renderedValue,
              padding: const EdgeInsets.symmetric(vertical: 2),
              colorSpans: _tajweedOn ? _spansByLine[i] : null,
            ),
        ],
      ),
    );
  }
}
