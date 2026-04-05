#include "harfbuzz_wrapper.h"
#include <hb.h>
#include <hb-ft.h>
#include <ft2build.h>
#include FT_FREETYPE_H
#include <cstring>
#include <cstdlib>
#include <vector>
#include <algorithm>
#include <cmath>
#include FT_OUTLINE_H

LineResult* shape_line(
        const char* font_path,
        const char* text,
        float       font_size,
        float       available_width
) {
    hb_buffer_t* buf = hb_buffer_create();
    hb_buffer_add_utf8(buf, text, -1, 0, -1);
    hb_buffer_set_direction(buf, HB_DIRECTION_RTL);
    hb_buffer_set_script(buf, HB_SCRIPT_ARABIC);
    hb_buffer_set_language(buf, hb_language_from_string("ar", -1));

    hb_blob_t*  blob = hb_blob_create_from_file(font_path);
    hb_face_t*  face = hb_face_create(blob, 0);
    hb_font_t*  font = hb_font_create(face);
    hb_font_set_scale(font, font_size * 64, font_size * 64);

    hb_shape(font, buf, NULL, 0);

    unsigned int glyph_count;
    hb_glyph_info_t*     infos = hb_buffer_get_glyph_infos(buf, &glyph_count);
    hb_glyph_position_t* poses = hb_buffer_get_glyph_positions(buf, &glyph_count);

    LineResult* result  = (LineResult*)malloc(sizeof(LineResult));
    result->glyphs      = (GlyphInfo*)malloc(sizeof(GlyphInfo) * glyph_count);
    result->glyph_count = (int)glyph_count;
    result->total_width = 0;

    for (unsigned int i = 0; i < glyph_count; i++) {
        result->glyphs[i].glyph_id  = (int)infos[i].codepoint;
        result->glyphs[i].x_offset  = poses[i].x_offset  / 64.0f;
        result->glyphs[i].y_offset  = poses[i].y_offset  / 64.0f;
        result->glyphs[i].x_advance = poses[i].x_advance / 64.0f;
        result->total_width        += poses[i].x_advance / 64.0f;
    }

    hb_buffer_destroy(buf);
    hb_font_destroy(font);
    hb_face_destroy(face);
    hb_blob_destroy(blob);

    return result;
}

void free_line_result(LineResult* result) {
    if (result) {
        free(result->glyphs);
        free(result);
    }
}

// Find word indices (byte offsets of space characters in UTF-8 text)
static std::vector<int> find_word_boundaries(const char* text) {
    std::vector<int> boundaries;
    boundaries.push_back(0);
    int len = (int)strlen(text);
    for (int i = 0; i < len; i++) {
        if (text[i] == ' ') {
            boundaries.push_back(i + 1);
        }
    }
    return boundaries;
}

// Map a cluster (byte offset) to a word index
static int cluster_to_word(const std::vector<int>& boundaries, unsigned int cluster) {
    for (int i = (int)boundaries.size() - 1; i >= 0; i--) {
        if ((int)cluster >= boundaries[i]) return i;
    }
    return 0;
}

