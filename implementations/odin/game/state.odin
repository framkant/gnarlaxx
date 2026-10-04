package game

import "core:mem"

init :: proc(g: ^Game, allocator := context.allocator) {
    g^ = {
        enemies = make([dynamic]Enemy, allocator),
        bullets = make([dynamic]Bullet, allocator),
        explosions = make([dynamic]Explosion, allocator),
        events = make([dynamic]Event, allocator),
        volumes = {.Master = .65, .Music = .28, .Effects = .65},
    }
}
destroy :: proc(g: ^Game) {
    delete(g.enemies)
    delete(g.bullets)
    delete(g.explosions)
    delete(g.events)
    g^ = {}
}
heap_bytes :: proc(g: ^Game) -> int {
    return cap(g.enemies)*size_of(Enemy) + cap(g.bullets)*size_of(Bullet) +
           cap(g.explosions)*size_of(Explosion) + cap(g.events)*size_of(Event)
}
push :: proc(g: ^Game, items: ^[dynamic]$T, value: T) -> bool {
    if g.allocation_error != .None { return false }
    count, err := append(items, value)
    g.allocation_error = err
    if count != 1 && err == .None { g.allocation_error = .Out_Of_Memory }
    return g.allocation_error == .None
}
compact :: proc(items: ^[dynamic]$T) {
    alive := 0
    for item in items^ {
        if item.active {
            items^[alive] = item
            alive += 1
        }
    }
    resize(items, alive)
}
start :: proc(g: ^Game) -> bool {
    if g.allocation_error != .None { return false }
    g^ = {
        scene = .Briefing, enemies = g.enemies, bullets = g.bullets,
        explosions = g.explosions, events = g.events, volumes = g.volumes,
        player = {pos = {GAME_CENTER_X, PLAYER_ENTRY_Y}, lives = PLAYER_LIVES,
                  invincible = PLAYER_INVINCIBILITY_TIME}, fade = 1,
    }
    clear(&g.enemies); clear(&g.bullets); clear(&g.explosions); clear(&g.events)
    sound(g, .Menu_Confirm, .5)
    return g.allocation_error == .None
}
pause :: proc(g: ^Game) {
    if g.scene == .Play || g.scene == .Briefing {
        g.paused_scene = g.scene
        g.scene = .Pause
    }
}
sound :: proc(g: ^Game, id: Sound, gain: f32) {
    push(g, &g.events, Event(Sound_Event{id, gain}))
}
explode :: proc(g: ^Game, pos: Vec2, scale: f32) {
    push(g, &g.explosions, Explosion{active = true, pos = pos, scale = scale})
}
bullet :: proc(g: ^Game, pos, velocity: Vec2, enemy: bool) {
    push(g, &g.bullets, Bullet{active = true, enemy = enemy, pos = pos, velocity = velocity})
}
finish :: proc(g: ^Game, won: bool) {
    g.scene = .Victory if won else .Game_Over
    g.scene_time = 0
    if won { g.score += VICTORY_SCORE + g.player.lives * SURVIVING_LIFE_SCORE }
    push(g, &g.events, Event(Finished_Event{g.score}))
    clear(&g.bullets)
}
damage_player :: proc(g: ^Game) {
    if g.player.invincible > 0 || g.scene != .Play { return }
    explode(g, g.player.pos, 1.5)
    sound(g, .Explosion, .8)
    g.damage_flash = .25
    g.player.lives -= 1
    if g.player.lives == 0 { finish(g, false); return }
    g.player.pos = {GAME_CENTER_X, PLAYER_SPAWN_Y}
    g.player.velocity = {}
    g.player.invincible = PLAYER_INVINCIBILITY_TIME
    for &shot in g.bullets { if shot.enemy { shot.active = false } }
}
