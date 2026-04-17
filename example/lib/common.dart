import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'main.dart';

mixin AyahSelectionMixin<T extends StatefulWidget> on State<T> {
  int? _selectedAyah;
  (int, int)? _selectedWord;
  late final Map<int, List<(int, int)>> _ayahIndex = buildAyahIndex(page3Lines);

  int? get selectedAyah => _selectedAyah;

  (int, int)? get selectedWord => _selectedWord;

  int? ayahOf(int lineIndex, int wordIndex) {
    for (final entry in _ayahIndex.entries) {
      for (final pair in entry.value) {
        if (pair.$1 == lineIndex && pair.$2 == wordIndex) return entry.key;
      }
    }
    return null;
  }

  Set<int>? highlightsFor(int lineIndex) {
    final ayah = _selectedAyah;
    if (ayah != null) {
      final pairs = _ayahIndex[ayah];
      if (pairs == null) return null;
      return {
        for (final p in pairs)
          if (p.$1 == lineIndex) p.$2,
      };
    }
    final word = _selectedWord;
    if (word != null && word.$1 == lineIndex) return {word.$2};
    return null;
  }

  void _showTap(String label, String text) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(SnackBar(
      content: Text('$label: $text'),
      duration: const Duration(seconds: 1),
    ));
  }

  void onWordTap(int lineIndex, int wordIndex, String word) {
    _showTap('Word', word);
    setState(() {
      _selectedAyah = null;
      final current = _selectedWord;
      _selectedWord = (current != null &&
              current.$1 == lineIndex &&
              current.$2 == wordIndex)
          ? null
          : (lineIndex, wordIndex);
    });
  }

  void onMarkerTap(int lineIndex, int wordIndex, String word) {
    final ayah = ayahOf(lineIndex, wordIndex);
    if (ayah != null) {
      final pairs = _ayahIndex[ayah];
      if (pairs != null) {
        final verse = pairs.map((p) => page3Lines[p.$1].words[p.$2]).join(' ');
        _showTap('Verse', verse);
      }
    }
    setState(() {
      _selectedWord = null;
      _selectedAyah = _selectedAyah == ayah ? null : ayah;
    });
  }
}

mixin FontSizeMixin<T extends StatefulWidget> on State<T> {
  double _fontSize = 20;
  double _renderedFontSize = 20;
  Timer? _fontDebounce;

  double get fontSize => _fontSize;

  double get renderedFontSize => _renderedFontSize;

  @override
  void dispose() {
    _fontDebounce?.cancel();
    super.dispose();
  }

  void onFontSizeChanged(double v) {
    setState(() => _fontSize = v);
    _fontDebounce?.cancel();
    _fontDebounce = Timer(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _renderedFontSize = v);
    });
  }
}

mixin PlaybackClockMixin<T extends StatefulWidget>
    on State<T>, SingleTickerProviderStateMixin<T> {
  late final Ticker _ticker = createTicker(_onTick);
  final Stopwatch _clock = Stopwatch();
  final ValueNotifier<Duration> position = ValueNotifier(Duration.zero);
  Duration _baseline = Duration.zero;
  bool _isPlaying = false;

  Duration get total;

  bool get isPlaying => _isPlaying;

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

class FontSizeHeader extends StatelessWidget {
  final double fontSize;
  final ValueChanged<double> onChanged;
  final int? selectedAyah;
  final (int, int)? selectedWord;

  const FontSizeHeader({
    super.key,
    required this.fontSize,
    required this.onChanged,
    this.selectedAyah,
    this.selectedWord,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Text('Font size:'),
          Expanded(
            child: Slider(
              value: fontSize,
              min: 8,
              max: 64,
              label: fontSize.round().toString(),
              onChanged: onChanged,
            ),
          ),
          Text(fontSize.round().toString()),
          const SizedBox(width: 8),
          if (selectedAyah != null)
            Text('Ayah: $selectedAyah',
                style: const TextStyle(color: Color(0xFF2E7D32))),
          if (selectedWord != null)
            Text('Word: ${selectedWord!.$1},${selectedWord!.$2}',
                style: const TextStyle(color: Color(0xFF2E7D32))),
        ],
      ),
    );
  }
}

class PlaybackControls extends StatelessWidget {
  final ValueListenable<Duration> position;
  final Duration total;
  final bool isPlaying;
  final VoidCallback onTogglePlay;
  final VoidCallback onReset;
  final ValueChanged<double> onSeek;

  const PlaybackControls({
    super.key,
    required this.position,
    required this.total,
    required this.isPlaying,
    required this.onTogglePlay,
    required this.onReset,
    required this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          ValueListenableBuilder<Duration>(
            valueListenable: position,
            builder: (_, pos, __) {
              final fraction = total.inMilliseconds == 0
                  ? 0.0
                  : pos.inMilliseconds / total.inMilliseconds;
              return Slider(
                value: fraction.clamp(0.0, 1.0),
                onChanged: onSeek,
              );
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filled(
                onPressed: onTogglePlay,
                icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
              ),
              const SizedBox(width: 12),
              IconButton.filledTonal(
                onPressed: onReset,
                icon: const Icon(Icons.stop),
              ),
              const SizedBox(width: 16),
              ValueListenableBuilder<Duration>(
                valueListenable: position,
                builder: (_, pos, __) => Text(
                  '${pos.inSeconds}s / ${total.inSeconds}s',
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
