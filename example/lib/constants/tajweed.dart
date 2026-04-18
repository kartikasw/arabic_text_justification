import 'package:flutter/painting.dart';
import 'package:arabic_text_justification/arabic_text_justification.dart';

enum TajweedRule {
  ghunnah('Ghunnah', Color(0xFFF57C00)),
  qalqalah('Qalqalah', Color(0xFFD32F2F)),
  ayahMarker('Ayah marker', Color(0xFFB8860B));

  const TajweedRule(this.label, this.color);

  final String label;
  final Color color;
}

typedef RegexColorRule = ({RegExp pattern, Color color});

List<WordColorSpan> colorSpansFromRegex({
  required List<String> words,
  required List<RegexColorRule> rules,
}) {
  final out = <WordColorSpan>[];
  for (var w = 0; w < words.length; w++) {
    final word = words[w];
    for (final r in rules) {
      for (final m in r.pattern.allMatches(word)) {
        if (m.end == m.start) continue;
        out.add(WordColorSpan(
          wordIndex: w,
          start: m.start,
          end: m.end,
          color: r.color,
        ));
      }
    }
  }
  return out;
}

final tajweedRegexRules = <RegexColorRule>[
  (
    pattern: RegExp(r'[من][\u064B-\u0652\u0670]*ّ[\u064B-\u0652\u0670]*'),
    color: TajweedRule.ghunnah.color,
  ),
  (
    pattern: RegExp(r'[قدطجب]ْ'),
    color: TajweedRule.qalqalah.color,
  ),
  (
    pattern: RegExp(r'۝[\u0660-\u0669]+'),
    color: TajweedRule.ayahMarker.color,
  ),
];
