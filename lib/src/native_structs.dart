import 'dart:ffi';

final class NativeGlyphInfo extends Struct {
  @Int32()
  external int glyphId;
  @Float()
  external double xOffset;
  @Float()
  external double yOffset;
  @Float()
  external double xAdvance;
}

final class NativeLineResult extends Struct {
  external Pointer<NativeGlyphInfo> glyphs;
  @Int32()
  external int glyphCount;
  @Float()
  external double totalWidth;
}

final class NativeWordRect extends Struct {
  @Float()
  external double x;
  @Float()
  external double y;
  @Float()
  external double width;
  @Float()
  external double height;
}

final class NativeRenderResult extends Struct {
  external Pointer<Uint8> pixels;
  @Int32()
  external int bmpWidth;
  @Int32()
  external int bmpHeight;
  external Pointer<NativeWordRect> wordRects;
  @Int32()
  external int wordCount;
}

final class NativePathCommand extends Struct {
  @Int32()
  external int type;
  @Float()
  external double x;
  @Float()
  external double y;
  @Float()
  external double x1;
  @Float()
  external double y1;
  @Float()
  external double x2;
  @Float()
  external double y2;
}

final class NativeGlyphOutline extends Struct {
  external Pointer<NativePathCommand> commands;
  @Int32()
  external int commandCount;
  @Float()
  external double offsetX;
  @Float()
  external double offsetY;
}

final class NativeOutlineResult extends Struct {
  external Pointer<NativeGlyphOutline> glyphs;
  @Int32()
  external int glyphCount;
  external Pointer<NativeWordRect> wordRects;
  @Int32()
  external int wordCount;
  @Float()
  external double ascender;
  @Float()
  external double descender;
  @Float()
  external double totalWidth;
}
