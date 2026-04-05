# Changelog

## 0.0.2

- Add vector outline rendering via `getOutline` using `FT_Outline_Decompose`
- Add kashida justification toggle (`justify` parameter) for `renderLine` and `getOutline`
- Add per-glyph word index for word-by-word animation
- Add `ArabicOutlinePainter` for Canvas-based rendering
- Restructure lib into `src/` (native_structs, models, painter, api)

## 0.0.1

- Initial project setup with Flutter FFI plugin scaffold
- Integrate HarfBuzz for Arabic text shaping (RTL, script-aware)
- Integrate FreeType for glyph rasterization
- Add `shapeLine` and `renderLine` APIs via dart:ffi
- Android and iOS platform support
