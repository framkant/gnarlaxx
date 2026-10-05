const std = @import("std");
const builtin = @import("builtin");
const sokol = @import("sokol");
const sapp = sokol.app;
const stm = sokol.time;
const g = @import("game.zig");
const p = @import("properties.zig");
const audio = @import("audio.zig");
const c = audio.c;
const Renderer = @import("renderer.zig").Renderer;
const presentation = @import("presentation.zig");
const Scores = @import("scores.zig").Scores;

const Keys = struct {
    held: [sapp.max_keycodes]bool = @splat(false),
    pressed: [sapp.max_keycodes]bool = @splat(false),
    fn down(k: *const Keys, code: sapp.Keycode) bool {
        return k.held[@intCast(@backingInt(code))];
    }
    fn hit(k: *const Keys, code: sapp.Keycode) bool {
        return k.pressed[@intCast(@backingInt(code))];
    }
    fn read(k: *Keys) g.Input {
        defer k.pressed = @splat(false);
        return .{
            .x = g.f(@as(i32, @intFromBool(k.down(.D) or k.down(.RIGHT))) - @as(i32, @intFromBool(k.down(.A) or k.down(.LEFT)))),
            .y = g.f(@as(i32, @intFromBool(k.down(.S) or k.down(.DOWN))) - @as(i32, @intFromBool(k.down(.W) or k.down(.UP)))),
            .fire = k.down(.SPACE),
            .confirm = k.hit(.ENTER),
            .cancel = k.hit(.ESCAPE),
            .up = k.hit(.UP) or k.hit(.W),
            .down = k.hit(.DOWN) or k.hit(.S),
            .left = k.hit(.LEFT) or k.hit(.A),
            .right = k.hit(.RIGHT) or k.hit(.D),
            .sound = k.hit(.V),
            .menu = k.hit(.Q),
        };
    }
    fn event(k: *Keys, e: sapp.Event, game: *g.Game, demo: bool) void {
        if (e.type == .UNFOCUSED or e.type == .ICONIFIED) {
            k.* = .{};
            if (!demo) game.pause();
            return;
        }
        const code = @backingInt(e.key_code);
        if (code < 0 or code >= sapp.max_keycodes) return;
        const index: usize = @intCast(code);
        if (e.type == .KEY_DOWN) {
            k.held[index] = true;
            if (!e.key_repeat) k.pressed[index] = true;
        } else if (e.type == .KEY_UP) {
            k.held[index] = false;
        }
    }
};
const Config = struct {
    asset_root: []const u8 = @import("options").asset_root,
    score_override: ?[]const u8 = null,
    capture: ?[:0]const u8 = null,
    scene: ?[]const u8 = null,
    demo: bool = false,
    mute: bool = false,
    frame_limit: usize = 0,
};
const App = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    home: ?[]const u8,
    config: Config,
    game: g.Game,
    renderer: ?Renderer = null,
    audio: ?*audio.Handle = null,
    scores: Scores = .{},
    score_path: ?[]u8 = null,
    keys: Keys = .{},
    save_failed: bool = false,
    audio_available: bool = false,
    failed: bool = false,
    accumulator: f64 = 0,
    work_seconds: f64 = 0,
    max_work_seconds: f64 = 0,
    started: u64 = 0,
    frames: usize = 0,
};
var app: App = undefined;
var debug_allocator: std.heap.DebugAllocator(.{}) = .init;

