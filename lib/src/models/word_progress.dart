import 'package:flutter/painting.dart';

enum WordProgressStyle {
  sweep,
  whole,
  ;
}

class WordProgress {
  final Set<int>? passedWordIndices;

  final Color? passedColor;

  final Color? passedHighlightColor;

  final int? activeWordIndex;

  final double activeProgress;

  final Color? activeColor;

  final Color? activeHighlightColor;

  final WordProgressStyle style;

  final Set<int>? hiddenWordIndices;

  const WordProgress({
    this.passedWordIndices,
    this.passedColor,
    this.passedHighlightColor,
    this.activeWordIndex,
    this.activeProgress = 0,
    this.activeColor,
    this.activeHighlightColor,
    this.style = WordProgressStyle.sweep,
    this.hiddenWordIndices,
  });

  bool get isEmpty =>
      (passedWordIndices == null || passedWordIndices!.isEmpty) &&
      (activeWordIndex == null ||
          (style == WordProgressStyle.sweep && activeProgress <= 0));
}
