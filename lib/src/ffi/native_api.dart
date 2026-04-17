import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:ffi/ffi.dart';

import 'native_structs.dart';
import '../models/models.dart';

class ArabicTextJustification {
  static final DynamicLibrary _lib = Platform.isAndroid
      ? DynamicLibrary.open('libarabic_text_justification.so')
      : DynamicLibrary.process();

  // ── FFI lookups ──

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
          Pointer<Utf8>, Pointer<Utf8>, Float, Float, Int32),
      Pointer<NativeRenderResult> Function(
          Pointer<Utf8>, Pointer<Utf8>, double, double, int)>('render_line');

  static final _freeRenderResult = _lib.lookupFunction<
      Void Function(Pointer<NativeRenderResult>),
      void Function(Pointer<NativeRenderResult>)>('free_render_result');

  static final _getOutline = _lib.lookupFunction<
      Pointer<NativeOutlineResult> Function(
          Pointer<Utf8>, Pointer<Utf8>, Float, Float, Int32),
      Pointer<NativeOutlineResult> Function(
          Pointer<Utf8>, Pointer<Utf8>, double, double, int)>('get_outline');

  static final _freeOutlineResult = _lib.lookupFunction<
      Void Function(Pointer<NativeOutlineResult>),
      void Function(Pointer<NativeOutlineResult>)>('free_outline_result');

  // ── Public API ──

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
    double availableWidth, {
    bool justify = false,
  }) async {
    final fontPathPtr = fontPath.toNativeUtf8();
    final textPtr = text.toNativeUtf8();
    final result = _renderLine(
        fontPathPtr, textPtr, fontSize, availableWidth, justify ? 1 : 0);

    calloc.free(fontPathPtr);
    calloc.free(textPtr);

    if (result == nullptr) return null;

    final ref = result.ref;
    final width = ref.bmpWidth;
    final height = ref.bmpHeight;
    final byteCount = width * height * 4;

    final pixels = Uint8List(byteCount);
    pixels.setAll(0, ref.pixels.asTypedList(byteCount));

    final wordRects = _copyWordRects(ref.wordRects, ref.wordCount);

    _freeRenderResult(result);

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

  static OutlineResult? getOutline(
    String fontPath,
    String text,
    double fontSize,
    double availableWidth, {
    bool justify = false,
  }) {
    final fontPathPtr = fontPath.toNativeUtf8();
    final textPtr = text.toNativeUtf8();
    final result = _getOutline(
        fontPathPtr, textPtr, fontSize, availableWidth, justify ? 1 : 0);

    calloc.free(fontPathPtr);
    calloc.free(textPtr);

    if (result == nullptr) return null;

    final ref = result.ref;

    final glyphs = <GlyphOutline>[];
    for (int i = 0; i < ref.glyphCount; i++) {
      final g = ref.glyphs[i];
      final commands = <PathCommand>[];
      for (int j = 0; j < g.commandCount; j++) {
        final c = g.commands[j];
        commands.add(PathCommand(
          type: PathCommandType.values[c.type],
          x: c.x,
          y: c.y,
          x1: c.x1,
          y1: c.y1,
          x2: c.x2,
          y2: c.y2,
        ));
      }
      glyphs.add(GlyphOutline(
        commands: commands,
        offsetX: g.offsetX,
        offsetY: g.offsetY,
        wordIndex: g.wordIndex,
        cluster: g.cluster,
      ));
    }

    final wordRects = _copyWordRects(ref.wordRects, ref.wordCount);

    final outlineResult = OutlineResult(
      glyphs: glyphs,
      wordRects: wordRects,
      ascender: ref.ascender,
      descender: ref.descender,
      totalWidth: ref.totalWidth,
    );

    _freeOutlineResult(result);
    return outlineResult;
  }

  static double calibrateFontSize(
    String fontPath,
    List<String> texts,
    double availableWidth, {
    double referenceFontSize = 100.0,
    double headroom = 0.98,
  }) {
    double maxNatural = 0;
    for (final text in texts) {
      final result =
          shapeLine(fontPath, text, referenceFontSize, availableWidth);
      if (result.totalWidth > maxNatural) {
        maxNatural = result.totalWidth;
      }
    }
    if (maxNatural <= 0) return referenceFontSize;
    return referenceFontSize * (availableWidth / maxNatural) * headroom;
  }

  static double fontSizeForWidth(
    String fontPath,
    String text,
    double width, {
    double referenceFontSize = 100.0,
    double headroom = 0.98,
  }) {
    final shape = shapeLine(fontPath, text, referenceFontSize, width);
    if (shape.totalWidth <= 0) return referenceFontSize;
    return referenceFontSize * (width / shape.totalWidth) * headroom;
  }

  static Future<RenderResult?> renderLineToFit(
    String fontPath,
    String text,
    double width, {
    bool justify = false,
  }) {
    final fontSize = fontSizeForWidth(fontPath, text, width);
    return renderLine(fontPath, text, fontSize, width, justify: justify);
  }

  static OutlineResult? getOutlineToFit(
    String fontPath,
    String text,
    double width, {
    bool justify = false,
  }) {
    final fontSize = fontSizeForWidth(fontPath, text, width);
    return getOutline(fontPath, text, fontSize, width, justify: justify);
  }

  // ── Helpers ──

  static List<WordRect> _copyWordRects(
      Pointer<NativeWordRect> rects, int count) {
    return [
      for (int i = 0; i < count; i++)
        WordRect(
          x: rects[i].x,
          y: rects[i].y,
          width: rects[i].width,
          height: rects[i].height,
        ),
    ];
  }
}