fn initResources() !void {
    stm.setup();
    if (app.config.score_override) |path| app.score_path = try app.allocator.dupe(u8, path) else {
        const directory = try std.fmt.allocPrint(app.allocator, "{s}/Library/Application Support/Gnarlaxx", .{app.home orelse return error.HomeMissing});
        defer app.allocator.free(directory);
        std.Io.Dir.cwd().createDir(app.io, directory, .fromMode(0o700)) catch |err| {
            if (err != error.PathAlreadyExists) app.save_failed = true;
        };
        app.score_path = try std.fmt.allocPrint(app.allocator, "{s}/scores.txt", .{directory});
    }
    app.scores = Scores.load(app.io, app.allocator, app.score_path.?) catch .{};
    app.renderer = try Renderer.init(app.allocator, app.config.asset_root);
    app.audio = try audio.load(app.allocator, app.config.asset_root);
    app.audio_available = c.gna_device_open(app.audio) != 0;
    if (app.config.mute) app.game.volumes.set(.master, 0);
    try setDiagnosticScene();
    if (app.config.demo and app.config.scene == null) try app.game.start();
    std.debug.print("Gnarlaxx Zig: Metal; audio={s} ({d} Hz); decoded audio={d:.2} MiB; game inline state={d} bytes\n", .{ if (app.audio_available) "ready" else "unavailable", c.gna_device_rate(app.audio), @as(f64, @floatFromInt(c.gna_decoded_bytes(app.audio))) / 1048576, @sizeOf(g.Game) });
    app.started = stm.now();
}
fn setDiagnosticScene() !void {
    const scene = app.config.scene orelse return;
    if (std.mem.eql(u8, scene, "menu")) return;
    const game = &app.game;
    try game.start();
    if (std.mem.eql(u8, scene, "briefing")) return;
    game.scene = .play;
    game.fade = 0;
    game.player.pos = .{ .x = p.GAME_CENTER_X, .y = p.PLAYER_SPAWN_Y };
    if (std.mem.eql(u8, scene, "play")) return;
    game.waves_spawned = p.PAWN_WAVE_COUNT;
    game.drones_spawned = p.DRONE_COUNT;
    try game.spawnBoss();
    game.boss.pos = .{ .x = p.GAME_CENTER_X, .y = p.BOSS_REST_Y };
    game.boss.phase = .roam;
    if (std.mem.eql(u8, scene, "core")) {
        game.boss.left_hp = 0;
        game.boss.right_hp = 0;
        game.boss.core_open = true;
    } else if (std.mem.eql(u8, scene, "pause")) game.pause() else if (std.mem.eql(u8, scene, "victory")) {
        game.scene = .victory;
        game.boss.active = false;
        game.score = 10000;
    } else if (!std.mem.eql(u8, scene, "boss")) return error.UnknownScene;
}
fn init() callconv(.c) void {
    initResources() catch |err| {
        std.log.err("Initialization failed: {t}", .{err});
        app.failed = true;
        sapp.requestQuit();
    };
}
fn input() g.Input {
    var result = app.keys.read();
    const game = &app.game;
    if (app.config.demo and game.scene == .play) {
        var target = p.GAME_CENTER_X + @sin(game.level_time * 0.9) * 125;
        if (game.boss.active) target = if (game.boss.core_open) game.boss.pos.x else game.boss.gun(game.boss.left_hp == 0).x;
        result.x = std.math.clamp((target - game.player.pos.x) * 0.03, -1, 1);
        result.fire = true;
        game.player.invincible = 1000;
    }
    return result;
}
fn processEvents() void {
    for (app.game.events.items) |message| switch (message) {
        .sound => |sound| {
            _ = c.gna_play(app.audio, @backingInt(sound.id), sound.gain);
        },
        .finished => |score| {
            std.debug.print("Run finished: {s}, score={d}, mission time={d:.2}s\n", .{ @tagName(app.game.scene), score, app.game.level_time });
            if (!app.config.demo and app.config.scene == null) {
                app.scores.insert(score);
                app.save_failed = false;
                app.scores.save(app.io, app.allocator, app.score_path.?) catch |err| {
                    app.save_failed = true;
                    std.log.err("Could not save scores to {s}: {t}", .{ app.score_path.?, err });
                };
            }
        },
    };
    app.game.events.clearRetainingCapacity();
}
fn frame() callconv(.c) void {
    if (app.failed) {
        sapp.requestQuit();
        return;
    }
    const begin = stm.now();
    app.accumulator += @min(sapp.frameDuration(), 0.1);
    while (app.accumulator >= p.GAME_STEP) {
        const previous = app.game.scene;
        app.game.update(input(), p.GAME_STEP) catch |err| {
            std.log.err("Cannot grow game collections: {t}", .{err});
            app.failed = true;
            sapp.requestQuit();
            return;
        };
        if ((app.game.scene == .briefing and previous != .briefing and previous != .pause and previous != .sound) or
            (app.game.scene == .menu and previous != .menu)) c.gna_stop_effects(app.audio);
        processEvents();
        app.accumulator -= p.GAME_STEP;
    }
    c.gna_set_volume(app.audio, app.game.volumes.get(.master), app.game.volumes.get(.music), app.game.volumes.get(.effects));
    c.gna_set_paused(app.audio, @intFromBool(app.game.scene == .pause));
    if (app.audio_available and c.gna_device_pump(app.audio) == 0) std.log.warn("Audio queue could not accept mixed frames", .{});
    presentation.draw(&app.renderer.?, &app.game, app.scores, app.save_failed, app.audio_available);
    const work = stm.sec(stm.since(begin));
    app.work_seconds += work;
    app.max_work_seconds = @max(app.max_work_seconds, work);
    app.frames += 1;
    if (app.config.frame_limit > 0 and app.frames >= app.config.frame_limit) {
        if (app.config.capture) |path| {
            if (!app.renderer.?.capture(path.ptr)) {
                std.log.err("Capture failed: {s}", .{path});
                app.failed = true;
            }
        }
        sapp.requestQuit();
    }
    if (app.game.quit_requested) sapp.requestQuit();
}
fn event(e: ?*const sapp.Event) callconv(.c) void {
    if (e) |value| app.keys.event(value.*, &app.game, app.config.demo);
}
fn cleanup() callconv(.c) void {
    if (app.started != 0) {
        const elapsed = stm.sec(stm.since(app.started));
        const frames: f64 = @floatFromInt(app.frames);
        std.debug.print("Stats: {d} frames / {d:.2}s = {d:.1} fps; frame work avg {d:.3}ms max {d:.3}ms\n", .{ app.frames, elapsed, if (elapsed > 0) frames / elapsed else 0, if (frames > 0) app.work_seconds * 1000 / frames else 0, app.max_work_seconds * 1000 });
        std.debug.print("Game storage: {d} inline bytes + {d} retained heap bytes; capacities: {d} enemies, {d} bullets, {d} explosions, {d} events\n", .{ @sizeOf(g.Game), app.game.heapBytes(), app.game.enemies.capacity, app.game.bullets.capacity, app.game.explosions.capacity, app.game.events.capacity });
    }
    app.game.deinit();
    c.gna_destroy(app.audio);
    app.audio = null;
    if (app.renderer) |*r| {
        r.deinit();
        app.renderer = null;
    }
    if (app.score_path) |path| {
        app.allocator.free(path);
        app.score_path = null;
    }
    // Cocoa may exit the process inside sapp.run, so cleanup belongs here.
    if (builtin.mode == .debug) {
        const status = debug_allocator.deinit();
        std.debug.print("Zig application allocator after shutdown: {t}\n", .{status});
        if (status == .leak) app.failed = true;
    }
    if (app.failed) std.process.exit(1);
}
pub fn main(init_data: std.process.Init) !void {
    const args = try init_data.minimal.args.toSlice(init_data.arena.allocator());
    var config: Config = .{};
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--demo")) config.demo = true else if (std.mem.eql(u8, arg, "--mute")) config.mute = true else if (std.mem.eql(u8, arg, "--help")) {
            std.debug.print("Gnarlaxx Zig: WASD/arrows move, Space fires, Enter selects, Esc pauses, V sound, Q leaves paused run.\nOptions: --assets PATH --scores PATH --mute\nDiagnostics: --frames N --capture PNG --demo (invulnerable, no saves)\n             --scene menu|briefing|play|boss|core|pause|victory (no saves)\n", .{});
            return;
        } else {
            i += 1;
            if (i >= args.len) return error.MissingOptionValue;
            const value = args[i];
            if (std.mem.eql(u8, arg, "--frames")) {
                config.frame_limit = try std.fmt.parseInt(usize, value, 10);
                if (config.frame_limit == 0) return error.FrameLimitMustBePositive;
            } else if (std.mem.eql(u8, arg, "--capture")) config.capture = value else if (std.mem.eql(u8, arg, "--assets")) config.asset_root = value else if (std.mem.eql(u8, arg, "--scores")) config.score_override = value else if (std.mem.eql(u8, arg, "--scene")) config.scene = value else return error.UnknownOption;
        }
    }
    if (config.capture != null and config.frame_limit == 0) return error.CaptureRequiresFrameLimit;
    const allocator = if (builtin.mode == .debug) debug_allocator.allocator() else std.heap.smp_allocator;
    app = .{ .allocator = allocator, .io = init_data.io, .home = init_data.environ_map.get("HOME"), .config = config, .game = g.Game.init(allocator) };
    sapp.run(.{ .init_cb = init, .frame_cb = frame, .event_cb = event, .cleanup_cb = cleanup, .width = p.GAME_WIDTH * p.WINDOW_SCALE, .height = p.GAME_HEIGHT * p.WINDOW_SCALE, .window_title = "Gnarlaxx - Zig", .high_dpi = true, .sample_count = 1, .icon = .{ .sokol_default = true }, .logger = .{ .func = sokol.log.func } });
}
test {
    std.testing.refAllDecls(g);
    std.testing.refAllDecls(audio);
    std.testing.refAllDecls(@import("scores.zig"));
}
test "keyboard edges, key repeats and focus pause" {
    var keys: Keys = .{};
    var game = g.Game.init(std.testing.allocator);
    defer game.deinit();
    game.scene = .play;
    keys.event(.{ .type = .KEY_DOWN, .key_code = .D }, &game, false);
    keys.event(.{ .type = .KEY_DOWN, .key_code = .SPACE }, &game, false);
    keys.event(.{ .type = .KEY_DOWN, .key_code = .ENTER }, &game, false);
    const first = keys.read();
    const second = keys.read();
    try std.testing.expect(first.x == 1 and first.fire and first.confirm);
    try std.testing.expect(second.x == 1 and second.fire and !second.confirm);
    keys.event(.{ .type = .KEY_DOWN, .key_code = .ENTER, .key_repeat = true }, &game, false);
    try std.testing.expect(!keys.read().confirm);
    keys.event(.{ .type = .KEY_UP, .key_code = .D }, &game, false);
    try std.testing.expectEqual(@as(f32, 0), keys.read().x);
    keys.event(.{ .type = .UNFOCUSED }, &game, false);
    try std.testing.expect(game.scene == .pause and !keys.read().fire);
    try game.update(.{ .confirm = true }, p.GAME_STEP);
    keys.event(.{ .type = .ICONIFIED }, &game, true);
    try std.testing.expectEqual(g.Scene.play, game.scene);
}