RenderResult* render_line(
        const char* font_path,
        const char* text,
        float       font_size,
        float       available_width,
        int         justify
) {
    // Initialize FreeType
    FT_Library ft_lib;
    if (FT_Init_FreeType(&ft_lib)) return NULL;

    FT_Face ft_face;
    if (FT_New_Face(ft_lib, font_path, 0, &ft_face)) {
        FT_Done_FreeType(ft_lib);
        return NULL;
    }

    FT_Set_Char_Size(ft_face, 0, (FT_F26Dot6)(font_size * 64), 72, 72);

    // Create HarfBuzz font from FreeType face
    hb_font_t* hb_font = hb_ft_font_create(ft_face, NULL);

    // Shape with HarfBuzz
    hb_buffer_t* buf = hb_buffer_create();
    hb_buffer_add_utf8(buf, text, -1, 0, -1);
    hb_buffer_set_direction(buf, HB_DIRECTION_RTL);
    hb_buffer_set_script(buf, HB_SCRIPT_ARABIC);
    hb_buffer_set_language(buf, hb_language_from_string("ar", -1));

    if (justify) {
        int lineWidth = (int)(available_width * 64);
        hb_buffer_set_justify(buf, lineWidth);
    }

    hb_shape(hb_font, buf, NULL, 0);

    unsigned int glyph_count;
    hb_glyph_info_t*     infos = hb_buffer_get_glyph_infos(buf, &glyph_count);
    hb_glyph_position_t* poses = hb_buffer_get_glyph_positions(buf, &glyph_count);

    // Word boundaries
    std::vector<int> boundaries = find_word_boundaries(text);
    int word_count = (int)boundaries.size();

    // Track per-word x ranges
    struct WordBounds {
        float x_min = 1e9f;
        float x_max = -1e9f;
    };
    std::vector<WordBounds> word_bounds(word_count);

    // Calculate bitmap dimensions using font metrics for tight height
    int total_advance = 0;
    for (unsigned int i = 0; i < glyph_count; i++) {
        total_advance += poses[i].x_advance;
    }

    float ascender  = ft_face->size->metrics.ascender / 64.0f;
    float descender = ft_face->size->metrics.descender / 64.0f; // negative
    float metric_height = ascender - descender;

    float text_width = total_advance / 64.0f;
    // Add padding for glyph overhangs (glyphs can extend beyond their advance)
    float padding = font_size * 0.5f;
    int bmp_width  = (int)ceilf((text_width > 0 ? text_width : available_width) + padding);
    int bmp_height = (int)(metric_height + 2); // +2 for safety
    int baseline_y = (int)ascender;

    if (bmp_width <= 0 || bmp_height <= 0) {
        hb_buffer_destroy(buf);
        hb_font_destroy(hb_font);
        FT_Done_Face(ft_face);
        FT_Done_FreeType(ft_lib);
        return NULL;
    }

    // Allocate RGBA buffer (transparent)
    uint8_t* pixels = (uint8_t*)calloc(bmp_width * bmp_height * 4, 1);

    // Render each glyph — bitmap is sized to text_width + padding, Flutter scales to display
    float cursor_x = padding * 0.5f;
    for (unsigned int i = 0; i < glyph_count; i++) {
        FT_UInt glyph_index = infos[i].codepoint;
        int word_idx = cluster_to_word(boundaries, infos[i].cluster);

        float glyph_x = cursor_x + poses[i].x_offset / 64.0f;
        float advance = poses[i].x_advance / 64.0f;

        // Update word bounds
        if (word_idx >= 0 && word_idx < word_count) {
            float left = glyph_x;
            float right = glyph_x + advance;
            // For RTL, left might be > right depending on offset
            if (left > right) std::swap(left, right);
            word_bounds[word_idx].x_min = std::min(word_bounds[word_idx].x_min, left);
            word_bounds[word_idx].x_max = std::max(word_bounds[word_idx].x_max, right);
        }

        if (FT_Load_Glyph(ft_face, glyph_index, FT_LOAD_RENDER) == 0) {
            FT_GlyphSlot slot = ft_face->glyph;
            FT_Bitmap* bmp = &slot->bitmap;

            int gx = (int)(glyph_x + slot->bitmap_left);
            int gy = baseline_y - poses[i].y_offset / 64 - slot->bitmap_top;

            for (unsigned int row = 0; row < bmp->rows; row++) {
                for (unsigned int col = 0; col < bmp->width; col++) {
                    int px = gx + col;
                    int py = gy + row;
                    if (px < 0 || px >= bmp_width || py < 0 || py >= bmp_height) continue;

                    uint8_t alpha = bmp->buffer[row * bmp->pitch + col];
                    if (alpha == 0) continue;

                    int idx = (py * bmp_width + px) * 4;
                    pixels[idx + 0] = 255;
                    pixels[idx + 1] = 255;
                    pixels[idx + 2] = 255;
                    if (alpha > pixels[idx + 3])
                        pixels[idx + 3] = alpha;
                }
            }
        }

        cursor_x += poses[i].x_advance / 64.0f;
    }

    hb_buffer_destroy(buf);
    hb_font_destroy(hb_font);
    FT_Done_Face(ft_face);
    FT_Done_FreeType(ft_lib);

    // Build word rects
    WordRect* rects = (WordRect*)malloc(sizeof(WordRect) * word_count);
    for (int w = 0; w < word_count; w++) {
        if (word_bounds[w].x_min > word_bounds[w].x_max) {
            // No glyphs for this word
            rects[w].x = 0; rects[w].y = 0;
            rects[w].width = 0; rects[w].height = 0;
        } else {
            rects[w].x = word_bounds[w].x_min;
            rects[w].y = 0;
            rects[w].width = word_bounds[w].x_max - word_bounds[w].x_min;
            rects[w].height = (float)bmp_height;
        }
    }

    RenderResult* result = (RenderResult*)malloc(sizeof(RenderResult));
    result->pixels     = pixels;
    result->bmp_width  = bmp_width;
    result->bmp_height = bmp_height;
    result->word_rects = rects;
    result->word_count = word_count;

    return result;
}

