import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:ffi/ffi.dart';

// Native structs

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

// Dart classes

class GlyphInfo {
  final int glyphId;
  final double xOffset;
  final double yOffset;
  final double xAdvance;

  GlyphInfo({
    required this.glyphId,
    required this.xOffset,
    required this.yOffset,
    required this.xAdvance,
  });
}

class ShapeResult {
  final List<GlyphInfo> glyphs;
  final double totalWidth;

  ShapeResult({required this.glyphs, required this.totalWidth});
}

class WordRect {
  final double x;
  final double y;
  final double width;
  final double height;

  WordRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  ui.Rect toRect() => ui.Rect.fromLTWH(x, y, width, height);
}

class RenderResult {
  final ui.Image image;
  final int bmpWidth;
  final int bmpHeight;
  final List<WordRect> wordRects;

  RenderResult({
    required this.image,
    required this.bmpWidth,
    required this.bmpHeight,
    required this.wordRects,
  });
}

class FlutterArabicJustification {
  static final DynamicLibrary _lib = Platform.isAndroid
      ? DynamicLibrary.open('libflutter_arabic_justification.so')
      : DynamicLibrary.process();

  static final _shapeLine = _lib.lookupFunction<
      Pointer<NativeLineResult> Function(
          Pointer<Utf8>, Pointer<Utf8>, Float, Float),
      Pointer<NativeLineResult> Function(
          Pointer<Utf8>, Pointer<Utf8>, double, double)>('shape_line');

  static final _freeLineResult = _lib.lookupFunction<
      Void Function(Pointer<NativeLineResult>),
      void Function(Pointer<NativeLineResult>)>('free_line_result');

  static final _renderLine = _lib.lookupFunction<
      Pointer<NativeRenderResult> Function(
          Pointer<Utf8>, Pointer<Utf8>, Float, Float),
      Pointer<NativeRenderResult> Function(
          Pointer<Utf8>, Pointer<Utf8>, double, double)>('render_line');

  static final _freeRenderResult = _lib.lookupFunction<
      Void Function(Pointer<NativeRenderResult>),
      void Function(Pointer<NativeRenderResult>)>('free_render_result');

  static ShapeResult shapeLine(
    String fontPath,
    String text,
    double fontSize,
    double availableWidth,
  ) {
    final fontPathPtr = fontPath.toNativeUtf8();
    final textPtr = text.toNativeUtf8();
    final result = _shapeLine(fontPathPtr, textPtr, fontSize, availableWidth);

    final ref = result.ref;
    final glyphs = <GlyphInfo>[];
    for (int i = 0; i < ref.glyphCount; i++) {
      final g = ref.glyphs[i];
      glyphs.add(GlyphInfo(
        glyphId: g.glyphId,
        xOffset: g.xOffset,
        yOffset: g.yOffset,
        xAdvance: g.xAdvance,
      ));
    }
    final totalWidth = ref.totalWidth;

    _freeLineResult(result);
    calloc.free(fontPathPtr);
    calloc.free(textPtr);

    return ShapeResult(glyphs: glyphs, totalWidth: totalWidth);
  }

  static Future<RenderResult?> renderLine(
    String fontPath,
    String text,
    double fontSize,
    double availableWidth,
  ) async {
    final fontPathPtr = fontPath.toNativeUtf8();
    final textPtr = text.toNativeUtf8();
    final result = _renderLine(fontPathPtr, textPtr, fontSize, availableWidth);

    calloc.free(fontPathPtr);
    calloc.free(textPtr);

    if (result == nullptr) return null;

    final ref = result.ref;
    final width = ref.bmpWidth;
    final height = ref.bmpHeight;
    final byteCount = width * height * 4;

    // Copy pixel data
    final pixels = Uint8List(byteCount);
    pixels.setAll(0, ref.pixels.asTypedList(byteCount));

    // Copy word rects
    final wordRects = <WordRect>[];
    for (int i = 0; i < ref.wordCount; i++) {
      final r = ref.wordRects[i];
      wordRects.add(WordRect(
        x: r.x,
        y: r.y,
        width: r.width,
        height: r.height,
      ));
    }

    _freeRenderResult(result);

    // Decode pixels into ui.Image
    final buffer = await ui.ImmutableBuffer.fromUint8List(pixels);
    final descriptor = ui.ImageDescriptor.raw(
      buffer,
      width: width,
      height: height,
      pixelFormat: ui.PixelFormat.rgba8888,
    );
    final codec = await descriptor.instantiateCodec();
    final frame = await codec.getNextFrame();

    return RenderResult(
      image: frame.image,
      bmpWidth: width,
      bmpHeight: height,
      wordRects: wordRects,
    );
  }
}
