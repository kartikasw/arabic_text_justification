#ifndef HARFBUZZ_WRAPPER_H
#define HARFBUZZ_WRAPPER_H

#include <stdint.h>

#define HBQ_EXPORT __attribute__((visibility("default")))

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    int   glyph_id;
    float x_offset;
    float y_offset;
    float x_advance;
} GlyphInfo;

typedef struct {
    GlyphInfo* glyphs;
    int        glyph_count;
    float      total_width;
} LineResult;

typedef struct {
    float x;
    float y;
    float width;
    float height;
} WordRect;

typedef struct {
    uint8_t*  pixels;       // RGBA data
    int       bmp_width;
    int       bmp_height;
    WordRect* word_rects;
    int       word_count;
} RenderResult;

HBQ_EXPORT LineResult* shape_line(
        const char* font_path,
        const char* text,
        float       font_size,
        float       available_width
);

HBQ_EXPORT void free_line_result(LineResult* result);

HBQ_EXPORT RenderResult* render_line(
        const char* font_path,
        const char* text,
        float       font_size,
        float       available_width
);

HBQ_EXPORT void free_render_result(RenderResult* result);

#ifdef __cplusplus
}
#endif

#endif
