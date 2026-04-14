# Changelog

## 0.1.0

- Add `JustificationFont` enum exposing the bundled `digitalKhatt` font with a `load()` helper that copies the asset to the application support directory and returns its path
- Ship prebuilt native binaries for Android and iOS; drop HarfBuzz/FreeType git submodules so consumers no longer need to build them from source
- Implement kashida justification via the font's `LTAT`/`RTAT` variable-font axes instead of glyph-level tatweel insertion
- Tighten kashida solver: bracket the full axis range and return the upper bracket so justified lines reach the target width instead of undershooting
- Use available line width when sizing justified bitmaps and outlines so equal-width lines are no longer clipped

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
