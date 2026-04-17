import 'package:flutter/material.dart';
import 'package:arabic_text_justification/arabic_text_justification.dart';

import 'constants/constants.dart';
import 'main.dart';
import 'mixins/playback_mixin.dart';
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
  bool includeWord(int lineIndex, int wordIndex) =>
      !page3Lines[lineIndex].words[wordIndex].contains(ayahMarker);

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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _showAll ? Icons.visibility : Icons.visibility_off,
                size: 20,
                color: const Color(0xFF2E7D32),
              ),
              const SizedBox(width: 8),
              const Text('Show all words'),
              const SizedBox(width: 8),
              Transform.scale(
                scale: 0.75,
                child: Switch(
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  value: _showAll,
                  onChanged: (v) => setState(() => _showAll = v),
                ),
              ),
            ],
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
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  marker: ayahMarker,
                  wordProgress: WordProgress(
                    hiddenWordIndices: _showAll ? null : states[i]?.hidden,
                    passedWordIndices: states[i]?.sung,
                    passedColor: Colors.black,
                    activeWordIndex: states[i]?.active,
                    activeProgress: states[i]?.progress ?? 0,
                    activeColor: Colors.blue,
                    style: WordProgressStyle.whole,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
