import 'package:flutter/material.dart';
import 'package:arabic_text_justification/arabic_text_justification.dart';

import 'constants/constants.dart';
import 'main.dart';
import 'mixins/playback_mixin.dart';
import 'widgets/labeled_switch_row.dart';
import 'widgets/playback_controls.dart';
import 'widgets/scrollable_page.dart';

class HiddenPage extends StatefulWidget {
  const HiddenPage({super.key});

  @override
  State<HiddenPage> createState() => _HiddenPageState();
}

class _HiddenPageState extends State<HiddenPage>
    with SingleTickerProviderStateMixin<HiddenPage>, PlaybackMixin<HiddenPage> {
  bool _showAll = false;

  @override
  List<PageLine> get dataLines => page3Lines;

  @override
  bool includeWord(int lineIndex, int wordIndex) =>
      !dataLines[lineIndex].words[wordIndex].contains(ayahMarker);

  @override
  Widget build(BuildContext context) {
    return ScrollablePage(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      header: PlaybackControls(
        position: position,
        total: total,
        isPlaying: isPlaying,
        onTogglePlay: togglePlay,
        onReset: reset,
        onSeek: seek,
      ),
      extras: [
        LabeledSwitchRow(
          label: 'Show all words',
          value: _showAll,
          onChanged: (v) => setState(() => _showAll = v),
          leading: Icon(
            _showAll ? Icons.visibility : Icons.visibility_off,
            size: 20,
            color: appGreen,
          ),
        ),
      ],
      child: ValueListenableBuilder<Duration>(
        valueListenable: position,
        builder: (_, pos, __) {
          final states = statesAt(pos);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < page3Lines.length; i++)
                JustifiedArabicLine(
                  words: page3Lines[i].words,
                  justify: page3Lines[i].justify,
                  fontSize: 18,
                  padding: linePadding,
                  marker: ayahMarker,
                  wordProgress: revealProgress(states[i], showAll: _showAll),
                ),
            ],
          );
        },
      ),
    );
  }
}
