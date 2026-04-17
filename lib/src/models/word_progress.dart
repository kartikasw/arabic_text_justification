import 'package:flutter/painting.dart';

enum WordProgressStyle {
  sweep,
  whole,
  ;
}

class WordProgress {
  final Set<int>? passedWordIndices;

  final Color passedColor;

  final int? activeWordIndex;

  final double activeProgress;

  final Color activeColor;

  final WordProgressStyle style;

  const WordProgress({
    this.passedWordIndices,
    this.passedColor = const Color(0x3300BCD4),
    this.activeWordIndex,
    this.activeProgress = 0,
    this.activeColor = const Color(0x66FF9800),
    this.style = WordProgressStyle.sweep,
  });

  bool get isEmpty =>
      (passedWordIndices == null || passedWordIndices!.isEmpty) &&
      (activeWordIndex == null ||
          (style == WordProgressStyle.sweep && activeProgress <= 0));
}
