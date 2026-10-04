package game

import "core:math"

toward :: proc(from, to: Vec2, speed: f32) -> Vec2 {
    delta := to - from
    length := math.sqrt(delta.x*delta.x + delta.y*delta.y)
    return delta / length * speed if length > .001 else Vec2{0, speed}
}

near :: proc(a, b: Vec2, radius: f32) -> bool {
    d := a - b
    return d.x*d.x + d.y*d.y < radius*radius
}

hit_box :: proc(p, center: Vec2, half_w, half_h: f32) -> bool {
    return abs(p.x-center.x) < half_w && abs(p.y-center.y) < half_h
}

formation_x :: proc(slot, count: int, side_margin: f32) -> f32 {
    if count == 1 { return GAME_CENTER_X }
    spacing := (GAME_WIDTH - 2*side_margin) / f32(count-1)
    return side_margin + spacing*f32(slot)
}

spawn_wave :: proc(g: ^Game) {
    wave := g.waves_spawned
    g.waves_spawned += 1
    spawn_y := -f32(SPRITE_RECTS[.Pawn_0].h)*.5 - PAWN_SPAWN_GAP
    middle := f32(PAWNS_PER_WAVE-1)*.5
    for slot in 0..<PAWNS_PER_WAVE {
        x := formation_x(slot, PAWNS_PER_WAVE, PAWN_SIDE_MARGIN)
        if !push(g, &g.enemies, Enemy{
            active = true, kind = .Pawn,
            pos = {x, spawn_y-PAWN_ROW_STAGGER*abs(middle-f32(slot))},
            base_x = x, wave = wave, slot = slot,
            shot_timer = PAWN_FIRST_SHOT_DELAY+f32(slot)*PAWN_SHOT_STAGGER,
        }) { return }
    }
}

spawn_drone :: proc(g: ^Game) {
    lane := g.drones_spawned % DRONE_LANE_COUNT
    g.drones_spawned += 1
    x := formation_x(lane, DRONE_LANE_COUNT, DRONE_SIDE_MARGIN)
    y := -f32(SPRITE_RECTS[.Drone_0].h)*.5 - DRONE_SPAWN_GAP
    push(g, &g.enemies, Enemy{active = true, kind = .Drone, pos = {x, y}})
}

update_enemies :: proc(g: ^Game, dt: f32) {
    for &e in g.enemies {
        if !e.active { continue }
        previous := e.age
        e.age += dt
        switch e.kind {
        case .Pawn:
            e.pos.y += PAWN_SPEED*dt
            e.pos.x = e.base_x + math.sin(e.age*PAWN_SWAY_RATE+f32(e.wave)*PAWN_WAVE_PHASE)*PAWN_SWAY_AMPLITUDE
            e.shot_timer -= dt
            if e.shot_timer <= 0 && e.pos.y > HUD_HEIGHT && e.pos.y < GAME_HEIGHT-PAWN_SHOOT_BOTTOM_INSET {
                direction := toward(e.pos, g.player.pos, PAWN_SHOT_SPEED)
                direction.y = max(direction.y, PAWN_MIN_SHOT_SPEED_Y)
                bullet(g, e.pos, direction, true)
                sound(g, .Enemy_Shot, .18)
                e.shot_timer = PAWN_SHOT_INTERVAL
            }
        case .Drone:
            if e.age < DRONE_APPROACH_TIME { e.pos.y += DRONE_APPROACH_SPEED*dt }
            if previous < DRONE_APPROACH_TIME && e.age >= DRONE_APPROACH_TIME { sound(g, .Warning, .3) }
            if previous < DRONE_CHARGE_TIME && e.age >= DRONE_CHARGE_TIME {
                e.velocity = toward(e.pos, g.player.pos, DRONE_CHARGE_SPEED)
            }
            if e.age >= DRONE_CHARGE_TIME {
                if e.age < DRONE_HOMING_END {
                    desired := toward(e.pos, g.player.pos, DRONE_CHARGE_SPEED)
                    e.velocity += (desired-e.velocity)*dt*DRONE_STEERING_RATE
                }
                e.pos += e.velocity*dt
            }
            if e.age > DRONE_LIFETIME { e.active = false }
        }
        if e.pos.y > GAME_HEIGHT+ENEMY_CULL_MARGIN_Y || e.pos.x < -ENEMY_CULL_MARGIN_X ||
           e.pos.x > GAME_WIDTH+ENEMY_CULL_MARGIN_X { e.active = false }
        if e.active && near(e.pos, g.player.pos, ENEMY_CONTACT_RADIUS) { damage_player(g) }
    }
}

