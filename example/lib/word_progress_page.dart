import 'package:flutter/material.dart';
import 'package:arabic_text_justification/arabic_text_justification.dart';

import 'common.dart';
import 'main.dart';

class _GlobalTiming {
  final int lineIndex;
  final int wordIndex;
  final Duration start;
  final Duration end;

  const _GlobalTiming(this.lineIndex, this.wordIndex, this.start, this.end);
}

class _LineState {
  final Set<int> sung = {};
  int? active;
  double progress = 0;
}

const _wordDuration = Duration(milliseconds: 500);

final List<_GlobalTiming> _timings = () {
  final list = <_GlobalTiming>[];
  var cursor = Duration.zero;
  for (var li = 0; li < page3Lines.length; li++) {
    for (var wi = 0; wi < page3Lines[li].words.length; wi++) {
      list.add(_GlobalTiming(li, wi, cursor, cursor + _wordDuration));
      cursor += _wordDuration;
    }
  }
  return list;
}();

final Duration _total = _timings.isEmpty ? Duration.zero : _timings.last.end;

Map<int, _LineState> _statesAt(Duration position) {
  final byLine = <int, _LineState>{};
  for (final t in _timings) {
    final s = byLine.putIfAbsent(t.lineIndex, _LineState.new);
    if (position >= t.end) {
      s.sung.add(t.wordIndex);
    } else if (s.active == null && position >= t.start) {
      s.active = t.wordIndex;
      final total = t.end - t.start;
      s.progress = total > Duration.zero
          ? (position - t.start).inMicroseconds / total.inMicroseconds
          : 1.0;
    }
  }
  return byLine;
}

class WordProgressPage extends StatefulWidget {
  const WordProgressPage({super.key});

  @override
  State<WordProgressPage> createState() => _WordProgressPageState();
}

class _WordProgressPageState extends State<WordProgressPage>
    with
        SingleTickerProviderStateMixin<WordProgressPage>,
        PlaybackClockMixin<WordProgressPage> {
  @override
  Duration get total => _total;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PlaybackControls(
          position: position,
          total: total,
          isPlaying: isPlaying,
          onTogglePlay: togglePlay,
          onReset: reset,
          onSeek: seek,
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: ValueListenableBuilder<Duration>(
              valueListenable: position,
              builder: (_, pos, __) {
                final states = _statesAt(pos);
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
                          passedHighlightColor:
                              Colors.grey.withValues(alpha: 0.25),
                          activeWordIndex: states[i]?.active,
                          activeProgress: states[i]?.progress ?? 0,
                          activeHighlightColor:
                              Colors.grey.withValues(alpha: 0.55),
                          style: WordProgressStyle.whole,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