void free_render_result(RenderResult* result) {
    if (result) {
        free(result->pixels);
        free(result->word_rects);
        free(result);
    }
}

// --- Vector outline extraction ---

struct OutlineUserData {
    std::vector<PathCommand> commands;
};

static int outline_move_to(const FT_Vector* to, void* user) {
    auto* data = (OutlineUserData*)user;
    PathCommand cmd = {};
    cmd.type = PATH_MOVE_TO;
    cmd.x = to->x / 64.0f;
    cmd.y = to->y / 64.0f;
    data->commands.push_back(cmd);
    return 0;
}

static int outline_line_to(const FT_Vector* to, void* user) {
    auto* data = (OutlineUserData*)user;
    PathCommand cmd = {};
    cmd.type = PATH_LINE_TO;
    cmd.x = to->x / 64.0f;
    cmd.y = to->y / 64.0f;
    data->commands.push_back(cmd);
    return 0;
}

static int outline_conic_to(const FT_Vector* control, const FT_Vector* to, void* user) {
    auto* data = (OutlineUserData*)user;
    PathCommand cmd = {};
    cmd.type = PATH_QUAD_TO;
    cmd.x1 = control->x / 64.0f;
    cmd.y1 = control->y / 64.0f;
    cmd.x  = to->x / 64.0f;
    cmd.y  = to->y / 64.0f;
    data->commands.push_back(cmd);
    return 0;
}

static int outline_cubic_to(const FT_Vector* ctrl1, const FT_Vector* ctrl2, const FT_Vector* to, void* user) {
    auto* data = (OutlineUserData*)user;
    PathCommand cmd = {};
    cmd.type = PATH_CUBIC_TO;
    cmd.x1 = ctrl1->x / 64.0f;
    cmd.y1 = ctrl1->y / 64.0f;
    cmd.x2 = ctrl2->x / 64.0f;
    cmd.y2 = ctrl2->y / 64.0f;
    cmd.x  = to->x / 64.0f;
    cmd.y  = to->y / 64.0f;
    data->commands.push_back(cmd);
    return 0;
}