boss_gun :: proc(b: ^Boss, right: bool) -> Vec2 {
    rect := sprite_rect(.Boss_Gun_Right if right else .Boss_Gun_Left)
    offset_x := f32(BOSS_RIGHT_GUN_OFFSET_X if right else BOSS_LEFT_GUN_OFFSET_X)
    offset_y := f32(BOSS_RIGHT_GUN_OFFSET_Y if right else BOSS_LEFT_GUN_OFFSET_Y)
    center_x := offset_x-BOSS_HALF_WIDTH+f32(rect.w)*.5
    center_x += (-1 if right else 1)*BOSS_RETRACT_DISTANCE*b.retract
    return {b.pos.x+center_x, b.pos.y+(offset_y-BOSS_HALF_HEIGHT+f32(rect.h)*.5)}
}

boss_core :: proc(b: ^Boss) -> Vec2 {
    rect := SPRITE_RECTS[.Boss_Core]
    return b.pos + Vec2{BOSS_CORE_OFFSET_X-BOSS_HALF_WIDTH+f32(rect.w)*.5,
                        BOSS_CORE_OFFSET_Y-BOSS_HALF_HEIGHT+f32(rect.h)*.5}
}

spawn_boss :: proc(g: ^Game) -> bool {
    if g.allocation_error != .None { return false }
    g.boss = {active = true, pos = {GAME_CENTER_X, -BOSS_HALF_HEIGHT-BOSS_SPAWN_GAP},
              left_hp = BOSS_GUN_HP, right_hp = BOSS_GUN_HP, core_hp = BOSS_CORE_HP}
    sound(g, .Warning, .7)
    return g.allocation_error == .None
}

boss_phase :: proc(b: ^Boss, phase: Boss_Phase) { b.phase = phase; b.timer = 0 }
boss_shoot :: proc(g: ^Game) {
    b := &g.boss
    sweep := math.sin(b.timer*BOSS_SWEEP_RATE)*BOSS_SWEEP_ANGLE
    if b.core_open {
        origin := boss_core(b)
        origin.y += f32(SPRITE_RECTS[.Boss_Core].h)*.5
        for i in 0..<BOSS_CORE_SHOTS {
            a := sweep+(f32(i)-f32(BOSS_CORE_SHOTS-1)*.5)*BOSS_CORE_SHOT_ANGLE
            bullet(g, origin, Vec2{math.sin(a), math.cos(a)}*BOSS_CORE_SHOT_SPEED, true)
        }
    } else {
        for side in 0..<2 {
            if (b.right_hp if side != 0 else b.left_hp) <= 0 { continue }
            origin := boss_gun(b, side != 0)
            rect := sprite_rect(.Boss_Gun_Right if side != 0 else .Boss_Gun_Left)
            origin.y += f32(rect.h)*.5-BOSS_GUN_MUZZLE_INSET
            for i in 0..<BOSS_GUN_SHOTS {
                a := sweep+(f32(i)-f32(BOSS_GUN_SHOTS-1)*.5)*BOSS_GUN_SHOT_ANGLE
                bullet(g, origin, Vec2{math.sin(a), math.cos(a)}*BOSS_GUN_SHOT_SPEED, true)
            }
        }
    }
    sound(g, .Enemy_Shot, .35)
}

