package game

update :: proc(g: ^Game, input: Input, dt: f32) -> bool {
    if g.allocation_error != .None { return false }
    update_scene(g, input, dt)
    compact(&g.enemies); compact(&g.bullets); compact(&g.explosions)
    return g.allocation_error == .None
}

update_scene :: proc(g: ^Game, input: Input, dt: f32) {
    g.ui_time += dt
    if input.sound && g.scene != .Sound { g.sound_return = g.scene; g.scene = .Sound; return }
    #partial switch g.scene {
    case .Sound:
        if input.up { g.volume_choice = Volume_Channel((int(g.volume_choice)+len(Volume_Channel)-1)%len(Volume_Channel)) }
        if input.down { g.volume_choice = Volume_Channel((int(g.volume_choice)+1)%len(Volume_Channel)) }
        if input.left || input.right {
            g.volumes[g.volume_choice] = clamp(g.volumes[g.volume_choice]+(.1 if input.right else -.1), 0, 1)
            sound(g, .Menu_Confirm, .25)
        }
        if input.cancel || input.confirm { g.scene = g.sound_return }
        return
    case .Pause:
        if input.menu { g.scene = .Menu; g.scene_time = 0; return }
        if input.cancel || input.confirm { g.scene = g.paused_scene }
        return
    case:
    }
    if input.cancel && (g.scene == .Play || g.scene == .Briefing) { pause(g); return }
    if g.scene == .Menu {
        g.scroll += dt*BACKGROUND_SCROLL_SPEED
        if input.up { g.menu_choice = Menu_Choice((int(g.menu_choice)+len(Menu_Choice)-1)%len(Menu_Choice)) }
        if input.down { g.menu_choice = Menu_Choice((int(g.menu_choice)+1)%len(Menu_Choice)) }
        if input.cancel { g.quit_requested = true }
        if input.confirm {
            sound(g, .Menu_Confirm, .4)
            switch g.menu_choice {
            case .Start: start(g)
            case .Scores: g.scene = .Scores
            case .Sound: g.sound_return = .Menu; g.scene = .Sound
            case .Quit: g.quit_requested = true
            }
        }
        return
    }
    if g.scene == .Scores {
        if input.cancel || input.confirm { g.scene = .Menu }
        return
    }
    g.scene_time += dt
    if g.scene == .Victory || g.scene == .Game_Over {
        for &e in g.explosions { e.age += dt; if e.age > EXPLOSION_DURATION+RESULT_EXPLOSION_HOLD { e.active = false } }
        if g.scene_time > .5 {
            if input.confirm { start(g) } else if input.cancel { g.scene = .Menu }
        }
        return
    }
    g.scroll += dt*BACKGROUND_SCROLL_SPEED
    if g.scene == .Briefing {
        before := g.scene_time-dt
        g.fade = clamp(1-g.scene_time/BRIEFING_FADE_TIME, 0, 1)
        g.player.pos.y = PLAYER_ENTRY_Y-clamp((g.scene_time-BRIEFING_ENTRY_DELAY)/BRIEFING_ENTRY_TIME, 0, 1)*(PLAYER_ENTRY_Y-PLAYER_SPAWN_Y)
        if before < BRIEFING_WARNING_TIME && g.scene_time >= BRIEFING_WARNING_TIME { sound(g, .Intro_Warning, .85) }
        if before < BRIEFING_GO_TIME && g.scene_time >= BRIEFING_GO_TIME { sound(g, .Intro_Go, .85) }
        if g.scene_time > BRIEFING_END_TIME {
            g.scene = .Play; g.scene_time = 0; g.player.invincible = PLAYER_INVINCIBILITY_TIME
        }
        return
    }
    g.level_time += dt
    g.damage_flash = max(0, g.damage_flash-dt)
    update_player(g, input, dt)
    if g.waves_spawned < PAWN_WAVE_COUNT && g.level_time >= FIRST_WAVE_TIME+f32(g.waves_spawned)*WAVE_INTERVAL { spawn_wave(g) }
    if g.drones_spawned < DRONE_COUNT && g.level_time >= FIRST_DRONE_TIME+f32(g.drones_spawned)*DRONE_INTERVAL { spawn_drone(g) }
    update_enemies(g, dt)
    if g.scene != .Play { return }
    any_alive := false
    for e in g.enemies { any_alive ||= e.active }
    if g.waves_spawned == PAWN_WAVE_COUNT && g.drones_spawned == DRONE_COUNT && !any_alive && !g.boss.active { spawn_boss(g) }
    update_boss(g, dt)
    if g.scene != .Play { return }
    update_bullets(g, dt)
    for &e in g.explosions { e.age += dt; if e.age > EXPLOSION_DURATION { e.active = false } }
}
