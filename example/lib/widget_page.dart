import 'dart:async';

import 'package:flutter/material.dart';
import 'package:arabic_text_justification/arabic_text_justification.dart';

import 'main.dart';

const _verseMarker = '۝';

class WidgetPage extends StatefulWidget {
  const WidgetPage({super.key});

  @override
  State<WidgetPage> createState() => _WidgetPageState();
}

class _WidgetPageState extends State<WidgetPage> {
  double _fontSize = 24;
  double _renderedFontSize = 24;
  Timer? _debounce;

  int? _selectedAyah;
  (int, int)? _selectedWord;
  late final Map<int, List<(int, int)>> _ayahIndex = buildAyahIndex(page3Lines);

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onFontSizeChanged(double v) {
    setState(() => _fontSize = v);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _renderedFontSize = v);
    });
  }

  int? _ayahOf(int lineIndex, int wordIndex) {
    for (final entry in _ayahIndex.entries) {
      for (final pair in entry.value) {
        if (pair.$1 == lineIndex && pair.$2 == wordIndex) return entry.key;
      }
    }
    return null;
  }

  Set<int>? _highlightsFor(int lineIndex) {
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
    if (word != null && word.$1 == lineIndex) {
      return {word.$2};
    }
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

  void _onWordTap(int lineIndex, int wordIndex, String word) {
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

  void _onMarkerTap(int lineIndex, int wordIndex, String word) {
    final ayah = _ayahOf(lineIndex, wordIndex);
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Text('Font size:'),
              Expanded(
                child: Slider(
                  value: _fontSize,
                  min: 8,
                  max: 64,
                  label: _fontSize.round().toString(),
                  onChanged: _onFontSizeChanged,
                ),
              ),
              Text(_fontSize.round().toString()),
              const SizedBox(width: 8),
              if (_selectedAyah != null)
                Text('Ayah: $_selectedAyah',
                    style: const TextStyle(color: Color(0xFF2E7D32))),
              if (_selectedWord != null)
                Text('Word: ${_selectedWord!.$1},${_selectedWord!.$2}',
                    style: const TextStyle(color: Color(0xFF2E7D32))),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: [
                JustifiedArabicLine(
                  words: page3Lines[0].words,
                  justify: page3Lines[0].justify,
                  fontSize: _renderedFontSize,
                ),
                for (int i = 1; i < page3Lines.length; i++)
                  JustifiedArabicLine(
                    words: page3Lines[i].words,
                    justify: page3Lines[i].justify,
                    fontSize: _renderedFontSize,
                    verseMarker: _verseMarker,
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    highlightedWordIndices: _highlightsFor(i),
                    onWordTap: (idx, w) => _onWordTap(i, idx, w),
                    onMarkerTap: (idx, w) => _onMarkerTap(i, idx, w),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
