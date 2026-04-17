# arabic_text_justification

A Flutter FFI plugin for Arabic text rendering with kashida-based justification using [HarfBuzz](https://harfbuzz.github.io/) and [FreeType](https://freetype.org/).

Ships two high-level line widgets plus the underlying shaping API. Supports both **bitmap** and **vector outline** rendering.

## Demo
<img width="150" alt="Home" src="https://github.com/user-attachments/assets/28c6de69-8540-483c-94c9-cbb1b67564c6" />
<img width="150" alt="Recording 1" src="https://github.com/user-attachments/assets/9dc766d5-63ae-4176-9e05-478b4ba57a1a" />
<img width="150" alt="Recording 2" src="https://github.com/user-attachments/assets/f245e9d1-5e4c-4943-a461-a17605b0b275" />
<img width="150" alt="Recording 3" src="https://github.com/user-attachments/assets/e590cd7e-5143-481c-aee6-9dedc5a780ef" />

## How It Works

1. **Text shaping** — HarfBuzz applies Arabic letter forms, ligatures, and optional kashida justification.
2. **Glyph processing** — FreeType either rasterizes glyphs to a bitmap or extracts vector bezier outlines.
3. **Word mapping** — per-word bounding rectangles and glyph-to-word indices are returned for hit-testing and animation.

## Capabilities

### Render a justified RTL line

Either `JustifiedArabicLine` (vector) or `JustifiedArabicBitmapLine` (bitmap) takes a list of words and renders the line.

```dart
JustifiedArabicLine(
  words: ['بِسْمِ', 'ٱللَّهِ', 'ٱلرَّحْمَٰنِ', 'ٱلرَّحِيمِ'],
  justify: true,
  fontSize: 24, // or null to auto-fit
  padding: EdgeInsets.symmetric(vertical: 4),
)
```

### Tap a word — or a verse marker

Pass a `verseMarker` substring. Regular word taps fire `onWordTap(index, word)`; words containing the marker fire `onMarkerTap(index, word)` instead. Both return the tapped word's text + its index.

```dart
JustifiedArabicLine(
  words: line.words,
  verseMarker: '۝',
  onWordTap: (i, w) => print('word: $w'),
  onMarkerTap: (i, w) => print('verse end: $w'),
)
```

### Highlight arbitrary words

`highlightedWordIndices` + `highlightColor` paint a background behind any subset of words, intended for tap-selection feedback. Independent of any animation.

```dart
JustifiedArabicLine(
  words: line.words,
  highlightedWordIndices: {2, 3, 4},
  highlightColor: Colors.blue.withOpacity(0.2),
)
```

### Animate progress through words

`WordProgress` bundles passed/active word state for read-along / recitation / subtitle-style animation. Two independent effects per state, each opt-in:

- **Background highlight** — `passedHighlightColor` / `activeHighlightColor`
- **Glyph tint** — `passedColor` / `activeColor` (falls back to default text color when null)

`WordProgressStyle` picks the active-word animation:

- `.sweep` — right-to-left partial fill driven by `activeProgress` (0..1)
- `.whole` — discrete on/off per word

```dart
JustifiedArabicLine(
  words: line.words,
  wordProgress: WordProgress(
    passedWordIndices: {0, 1, 2},
    passedColor: Colors.green,
    activeWordIndex: 3,
    activeProgress: 0.6,
    activeColor: Colors.orange,
    style: WordProgressStyle.sweep,
  ),
)
```

### Hide words until they're recited

`hiddenWordIndices` omits glyphs, highlights, active fill, and tap hits for the listed words. Combined with `verseMarker`, callers can keep ayah markers visible while hiding the verse body, then progressively reveal words as the reader recites them.

```dart
JustifiedArabicLine(
  words: line.words,
  verseMarker: '۝',
  wordProgress: WordProgress(
    hiddenWordIndices: notYetRevealed,
    passedWordIndices: revealed,
    passedColor: Colors.black,
  ),
)
```

## Example

See `example/` — four tabs cover the Widget, Bitmap, timer-driven progress animation, and the memorization / reveal mode end-to-end.

## Acknowledgments

- [DigitalKhatt](https://digitalkhatt.org/) — Arabic justification and font technology
- [HarfBuzz](https://harfbuzz.github.io/) — Text shaping engine (justification branch by DigitalKhatt)
- [FreeType](https://freetype.org/) — Font rendering library

Portions of this software are copyright (c) 2023 The FreeType Project (https://freetype.org). All rights reserved.

See [THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES) for full license details.

## License

MIT — see [LICENSE](LICENSE) for details.