update_boss :: proc(g: ^Game, dt: f32) {
    b := &g.boss
    if !b.active { return }
    b.timer += dt
    b.flash = max(0, b.flash-dt)
    switch b.phase {
    case .Enter:
        b.pos.y += BOSS_ENTRY_SPEED*dt
        if b.pos.y >= BOSS_REST_Y { b.pos.y = BOSS_REST_Y; boss_phase(b, .Roam) }
    case .Roam:
        b.retract = max(0, b.retract-dt*BOSS_EXTEND_RATE)
        b.pos.x = GAME_CENTER_X+math.sin(g.level_time*BOSS_SWAY_RATE)*BOSS_ROAM_AMPLITUDE
        if b.timer > BOSS_ROAM_TIME { boss_phase(b, .Warn); sound(g, .Warning, .6) }
    case .Warn:
        if b.timer > BOSS_WARNING_TIME { boss_phase(b, .Fire); b.shot_timer = 0 }
    case .Fire:
        b.pos.x += math.sin(g.level_time*BOSS_SWAY_RATE)*BOSS_FIRE_DRIFT_SPEED*dt
        b.pos.x = clamp(b.pos.x, BOSS_FIRE_SIDE_MARGIN, GAME_WIDTH-BOSS_FIRE_SIDE_MARGIN)
        b.shot_timer -= dt
        if b.shot_timer <= 0 {
            boss_shoot(g)
            b.shot_timer += BOSS_CORE_SHOT_INTERVAL if b.core_open else BOSS_GUN_SHOT_INTERVAL
        }
        if b.timer > BOSS_FIRE_TIME { boss_phase(b, .Retract); sound(g, .Warning, .55) }
    case .Retract:
        b.retract = clamp(b.timer/BOSS_RETRACT_TIME, 0, 1)
        if b.timer > BOSS_RETRACT_TIME {
            b.move_start = b.pos
            b.target = {clamp(g.player.pos.x, BOSS_RAM_SIDE_MARGIN, GAME_WIDTH-BOSS_RAM_SIDE_MARGIN),
                        clamp(g.player.pos.y, BOSS_RAM_MIN_Y, GAME_HEIGHT-BOSS_RAM_BOTTOM_INSET)}
            boss_phase(b, .Ram); sound(g, .Boss_Ram, .65)
        }
    case .Ram:
        t := clamp(b.timer/BOSS_RAM_TRAVEL_TIME, 0, 1)
        b.pos = b.move_start+(b.target-b.move_start)*t
        if b.timer > BOSS_RAM_TRAVEL_TIME+BOSS_RAM_HOLD_TIME { b.move_start = b.pos; boss_phase(b, .Return) }
    case .Return:
        t := clamp(b.timer/BOSS_RETURN_TIME, 0, 1)
        b.pos = b.move_start+(Vec2{GAME_CENTER_X, BOSS_REST_Y}-b.move_start)*t
        if b.timer > BOSS_RETURN_TIME { b.retract = 0; boss_phase(b, .Roam) }
    }
    if hit_box(g.player.pos, b.pos, BOSS_HALF_WIDTH-BOSS_HULL_CONTACT_INSET_X,
               BOSS_HALF_HEIGHT-BOSS_HULL_CONTACT_INSET_Y) { damage_player(g) }
    for side in 0..<2 {
        if (b.right_hp if side != 0 else b.left_hp) > 0 &&
           near(g.player.pos, boss_gun(b, side != 0), BOSS_GUN_CONTACT_RADIUS) { damage_player(g) }
    }
}

