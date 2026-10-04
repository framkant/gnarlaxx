package renderer

import "core:fmt"
import "core:math"
import game "../game"
import sg "../../../vendor/sokol_odin/gfx"
import sgl "../../../vendor/sokol_odin/gl"
import sapp "../../../vendor/sokol_odin/app"
import sglue "../../../vendor/sokol_odin/glue"
import slog "../../../vendor/sokol_odin/log"

IMAGE_LIB :: #config(GNARLAXX_IMAGE_LIB,  "../../../build/odin/native/libdecoders.a")
PLATFORM_LIB :: #config(GNARLAXX_SOKOL_LIB,  "../../../build/odin/native/libsokol_odin.a")
foreign import images {IMAGE_LIB}
foreign import platform {PLATFORM_LIB}
foreign images {
    stbi_load :: proc "c"(path: cstring, w, h, channels: ^i32, desired: i32) -> [^]u8 ---
    stbi_image_free :: proc "c"(pixels: rawptr) ---
    stbi_failure_reason :: proc "c"() -> cstring ---
}

foreign platform { platform_capture :: proc "c"(image: sg.Image, path: cstring) -> bool --- }

State :: struct {
    atlas, font, target: sg.Image,
    atlas_view, font_view, target_view, target_attachment: sg.View,
    sampler: sg.Sampler,
    scene: sgl.Context,
    blend: sgl.Pipeline,
}

r: State
load_texture :: proc(path: cstring) -> (sg.Image, sg.View, bool) {
    w, h, channels: i32
    pixels := stbi_load(path, &w, &h, &channels, 4)
    if pixels == nil { fmt.eprintf("Cannot load PNG %s: %s\n", path, stbi_failure_reason()); return {}, {}, false }
    defer stbi_image_free(pixels)
    texture := sg.make_image({width = w, height = h, pixel_format = .RGBA8,
        data = {mip_levels = {0 = {ptr = pixels, size = uint(w*h*4)}}}, label = path})
    view := sg.make_view({texture = {image = texture}})
    return texture, view, sg.query_image_state(texture) == .VALID && sg.query_view_state(view) == .VALID
}

init :: proc(root: string) -> bool {
    sg.setup({environment = sglue.environment(), logger = {func = slog.func}})
    sgl.setup({max_vertices = 20000, max_commands = 4000, logger = {func = slog.func}})
    r.scene = sgl.make_context({max_vertices = 20000, max_commands = 4000, color_format = .RGBA8, depth_format = .NONE, sample_count = 1})
    sgl.set_context(r.scene)
    r.blend = sgl.make_pipeline({colors = {0 = {blend = {enabled = true, src_factor_rgb = .SRC_ALPHA,
        dst_factor_rgb = .ONE_MINUS_SRC_ALPHA, src_factor_alpha = .ONE, dst_factor_alpha = .ONE_MINUS_SRC_ALPHA}}}})
    r.sampler = sg.make_sampler({min_filter = .NEAREST, mag_filter = .NEAREST, wrap_u = .CLAMP_TO_EDGE, wrap_v = .CLAMP_TO_EDGE})
    r.target = sg.make_image({width = game.GAME_WIDTH, height = game.GAME_HEIGHT, pixel_format = .RGBA8, usage = {color_attachment = true}, sample_count = 1})
    r.target_view = sg.make_view({texture = {image = r.target}})
    r.target_attachment = sg.make_view({color_attachment = {image = r.target}})
    ok: bool
    r.atlas, r.atlas_view, ok = load_texture(fmt.ctprintf("%s/graphics/sprites.png", root))
    if !ok { return false }
    r.font, r.font_view, ok = load_texture(fmt.ctprintf("%s/graphics/font.png", root))
    return ok
}

shutdown :: proc() { sgl.shutdown(); sg.shutdown() }
begin :: proc() {
    sgl.set_context(r.scene); sgl.defaults(); sgl.load_pipeline(r.blend)
    sgl.matrix_mode_projection(); sgl.ortho(0, game.GAME_WIDTH, game.GAME_HEIGHT, 0, -1, 1)
    sgl.matrix_mode_modelview()
}

