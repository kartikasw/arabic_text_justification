import 'package:flutter/painting.dart';

class WordColorSpan {
  final int wordIndex;
  final int start;
  final int end;
  final Color color;

  const WordColorSpan({
    required this.wordIndex,
    required this.start,
    required this.end,
    required this.color,
  });
}
