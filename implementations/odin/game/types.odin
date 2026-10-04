package game

import "core:mem"

Vec2 :: [2]f32
Scene :: enum { Menu, Briefing, Play, Pause, Scores, Sound, Victory, Game_Over }
Menu_Choice :: enum { Start, Scores, Sound, Quit }
Volume_Channel :: enum { Master, Music, Effects }
Enemy_Kind :: enum { Pawn, Drone }
Boss_Phase :: enum { Enter, Roam, Warn, Fire, Retract, Ram, Return }
Sound :: enum u32 {
    Player_Shot, Enemy_Shot, Hit, Explosion, Boss_Explosion, Warning,
    Menu_Confirm, Boss_Ram, Intro_Warning, Intro_Go,
}

Input :: struct {
    x, y: f32,
    fire, confirm, cancel, up, down, left, right, sound, menu: bool,
}

Player :: struct {
    pos, velocity: Vec2,
    invincible, shot_timer: f32,
    lives: int,
}

Enemy :: struct {
    active: bool,
    kind: Enemy_Kind,
    pos, velocity: Vec2,
    age, base_x, shot_timer: f32,
    wave, slot: int,
}

Bullet :: struct { active, enemy: bool, pos, velocity: Vec2 }
Explosion :: struct { active: bool, pos: Vec2, age, scale: f32 }
Boss :: struct {
    active, core_open: bool,
    pos, move_start, target: Vec2,
    left_hp, right_hp, core_hp: int,
    phase: Boss_Phase,
    timer, shot_timer, retract, flash: f32,
}

Sound_Event :: struct { sound: Sound, gain: f32 }
Finished_Event :: struct { score: int }
Event :: union { Sound_Event, Finished_Event }

// Owns its dynamic arrays. Do not copy live state or retain element pointers across updates.
Game :: struct {
    scene, paused_scene, sound_return: Scene,
    player: Player,
    enemies: [dynamic]Enemy,
    bullets: [dynamic]Bullet,
    explosions: [dynamic]Explosion,
    boss: Boss,
    events: [dynamic]Event,
    menu_choice: Menu_Choice,
    volume_choice: Volume_Channel,
    score, waves_spawned, drones_spawned: int,
    volumes: [Volume_Channel]f32,
    ui_time, scene_time, level_time, scroll, fade, damage_flash: f32,
    quit_requested: bool,
    allocation_error: mem.Allocator_Error,
}
