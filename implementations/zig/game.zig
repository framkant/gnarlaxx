const std = @import("std");
const p = @import("properties.zig");
const a = @import("assets.zig");
const Allocator = std.mem.Allocator;
pub const Vec2 = struct {
    x: f32 = 0,
    y: f32 = 0,
    pub fn add(v: Vec2, w: Vec2) Vec2 {
        return .{ .x = v.x + w.x, .y = v.y + w.y };
    }
    pub fn sub(v: Vec2, w: Vec2) Vec2 {
        return .{ .x = v.x - w.x, .y = v.y - w.y };
    }
    pub fn scale(v: Vec2, n: f32) Vec2 {
        return .{ .x = v.x * n, .y = v.y * n };
    }
};
pub const Scene = enum { menu, briefing, play, pause, scores, sound, victory, game_over };
pub const MenuChoice = enum { start, scores, sound, quit };
pub const VolumeChannel = enum { master, music, effects };
pub const EnemyKind = enum { pawn, drone };
pub const BossPhase = enum { enter, roam, warn, fire, retract, ram, back };
pub const Sound = enum(u32) { player_shot, enemy_shot, hit, explosion, boss_explosion, warning, menu_confirm, boss_ram, intro_warning, intro_go };
pub const Input = struct {
    x: f32 = 0,
    y: f32 = 0,
    fire: bool = false,
    confirm: bool = false,
    cancel: bool = false,
    up: bool = false,
    down: bool = false,
    left: bool = false,
    right: bool = false,
    sound: bool = false,
    menu: bool = false,
};
pub const Player = struct { pos: Vec2 = .{}, velocity: Vec2 = .{}, invincible: f32 = 0, shot_timer: f32 = 0, lives: i32 = 0 };
pub const Enemy = struct {
    active: bool = true,
    kind: EnemyKind = .pawn,
    pos: Vec2 = .{},
    velocity: Vec2 = .{},
    age: f32 = 0,
    base_x: f32 = 0,
    shot_timer: f32 = 0,
    wave: u32 = 0,
    slot: u32 = 0,
};
pub const Bullet = struct { active: bool = true, enemy: bool = false, pos: Vec2 = .{}, velocity: Vec2 = .{} };
pub const Explosion = struct { active: bool = true, pos: Vec2 = .{}, age: f32 = 0, scale: f32 = 1 };
pub const Boss = struct {
    active: bool = false,
    core_open: bool = false,
    pos: Vec2 = .{},
    move_start: Vec2 = .{},
    target: Vec2 = .{},
    left_hp: i32 = 0,
    right_hp: i32 = 0,
    core_hp: i32 = 0,
    phase: BossPhase = .enter,
    timer: f32 = 0,
    shot_timer: f32 = 0,
    retract: f32 = 0,
    flash: f32 = 0,
    pub fn gun(b: *const Boss, right: bool) Vec2 {
        const rect = a.rect(if (right) .boss_gun_right else .boss_gun_left);
        const ox: f32 = if (right) a.BOSS_RIGHT_GUN_OFFSET_X else a.BOSS_LEFT_GUN_OFFSET_X;
        const oy: f32 = if (right) a.BOSS_RIGHT_GUN_OFFSET_Y else a.BOSS_LEFT_GUN_OFFSET_Y;
        const cx = ox - p.BOSS_HALF_WIDTH + f(rect.w) * 0.5 + @as(f32, if (right) -1 else 1) * p.BOSS_RETRACT_DISTANCE * b.retract;
        return .{ .x = b.pos.x + cx, .y = b.pos.y + oy - p.BOSS_HALF_HEIGHT + f(rect.h) * 0.5 };
    }
    pub fn core(b: *const Boss) Vec2 {
        const rect = a.rect(.boss_core);
        return b.pos.add(.{ .x = a.BOSS_CORE_OFFSET_X - p.BOSS_HALF_WIDTH + f(rect.w) * 0.5, .y = a.BOSS_CORE_OFFSET_Y - p.BOSS_HALF_HEIGHT + f(rect.h) * 0.5 });
    }
    fn setPhase(b: *Boss, phase: BossPhase) void {
        b.phase = phase;
        b.timer = 0;
    }
};
pub const Event = union(enum) { sound: struct { id: Sound, gain: f32 }, finished: i32 };

