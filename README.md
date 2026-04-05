# arabic_text_justification

A Flutter FFI plugin for Arabic text rendering with kashida-based justification using [HarfBuzz](https://harfbuzz.github.io/) and [FreeType](https://freetype.org/).

Supports two rendering modes: **bitmap** and **vector outline**.

## Demo

<img width="200" height="445" alt="screenshot" src="https://github.com/user-attachments/assets/22aee348-7d6f-431e-9218-f6a4fdce5423" />
&nbsp;&nbsp;&nbsp;&nbsp;
<img width="200" height="445" alt="demo" src="https://github.com/user-attachments/assets/c7c25982-927a-4f87-b6f6-7a5263752579" />

## How It Works

1. **Text shaping** — HarfBuzz applies Arabic letter forms, ligatures, and optional kashida justification.
2. **Glyph processing** — FreeType either rasterizes glyphs to bitmap or extracts vector bezier outlines.
3. **Word mapping** — per-word bounding rectangles and glyph-to-word indices for hit-testing and animation.

## Usage

```dart
import 'package:arabic_text_justification/arabic_text_justification.dart';

// Bitmap rendering
final result = await ArabicTextJustification.renderLine(
  fontPath, text, fontSize, availableWidth,
  justify: true,
);
RawImage(image: result.image, fit: BoxFit.fill);

// Vector outline rendering
final outline = ArabicTextJustification.getOutline(
  fontPath, text, fontSize, availableWidth,
  justify: true,
);
CustomPaint(painter: ArabicOutlinePainter(outline: outline));
```

## Acknowledgments

- [DigitalKhatt](https://digitalkhatt.org/) — Arabic justification and font technology
- [HarfBuzz](https://harfbuzz.github.io/) — Text shaping engine (justification branch by DigitalKhatt)
- [FreeType](https://freetype.org/) — Font rendering library

Portions of this software are copyright (c) 2023 The FreeType Project (https://freetype.org). All rights reserved.

See [THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES) for full license details.

## License

MIT — see [LICENSE](LICENSE) for details.