tint :: proc(color: u32) { sgl.c4b(u8(color>>24), u8(color>>16), u8(color>>8), u8(color)) }
quad :: proc(x, y, w, h, u, v, uw, vh: f32) {
    sgl.begin_quads()
    sgl.v2f_t2f(x, y, u, v); sgl.v2f_t2f(x+w, y, u+uw, v)
    sgl.v2f_t2f(x+w, y+h, u+uw, v+vh); sgl.v2f_t2f(x, y+h, u, v+vh)
    sgl.end()
}

sprite :: proc(id: game.Sprite, x, y, scale: f32, color: u32) {
    a := game.sprite_rect(id)
    sgl.enable_texture(); sgl.texture(r.atlas_view, r.sampler); tint(color)
    quad(math.round(x), math.round(y), f32(a.w)*scale, f32(a.h)*scale,
        f32(a.x)/game.ATLAS_WIDTH, f32(a.y)/game.ATLAS_HEIGHT, f32(a.w)/game.ATLAS_WIDTH, f32(a.h)/game.ATLAS_HEIGHT)
}

text :: proc(value: string, x, y: f32, scale: int, color: u32) {
    sgl.enable_texture(); sgl.texture(r.font_view, r.sampler); tint(color)
    start := x
    x, y := x, y
    for code in value {
        if code == '\n' { x = start; y += f32((game.FONT_CELL_HEIGHT+2)*scale); continue }
        code := code
        if code < game.FONT_FIRST_CODEPOINT || code >= game.FONT_FIRST_CODEPOINT+game.FONT_COUNT { code = '?' }
        cell := int(code)-game.FONT_FIRST_CODEPOINT
        u := f32((cell%game.FONT_COLUMNS)*game.FONT_CELL_WIDTH)/game.FONT_WIDTH
        v := f32((cell/game.FONT_COLUMNS)*game.FONT_CELL_HEIGHT)/game.FONT_HEIGHT
        quad(math.round(x), math.round(y), f32(game.FONT_CELL_WIDTH*scale), f32(game.FONT_CELL_HEIGHT*scale), u, v,
            f32(game.FONT_CELL_WIDTH)/game.FONT_WIDTH, f32(game.FONT_CELL_HEIGHT)/game.FONT_HEIGHT)
        x += f32(game.FONT_ADVANCE*scale)
    }
}

rect :: proc(x, y, w, h: f32, color: u32) { sgl.disable_texture(); tint(color); quad(x, y, w, h, 0, 0, 1, 1) }
present :: proc() {
    sg.begin_pass({attachments = {colors = {0 = r.target_attachment}}, action = {colors = {0 = {load_action = .CLEAR, clear_value = {.01, .015, .04, 1}}}}})
    sgl.draw(); sg.end_pass()
    sgl.set_context(sgl.default_context()); sgl.defaults()
    w, h := int(sapp.width()), int(sapp.height())
    scale := max(1, min(w/game.GAME_WIDTH, h/game.GAME_HEIGHT))
    sgl.matrix_mode_projection(); sgl.ortho(0, f32(w), f32(h), 0, -1, 1); sgl.matrix_mode_modelview()
    sgl.enable_texture(); sgl.texture(r.target_view, r.sampler); sgl.c4b(255, 255, 255, 255)
    quad(f32((w-game.GAME_WIDTH*scale)/2), f32((h-game.GAME_HEIGHT*scale)/2),
        f32(game.GAME_WIDTH*scale), f32(game.GAME_HEIGHT*scale), 0, 0, 1, 1)
    sg.begin_pass({swapchain = sglue.swapchain(), action = {colors = {0 = {load_action = .CLEAR, clear_value = {0, 0, 0, 1}}}}})
    sgl.draw(); sg.end_pass(); sg.commit()
}

capture :: proc(path: string) -> bool { return platform_capture(r.target, fmt.ctprintf("%s", path)) }
