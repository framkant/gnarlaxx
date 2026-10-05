const std = @import("std");
const game = @import("game.zig");
const p = @import("properties.zig");
const a = @import("assets.zig");
const Renderer = @import("renderer.zig").Renderer;
const Scores = @import("scores.zig").Scores;
const f = game.f;
const white = 0xeaf5ffff;
const cyan = 0x73dbe8ff;
const muted = 0x93a0b8ff;
const gold = 0xffdc8aff;
const panel_margin = 26;
const life_right_margin = 14;
const life_gap = 6;
const bar_width = 52;
const bar_gap = 10;
const bar_count = 3;

fn centered(r: *const Renderer, text: []const u8, y: f32, scale: u32, color: u32) void {
    r.text(text, (p.GAME_WIDTH - f(text.len * a.FONT_ADVANCE * scale)) * 0.5, y, scale, color);
}
fn centerFmt(r: *const Renderer, comptime format: []const u8, args: anytype, y: f32, scale: u32, color: u32) void {
    var buffer: [128]u8 = undefined;
    centered(r, std.fmt.bufPrint(&buffer, format, args) catch unreachable, y, scale, color);
}
fn spriteCentered(r: *const Renderer, id: a.Sprite, pos: game.Vec2, scale: f32, color: u32) void {
    const rect = a.rect(id);
    r.sprite(id, pos.x - f(rect.w) * scale * 0.5, pos.y - f(rect.h) * scale * 0.5, scale, color);
}
fn panel(r: *const Renderer, y: f32, h: f32) void {
    const width = p.GAME_WIDTH - 2 * panel_margin;
    r.rect(panel_margin, y, width, h, 0x0a1024ee);
    r.rect(panel_margin, y, width, 1, 0x526389ff);
    r.rect(panel_margin, y + h - 1, width, 1, 0x526389ff);
}
fn background(r: *const Renderer, g: *const game.Game) void {
    const rows = (p.GAME_HEIGHT + a.BACKGROUND_TILE_SIZE - 1) / a.BACKGROUND_TILE_SIZE;
    const columns = (p.GAME_WIDTH + a.BACKGROUND_TILE_SIZE - 1) / a.BACKGROUND_TILE_SIZE;
    const pattern_height = a.BACKGROUND_PATTERN_ROWS * a.BACKGROUND_TILE_SIZE;
    for (0..2) |layer| {
        const offset = @mod(g.scroll * @as(f32, if (layer != 0) p.BACKGROUND_NEAR_SPEED_RATIO else 1), pattern_height);
        var row: i32 = -a.BACKGROUND_PATTERN_ROWS;
        while (row < rows) : (row += 1) {
            for (0..columns) |col| {
                const tile = a.BACKGROUND_PATTERN[@intCast(@mod(row + a.BACKGROUND_PATTERN_ROWS, a.BACKGROUND_PATTERN_ROWS))][col % a.BACKGROUND_PATTERN_COLUMNS];
                const base: a.Sprite = if (layer != 0) .stars_near_0 else .stars_far_0;
                r.sprite(@fromBackingInt(@intCast(@as(u32, @backingInt(base)) + tile)), f(col * a.BACKGROUND_TILE_SIZE), f(row * a.BACKGROUND_TILE_SIZE) + offset, 1, if (layer != 0) 0xaabbdde0 else 0xffffffff);
            }
        }
    }
}
fn drawBoss(r: *const Renderer, g: *const game.Game) void {
    const b = &g.boss;
    if (!b.active) return;
    const warn = (b.phase == .warn or b.phase == .retract) and @as(u32, @intFromFloat(b.timer * 10)) % 2 == 0;
    const tint: u32 = if (b.flash > 0) 0xffaaaaff else if (warn) 0xff5555ff else 0xffffffff;
    for (0..2) |side| {
        if ((if (side != 0) b.right_hp else b.left_hp) > 0) spriteCentered(r, if (side != 0) .boss_gun_right else .boss_gun_left, b.gun(side != 0), 1, tint);
    }
    spriteCentered(r, .boss_body, b.pos, 1, tint);
    if (b.core_open) spriteCentered(r, .boss_core, b.core(), 1, tint);
    centered(r, if (b.core_open) "CORE EXPOSED" else if (b.phase == .retract or b.phase == .ram) "RAM ATTACK" else "DESTROY BOTH GUNS", 38, 1, if (b.core_open) 0xff8e9fff else gold);
    const group_width = bar_count * bar_width + (bar_count - 1) * bar_gap;
    for (0..bar_count) |side| {
        const hp = if (side == 0) b.left_hp else if (side == 1) b.core_hp else b.right_hp;
        if (side == 1 and !b.core_open) continue;
        const x = f(p.GAME_WIDTH - group_width) * 0.5 + f(side * (bar_width + bar_gap));
        const max_hp: f32 = if (side == 1) p.BOSS_CORE_HP else p.BOSS_GUN_HP;
        r.rect(x, 52, bar_width, 3, 0x30394fff);
        r.rect(x, 52, bar_width * f(hp) / max_hp, 3, if (side == 1) 0xff688aff else 0xa6df64ff);
    }
}
fn world(r: *const Renderer, g: *const game.Game) void {
    for (g.enemies.items) |e| {
        if (!e.active) continue;
        const blink = e.kind == .drone and e.age >= p.DRONE_APPROACH_TIME and e.age < p.DRONE_CHARGE_TIME and @as(u32, @intFromFloat(e.age * 12)) % 2 == 0;
        const id: a.Sprite = if (e.kind == .pawn)
            @fromBackingInt(@intCast(@backingInt(a.Sprite.pawn_0) + @as(u32, @intFromFloat(e.age * 5)) % 2))
        else
            @fromBackingInt(@intCast(@backingInt(a.Sprite.drone_0) + @as(u32, if (e.age >= p.DRONE_CHARGE_TIME) 2 else @as(u32, @intFromFloat(e.age * 4)) % 2)));
        spriteCentered(r, id, e.pos, 1, if (blink) 0xff7777ff else 0xffffffff);
    }
    drawBoss(r, g);
    for (g.bullets.items) |b| {
        if (b.active) spriteCentered(r, if (b.enemy) (if (g.boss.core_open) .enemy_bullet_hot else .enemy_bullet) else .player_bullet, b.pos, 1, 0xffffffff);
    }
    const player = &g.player;
    if (player.lives > 0 and (player.invincible <= 0 or player.invincible > 10 or @as(u32, @intFromFloat(g.ui_time * 12)) % 2 == 0)) {
        const id: a.Sprite = if (player.velocity.x < -p.PLAYER_BANK_SPEED) .player_left else if (player.velocity.x > p.PLAYER_BANK_SPEED) .player_right else .player_idle;
        spriteCentered(r, id, player.pos, 1, 0xffffffff);
        r.sprite(@fromBackingInt(@intCast(@backingInt(a.Sprite.player_flame_0) + @as(u32, @intFromFloat(g.ui_time * 12)) % 2)), player.pos.x - f(a.rect(.player_flame_0).w) * 0.5, player.pos.y + p.PLAYER_HALF_HEIGHT, 1, 0xffffffff);
    }
    for (g.explosions.items) |e| {
        if (e.active) spriteCentered(r, @fromBackingInt(@intCast(@backingInt(a.Sprite.explosion_0) + @min(@as(u32, @intFromFloat(e.age * p.EXPLOSION_FPS)), p.EXPLOSION_FRAMES - 1))), e.pos, e.scale, 0xffffffff);
    }
    r.rect(0, 0, p.GAME_WIDTH, p.HUD_HEIGHT, 0x080b1cdd);
    var buffer: [80]u8 = undefined;
    r.text(std.fmt.bufPrint(&buffer, "SCORE {d:0>7}", .{@as(u32, @intCast(g.score))}) catch unreachable, 12, 11, 1, white);
    const life = a.rect(.life);
    const stride = life.w + life_gap;
    const start = p.GAME_WIDTH - life_right_margin - p.PLAYER_LIVES * stride + life_gap;
    var i: i32 = 0;
    while (i < player.lives) : (i += 1) r.sprite(.life, f(start + i * stride), f(p.HUD_HEIGHT - life.h) * 0.5, 1, 0xffffffff);
    if (!g.boss.active and g.scene != .briefing) r.text(std.fmt.bufPrint(&buffer, "WAVES {d:0>2}/{d}  DRONES {d}/{d}", .{ g.waves_spawned, p.PAWN_WAVE_COUNT, g.drones_spawned, p.DRONE_COUNT }) catch unreachable, 12, p.GAME_HEIGHT - a.FONT_CELL_HEIGHT - 10, 1, muted);
    if (g.damage_flash > 0) r.rect(0, p.HUD_HEIGHT, p.GAME_WIDTH, p.GAME_HEIGHT - p.HUD_HEIGHT, 0xa7203030);
}
pub fn draw(r: *const Renderer, g: *const game.Game, scores: Scores, save_failed: bool, audio_available: bool) void {
    r.begin();
    background(r, g);
    var visible = if (g.scene == .pause) g.paused_scene else g.scene;
    if (visible == .sound) visible = if (g.sound_return == .pause) g.paused_scene else g.sound_return;
    if (visible == .menu or visible == .scores) {
        r.sprite(.title, f(p.GAME_WIDTH - a.rect(.title).w) * 0.5, 70, 1, 0xffffffff);
        centered(r, "ONE SHIP. ONE BAD INVASION.", 128, 1, cyan);
        if (visible == .menu) {
            const labels = std.enums.EnumArray(game.MenuChoice, []const u8).init(.{ .start = "START MISSION", .scores = "HIGH SCORES", .sound = "SOUND", .quit = "QUIT" });
            for (std.enums.values(game.MenuChoice)) |choice| {
                const y = f(@backingInt(choice)) * 30;
                if (choice == g.menu_choice) {
                    r.rect(102, 211 + y, 196, 23, 0x1b294dcc);
                    r.text(">", 110, 219 + y, 1, gold);
                }
                centered(r, labels.get(choice), 219 + y, 1, if (choice == g.menu_choice) gold else white);
            }
            centered(r, "WASD MOVE / HOLD SPACE TO FIRE", 390, 1, muted);
            centered(r, "ENTER SELECT / ESC PAUSE / V SOUND", 410, 1, muted);
            centered(r, "ZIG  /  SOKOL  /  GNARLAXX", 466, 1, cyan);
        } else {
            centered(r, "HIGH SCORES", 186, 2, gold);
            for (scores.values, 0..) |score, i| centerFmt(r, "{d}.   {d:0>9}", .{ i + 1, @as(u32, @intCast(score)) }, f(237 + i * 28), 1, white);
            centered(r, "ENTER / ESC TO RETURN", 429, 1, muted);
        }
    } else {
        world(r, g);
        if (visible == .briefing) {
            panel(r, 191, 104);
            if (g.scene_time < p.BRIEFING_GO_TIME) {
                centered(r, "ENEMY BOSS REPORTED", 212, 1, gold);
                centered(r, "TO PREPARE INVASION", 232, 1, gold);
            } else {
                centered(r, "YOU MUST STOPP HIM!", 212, 1, gold);
                centered(r, "GO!", 240, 2, cyan);
            }
        }
        if (visible == .victory or visible == .game_over) {
            panel(r, 174, 158);
            if (visible == .victory) r.sprite(.level_cleared, f(p.GAME_WIDTH - a.rect(.level_cleared).w) * 0.5, 192, 1, 0xffffffff) else centered(r, "GAME OVER", 198, 2, 0xff8e9fff);
            centerFmt(r, "FINAL SCORE {d:0>7}", .{@as(u32, @intCast(g.score))}, 242, 1, gold);
            centered(r, if (visible == .victory) "READY FOR THE NEXT MISSION?" else "THE INVASION WILL HAVE TO WAIT.", 266, 1, white);
            centered(r, "ENTER REPLAY / ESC MENU", 304, 1, muted);
        }
    }
    if (g.scene == .pause) {
        r.rect(0, 0, p.GAME_WIDTH, p.GAME_HEIGHT, 0x020510a0);
        panel(r, 191, 116);
        centered(r, "PAUSED", 214, 2, gold);
        centered(r, "ESC / ENTER RESUME", 253, 1, white);
        centered(r, "V SOUND / Q MAIN MENU", 278, 1, muted);
    }
    if (g.scene == .sound) {
        r.rect(0, 0, p.GAME_WIDTH, p.GAME_HEIGHT, 0x020510c0);
        panel(r, 158, 198);
        centered(r, "SOUND", 179, 2, gold);
        const labels = std.enums.EnumArray(game.VolumeChannel, []const u8).init(.{ .master = "MASTER", .music = "MUSIC", .effects = "EFFECTS" });
        for (std.enums.values(game.VolumeChannel)) |channel| {
            centerFmt(r, "{s} {s: <7} {d: >3}%", .{ if (g.volume_choice == channel) ">" else " ", labels.get(channel), @as(u32, @intFromFloat(@round(g.volumes.get(channel) * 100))) }, 222 + f(@backingInt(channel)) * 28, 1, if (g.volume_choice == channel) gold else white);
        }
        centered(r, "ARROWS ADJUST / ESC RETURN", 328, 1, muted);
    }
    if (save_failed) centered(r, "HIGH SCORES COULD NOT BE SAVED", 450, 1, 0xff8e9fff);
    if (!audio_available) centered(r, "AUDIO OUTPUT UNAVAILABLE", p.GAME_HEIGHT - a.FONT_CELL_HEIGHT - 10, 1, 0xff8e9fff);
    if (g.fade > 0 and (g.scene == .briefing or g.scene == .pause)) r.rect(0, 0, p.GAME_WIDTH, p.GAME_HEIGHT, @intFromFloat(g.fade * 255));
    r.present();
}
