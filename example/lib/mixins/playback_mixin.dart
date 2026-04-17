import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../constants/constants.dart';
import '../main.dart';
import '../models/playback.dart';

mixin PlaybackMixin<T extends StatefulWidget>
    on State<T>, SingleTickerProviderStateMixin<T> {
  late final Ticker _ticker = createTicker(_onTick);
  final Stopwatch _clock = Stopwatch();
  final ValueNotifier<Duration> position = ValueNotifier(Duration.zero);
  Duration _baseline = Duration.zero;
  bool _isPlaying = false;

  @protected
  bool includeWord(int lineIndex, int wordIndex) => true;

  late final List<GlobalTiming> timings = () {
    final list = <GlobalTiming>[];
    var cursor = Duration.zero;
    for (var li = 0; li < page3Lines.length; li++) {
      for (var wi = 0; wi < page3Lines[li].words.length; wi++) {
        if (!includeWord(li, wi)) continue;
        list.add(GlobalTiming(li, wi, cursor, cursor + wordDuration));
        cursor += wordDuration;
      }
    }
    return list;
  }();

  Duration get total => timings.isEmpty ? Duration.zero : timings.last.end;

  bool get isPlaying => _isPlaying;

  Map<int, LineState> statesAt(Duration position) {
    final byLine = <int, LineState>{
      for (var i = 0; i < page3Lines.length; i++) i: LineState(),
    };
    for (final t in timings) {
      final s = byLine[t.lineIndex]!;
      if (position >= t.end) {
        s.sung.add(t.wordIndex);
      } else if (s.active == null && position >= t.start) {
        s.active = t.wordIndex;
        final span = t.end - t.start;
        s.progress = span > Duration.zero
            ? (position - t.start).inMicroseconds / span.inMicroseconds
            : 1.0;
      } else if (position < t.start) {
        s.hidden.add(t.wordIndex);
      }
    }
    return byLine;
  }

  @override
  void dispose() {
    _ticker.dispose();
    position.dispose();
    super.dispose();
  }

  void _onTick(Duration _) {
    final pos = _baseline + _clock.elapsed;
    if (pos >= total) {
      _ticker.stop();
      _clock.stop();
      position.value = total;
      setState(() => _isPlaying = false);
      return;
    }
    position.value = pos;
  }

  void togglePlay() {
    if (_isPlaying) {
      _ticker.stop();
      _clock.stop();
      _baseline = position.value;
      setState(() => _isPlaying = false);
      return;
    }
    if (position.value >= total) position.value = Duration.zero;
    _baseline = position.value;
    _clock
      ..reset()
      ..start();
    _ticker.start();
    setState(() => _isPlaying = true);
  }

  void reset() {
    _ticker.stop();
    _clock
      ..stop()
      ..reset();
    _baseline = Duration.zero;
    position.value = Duration.zero;
    setState(() => _isPlaying = false);
  }

  void seek(double fraction) {
    final pos = Duration(
      milliseconds: (fraction * total.inMilliseconds).round(),
    );
    _baseline = pos;
    position.value = pos;
    _clock
      ..reset()
      ..start();
    if (!_isPlaying) _clock.stop();
  }
}
