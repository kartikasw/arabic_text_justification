class GlobalTiming {
  final int lineIndex;
  final int wordIndex;
  final Duration start;
  final Duration end;

  const GlobalTiming(this.lineIndex, this.wordIndex, this.start, this.end);
}

class LineState {
  final Set<int> sung = {};
  final Set<int> hidden = {};
  int? active;
  double progress = 0;
}
