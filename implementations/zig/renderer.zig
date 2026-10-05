const std = @import("std");
const sokol = @import("sokol");
const sg = sokol.gfx;
const sgl = sokol.gl;
const p = @import("properties.zig");
const a = @import("assets.zig");
const f = @import("game.zig").f;
extern fn stbi_load(path: [*:0]const u8, w: *c_int, h: *c_int, channels: *c_int, desired: c_int) ?[*]u8;
extern fn stbi_image_free(pixels: ?*anyopaque) void;
extern fn stbi_failure_reason() [*:0]const u8;
extern fn platform_capture(image: sg.Image, path: [*:0]const u8) bool;

pub const Renderer = struct {
    atlas: sg.View,
    font: sg.View,
    target: sg.Image,
    target_view: sg.View,
    target_attachment: sg.View,
    sampler: sg.Sampler,
    scene: sgl.Context,
    blend: sgl.Pipeline,
    pub fn init(allocator: std.mem.Allocator, root: []const u8) !Renderer {
        sg.setup(.{ .environment = sokol.glue.environment(), .logger = .{ .func = sokol.log.func } });
        errdefer sg.shutdown();
        sgl.setup(.{ .max_vertices = 20000, .max_commands = 4000, .logger = .{ .func = sokol.log.func } });
        errdefer sgl.shutdown();
        const scene = sgl.makeContext(.{ .max_vertices = 20000, .max_commands = 4000, .color_format = .RGBA8, .depth_format = .NONE, .sample_count = 1 });
        sgl.setContext(scene);
        var blend_desc: sg.PipelineDesc = .{};
        blend_desc.colors[0].blend = .{ .enabled = true, .src_factor_rgb = .SRC_ALPHA, .dst_factor_rgb = .ONE_MINUS_SRC_ALPHA, .src_factor_alpha = .ONE, .dst_factor_alpha = .ONE_MINUS_SRC_ALPHA };
        const blend = sgl.makePipeline(blend_desc);
        const sampler = sg.makeSampler(.{ .min_filter = .NEAREST, .mag_filter = .NEAREST, .wrap_u = .CLAMP_TO_EDGE, .wrap_v = .CLAMP_TO_EDGE });
        const target = sg.makeImage(.{ .width = p.GAME_WIDTH, .height = p.GAME_HEIGHT, .pixel_format = .RGBA8, .usage = .{ .color_attachment = true }, .sample_count = 1 });
        return .{
            .atlas = try loadTexture(allocator, root, "sprites"),
            .font = try loadTexture(allocator, root, "font"),
            .target = target,
            .target_view = sg.makeView(.{ .texture = .{ .image = target } }),
            .target_attachment = sg.makeView(.{ .color_attachment = .{ .image = target } }),
            .scene = scene,
            .blend = blend,
            .sampler = sampler,
        };
    }
    pub fn deinit(_: *Renderer) void {
        sgl.shutdown();
        sg.shutdown();
    }
    pub fn begin(r: *const Renderer) void {
        sgl.setContext(r.scene);
        sgl.defaults();
        sgl.loadPipeline(r.blend);
        sgl.matrixModeProjection();
        sgl.ortho(0, p.GAME_WIDTH, p.GAME_HEIGHT, 0, -1, 1);
        sgl.matrixModeModelview();
    }
    pub fn sprite(r: *const Renderer, id: a.Sprite, x: f32, y: f32, scale: f32, color: u32) void {
        const area = a.rect(id);
        sgl.enableTexture();
        sgl.texture(r.atlas, r.sampler);
        tint(color);
        quad(@round(x), @round(y), f(area.w) * scale, f(area.h) * scale, f(area.x) / a.ATLAS_WIDTH, f(area.y) / a.ATLAS_HEIGHT, f(area.w) / a.ATLAS_WIDTH, f(area.h) / a.ATLAS_HEIGHT);
    }
    pub fn text(r: *const Renderer, value: []const u8, x_start: f32, y_start: f32, scale: u32, color: u32) void {
        sgl.enableTexture();
        sgl.texture(r.font, r.sampler);
        tint(color);
        var x = x_start;
        var y = y_start;
        for (value) |byte| {
            if (byte == '\n') {
                x = x_start;
                y += f((a.FONT_CELL_HEIGHT + 2) * scale);
                continue;
            }
            const code: u32 = if (byte < a.FONT_COUNT) byte else '?';
            const cell = code - a.FONT_FIRST_CODEPOINT;
            quad(@round(x), @round(y), f(a.FONT_CELL_WIDTH * scale), f(a.FONT_CELL_HEIGHT * scale), f((cell % a.FONT_COLUMNS) * a.FONT_CELL_WIDTH) / a.FONT_WIDTH, f((cell / a.FONT_COLUMNS) * a.FONT_CELL_HEIGHT) / a.FONT_HEIGHT, @as(f32, a.FONT_CELL_WIDTH) / a.FONT_WIDTH, @as(f32, a.FONT_CELL_HEIGHT) / a.FONT_HEIGHT);
            x += f(a.FONT_ADVANCE * scale);
        }
    }
    pub fn rect(_: *const Renderer, x: f32, y: f32, w: f32, h: f32, color: u32) void {
        sgl.disableTexture();
        tint(color);
        quad(x, y, w, h, 0, 0, 1, 1);
    }
    pub fn present(r: *const Renderer) void {
        var offscreen: sg.Pass = .{};
        offscreen.attachments.colors[0] = r.target_attachment;
        offscreen.action.colors[0] = .{ .load_action = .CLEAR, .clear_value = .{ .r = 0.01, .g = 0.015, .b = 0.04, .a = 1 } };
        sg.beginPass(offscreen);
        sgl.draw();
        sg.endPass();
        sgl.setContext(sgl.defaultContext());
        sgl.defaults();
        const w = sokol.app.width();
        const h = sokol.app.height();
        const scale = @max(1, @min(@divTrunc(w, p.GAME_WIDTH), @divTrunc(h, p.GAME_HEIGHT)));
        sgl.matrixModeProjection();
        sgl.ortho(0, f(w), f(h), 0, -1, 1);
        sgl.matrixModeModelview();
        sgl.enableTexture();
        sgl.texture(r.target_view, r.sampler);
        sgl.c4b(255, 255, 255, 255);
        quad(f(@divTrunc(w - p.GAME_WIDTH * scale, 2)), f(@divTrunc(h - p.GAME_HEIGHT * scale, 2)), f(p.GAME_WIDTH * scale), f(p.GAME_HEIGHT * scale), 0, 0, 1, 1);
        var screen: sg.Pass = .{ .swapchain = sokol.glue.swapchain() };
        screen.action.colors[0] = .{ .load_action = .CLEAR, .clear_value = .{ .a = 1 } };
        sg.beginPass(screen);
        sgl.draw();
        sg.endPass();
        sg.commit();
    }
    pub fn capture(r: *const Renderer, path: [*:0]const u8) bool {
        return platform_capture(r.target, path);
    }
};
fn loadTexture(allocator: std.mem.Allocator, root: []const u8, name: []const u8) !sg.View {
    const path = try std.fmt.allocPrintSentinel(allocator, "{s}/graphics/{s}.png", .{ root, name }, 0);
    defer allocator.free(path);
    var w: c_int = 0;
    var h: c_int = 0;
    var channels: c_int = 0;
    const pixels = stbi_load(path.ptr, &w, &h, &channels, 4) orelse {
        std.log.err("Cannot load PNG {s}: {s}", .{ path, std.mem.span(stbi_failure_reason()) });
        return error.TextureLoadFailed;
    };
    defer stbi_image_free(pixels);
    var desc: sg.ImageDesc = .{ .width = w, .height = h, .pixel_format = .RGBA8, .label = path.ptr };
    desc.data.mip_levels[0] = .{ .ptr = pixels, .size = @intCast(w * h * 4) };
    const image = sg.makeImage(desc);
    const view = sg.makeView(.{ .texture = .{ .image = image } });
    if (sg.queryImageState(image) != .VALID or sg.queryViewState(view) != .VALID) return error.TextureLoadFailed;
    return view;
}
fn tint(color: u32) void {
    sgl.c4b(@truncate(color >> 24), @truncate(color >> 16), @truncate(color >> 8), @truncate(color));
}
fn quad(x: f32, y: f32, w: f32, h: f32, u: f32, v: f32, uw: f32, vh: f32) void {
    sgl.beginQuads();
    sgl.v2fT2f(x, y, u, v);
    sgl.v2fT2f(x + w, y, u + uw, v);
    sgl.v2fT2f(x + w, y + h, u + uw, v + vh);
    sgl.v2fT2f(x, y + h, u, v + vh);
    sgl.end();
}
