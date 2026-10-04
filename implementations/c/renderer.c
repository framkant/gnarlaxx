#include "renderer.h"
#include "sokol_app.h"
#include "sokol_gfx.h"
#include "sokol_glue.h"
#include "sokol_log.h"
#include "util/sokol_gl.h"
#include "stb_image.h"
#include <math.h>
#include <stdio.h>

static struct {
    sg_image atlas, font, target;
    sg_view atlas_view, font_view, target_view, target_attachment;
    sg_sampler sampler;
    sgl_context scene;
    sgl_pipeline blend;
} r;

bool platform_capture(sg_image image, const char *path);

static bool load_texture(const char *path, sg_image *image, sg_view *view) {
    int w, h, channels;
    unsigned char *pixels = stbi_load(path, &w, &h, &channels, 4);
    if (!pixels) { fprintf(stderr, "Cannot load PNG %s: %s\n", path, stbi_failure_reason()); return false; }
    *image = sg_make_image(&(sg_image_desc){.width=w, .height=h,
        .pixel_format=SG_PIXELFORMAT_RGBA8,
        .data.mip_levels[0]={pixels, (size_t)w*h*4}, .label=path});
    stbi_image_free(pixels);
    *view = sg_make_view(&(sg_view_desc){.texture.image=*image});
    return sg_query_image_state(*image) == SG_RESOURCESTATE_VALID && sg_query_view_state(*view) == SG_RESOURCESTATE_VALID;
}

bool renderer_init(const char *root) {
    sg_setup(&(sg_desc){.environment=sglue_environment(), .logger.func=slog_func});
    sgl_setup(&(sgl_desc_t){.max_vertices=20000, .max_commands=4000, .logger.func=slog_func});
    r.scene = sgl_make_context(&(sgl_context_desc_t){.max_vertices=20000, .max_commands=4000,
        .color_format=SG_PIXELFORMAT_RGBA8, .depth_format=SG_PIXELFORMAT_NONE, .sample_count=1});
    sgl_set_context(r.scene);
    r.blend = sgl_make_pipeline(&(sg_pipeline_desc){.colors[0].blend={
        .enabled=true, .src_factor_rgb=SG_BLENDFACTOR_SRC_ALPHA,
        .dst_factor_rgb=SG_BLENDFACTOR_ONE_MINUS_SRC_ALPHA,
        .src_factor_alpha=SG_BLENDFACTOR_ONE, .dst_factor_alpha=SG_BLENDFACTOR_ONE_MINUS_SRC_ALPHA}});
    r.sampler = sg_make_sampler(&(sg_sampler_desc){.min_filter=SG_FILTER_NEAREST,
        .mag_filter=SG_FILTER_NEAREST, .wrap_u=SG_WRAP_CLAMP_TO_EDGE, .wrap_v=SG_WRAP_CLAMP_TO_EDGE});
    r.target = sg_make_image(&(sg_image_desc){.width=GAME_WIDTH, .height=GAME_HEIGHT,
        .pixel_format=SG_PIXELFORMAT_RGBA8, .usage.color_attachment=true, .sample_count=1});
    r.target_view = sg_make_view(&(sg_view_desc){.texture.image=r.target});
    r.target_attachment = sg_make_view(&(sg_view_desc){.color_attachment.image=r.target});
    char path[2048];
    snprintf(path, sizeof path, "%s/graphics/sprites.png", root);
    if (!load_texture(path, &r.atlas, &r.atlas_view)) return false;
    snprintf(path, sizeof path, "%s/graphics/font.png", root);
    return load_texture(path, &r.font, &r.font_view);
}

void renderer_shutdown(void) { sgl_shutdown(); sg_shutdown(); }

void renderer_begin(void) {
    sgl_set_context(r.scene);
    sgl_defaults();
    sgl_load_pipeline(r.blend);
    sgl_matrix_mode_projection();
    sgl_ortho(0, GAME_WIDTH, GAME_HEIGHT, 0, -1, 1);
    sgl_matrix_mode_modelview();
}

static void tint(uint32_t color) {
    sgl_c4b((uint8_t)(color>>24), (uint8_t)(color>>16), (uint8_t)(color>>8), (uint8_t)color);
}

static void quad(float x, float y, float w, float h, float u, float v, float uw, float vh) {
    sgl_begin_quads();
    sgl_v2f_t2f(x, y, u, v); sgl_v2f_t2f(x+w, y, u+uw, v);
    sgl_v2f_t2f(x+w, y+h, u+uw, v+vh); sgl_v2f_t2f(x, y+h, u, v+vh);
    sgl_end();
}

void renderer_sprite(Sprite id, float x, float y, float scale, uint32_t color) {
    const AtlasRect a = SPRITE_RECTS[id];
    sgl_enable_texture(); sgl_texture(r.atlas_view, r.sampler); tint(color);
    quad(roundf(x), roundf(y), a.w*scale, a.h*scale, a.x/512.f, a.y/512.f, a.w/512.f, a.h/512.f);
}

void renderer_text(const char *text, float x, float y, int scale, uint32_t color) {
    sgl_enable_texture(); sgl_texture(r.font_view, r.sampler); tint(color);
    const float start = x;
    for (; *text; text++) {
        if (*text == '\n') { x=start; y+=10*scale; continue; }
        unsigned code = (unsigned char)*text;
        if (code >= 128) code = '?';
        quad(roundf(x), roundf(y), 8*scale, 8*scale, (code%16)/16.f, (code/16)/8.f, 1/16.f, 1/8.f);
        x += 8*scale;
    }
}

void renderer_rect(float x, float y, float w, float h, uint32_t color) {
    sgl_disable_texture(); tint(color); quad(x, y, w, h, 0, 0, 1, 1);
}

void renderer_present(void) {
    sg_begin_pass(&(sg_pass){.attachments.colors[0]=r.target_attachment,
        .action.colors[0]={.load_action=SG_LOADACTION_CLEAR, .clear_value={0.01f,0.015f,0.04f,1}}});
    sgl_draw(); sg_end_pass();
    sgl_set_context(sgl_default_context());
    sgl_defaults();
    int w = sapp_width(), h = sapp_height();
    int scale = w/GAME_WIDTH < h/GAME_HEIGHT ? w/GAME_WIDTH : h/GAME_HEIGHT;
    if (scale < 1) scale = 1; // Below 400x500, crop rather than blur fractional pixels.
    sgl_matrix_mode_projection(); sgl_ortho(0, (float)w, (float)h, 0, -1, 1);
    sgl_matrix_mode_modelview(); sgl_enable_texture(); sgl_texture(r.target_view, r.sampler);
    sgl_c4b(255,255,255,255);
    quad((float)((w-GAME_WIDTH*scale)/2), (float)((h-GAME_HEIGHT*scale)/2),
         GAME_WIDTH*scale, GAME_HEIGHT*scale, 0, 0, 1, 1);
    sg_begin_pass(&(sg_pass){.swapchain=sglue_swapchain(),
        .action.colors[0]={.load_action=SG_LOADACTION_CLEAR, .clear_value={0,0,0,1}}});
    sgl_draw(); sg_end_pass(); sg_commit();
}

bool renderer_capture(const char *path) { return platform_capture(r.target, path); }