OutlineResult* get_outline(
        const char* font_path,
        const char* text,
        float       font_size,
        float       available_width,
        int         justify
) {
    FT_Library ft_lib;
    if (FT_Init_FreeType(&ft_lib)) return NULL;

    FT_Face ft_face;
    if (FT_New_Face(ft_lib, font_path, 0, &ft_face)) {
        FT_Done_FreeType(ft_lib);
        return NULL;
    }

    FT_Set_Char_Size(ft_face, 0, (FT_F26Dot6)(font_size * 64), 72, 72);

    hb_font_t* hb_font = hb_ft_font_create(ft_face, NULL);

    hb_buffer_t* buf = hb_buffer_create();
    hb_buffer_add_utf8(buf, text, -1, 0, -1);
    hb_buffer_set_direction(buf, HB_DIRECTION_RTL);
    hb_buffer_set_script(buf, HB_SCRIPT_ARABIC);
    hb_buffer_set_language(buf, hb_language_from_string("ar", -1));

    if (justify) {
        int lineWidth = (int)(available_width * 64);
        hb_buffer_set_justify(buf, lineWidth);
    }

    hb_shape(hb_font, buf, NULL, 0);

    unsigned int glyph_count;
    hb_glyph_info_t*     infos = hb_buffer_get_glyph_infos(buf, &glyph_count);
    hb_glyph_position_t* poses = hb_buffer_get_glyph_positions(buf, &glyph_count);

    // Word boundaries
    std::vector<int> boundaries = find_word_boundaries(text);
    int word_count = (int)boundaries.size();

    struct WordBounds {
        float x_min = 1e9f;
        float x_max = -1e9f;
    };
    std::vector<WordBounds> word_bounds(word_count);

    float ascender  = ft_face->size->metrics.ascender / 64.0f;
    float descender = ft_face->size->metrics.descender / 64.0f;
    float metric_height = ascender - descender;

    // Decompose outlines
    FT_Outline_Funcs funcs = {};
    funcs.move_to  = outline_move_to;
    funcs.line_to  = outline_line_to;
    funcs.conic_to = outline_conic_to;
    funcs.cubic_to = outline_cubic_to;

    GlyphOutline* glyph_outlines = (GlyphOutline*)malloc(sizeof(GlyphOutline) * glyph_count);
    float padding = font_size * 0.5f;
    float cursor_x = padding * 0.5f;

    for (unsigned int i = 0; i < glyph_count; i++) {
        FT_UInt glyph_index = infos[i].codepoint;
        int word_idx = cluster_to_word(boundaries, infos[i].cluster);

        float glyph_x = cursor_x + poses[i].x_offset / 64.0f;
        float glyph_y = poses[i].y_offset / 64.0f;
        float advance  = poses[i].x_advance / 64.0f;

        // Update word bounds
        if (word_idx >= 0 && word_idx < word_count) {
            float left = glyph_x;
            float right = glyph_x + advance;
            if (left > right) std::swap(left, right);
            word_bounds[word_idx].x_min = std::min(word_bounds[word_idx].x_min, left);
            word_bounds[word_idx].x_max = std::max(word_bounds[word_idx].x_max, right);
        }

        glyph_outlines[i].offset_x = glyph_x;
        glyph_outlines[i].offset_y = glyph_y;

        if (FT_Load_Glyph(ft_face, glyph_index, FT_LOAD_NO_BITMAP) == 0 &&
            ft_face->glyph->format == FT_GLYPH_FORMAT_OUTLINE) {

            OutlineUserData user_data;
            FT_Outline_Decompose(&ft_face->glyph->outline, &funcs, &user_data);

            int cmd_count = (int)user_data.commands.size();
            glyph_outlines[i].command_count = cmd_count;
            if (cmd_count > 0) {
                glyph_outlines[i].commands = (PathCommand*)malloc(sizeof(PathCommand) * cmd_count);
                memcpy(glyph_outlines[i].commands, user_data.commands.data(), sizeof(PathCommand) * cmd_count);
            } else {
                glyph_outlines[i].commands = NULL;
            }
        } else {
            glyph_outlines[i].commands = NULL;
            glyph_outlines[i].command_count = 0;
        }

        cursor_x += advance;
    }

    hb_buffer_destroy(buf);
    hb_font_destroy(hb_font);
    FT_Done_Face(ft_face);
    FT_Done_FreeType(ft_lib);

    // Build word rects
    WordRect* rects = (WordRect*)malloc(sizeof(WordRect) * word_count);
    for (int w = 0; w < word_count; w++) {
        if (word_bounds[w].x_min > word_bounds[w].x_max) {
            rects[w].x = 0; rects[w].y = 0;
            rects[w].width = 0; rects[w].height = 0;
        } else {
            rects[w].x = word_bounds[w].x_min;
            rects[w].y = 0;
            rects[w].width = word_bounds[w].x_max - word_bounds[w].x_min;
            rects[w].height = metric_height;
        }
    }

    OutlineResult* result = (OutlineResult*)malloc(sizeof(OutlineResult));
    result->glyphs      = glyph_outlines;
    result->glyph_count = (int)glyph_count;
    result->word_rects  = rects;
    result->word_count  = word_count;
    result->ascender    = ascender;
    result->descender   = descender;
    result->total_width = cursor_x + padding * 0.5f;

    return result;
}

void free_outline_result(OutlineResult* result) {
    if (result) {
        for (int i = 0; i < result->glyph_count; i++) {
            free(result->glyphs[i].commands);
        }
        free(result->glyphs);
        free(result->word_rects);
        free(result);
    }
}
