#include "harfbuzz_wrapper.h"
#include <hb.h>
#include <hb-ot.h>
#include <hb-ft.h>
#include <ft2build.h>
#include FT_FREETYPE_H
#include FT_OUTLINE_H
#include FT_MULTIPLE_MASTERS_H
#include <cstring>
#include <cstdlib>
#include <climits>
#include <vector>
#include <algorithm>
#include <cmath>

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

// Decode one UTF-8 codepoint starting at `text + offset`. Returns the
// codepoint, writes the number of bytes consumed into *out_len. Returns
// 0 on invalid input.
static uint32_t utf8_decode(const char* text, int offset, int text_len, int* out_len) {
    unsigned char c = (unsigned char)text[offset];
    if (c < 0x80) { *out_len = 1; return c; }
    if ((c & 0xE0) == 0xC0 && offset + 1 < text_len) {
        *out_len = 2;
        return ((uint32_t)(c & 0x1F) << 6) | (text[offset+1] & 0x3F);
    }
    if ((c & 0xF0) == 0xE0 && offset + 2 < text_len) {
        *out_len = 3;
        return ((uint32_t)(c & 0x0F) << 12)
             | ((uint32_t)(text[offset+1] & 0x3F) << 6)
             |  (text[offset+2] & 0x3F);
    }
    if ((c & 0xF8) == 0xF0 && offset + 3 < text_len) {
        *out_len = 4;
        return ((uint32_t)(c & 0x07) << 18)
             | ((uint32_t)(text[offset+1] & 0x3F) << 12)
             | ((uint32_t)(text[offset+2] & 0x3F) << 6)
             |  (text[offset+3] & 0x3F);
    }
    *out_len = 1;
    return 0;
}

// Arabic dual-joining letters: connect to both sides, so their tail can
// carry a kashida stretch.
static bool is_dual_joining(uint32_t cp) {
    switch (cp) {
        case 0x0626: case 0x0628: case 0x062A: case 0x062B:
        case 0x062C: case 0x062D: case 0x062E:
        case 0x0633: case 0x0634: case 0x0635: case 0x0636:
        case 0x0637: case 0x0638: case 0x0639: case 0x063A:
        case 0x0641: case 0x0642: case 0x0643: case 0x0644:
        case 0x0645: case 0x0646: case 0x0647: case 0x064A:
            return true;
        default: return false;
    }
}

// A kashida can only stretch into a letter that joins on its right side,
// i.e. dual-joining or right-joining Arabic letters.
static bool is_joining_right(uint32_t cp) {
    if (is_dual_joining(cp)) return true;
    switch (cp) {
        case 0x0622: case 0x0623: case 0x0624: case 0x0625:
        case 0x0627: case 0x0629: case 0x062F: case 0x0630:
        case 0x0631: case 0x0632: case 0x0648: case 0x0649:
        case 0x0671:
            return true;
        default: return false;
    }
}

// Shape `text` with the given features and return total advance in 26.6.
static int measure_shaped(
        hb_font_t*          hb_font,
        const char*         text,
        const hb_feature_t* features,
        unsigned int        feature_count)
{
    hb_buffer_t* buf = hb_buffer_create();
    hb_buffer_add_utf8(buf, text, -1, 0, -1);
    hb_buffer_set_direction(buf, HB_DIRECTION_RTL);
    hb_buffer_set_script(buf, HB_SCRIPT_ARABIC);
    hb_buffer_set_language(buf, hb_language_from_string("ar", -1));
    hb_shape(hb_font, buf, features, feature_count);
    unsigned int c;
    hb_glyph_position_t* p = hb_buffer_get_glyph_positions(buf, &c);
    int w = 0;
    for (unsigned int i = 0; i < c; i++) w += p[i].x_advance;
    hb_buffer_destroy(buf);
    return w;
}

