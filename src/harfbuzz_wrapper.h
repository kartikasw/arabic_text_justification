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

// Path command types for vector outline rendering
enum PathCommandType {
    PATH_MOVE_TO  = 0,
    PATH_LINE_TO  = 1,
    PATH_QUAD_TO  = 2,  // quadratic bezier (FreeType "conic")
    PATH_CUBIC_TO = 3
};

typedef struct {
    int   type;    // PathCommandType
    float x, y;    // end point (all commands)
    float x1, y1;  // control point 1 (quad & cubic)
    float x2, y2;  // control point 2 (cubic only)
} PathCommand;

typedef struct {
    PathCommand* commands;
    int          command_count;
    float        offset_x;  // glyph position from shaping
    float        offset_y;
    int          word_index;
} GlyphOutline;

typedef struct {
    GlyphOutline* glyphs;
    int           glyph_count;
    WordRect*     word_rects;
    int           word_count;
    float         ascender;
    float         descender;
    float         total_width;
} OutlineResult;

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
        float       available_width,
        int         justify
);

HBQ_EXPORT void free_render_result(RenderResult* result);

HBQ_EXPORT OutlineResult* get_outline(
        const char* font_path,
        const char* text,
        float       font_size,
        float       available_width,
        int         justify
);

HBQ_EXPORT void free_outline_result(OutlineResult* result);

#ifdef __cplusplus
}
#endif

#endif
