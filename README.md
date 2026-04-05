# arabic_text_justification

A Flutter FFI plugin for Arabic text justification with kashida stretching. It uses [HarfBuzz](https://harfbuzz.github.io/) for text shaping and [FreeType](https://freetype.org/) for glyph rasterization, all running natively through Dart FFI.

## Screenshot

<img src="screenshot.png" width="300" alt="Arabic text justification example" />

## Problem

Arabic text in most mobile frameworks is justified by adding spaces between words, the same way Latin text is handled. This doesn't work well for Arabic because the script is cursive — words are connected strokes, and wide gaps between them break the visual flow. Proper Arabic justification uses **kashida** (also called tatweel), which stretches specific connective strokes within letters to fill the line naturally without disrupting readability.

Flutter's built-in text widgets don't support kashida-based justification. This plugin solves that by using a custom HarfBuzz fork that understands how to stretch Arabic letters at the right points.

## How It Works

1. **Text shaping** — HarfBuzz (DigitalKhatt's justification branch) analyzes the Arabic text, applies correct letter forms and ligatures, and stretches kashida where needed to justify the line to the given width.
2. **Glyph rasterization** — FreeType renders each shaped glyph into a bitmap.
3. **Pixel output** — The C++ layer composites all glyphs into a single RGBA buffer and computes per-word bounding rectangles.
4. **Flutter display** — Dart FFI bridges the native output to a Flutter `ui.Image`, ready to display with `RawImage`.

## Features

- Arabic text rendering with correct RTL layout and ligature handling
- Dynamic kashida-based justification using DigitalKhatt's HarfBuzz justification branch
- HarfBuzz text shaping with FreeType glyph rasterization via Dart FFI
- Word-level bounding boxes for hit-testing and highlighting
- Automatic line justification to fill available width
- Android and iOS support

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  arabic_text_justification: ^0.0.1
```

## Usage

```dart
import 'package:arabic_text_justification/arabic_text_justification.dart';

// Render a justified line of Arabic text
final result = await ArabicTextJustification.renderLine(
  fontPath,       // path to .otf font file on disk
  'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ',
  fontSize,       // font size in pixels
  availableWidth, // target line width in pixels
);

// Display the rendered image
RawImage(
  image: result.image,
  fit: BoxFit.fill,
);

// Use word bounding boxes for tap detection
for (final rect in result.wordRects) {
  print(rect.toRect()); // Rect for each word
}
```

### Font Setup

The plugin requires an OpenType font file that supports DigitalKhatt's justification features. A bundled font (`digitalkhatt.otf`) is included in the plugin assets. To use it:

```dart
// Copy the bundled font to a file path accessible by the native layer
final data = await rootBundle.load('packages/arabic_text_justification/assets/digitalkhatt.otf');
final file = File('${(await getApplicationSupportDirectory()).path}/digitalkhatt.otf');
await file.writeAsBytes(data.buffer.asUint8List());
final fontPath = file.path;
```

## API Reference

### `ArabicTextJustification.renderLine(fontPath, text, fontSize, availableWidth)`

Shapes and rasterizes a line of Arabic text into a justified RGBA bitmap.

**Parameters:**
- `fontPath` (`String`) — Absolute path to an OpenType font file
- `text` (`String`) — Arabic text to render
- `fontSize` (`double`) — Font size in pixels
- `availableWidth` (`double`) — Target line width in pixels for justification

**Returns:** `Future<RenderResult?>` containing:
- `image` — Flutter `ui.Image` ready for display
- `bmpWidth`, `bmpHeight` — Bitmap dimensions in pixels
- `wordRects` — List of `WordRect` with per-word bounding boxes

### `ArabicTextJustification.shapeLine(fontPath, text, fontSize, availableWidth)`

Shapes text and returns glyph metrics without rasterizing. Useful for layout calculations.

**Parameters:** Same as `renderLine`.

**Returns:** `ShapeResult` containing:
- `glyphs` — List of `GlyphInfo` with glyph IDs, offsets, and advances
- `totalWidth` — Total shaped line width in pixels

## Project Structure

```
lib/    Dart FFI bindings and public API
src/    C++ wrapper (HarfBuzz + FreeType integration)
android/    Android build configuration (CMake)
ios/    iOS build configuration (CocoaPods)
third_party/
  harfbuzz/    DigitalKhatt's HarfBuzz fork (justification branch)
  freetype/    FreeType library
assets/
  digitalkhatt.otf    Bundled font with justification support
```

## Acknowledgments

- [DigitalKhatt](https://digitalkhatt.org/) — Arabic justification and font technology
- [HarfBuzz](https://harfbuzz.github.io/) — Text shaping engine (justification branch by DigitalKhatt)
- [FreeType](https://freetype.org/) — Font rendering library

Portions of this software are copyright (c) 2023 The FreeType Project (https://freetype.org). All rights reserved.

See [THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES) for full license details.

## License

MIT — see [LICENSE](LICENSE) for details.