// Find the LTAT/RTAT design value (axis range ±20) that stretches the line
// from its natural width to target_px. HarfBuzz is told about the axis
// values via hb_font_set_variations so its advances match what FreeType
// will draw at the same coords. Linear probe then binary refine, since
// HVAR delta mapping on this font is not strictly linear at low values.
static float compute_line_tatweel(
    hb_font_t*  hb_font,
    const char* text,
    float       target_px)
{
    int target_fixed = (int)(target_px * 64.0f);

    auto set_and_measure = [&](float design_val) -> int {
        hb_variation_t v[2] = {
            { HB_TAG('L','T','A','T'), design_val },
            { HB_TAG('R','T','A','T'), design_val },
        };
        hb_font_set_variations(hb_font, v, 2);
        return measure_shaped(hb_font, text, NULL, 0);
    };

    int natural = set_and_measure(0.0f);

    float lo = -20.0f, hi = 20.0f;
    bool bracketed = false;
    int prev_w = set_and_measure(-20.0f);
    for (float t = -19.0f; t <= 20.0f; t += 1.0f) {
        int w = set_and_measure(t);
        if (prev_w < target_fixed && w >= target_fixed) {
            lo = t - 1.0f; hi = t; bracketed = true; break;
        }
        prev_w = w;
    }
    if (!bracketed) {
        // Target is outside the representable range. Clamp to nearer end.
        float chosen = (natural >= target_fixed) ? -20.0f : 20.0f;
        set_and_measure(chosen);
        return chosen;
    }

    // Binary refine between lo and hi to 0.1 design units.
    for (int iter = 0; iter < 8 && hi - lo > 0.1f; iter++) {
        float mid = (lo + hi) * 0.5f;
        int w = set_and_measure(mid);
        if (w >= target_fixed) hi = mid; else lo = mid;
    }

    // Return the upper bracket so the measured width reaches target.
    // Overshooting by <1px at 0.1 design-unit resolution is invisible;
    // undershooting leaves a ragged column.
    float chosen = hi;
    set_and_measure(chosen);
    return chosen;
}

// The DigitalKhatt fork's GSUB lookups (AlternateSetWithTatweels) populate
// info[i].lefttatweel/righttatweel as a side effect of substituting to a
// wider glyph. HarfBuzz uses those values to compute advance widths, but
// FreeType needs the same values applied to the font's variable axes
// (LTAT, RTAT) before FT_Load_Glyph, or else it draws the glyph's default
// outline at the wider advance — looking like padding instead of kashida.
// `norm` inputs are normalized F2DOT14-ish values (roughly [-1,+1]) as
// stored in the glyph info; we scale to LTAT/RTAT design units (axis
// range ±20) then to FT_Fixed 16.16.
static void set_ft_tatweel(FT_Face face, double l_norm, double r_norm) {
    FT_Fixed coords[2];
    coords[0] = (FT_Fixed)(l_norm * 20.0 * 65536.0);
    coords[1] = (FT_Fixed)(r_norm * 20.0 * 65536.0);
    FT_Set_Var_Design_Coordinates(face, 2, coords);
}

