#include "harfbuzz_wrapper.h"
#include <hb.h>
#include <hb-ft.h>
#include <ft2build.h>
#include FT_FREETYPE_H
#include <cstring>
#include <cstdlib>
#include <cstdio>
#include <climits>
#include <vector>
#include <algorithm>
#include <cmath>
#include FT_OUTLINE_H

#if defined(__ANDROID__)
  #include <android/log.h>
  #define ATJ_LOG(...) __android_log_print(ANDROID_LOG_INFO, "atj", __VA_ARGS__)
#else
  #define ATJ_LOG(...) fprintf(stderr, "[atj] " __VA_ARGS__), fprintf(stderr, "\n")
#endif

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

// Shape `text` once with the given feature array and return total advance
// width in 26.6 fixed-point.
static int measure_with_features(
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

    unsigned int count;
    hb_glyph_position_t* poses = hb_buffer_get_glyph_positions(buf, &count);
    int total = 0;
    for (unsigned int i = 0; i < count; i++) total += poses[i].x_advance;
    hb_buffer_destroy(buf);
    return total;
}

// Pick the OpenType feature combination that produces the largest line
// width still <= target_px. The residual gap (target - chosen_width) is
// closed afterwards by widening inter-word space advances in the caller.
//
// The font exposes these justification features:
//   stretch (priority order): jalt, tug1, sch1
//   shrink  (priority order): shr1, shr2
//
// For stretching, we walk combinations cumulatively — first {}, then {jalt},
// then {jalt,tug1}, then {jalt,tug1,sch1} — and keep the one whose width is
// the largest value still <= target. This avoids massive overshoots (we
// saw a line jump from ~900 px to 1190 px with jalt alone, target 1038).
//
// For shrinking, we turn on features until width <= target (overshoot is
// fine when shrinking — we can't negatively-space letters).
//
// Writes the chosen feature list into `out_features` and returns count.
static unsigned int build_justify_features(
        hb_font_t*    hb_font,
        const char*   text,
        float         target_px,
        hb_feature_t* out_features,
        unsigned int  out_capacity)
{
    static const hb_tag_t kStretchTags[] = {
        HB_TAG('j','a','l','t'),
        HB_TAG('t','u','g','1'),
        HB_TAG('s','c','h','1'),
    };
    static const hb_tag_t kShrinkTags[] = {
        HB_TAG('s','h','r','1'),
        HB_TAG('s','h','r','2'),
    };

    int natural = measure_with_features(hb_font, text, NULL, 0);
    int target_fixed = (int)(target_px * 64.0f);

    if (natural == target_fixed) {
        ATJ_LOG("features: natural %.1f == target, none needed", natural / 64.0f);
        return 0;
    }

    if (natural < target_fixed) {
        // STRETCH: pick the combo with the largest width still <= target.
        const unsigned int stretch_count =
            sizeof(kStretchTags) / sizeof(kStretchTags[0]);
        int best_w = natural;
        unsigned int best_count = 0;

        hb_feature_t trial[8];
        for (unsigned int k = 1; k <= stretch_count && k <= out_capacity; k++) {
            trial[k - 1] = hb_feature_t{ kStretchTags[k - 1], 1, 0, (unsigned)-1 };
            int w = measure_with_features(hb_font, text, trial, k);
            if (w <= target_fixed && w > best_w) {
                best_w = w;
                best_count = k;
                memcpy(out_features, trial, k * sizeof(hb_feature_t));
            }
        }
        ATJ_LOG("features: stretch picked %u feature(s), width %.1f (target %.1f, gap %.1f)",
                best_count, best_w / 64.0f, target_px,
                target_px - best_w / 64.0f);
        return best_count;
    }

    // SHRINK: apply shrink features until width <= target (or exhausted).
    const unsigned int shrink_count =
        sizeof(kShrinkTags) / sizeof(kShrinkTags[0]);
    unsigned int enabled = 0;
    for (unsigned int i = 0; i < shrink_count && enabled < out_capacity; i++) {
        out_features[enabled] = hb_feature_t{ kShrinkTags[i], 1, 0, (unsigned)-1 };
        enabled++;
        int w = measure_with_features(hb_font, text, out_features, enabled);
        if (w <= target_fixed) {
            ATJ_LOG("features: shrink reached target with %u feature(s), width %.1f",
                    enabled, w / 64.0f);
            return enabled;
        }
    }
    int w = measure_with_features(hb_font, text, out_features, enabled);
    ATJ_LOG("features: shrink exhausted, width %.1f (target %.1f)",
            w / 64.0f, target_px);
    return enabled;
}

// After shaping, widen inter-word space advances so the line total matches
// the target width. Letter advances are untouched, so joining stays intact.
// Called only if the feature-pick left a residual gap.
static void fill_residual_with_spaces(
        hb_buffer_t* buf,
        const char*  text,
        float        target_px)
{
    unsigned int count;
    hb_glyph_info_t*     infos = hb_buffer_get_glyph_infos(buf, &count);
    hb_glyph_position_t* poses = hb_buffer_get_glyph_positions(buf, &count);

    int natural = 0;
    for (unsigned int i = 0; i < count; i++) natural += poses[i].x_advance;

    int target_fixed = (int)(target_px * 64.0f);
    int delta = target_fixed - natural;
    if (delta <= 0) return;

    std::vector<int> space_indices;
    int text_len = (int)strlen(text);
    unsigned int last_cluster = UINT_MAX;
    for (unsigned int i = 0; i < count; i++) {
        unsigned int cluster = infos[i].cluster;
        if (cluster == last_cluster) continue;
        if ((int)cluster < text_len && text[cluster] == ' ') {
            space_indices.push_back((int)i);
        }
        last_cluster = cluster;
    }
    if (space_indices.empty()) return;

    int per_space = delta / (int)space_indices.size();
    int remainder = delta - per_space * (int)space_indices.size();
    for (size_t k = 0; k < space_indices.size(); k++) {
        int extra = per_space + (k < (size_t)remainder ? 1 : 0);
        poses[space_indices[k]].x_advance += extra;
    }
    ATJ_LOG("residual: +%.1f px across %zu spaces", delta / 64.0f, space_indices.size());
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

    // Pick OpenType justification features (jalt, tug1, sch1, shr1, shr2)
    // that stretch/shrink the line to `available_width`.
    hb_feature_t features[8];
    unsigned int feature_count = 0;
    if (justify) {
        feature_count = build_justify_features(
            hb_font, text, available_width, features, 8);
    }

    hb_buffer_t* buf = hb_buffer_create();
    hb_buffer_add_utf8(buf, text, -1, 0, -1);
    hb_buffer_set_direction(buf, HB_DIRECTION_RTL);
    hb_buffer_set_script(buf, HB_SCRIPT_ARABIC);
    hb_buffer_set_language(buf, hb_language_from_string("ar", -1));

    hb_shape(hb_font, buf, features, feature_count);

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

    hb_feature_t features[8];
    unsigned int feature_count = 0;
    if (justify) {
        feature_count = build_justify_features(
            hb_font, text, available_width, features, 8);
    }

    hb_buffer_t* buf = hb_buffer_create();
    hb_buffer_add_utf8(buf, text, -1, 0, -1);
    hb_buffer_set_direction(buf, HB_DIRECTION_RTL);
    hb_buffer_set_script(buf, HB_SCRIPT_ARABIC);
    hb_buffer_set_language(buf, hb_language_from_string("ar", -1));

    hb_shape(hb_font, buf, features, feature_count);

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
        glyph_outlines[i].word_index = word_idx;

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
