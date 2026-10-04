package game

import "core:testing"
import "core:mem"
import "core:math"
import "core:fmt"

advance :: proc(g: ^Game, steps: int, input: Input = {}) {
    for _ in 0..<steps { clear(&g.events); assert(update(g, input, GAME_STEP)) }
}
playing :: proc(g: ^Game) {
    init(g)
    assert(start(g))
    g.scene = .Play; g.fade = 0; g.player.pos = {GAME_CENTER_X, PLAYER_SPAWN_Y}
    clear(&g.events)
}
@(test)
movement_pause_and_flow :: proc(t: ^testing.T) {
    g: Game; init(&g); defer destroy(&g)
    testing.expect(t, update(&g, {down = true}, GAME_STEP))
    testing.expect(t, g.menu_choice == .Scores)
    update(&g, {confirm = true}, GAME_STEP)
    testing.expect(t, g.scene == .Scores)
    update(&g, {cancel = true}, GAME_STEP)
    testing.expect(t, g.scene == .Menu)
    testing.expect(t, start(&g))
    warning, go := 0, 0
    for _ in 0..<840 {
        clear(&g.events); testing.expect(t, update(&g, {}, GAME_STEP))
        for event in g.events {
            switch e in event {
            case Sound_Event:
                if e.sound == .Intro_Warning { warning += 1 }
                if e.sound == .Intro_Go { go += 1 }
            case Finished_Event:
            }
        }
    }
    testing.expect(t, warning == 1 && go == 1 && g.scene == .Play && g.fade == 0)
    testing.expect(t, g.player.pos.y == 420 && g.player.lives == 3)
    advance(&g, 60, {x = 1})
    testing.expect(t, g.player.pos.x > 250 && g.player.velocity.x > 150)
    x, speed := g.player.pos.x, g.player.velocity.x
    advance(&g, 12)
    testing.expect(t, g.player.pos.x > x && g.player.velocity.x < speed)
    advance(&g, 300, {x = 1, y = 1, fire = true})
    testing.expect(t, g.player.pos.x <= 384 && g.player.pos.y <= 468 && len(g.bullets) > 0)
    pause(&g)
    time, pos, shot_pos := g.level_time, g.player.pos, g.bullets[0].pos
    advance(&g, 120, {x = 1, fire = true})
    testing.expect(t, g.level_time == time && g.player.pos == pos && g.bullets[0].pos == shot_pos)
    update(&g, {sound = true}, GAME_STEP)
    testing.expect(t, g.scene == .Sound)
    advance(&g, 40, {right = true})
    testing.expect(t, g.volumes[.Master] == 1)
    update(&g, {cancel = true}, GAME_STEP)
    testing.expect(t, g.scene == .Pause)
    update(&g, {confirm = true}, GAME_STEP)
    testing.expect(t, g.scene == .Play)
    pause(&g); update(&g, {menu = true}, GAME_STEP)
    testing.expect(t, g.scene == .Menu)
    start(&g); testing.expect(t, g.volumes[.Master] == 1)
}
inject_hit :: proc(g: ^Game, pos: Vec2) {
    clear(&g.events); clear(&g.bullets)
    assert(push(g, &g.bullets, Bullet{active = true, pos = pos}))
    assert(update(g, {}, GAME_STEP))
}
@(test)
boss_damage_and_lives :: proc(t: ^testing.T) {
    g: Game; playing(&g); defer destroy(&g)
    g.waves_spawned = PAWN_WAVE_COUNT; g.drones_spawned = DRONE_COUNT
    spawn_boss(&g); g.boss.pos = {GAME_CENTER_X, BOSS_REST_Y}; g.boss.phase = .Warn
    inject_hit(&g, g.boss.pos)
    testing.expect(t, g.boss.core_hp == 10 && !g.boss.core_open)
    for _ in 0..<9 { inject_hit(&g, boss_gun(&g.boss, false)) }
    testing.expect(t, g.boss.left_hp == 1 && !g.boss.core_open)
    inject_hit(&g, boss_gun(&g.boss, false))
    for _ in 0..<10 { inject_hit(&g, boss_gun(&g.boss, true)) }
    testing.expect(t, g.boss.core_open && g.boss.right_hp == 0)
    clear(&g.bullets)
    bullet(&g, g.boss.pos+Vec2{0, 65}, {0, -PLAYER_SHOT_SPEED}, false)
    advance(&g, 12)
    testing.expect(t, g.boss.core_hp == 9)
    for _ in 0..<9 { inject_hit(&g, boss_core(&g.boss)) }
    testing.expect(t, g.scene == .Victory && !g.boss.active && g.score == 3750 && len(g.bullets) == 0)
    finished := 0
    for event in g.events { if _, ok := event.(Finished_Event); ok { finished += 1 } }
    testing.expect(t, finished == 1)
    advance(&g, 120)
    update(&g, {confirm = true}, GAME_STEP)
    testing.expect(t, g.scene == .Briefing && g.score == 0 && g.player.lives == 3)
    g.scene = .Play; g.player.pos = {GAME_CENTER_X, PLAYER_SPAWN_Y}
    for life in 0..<3 {
        g.player.invincible = 0
        bullet(&g, g.player.pos, {}, true); bullet(&g, g.player.pos, {}, true)
        testing.expect(t, update(&g, {}, GAME_STEP))
        testing.expect(t, g.player.lives == 2-life)
    }
    testing.expect(t, g.scene == .Game_Over)
}
@(test)
mission_and_replay :: proc(t: ^testing.T) {
    tracker: mem.Tracking_Allocator
    mem.tracking_allocator_init(&tracker, context.allocator)
    defer mem.tracking_allocator_destroy(&tracker)
    g: Game; init(&g, mem.tracking_allocator(&tracker))
    for run in 0..<3 {
        testing.expect(t, start(&g))
        for step := 0; step < 120*95 && g.scene != .Victory; step += 1 {
            input: Input
            if g.scene == .Play {
                target := f32(GAME_CENTER_X)+math.sin(g.level_time*.9)*125
                if g.boss.active { target = g.boss.pos.x if g.boss.core_open else boss_gun(&g.boss, g.boss.left_hp == 0).x }
                input = {x = clamp((target-g.player.pos.x)*.03, -1, 1), fire = true}
                g.player.invincible = 1000
            }
            clear(&g.events); testing.expect(t, update(&g, input, GAME_STEP))
        }
        fmt.printf("Odin mission %d: %v, score=%d, time=%.2fs, heap=%d bytes\n", run+1, g.scene, g.score, g.level_time, heap_bytes(&g))
        testing.expect(t, g.scene == .Victory && g.player.lives == 3 && g.waves_spawned == 10 && g.drones_spawned == 5)
        testing.expect(t, g.score == 9600 && abs(g.level_time-52.75) < .02)
    }
    destroy(&g)
    testing.expect(t, len(tracker.allocation_map) == 0)
}
@(test)
boss_cycle :: proc(t: ^testing.T) {
    g: Game; playing(&g); defer destroy(&g)
    g.player.invincible = 1000
    phases: bit_set[Boss_Phase]
    for _ in 0..<120*85 {
        clear(&g.events); testing.expect(t, update(&g, {}, GAME_STEP))
        if g.boss.active { phases += {g.boss.phase} }
    }
    testing.expect(t, card(phases) == len(Boss_Phase) && g.waves_spawned == 10 && g.drones_spawned == 5)
}