// Residual gap absorber: after shaping with kashida features, if the total
// line width is still less than target, widen inter-word space advances
// equally across all space glyphs to close the gap.
static void widen_spaces(
    hb_buffer_t* buf,
    const char*  text,
    float        target_px)
{
    unsigned int count;
    hb_glyph_info_t*     infos = hb_buffer_get_glyph_infos(buf, &count);
    hb_glyph_position_t* poses = hb_buffer_get_glyph_positions(buf, &count);

    int current = 0;
    for (unsigned int i = 0; i < count; i++) current += poses[i].x_advance;
    int target_fixed = (int)(target_px * 64.0f);
    int delta = target_fixed - current;
    if (delta <= 0) return;

    std::vector<unsigned int> space_glyphs;
    int text_len = (int)strlen(text);
    unsigned int last_cluster = UINT_MAX;
    for (unsigned int i = 0; i < count; i++) {
        unsigned int c = infos[i].cluster;
        if (c == last_cluster) continue;
        if ((int)c < text_len && text[c] == ' ') space_glyphs.push_back(i);
        last_cluster = c;
    }
    if (space_glyphs.empty()) return;

    int per = delta / (int)space_glyphs.size();
    int rem = delta - per * (int)space_glyphs.size();
    for (size_t k = 0; k < space_glyphs.size(); k++) {
        poses[space_glyphs[k]].x_advance += per + (k < (size_t)rem ? 1 : 0);
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

    // Create a native-OT HarfBuzz font.
    hb_blob_t* blob = hb_blob_create_from_file(font_path);
    hb_face_t* face = hb_face_create(blob, 0);
    hb_font_t* hb_font = hb_font_create(face);
    hb_font_set_scale(hb_font, (int)(font_size * 64), (int)(font_size * 64));
    hb_ot_font_set_funcs(hb_font);

    // Kashida via variable-font axes: find the LTAT/RTAT design value that
    // brings the line to target, then apply it to both HarfBuzz (so shaped
    // advances match) and FreeType (so rendered outlines match). Without
    // matching both sides, you get either wide advances + narrow glyphs
    // (looks like padded space) or narrow advances + wide glyphs (overlap).
    float tatweel_val = 0.0f;
    if (justify) {
        tatweel_val = compute_line_tatweel(hb_font, text, available_width);
    }

    hb_buffer_t* buf = hb_buffer_create();
    hb_buffer_add_utf8(buf, text, -1, 0, -1);
    hb_buffer_set_direction(buf, HB_DIRECTION_RTL);
    hb_buffer_set_script(buf, HB_SCRIPT_ARABIC);
    hb_buffer_set_language(buf, hb_language_from_string("ar", -1));

    // Shape with the chosen axis values already set on the font.
    hb_shape(hb_font, buf, NULL, 0);

    // Mirror the axis to FreeType for outline rendering.
    if (justify) {
        FT_Fixed coords[2] = {
            (FT_Fixed)(tatweel_val * 65536.0f),
            (FT_Fixed)(tatweel_val * 65536.0f),
        };
        FT_Set_Var_Design_Coordinates(ft_face, 2, coords);
    }

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
    float padding = font_size * 0.5f;
    int bmp_width  = (int)ceilf(text_width + padding);
    int bmp_height = (int)(metric_height + 2); // +2 for safety
    int baseline_y = (int)ascender;

    if (bmp_width <= 0 || bmp_height <= 0) {
        hb_buffer_destroy(buf);
        hb_font_destroy(hb_font);
        hb_face_destroy(face);
        hb_blob_destroy(blob);
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
    hb_face_destroy(face);
    hb_blob_destroy(blob);
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

    hb_blob_t* blob = hb_blob_create_from_file(font_path);
    hb_face_t* face = hb_face_create(blob, 0);
    hb_font_t* hb_font = hb_font_create(face);
    hb_font_set_scale(hb_font, (int)(font_size * 64), (int)(font_size * 64));
    hb_ot_font_set_funcs(hb_font);

    float tatweel_val = 0.0f;
    if (justify) {
        tatweel_val = compute_line_tatweel(hb_font, text, available_width);
    }

    hb_buffer_t* buf = hb_buffer_create();
    hb_buffer_add_utf8(buf, text, -1, 0, -1);
    hb_buffer_set_direction(buf, HB_DIRECTION_RTL);
    hb_buffer_set_script(buf, HB_SCRIPT_ARABIC);
    hb_buffer_set_language(buf, hb_language_from_string("ar", -1));

    hb_shape(hb_font, buf, NULL, 0);

    if (justify) {
        FT_Fixed coords[2] = {
            (FT_Fixed)(tatweel_val * 65536.0f),
            (FT_Fixed)(tatweel_val * 65536.0f),
        };
        FT_Set_Var_Design_Coordinates(ft_face, 2, coords);
    }

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
    float cursor_x = 0.0f;

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
        glyph_outlines[i].word_index = word_idx;
        glyph_outlines[i].cluster = (int)infos[i].cluster;

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
    hb_face_destroy(face);
    hb_blob_destroy(blob);
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

    result->total_width = (justify && cursor_x < available_width)
        ? available_width
        : cursor_x;

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