// Owns these four lists through allocator. Do not copy a live Game or keep
// element pointers across a call that might grow their list.
pub const Game = struct {
    allocator: Allocator,
    enemies: std.ArrayList(Enemy) = .empty,
    bullets: std.ArrayList(Bullet) = .empty,
    explosions: std.ArrayList(Explosion) = .empty,
    events: std.ArrayList(Event) = .empty,
    scene: Scene = .menu,
    paused_scene: Scene = .menu,
    sound_return: Scene = .menu,
    player: Player = .{},
    boss: Boss = .{},
    menu_choice: MenuChoice = .start,
    volume_choice: VolumeChannel = .master,
    score: i32 = 0,
    waves_spawned: u32 = 0,
    drones_spawned: u32 = 0,
    volumes: std.enums.EnumArray(VolumeChannel, f32) = .{ .values = .{ 0.65, 0.28, 0.65 } },
    ui_time: f32 = 0,
    scene_time: f32 = 0,
    level_time: f32 = 0,
    scroll: f32 = 0,
    fade: f32 = 0,
    damage_flash: f32 = 0,
    quit_requested: bool = false,
    allocation_failed: bool = false,

    pub fn init(allocator: Allocator) Game {
        return .{ .allocator = allocator };
    }
    pub fn deinit(g: *Game) void {
        g.enemies.deinit(g.allocator);
        g.bullets.deinit(g.allocator);
        g.explosions.deinit(g.allocator);
        g.events.deinit(g.allocator);
        g.* = .{ .allocator = g.allocator };
    }
    pub fn heapBytes(g: *const Game) usize {
        return g.enemies.capacity * @sizeOf(Enemy) + g.bullets.capacity * @sizeOf(Bullet) +
            g.explosions.capacity * @sizeOf(Explosion) + g.events.capacity * @sizeOf(Event);
    }
    pub fn start(g: *Game) Allocator.Error!void {
        if (g.allocation_failed) return error.OutOfMemory;
        errdefer g.allocation_failed = true;
        g.* = .{ .allocator = g.allocator, .enemies = g.enemies, .bullets = g.bullets, .explosions = g.explosions, .events = g.events, .volumes = g.volumes, .scene = .briefing, .player = .{ .pos = .{ .x = p.GAME_CENTER_X, .y = p.PLAYER_ENTRY_Y }, .lives = p.PLAYER_LIVES, .invincible = p.PLAYER_INVINCIBILITY_TIME }, .fade = 1 };
        g.enemies.clearRetainingCapacity();
        g.bullets.clearRetainingCapacity();
        g.explosions.clearRetainingCapacity();
        g.events.clearRetainingCapacity();
        try g.sound(.menu_confirm, 0.5);
    }
    pub fn pause(g: *Game) void {
        if (g.scene == .play or g.scene == .briefing) {
            g.paused_scene = g.scene;
            g.scene = .pause;
        }
    }
    fn sound(g: *Game, id: Sound, gain: f32) Allocator.Error!void {
        try g.events.append(g.allocator, .{ .sound = .{ .id = id, .gain = gain } });
    }
    fn explode(g: *Game, pos: Vec2, scale: f32) Allocator.Error!void {
        try g.explosions.append(g.allocator, .{ .pos = pos, .scale = scale });
    }
    pub fn bullet(g: *Game, pos: Vec2, velocity: Vec2, enemy: bool) Allocator.Error!void {
        try g.bullets.append(g.allocator, .{ .pos = pos, .velocity = velocity, .enemy = enemy });
    }
    fn finish(g: *Game, won: bool) Allocator.Error!void {
        g.scene = if (won) .victory else .game_over;
        g.scene_time = 0;
        if (won) g.score += p.VICTORY_SCORE + g.player.lives * p.SURVIVING_LIFE_SCORE;
        try g.events.append(g.allocator, .{ .finished = g.score });
        g.bullets.clearRetainingCapacity();
    }
    fn damagePlayer(g: *Game) Allocator.Error!void {
        if (g.player.invincible > 0 or g.scene != .play) return;
        try g.explode(g.player.pos, 1.5);
        try g.sound(.explosion, 0.8);
        g.damage_flash = 0.25;
        g.player.lives -= 1;
        if (g.player.lives == 0) return g.finish(false);
        g.player.pos = .{ .x = p.GAME_CENTER_X, .y = p.PLAYER_SPAWN_Y };
        g.player.velocity = .{};
        g.player.invincible = p.PLAYER_INVINCIBILITY_TIME;
        for (g.bullets.items) |*shot| {
            if (shot.enemy) shot.active = false;
        }
    }
    fn spawnWave(g: *Game) Allocator.Error!void {
        const wave = g.waves_spawned;
        g.waves_spawned += 1;
        const y = -f(a.rect(.pawn_0).h) * 0.5 - p.PAWN_SPAWN_GAP;
        const middle = f(p.PAWNS_PER_WAVE - 1) * 0.5;
        for (0..p.PAWNS_PER_WAVE) |slot| {
            const x = formationX(slot, p.PAWNS_PER_WAVE, p.PAWN_SIDE_MARGIN);
            try g.enemies.append(g.allocator, .{ .pos = .{ .x = x, .y = y - p.PAWN_ROW_STAGGER * @abs(middle - f(slot)) }, .base_x = x, .wave = wave, .slot = @intCast(slot), .shot_timer = p.PAWN_FIRST_SHOT_DELAY + f(slot) * p.PAWN_SHOT_STAGGER });
        }
    }
    fn spawnDrone(g: *Game) Allocator.Error!void {
        const lane = g.drones_spawned % p.DRONE_LANE_COUNT;
        g.drones_spawned += 1;
        try g.enemies.append(g.allocator, .{ .kind = .drone, .pos = .{ .x = formationX(lane, p.DRONE_LANE_COUNT, p.DRONE_SIDE_MARGIN), .y = -f(a.rect(.drone_0).h) * 0.5 - p.DRONE_SPAWN_GAP } });
    }
    fn updateEnemies(g: *Game, dt: f32) Allocator.Error!void {
        for (g.enemies.items) |*e| {
            if (!e.active) continue;
            const before = e.age;
            e.age += dt;
            switch (e.kind) {
                .pawn => {
                    e.pos.y += p.PAWN_SPEED * dt;
                    e.pos.x = e.base_x + @sin(e.age * p.PAWN_SWAY_RATE + f(e.wave) * p.PAWN_WAVE_PHASE) * p.PAWN_SWAY_AMPLITUDE;
                    e.shot_timer -= dt;
                    if (e.shot_timer <= 0 and e.pos.y > p.HUD_HEIGHT and e.pos.y < p.GAME_HEIGHT - p.PAWN_SHOOT_BOTTOM_INSET) {
                        var direction = toward(e.pos, g.player.pos, p.PAWN_SHOT_SPEED);
                        direction.y = @max(direction.y, p.PAWN_MIN_SHOT_SPEED_Y);
                        try g.bullet(e.pos, direction, true);
                        try g.sound(.enemy_shot, 0.18);
                        e.shot_timer = p.PAWN_SHOT_INTERVAL;
                    }
                },
                .drone => {
                    if (e.age < p.DRONE_APPROACH_TIME) e.pos.y += p.DRONE_APPROACH_SPEED * dt;
                    if (before < p.DRONE_APPROACH_TIME and e.age >= p.DRONE_APPROACH_TIME) try g.sound(.warning, 0.3);
                    if (before < p.DRONE_CHARGE_TIME and e.age >= p.DRONE_CHARGE_TIME) e.velocity = toward(e.pos, g.player.pos, p.DRONE_CHARGE_SPEED);
                    if (e.age >= p.DRONE_CHARGE_TIME) {
                        if (e.age < p.DRONE_HOMING_END) {
                            const desired = toward(e.pos, g.player.pos, p.DRONE_CHARGE_SPEED);
                            e.velocity = e.velocity.add(desired.sub(e.velocity).scale(dt * p.DRONE_STEERING_RATE));
                        }
                        e.pos = e.pos.add(e.velocity.scale(dt));
                    }
                    if (e.age > p.DRONE_LIFETIME) e.active = false;
                },
            }
            if (e.pos.y > p.GAME_HEIGHT + p.ENEMY_CULL_MARGIN_Y or e.pos.x < -p.ENEMY_CULL_MARGIN_X or e.pos.x > p.GAME_WIDTH + p.ENEMY_CULL_MARGIN_X) e.active = false;
            if (e.active and near(e.pos, g.player.pos, p.ENEMY_CONTACT_RADIUS)) try g.damagePlayer();
        }
    }
    pub fn spawnBoss(g: *Game) Allocator.Error!void {
        if (g.allocation_failed) return error.OutOfMemory;
        errdefer g.allocation_failed = true;
        g.boss = .{ .active = true, .pos = .{ .x = p.GAME_CENTER_X, .y = -p.BOSS_HALF_HEIGHT - p.BOSS_SPAWN_GAP }, .left_hp = p.BOSS_GUN_HP, .right_hp = p.BOSS_GUN_HP, .core_hp = p.BOSS_CORE_HP };
        try g.sound(.warning, 0.7);
    }
    fn bossShoot(g: *Game) Allocator.Error!void {
        const b = &g.boss;
        const sweep = @sin(b.timer * p.BOSS_SWEEP_RATE) * p.BOSS_SWEEP_ANGLE;
        if (b.core_open) {
            var origin = b.core();
            origin.y += f(a.rect(.boss_core).h) * 0.5;
            for (0..p.BOSS_CORE_SHOTS) |i| {
                const angle = sweep + (f(i) - f(p.BOSS_CORE_SHOTS - 1) * 0.5) * p.BOSS_CORE_SHOT_ANGLE;
                try g.bullet(origin, (Vec2{ .x = @sin(angle), .y = @cos(angle) }).scale(p.BOSS_CORE_SHOT_SPEED), true);
            }
        } else {
            for (0..2) |side| {
                if ((if (side != 0) b.right_hp else b.left_hp) <= 0) continue;
                var origin = b.gun(side != 0);
                origin.y += f(a.rect(if (side != 0) .boss_gun_right else .boss_gun_left).h) * 0.5 - p.BOSS_GUN_MUZZLE_INSET;
                for (0..p.BOSS_GUN_SHOTS) |i| {
                    const angle = sweep + (f(i) - f(p.BOSS_GUN_SHOTS - 1) * 0.5) * p.BOSS_GUN_SHOT_ANGLE;
                    try g.bullet(origin, (Vec2{ .x = @sin(angle), .y = @cos(angle) }).scale(p.BOSS_GUN_SHOT_SPEED), true);
                }
            }
        }
        try g.sound(.enemy_shot, 0.35);
    }
    fn updateBoss(g: *Game, dt: f32) Allocator.Error!void {
        const b = &g.boss;
        if (!b.active) return;
        b.timer += dt;
        b.flash = @max(0, b.flash - dt);
        switch (b.phase) {
            .enter => {
                b.pos.y += p.BOSS_ENTRY_SPEED * dt;
                if (b.pos.y >= p.BOSS_REST_Y) {
                    b.pos.y = p.BOSS_REST_Y;
                    b.setPhase(.roam);
                }
            },
            .roam => {
                b.retract = @max(0, b.retract - dt * p.BOSS_EXTEND_RATE);
                b.pos.x = p.GAME_CENTER_X + @sin(g.level_time * p.BOSS_SWAY_RATE) * p.BOSS_ROAM_AMPLITUDE;
                if (b.timer > p.BOSS_ROAM_TIME) {
                    b.setPhase(.warn);
                    try g.sound(.warning, 0.6);
                }
            },
            .warn => {
                if (b.timer > p.BOSS_WARNING_TIME) {
                    b.setPhase(.fire);
                    b.shot_timer = 0;
                }
            },
            .fire => {
                b.pos.x += @sin(g.level_time * p.BOSS_SWAY_RATE) * p.BOSS_FIRE_DRIFT_SPEED * dt;
                b.pos.x = std.math.clamp(b.pos.x, p.BOSS_FIRE_SIDE_MARGIN, p.GAME_WIDTH - p.BOSS_FIRE_SIDE_MARGIN);
                b.shot_timer -= dt;
                if (b.shot_timer <= 0) {
                    try g.bossShoot();
                    b.shot_timer += if (b.core_open) p.BOSS_CORE_SHOT_INTERVAL else p.BOSS_GUN_SHOT_INTERVAL;
                }
                if (b.timer > p.BOSS_FIRE_TIME) {
                    b.setPhase(.retract);
                    try g.sound(.warning, 0.55);
                }
            },
            .retract => {
                b.retract = std.math.clamp(b.timer / p.BOSS_RETRACT_TIME, 0, 1);
                if (b.timer > p.BOSS_RETRACT_TIME) {
                    b.move_start = b.pos;
                    b.target = .{ .x = std.math.clamp(g.player.pos.x, p.BOSS_RAM_SIDE_MARGIN, p.GAME_WIDTH - p.BOSS_RAM_SIDE_MARGIN), .y = std.math.clamp(g.player.pos.y, p.BOSS_RAM_MIN_Y, p.GAME_HEIGHT - p.BOSS_RAM_BOTTOM_INSET) };
                    b.setPhase(.ram);
                    try g.sound(.boss_ram, 0.65);
                }
            },
            .ram => {
                const t = std.math.clamp(b.timer / p.BOSS_RAM_TRAVEL_TIME, 0, 1);
                b.pos = b.move_start.add(b.target.sub(b.move_start).scale(t));
                if (b.timer > p.BOSS_RAM_TRAVEL_TIME + p.BOSS_RAM_HOLD_TIME) {
                    b.move_start = b.pos;
                    b.setPhase(.back);
                }
            },
            .back => {
                const t = std.math.clamp(b.timer / p.BOSS_RETURN_TIME, 0, 1);
                b.pos = b.move_start.add((Vec2{ .x = p.GAME_CENTER_X, .y = p.BOSS_REST_Y }).sub(b.move_start).scale(t));
                if (b.timer > p.BOSS_RETURN_TIME) {
                    b.retract = 0;
                    b.setPhase(.roam);
                }
            },
        }
        if (hitBox(g.player.pos, b.pos, p.BOSS_HALF_WIDTH - p.BOSS_HULL_CONTACT_INSET_X, p.BOSS_HALF_HEIGHT - p.BOSS_HULL_CONTACT_INSET_Y)) try g.damagePlayer();
        for (0..2) |side| {
            if ((if (side != 0) b.right_hp else b.left_hp) > 0 and near(g.player.pos, b.gun(side != 0), p.BOSS_GUN_CONTACT_RADIUS)) try g.damagePlayer();
        }
    }
    fn hitBoss(g: *Game, pos: Vec2) Allocator.Error!bool {
        const b = &g.boss;
        if (!b.active) return false;
        for (0..2) |side| {
            const hp = if (side != 0) &b.right_hp else &b.left_hp;
            const gun = b.gun(side != 0);
            const rect = a.rect(if (side != 0) .boss_gun_right else .boss_gun_left);
            if (hp.* > 0 and hitBox(pos, gun, f(rect.w) * 0.5 + p.BOSS_SHOT_HIT_PADDING, f(rect.h) * 0.5 + p.BOSS_SHOT_HIT_PADDING)) {
                hp.* -= 1;
                b.flash = p.BOSS_HIT_FLASH_TIME;
                try g.sound(.hit, 0.4);
                if (hp.* == 0) {
                    g.score += p.BOSS_GUN_SCORE;
                    try g.explode(gun, 1.8);
                    try g.sound(.explosion, 0.8);
                }
                if (b.left_hp == 0 and b.right_hp == 0 and !b.core_open) {
                    b.core_open = true;
                    b.setPhase(.warn);
                    b.retract = 0;
                    try g.sound(.warning, 0.8);
                }
                return true;
            }
        }
        const rect = a.rect(.boss_core);
        const half_w = f(rect.w) * 0.5 + p.BOSS_SHOT_HIT_PADDING;
        if (b.core_open and hitBox(pos, b.core(), half_w, f(rect.h) * 0.5 + p.BOSS_SHOT_HIT_PADDING)) {
            b.core_hp -= 1;
            b.flash = p.BOSS_HIT_FLASH_TIME;
            try g.sound(.hit, 0.5);
            if (b.core_hp == 0) {
                b.active = false;
                try g.explode(b.pos, 3.5);
                try g.explode(b.pos.add(.{ .x = -38, .y = 25 }), 2);
                try g.explode(b.pos.add(.{ .x = 38, .y = 25 }), 2);
                try g.sound(.boss_explosion, 1);
                try g.finish(true);
            }
            return true;
        }
        if (b.core_open and @abs(pos.x - b.core().x) < half_w) return false;
        return hitBox(pos, b.pos, p.BOSS_HALF_WIDTH - p.BOSS_HULL_SHOT_INSET_X, p.BOSS_HALF_HEIGHT - p.BOSS_HULL_SHOT_INSET_Y);
    }
    fn updateBullets(g: *Game, dt: f32) Allocator.Error!void {
        for (g.bullets.items) |*shot| {
            if (!shot.active) continue;
            shot.pos = shot.pos.add(shot.velocity.scale(dt));
            if (shot.pos.x < -p.BULLET_CULL_MARGIN_X or shot.pos.x > p.GAME_WIDTH + p.BULLET_CULL_MARGIN_X or shot.pos.y < -p.BULLET_CULL_MARGIN_Y or shot.pos.y > p.GAME_HEIGHT + p.BULLET_CULL_MARGIN_Y) {
                shot.active = false;
                continue;
            }
            if (shot.enemy) {
                if (near(shot.pos, g.player.pos, p.PLAYER_HURT_RADIUS)) {
                    shot.active = false;
                    try g.damagePlayer();
                }
            } else {
                for (g.enemies.items) |*enemy| {
                    if (enemy.active and near(shot.pos, enemy.pos, p.ENEMY_HURT_RADIUS)) {
                        enemy.active = false;
                        shot.active = false;
                        g.score += if (enemy.kind == .pawn) p.PAWN_SCORE else p.DRONE_SCORE;
                        try g.explode(enemy.pos, 1.2);
                        try g.sound(.explosion, 0.55);
                        break;
                    }
                }
                if (shot.active and try g.hitBoss(shot.pos)) shot.active = false;
            }
            if (g.scene != .play) break;
        }
    }
    fn updatePlayer(g: *Game, input: Input, dt: f32) Allocator.Error!void {
        const player = &g.player;
        var direction = Vec2{ .x = input.x, .y = input.y };
        const length = @sqrt(direction.x * direction.x + direction.y * direction.y);
        if (length > 1) direction = direction.scale(1 / length);
        const drag = @exp(-p.PLAYER_DRAG * dt);
        player.velocity = player.velocity.add(direction.scale(p.PLAYER_ACCELERATION * dt)).scale(drag);
        player.pos.x = std.math.clamp(player.pos.x + player.velocity.x * dt, p.PLAYER_HALF_WIDTH, p.GAME_WIDTH - p.PLAYER_HALF_WIDTH);
        player.pos.y = std.math.clamp(player.pos.y + player.velocity.y * dt, p.HUD_HEIGHT + p.PLAYER_HALF_HEIGHT, p.GAME_HEIGHT - p.PLAYER_HALF_HEIGHT - f(a.rect(.player_flame_0).h));
        player.invincible = @max(0, player.invincible - dt);
        player.shot_timer -= dt;
        if (input.fire and player.shot_timer <= 0) {
            try g.bullet(player.pos.sub(.{ .y = p.PLAYER_HALF_HEIGHT + p.PLAYER_MUZZLE_GAP }), .{ .y = -p.PLAYER_SHOT_SPEED }, false);
            try g.sound(.player_shot, 0.35);
            player.shot_timer = p.PLAYER_SHOT_INTERVAL;
        }
    }
    pub fn update(g: *Game, input: Input, dt: f32) Allocator.Error!void {
        if (g.allocation_failed) return error.OutOfMemory;
        // No rollback: a failed step is terminal, and its events must not be consumed.
        errdefer g.allocation_failed = true;
        try g.updateScene(input, dt);
        compact(Enemy, &g.enemies);
        compact(Bullet, &g.bullets);
        compact(Explosion, &g.explosions);
    }
    fn updateScene(g: *Game, input: Input, dt: f32) Allocator.Error!void {
        g.ui_time += dt;
        if (input.sound and g.scene != .sound) {
            g.sound_return = g.scene;
            g.scene = .sound;
            return;
        }
        switch (g.scene) {
            .sound => {
                if (input.up) g.volume_choice = cycle(VolumeChannel, g.volume_choice, -1);
                if (input.down) g.volume_choice = cycle(VolumeChannel, g.volume_choice, 1);
                if (input.left or input.right) {
                    const volume = g.volumes.getPtr(g.volume_choice);
                    volume.* = std.math.clamp(volume.* + @as(f32, if (input.right) 0.1 else -0.1), 0, 1);
                    try g.sound(.menu_confirm, 0.25);
                }
                if (input.cancel or input.confirm) g.scene = g.sound_return;
                return;
            },
            .pause => {
                if (input.menu) {
                    g.scene = .menu;
                    g.scene_time = 0;
                    return;
                }
                if (input.cancel or input.confirm) g.scene = g.paused_scene;
                return;
            },
            else => {},
        }
        if (input.cancel and (g.scene == .play or g.scene == .briefing)) {
            g.pause();
            return;
        }
        if (g.scene == .menu) {
            g.scroll += dt * p.BACKGROUND_SCROLL_SPEED;
            if (input.up) g.menu_choice = cycle(MenuChoice, g.menu_choice, -1);
            if (input.down) g.menu_choice = cycle(MenuChoice, g.menu_choice, 1);
            if (input.cancel) g.quit_requested = true;
            if (input.confirm) {
                try g.sound(.menu_confirm, 0.4);
                switch (g.menu_choice) {
                    .start => try g.start(),
                    .scores => g.scene = .scores,
                    .sound => {
                        g.sound_return = .menu;
                        g.scene = .sound;
                    },
                    .quit => g.quit_requested = true,
                }
            }
            return;
        }
        if (g.scene == .scores) {
            if (input.cancel or input.confirm) g.scene = .menu;
            return;
        }
        g.scene_time += dt;
        if (g.scene == .victory or g.scene == .game_over) {
            for (g.explosions.items) |*e| {
                e.age += dt;
                if (e.age > p.EXPLOSION_DURATION + p.RESULT_EXPLOSION_HOLD) e.active = false;
            }
            if (g.scene_time > 0.5) {
                if (input.confirm) try g.start() else if (input.cancel) {
                    g.scene = .menu;
                }
            }
            return;
        }
        g.scroll += dt * p.BACKGROUND_SCROLL_SPEED;
        if (g.scene == .briefing) {
            const before = g.scene_time - dt;
            g.fade = std.math.clamp(1 - g.scene_time / p.BRIEFING_FADE_TIME, 0, 1);
            g.player.pos.y = p.PLAYER_ENTRY_Y - std.math.clamp((g.scene_time - p.BRIEFING_ENTRY_DELAY) / p.BRIEFING_ENTRY_TIME, 0, 1) * (p.PLAYER_ENTRY_Y - p.PLAYER_SPAWN_Y);
            if (before < p.BRIEFING_WARNING_TIME and g.scene_time >= p.BRIEFING_WARNING_TIME) try g.sound(.intro_warning, 0.85);
            if (before < p.BRIEFING_GO_TIME and g.scene_time >= p.BRIEFING_GO_TIME) try g.sound(.intro_go, 0.85);
            if (g.scene_time > p.BRIEFING_END_TIME) {
                g.scene = .play;
                g.scene_time = 0;
                g.player.invincible = p.PLAYER_INVINCIBILITY_TIME;
            }
            return;
        }
        g.level_time += dt;
        g.damage_flash = @max(0, g.damage_flash - dt);
        try g.updatePlayer(input, dt);
        if (g.waves_spawned < p.PAWN_WAVE_COUNT and g.level_time >= p.FIRST_WAVE_TIME + f(g.waves_spawned) * p.WAVE_INTERVAL) try g.spawnWave();
        if (g.drones_spawned < p.DRONE_COUNT and g.level_time >= p.FIRST_DRONE_TIME + f(g.drones_spawned) * p.DRONE_INTERVAL) try g.spawnDrone();
        try g.updateEnemies(dt);
        if (g.scene != .play) return;
        var any_alive = false;
        for (g.enemies.items) |enemy| {
            any_alive = any_alive or enemy.active;
        }
        if (g.waves_spawned == p.PAWN_WAVE_COUNT and g.drones_spawned == p.DRONE_COUNT and !any_alive and !g.boss.active) try g.spawnBoss();
        try g.updateBoss(dt);
        if (g.scene != .play) return;
        try g.updateBullets(dt);
        for (g.explosions.items) |*e| {
            e.age += dt;
            if (e.age > p.EXPLOSION_DURATION) e.active = false;
        }
    }
};
pub fn f(value: anytype) f32 {
    return @floatFromInt(value);
}
fn cycle(comptime T: type, value: T, delta: i32) T {
    const count: i32 = @intCast(@typeInfo(T).@"enum".field_names.len);
    return @fromBackingInt(@intCast(@mod(@as(i32, @backingInt(value)) + delta, count)));
}
fn toward(from: Vec2, to: Vec2, speed: f32) Vec2 {
    const d = to.sub(from);
    const length = @sqrt(d.x * d.x + d.y * d.y);
    return if (length > 0.001) d.scale(1 / length).scale(speed) else .{ .y = speed };
}
fn near(v: Vec2, w: Vec2, radius: f32) bool {
    const d = v.sub(w);
    return d.x * d.x + d.y * d.y < radius * radius;
}
fn hitBox(pos: Vec2, center: Vec2, hw: f32, hh: f32) bool {
    return @abs(pos.x - center.x) < hw and @abs(pos.y - center.y) < hh;
}
fn formationX(slot: usize, count: usize, side_margin: f32) f32 {
    if (count == 1) return p.GAME_CENTER_X;
    return side_margin + (p.GAME_WIDTH - 2 * side_margin) / f(count - 1) * f(slot);
}
fn compact(comptime T: type, list: *std.ArrayList(T)) void {
    var alive: usize = 0;
    for (list.items) |item| {
        if (item.active) {
            list.items[alive] = item;
            alive += 1;
        }
    }
    list.items.len = alive;
}

