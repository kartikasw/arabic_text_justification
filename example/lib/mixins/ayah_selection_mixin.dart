import 'package:flutter/material.dart';

import '../main.dart';

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
    final ayahIdx = ayahOf(lineIndex, wordIndex);
    if (ayahIdx != null) {
      final pairs = _ayahIndex[ayahIdx];
      if (pairs != null) {
        final ayah = pairs.map((p) => page3Lines[p.$1].words[p.$2]).join(' ');
        _showTap('Ayah', ayah);
      }
    }
    setState(() {
      _selectedWord = null;
      _selectedAyah = _selectedAyah == ayahIdx ? null : ayahIdx;
    });
  }
}