hit_boss :: proc(g: ^Game, pos: Vec2) -> bool {
    b := &g.boss
    if !b.active { return false }
    for side in 0..<2 {
        hp := &b.right_hp if side != 0 else &b.left_hp
        gun := boss_gun(b, side != 0)
        rect := sprite_rect(.Boss_Gun_Right if side != 0 else .Boss_Gun_Left)
        if hp^ > 0 && hit_box(pos, gun, f32(rect.w)*.5+BOSS_SHOT_HIT_PADDING,
                              f32(rect.h)*.5+BOSS_SHOT_HIT_PADDING) {
            hp^ -= 1
            b.flash = BOSS_HIT_FLASH_TIME
            sound(g, .Hit, .4)
            if hp^ == 0 { g.score += BOSS_GUN_SCORE; explode(g, gun, 1.8); sound(g, .Explosion, .8) }
            if b.left_hp == 0 && b.right_hp == 0 && !b.core_open {
                b.core_open = true; boss_phase(b, .Warn); b.retract = 0; sound(g, .Warning, .8)
            }
            return true
        }
    }
    core := SPRITE_RECTS[.Boss_Core]
    half_w := f32(core.w)*.5+BOSS_SHOT_HIT_PADDING
    if b.core_open && hit_box(pos, boss_core(b), half_w, f32(core.h)*.5+BOSS_SHOT_HIT_PADDING) {
        b.core_hp -= 1; b.flash = BOSS_HIT_FLASH_TIME; sound(g, .Hit, .5)
        if b.core_hp == 0 {
            b.active = false
            explode(g, b.pos, 3.5)
            explode(g, b.pos+Vec2{-38, 25}, 2)
            explode(g, b.pos+Vec2{38, 25}, 2)
            sound(g, .Boss_Explosion, 1); finish(g, true)
        }
        return true
    }
    // The open channel lets shots reach the recessed core through the hull.
    if b.core_open && abs(pos.x-boss_core(b).x) < half_w { return false }
    return hit_box(pos, b.pos, BOSS_HALF_WIDTH-BOSS_HULL_SHOT_INSET_X,
                   BOSS_HALF_HEIGHT-BOSS_HULL_SHOT_INSET_Y)
}

update_bullets :: proc(g: ^Game, dt: f32) {
    for &shot in g.bullets {
        if !shot.active { continue }
        shot.pos += shot.velocity*dt
        if shot.pos.x < -BULLET_CULL_MARGIN_X || shot.pos.x > GAME_WIDTH+BULLET_CULL_MARGIN_X ||
           shot.pos.y < -BULLET_CULL_MARGIN_Y || shot.pos.y > GAME_HEIGHT+BULLET_CULL_MARGIN_Y {
            shot.active = false; continue
        }
        if shot.enemy {
            if near(shot.pos, g.player.pos, PLAYER_HURT_RADIUS) { shot.active = false; damage_player(g) }
        } else {
            for &enemy in g.enemies {
                if enemy.active && near(shot.pos, enemy.pos, ENEMY_HURT_RADIUS) {
                    enemy.active = false; shot.active = false
                    g.score += PAWN_SCORE if enemy.kind == .Pawn else DRONE_SCORE
                    explode(g, enemy.pos, 1.2); sound(g, .Explosion, .55)
                    break
                }
            }
            if shot.active && hit_boss(g, shot.pos) { shot.active = false }
        }
        if g.scene != .Play { break }
    }
}

update_player :: proc(g: ^Game, input: Input, dt: f32) {
    p := &g.player
    direction := Vec2{input.x, input.y}
    length := math.sqrt(direction.x*direction.x+direction.y*direction.y)
    if length > 1 { direction /= length }
    drag := math.exp(-PLAYER_DRAG*dt)
    p.velocity = (p.velocity+direction*PLAYER_ACCELERATION*dt)*drag
    p.pos.x = clamp(p.pos.x+p.velocity.x*dt, PLAYER_HALF_WIDTH, GAME_WIDTH-PLAYER_HALF_WIDTH)
    p.pos.y = clamp(p.pos.y+p.velocity.y*dt, HUD_HEIGHT+PLAYER_HALF_HEIGHT,
                     GAME_HEIGHT-PLAYER_HALF_HEIGHT-f32(SPRITE_RECTS[.Player_Flame_0].h))
    p.invincible = max(0, p.invincible-dt)
    p.shot_timer -= dt
    if input.fire && p.shot_timer <= 0 {
        bullet(g, p.pos-Vec2{0, PLAYER_HALF_HEIGHT+PLAYER_MUZZLE_GAP}, {0, -PLAYER_SHOT_SPEED}, false)
        sound(g, .Player_Shot, .35); p.shot_timer = PLAYER_SHOT_INTERVAL
    }
}