test "complete missions and retained storage on replay" {
    var g = Game.init(std.testing.allocator);
    defer g.deinit();
    var retained: usize = 0;
    for (0..3) |run| {
        try g.start();
        var finished: usize = 0;
        for (0..120 * 95) |_| {
            if (g.scene == .victory) break;
            var input: Input = .{};
            if (g.scene == .play) {
                var target = p.GAME_CENTER_X + @sin(g.level_time * 0.9) * 125;
                if (g.boss.active) target = if (g.boss.core_open) g.boss.pos.x else g.boss.gun(g.boss.left_hp == 0).x;
                input = .{ .x = std.math.clamp((target - g.player.pos.x) * 0.03, -1, 1), .fire = true };
                g.player.invincible = 1000;
            }
            g.events.clearRetainingCapacity();
            try g.update(input, p.GAME_STEP);
            for (g.events.items) |event| {
                if (event == .finished) finished += 1;
            }
        }
        std.debug.print("Zig mission {d}: {s}, score={d}, time={d:.2}s, heap={d} bytes\n", .{ run + 1, @tagName(g.scene), g.score, g.level_time, g.heapBytes() });
        try std.testing.expectEqual(Scene.victory, g.scene);
        try std.testing.expectEqual(@as(i32, 9600), g.score);
        try std.testing.expectApproxEqAbs(@as(f32, 52.75), g.level_time, 0.02);
        try std.testing.expectEqual(@as(usize, 1), finished);
        try std.testing.expectEqual(@as(i32, 3), g.player.lives);
        try std.testing.expectEqual(@as(u32, 10), g.waves_spawned);
        try std.testing.expectEqual(@as(u32, 5), g.drones_spawned);
        if (run > 0) try std.testing.expectEqual(retained, g.heapBytes());
        retained = g.heapBytes();
    }
}
