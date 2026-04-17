import 'package:flutter/material.dart';
import 'package:arabic_text_justification/arabic_text_justification.dart';

import 'common.dart';
import 'main.dart';

const _verseMarker = '۝';
const _wordDuration = Duration(milliseconds: 500);

class _GlobalTiming {
  final int lineIndex;
  final int wordIndex;
  final Duration start;
  final Duration end;

  const _GlobalTiming(this.lineIndex, this.wordIndex, this.start, this.end);
}

class _LineState {
  final Set<int> sung = {};
  final Set<int> hidden = {};
  int? active;
  double progress = 0;
}

final List<_GlobalTiming> _timings = () {
  final list = <_GlobalTiming>[];
  var cursor = Duration.zero;
  for (var li = 0; li < page3Lines.length; li++) {
    for (var wi = 0; wi < page3Lines[li].words.length; wi++) {
      if (page3Lines[li].words[wi].contains(_verseMarker)) continue;
      list.add(_GlobalTiming(li, wi, cursor, cursor + _wordDuration));
      cursor += _wordDuration;
    }
  }
  return list;
}();

final Duration _total = _timings.isEmpty ? Duration.zero : _timings.last.end;

Map<int, _LineState> _statesAt(Duration position) {
  final byLine = <int, _LineState>{
    for (var i = 0; i < page3Lines.length; i++) i: _LineState(),
  };
  for (final t in _timings) {
    final s = byLine[t.lineIndex]!;
    if (position >= t.end) {
      s.sung.add(t.wordIndex);
    } else if (s.active == null && position >= t.start) {
      s.active = t.wordIndex;
      final total = t.end - t.start;
      s.progress = total > Duration.zero
          ? (position - t.start).inMicroseconds / total.inMicroseconds
          : 1.0;
    } else if (position < t.start) {
      s.hidden.add(t.wordIndex);
    }
  }
  return byLine;
}

class HiddenPage extends StatefulWidget {
  const HiddenPage({super.key});

  @override
  State<HiddenPage> createState() => _HiddenPageState();
}

class _HiddenPageState extends State<HiddenPage>
    with
        SingleTickerProviderStateMixin<HiddenPage>,
        PlaybackClockMixin<HiddenPage> {
  @override
  Duration get total => _total;

  bool _showAll = false;

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
              Switch(
                value: _showAll,
                onChanged: (v) => setState(() => _showAll = v),
              ),
            ],
          ),
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
                        verseMarker: _verseMarker,
                        wordProgress: WordProgress(
                          hiddenWordIndices:
                              _showAll ? null : states[i]?.hidden,
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
          ),
        ),
      ],
    );
  }
}
