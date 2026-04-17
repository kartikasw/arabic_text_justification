import 'package:flutter/material.dart';
import 'package:arabic_text_justification/arabic_text_justification.dart';

import 'main.dart';
import 'mixins/playback_mixin.dart';
import 'widgets/playback_controls.dart';
import 'widgets/scrollable_page.dart';

class WordProgressPage extends StatefulWidget {
  const WordProgressPage({super.key});

  @override
  State<WordProgressPage> createState() => _WordProgressPageState();
}

class _WordProgressPageState extends State<WordProgressPage>
    with
        SingleTickerProviderStateMixin<WordProgressPage>,
        PlaybackMixin<WordProgressPage> {
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
                  fontSize: 20,
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  wordProgress: WordProgress(
                    passedWordIndices: states[i]?.sung,
                    passedHighlightColor: Colors.grey.withValues(alpha: 0.25),
                    activeWordIndex: states[i]?.active,
                    activeProgress: states[i]?.progress ?? 0,
                    activeHighlightColor: Colors.grey.withValues(alpha: 0.55),
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
