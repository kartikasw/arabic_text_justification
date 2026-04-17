import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:arabic_text_justification/arabic_text_justification.dart';

import 'main.dart';

/// Minimal timing for the demo, keyed by (line, word) so the flat timing list
/// can fan out to per-line state at render time.
class _GlobalTiming {
  final int lineIndex;
  final int wordIndex;
  final Duration start;
  final Duration end;

  const _GlobalTiming(this.lineIndex, this.wordIndex, this.start, this.end);
}

/// Per-line state the widget consumes.
class _LineState {
  final Set<int> sung = {};
  int? active;
  double progress = 0;
}

/// Synthetic timings across every word on the page: 500 ms per word.
const _wordDuration = Duration(milliseconds: 500);

final List<_GlobalTiming> _timings = () {
  final list = <_GlobalTiming>[];
  var cursor = Duration.zero;
  for (var li = 0; li < page3Lines.length; li++) {
    for (var wi = 0; wi < page3Lines[li].words.length; wi++) {
      list.add(_GlobalTiming(
        li,
        wi,
        cursor,
        cursor + _wordDuration,
      ));
      cursor += _wordDuration;
    }
  }
  return list;
}();

final Duration _total = _timings.isEmpty ? Duration.zero : _timings.last.end;

/// Walks the flat timing list once, producing per-line state. Pure.
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
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final Stopwatch _clock = Stopwatch();
  final ValueNotifier<Duration> _position = ValueNotifier(Duration.zero);
  Duration _baseline = Duration.zero;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _position.dispose();
    super.dispose();
  }

  void _onTick(Duration _) {
    final pos = _baseline + _clock.elapsed;
    if (pos >= _total) {
      _ticker.stop();
      _clock.stop();
      _position.value = _total;
      setState(() => _isPlaying = false);
      return;
    }
    _position.value = pos;
  }

  void _togglePlay() {
    if (_isPlaying) {
      _ticker.stop();
      _clock.stop();
      _baseline = _position.value;
      setState(() => _isPlaying = false);
      return;
    }
    if (_position.value >= _total) _position.value = Duration.zero;
    _baseline = _position.value;
    _clock
      ..reset()
      ..start();
    _ticker.start();
    setState(() => _isPlaying = true);
  }

  void _reset() {
    _ticker.stop();
    _clock
      ..stop()
      ..reset();
    _baseline = Duration.zero;
    _position.value = Duration.zero;
    setState(() => _isPlaying = false);
  }

  void _onSeek(double v) {
    final pos = Duration(
      milliseconds: (v * _total.inMilliseconds).round(),
    );
    _baseline = pos;
    _position.value = pos;
    _clock
      ..reset()
      ..start();
    if (!_isPlaying) _clock.stop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              // Slider rebuilds only when position changes.
              ValueListenableBuilder<Duration>(
                valueListenable: _position,
                builder: (_, pos, __) {
                  final fraction = _total.inMilliseconds == 0
                      ? 0.0
                      : pos.inMilliseconds / _total.inMilliseconds;
                  return Slider(
                    value: fraction.clamp(0.0, 1.0),
                    onChanged: _onSeek,
                  );
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Buttons rebuild only on play/pause via setState.
                  IconButton.filled(
                    onPressed: _togglePlay,
                    icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                  ),
                  const SizedBox(width: 12),
                  IconButton.filledTonal(
                    onPressed: _reset,
                    icon: const Icon(Icons.stop),
                  ),
                  const SizedBox(width: 16),
                  // Label rebuilds only with position.
                  ValueListenableBuilder<Duration>(
                    valueListenable: _position,
                    builder: (_, pos, __) => Text(
                      '${pos.inSeconds}s / ${_total.inSeconds}s',
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Only the lines subtree rebuilds per position change. Scaffold,
        // padding, divider, buttons, scroll view host all stay put.
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: ValueListenableBuilder<Duration>(
              valueListenable: _position,
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
                          passedColor: Colors.grey.withValues(alpha: 0.25),
                          activeWordIndex: states[i]?.active,
                          activeProgress: states[i]?.progress ?? 0,
                          activeColor: Colors.grey.withValues(alpha: 0.55),
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
