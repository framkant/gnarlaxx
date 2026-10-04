package presentation

import "core:fmt"
import "core:math"
import g "../game"
import r "../renderer"
import scores "../scores"

WHITE :: 0xeaf5ffff
CYAN :: 0x73dbe8ff
MUTED :: 0x93a0b8ff
GOLD :: 0xffdc8aff
PANEL_MARGIN :: 26
LIFE_RIGHT_MARGIN :: 14
LIFE_GAP :: 6
BOSS_HEALTH_BAR_WIDTH :: 52
BOSS_HEALTH_BAR_GAP :: 10
BOSS_HEALTH_BAR_COUNT :: 3

centered :: proc(text: string, y: f32, scale: int, color: u32) {
    r.text(text, (g.GAME_WIDTH-f32(len(text)*g.FONT_ADVANCE*scale))*.5, y, scale, color)
}

sprite_centered :: proc(id: g.Sprite, pos: g.Vec2, scale: f32, color: u32) {
    rect := g.sprite_rect(id)
    r.sprite(id, pos.x-f32(rect.w)*scale*.5, pos.y-f32(rect.h)*scale*.5, scale, color)
}

panel :: proc(y, h: f32) {
    width :: g.GAME_WIDTH-2*PANEL_MARGIN
    r.rect(PANEL_MARGIN, y, width, h, 0x0a1024ee)
    r.rect(PANEL_MARGIN, y, width, 1, 0x526389ff)
    r.rect(PANEL_MARGIN, y+h-1, width, 1, 0x526389ff)
}

background :: proc(game: ^g.Game) {
    rows :: (g.GAME_HEIGHT+g.BACKGROUND_TILE_SIZE-1)/g.BACKGROUND_TILE_SIZE
    columns :: (g.GAME_WIDTH+g.BACKGROUND_TILE_SIZE-1)/g.BACKGROUND_TILE_SIZE
    pattern_height :: g.BACKGROUND_PATTERN_ROWS*g.BACKGROUND_TILE_SIZE
    pattern := g.BACKGROUND_PATTERN
    for layer in 0..<2 {
        offset := math.mod(game.scroll*(g.BACKGROUND_NEAR_SPEED_RATIO if layer != 0 else 1), pattern_height)
        for row in -g.BACKGROUND_PATTERN_ROWS..<rows {
            for col in 0..<columns {
                tile := pattern[(row+g.BACKGROUND_PATTERN_ROWS)%g.BACKGROUND_PATTERN_ROWS][col%g.BACKGROUND_PATTERN_COLUMNS]
                base := g.Sprite.Stars_Near_0 if layer != 0 else g.Sprite.Stars_Far_0
                r.sprite(g.Sprite(int(base)+tile), f32(col*g.BACKGROUND_TILE_SIZE), f32(row*g.BACKGROUND_TILE_SIZE)+offset,
                    1, 0xaabbdde0 if layer != 0 else 0xffffffff)
            }
        }
    }
}

draw_boss :: proc(game: ^g.Game) {
    b := &game.boss
    if !b.active { return }
    warn := (b.phase == .Warn || b.phase == .Retract) && int(b.timer*10)%2 == 0
    tint: u32 = 0xffaaaaff if b.flash > 0 else (0xff5555ff if warn else 0xffffffff)
    for side in 0..<2 {
        if (b.right_hp if side != 0 else b.left_hp) > 0 {
            sprite_centered(.Boss_Gun_Right if side != 0 else .Boss_Gun_Left, g.boss_gun(b, side != 0), 1, tint)
        }
    }
    sprite_centered(.Boss_Body, b.pos, 1, tint)
    if b.core_open { sprite_centered(.Boss_Core, g.boss_core(b), 1, tint) }
    label := "CORE EXPOSED" if b.core_open else ("RAM ATTACK" if b.phase == .Retract || b.phase == .Ram else "DESTROY BOTH GUNS")
    centered(label, 38, 1, 0xff8e9fff if b.core_open else GOLD)
    bar_group_width :: BOSS_HEALTH_BAR_COUNT*BOSS_HEALTH_BAR_WIDTH+(BOSS_HEALTH_BAR_COUNT-1)*BOSS_HEALTH_BAR_GAP
    for side in 0..<BOSS_HEALTH_BAR_COUNT {
        hp := b.left_hp if side == 0 else (b.core_hp if side == 1 else b.right_hp)
        if side == 1 && !b.core_open { continue }
        x := f32(g.GAME_WIDTH-bar_group_width)*.5+f32(side*(BOSS_HEALTH_BAR_WIDTH+BOSS_HEALTH_BAR_GAP))
        max_hp := f32(g.BOSS_CORE_HP if side == 1 else g.BOSS_GUN_HP)
        r.rect(x, 52, BOSS_HEALTH_BAR_WIDTH, 3, 0x30394fff)
        r.rect(x, 52, BOSS_HEALTH_BAR_WIDTH*f32(hp)/max_hp, 3, 0xff688aff if side == 1 else 0xa6df64ff)
    }
}

world :: proc(game: ^g.Game) {
    for e in game.enemies {
        if !e.active { continue }
        blink := e.kind == .Drone && e.age >= g.DRONE_APPROACH_TIME && e.age < g.DRONE_CHARGE_TIME && int(e.age*12)%2 == 0
        id := g.Sprite(int(g.Sprite.Pawn_0)+int(e.age*5)%2) if e.kind == .Pawn else
            g.Sprite(int(g.Sprite.Drone_0)+(2 if e.age >= g.DRONE_CHARGE_TIME else int(e.age*4)%2))
        sprite_centered(id, e.pos, 1, 0xff7777ff if blink else 0xffffffff)
    }
    draw_boss(game)
    for b in game.bullets {
        if b.active { sprite_centered((.Enemy_Bullet_Hot if game.boss.core_open else .Enemy_Bullet) if b.enemy else .Player_Bullet, b.pos, 1, 0xffffffff) }
    }
    p := &game.player
    if p.lives > 0 && (p.invincible <= 0 || p.invincible > 10 || int(game.ui_time*12)%2 == 0) {
        id: g.Sprite = .Player_Left if p.velocity.x < -g.PLAYER_BANK_SPEED else (.Player_Right if p.velocity.x > g.PLAYER_BANK_SPEED else .Player_Idle)
        sprite_centered(id, p.pos, 1, 0xffffffff)
        r.sprite(g.Sprite(int(g.Sprite.Player_Flame_0)+int(game.ui_time*12)%2),
            p.pos.x-f32(g.SPRITE_RECTS[.Player_Flame_0].w)*.5, p.pos.y+g.PLAYER_HALF_HEIGHT, 1, 0xffffffff)
    }
    for e in game.explosions {
        if e.active { sprite_centered(g.Sprite(int(g.Sprite.Explosion_0)+min(int(e.age*g.EXPLOSION_FPS), g.EXPLOSION_FRAMES-1)), e.pos, e.scale, 0xffffffff) }
    }
    r.rect(0, 0, g.GAME_WIDTH, g.HUD_HEIGHT, 0x080b1cdd)
    r.text(fmt.tprintf("SCORE %07d", game.score), 12, 11, 1, WHITE)
    life :: g.SPRITE_RECTS[.Life]
    life_stride :: life.w+LIFE_GAP
    life_start :: g.GAME_WIDTH-LIFE_RIGHT_MARGIN-g.PLAYER_LIVES*life_stride+LIFE_GAP
    for i in 0..<p.lives { r.sprite(.Life, f32(life_start+i*life_stride), f32(g.HUD_HEIGHT-life.h)*.5, 1, 0xffffffff) }
    if !game.boss.active && game.scene != .Briefing {
        r.text(fmt.tprintf("WAVES %02d/%d  DRONES %d/%d", game.waves_spawned, g.PAWN_WAVE_COUNT, game.drones_spawned, g.DRONE_COUNT),
            12, g.GAME_HEIGHT-g.FONT_CELL_HEIGHT-10, 1, MUTED)
    }
    if game.damage_flash > 0 { r.rect(0, g.HUD_HEIGHT, g.GAME_WIDTH, g.GAME_HEIGHT-g.HUD_HEIGHT, 0xa7203030) }
}

draw :: proc(game: ^g.Game, table: scores.Scores, save_failed, audio_available: bool) {
    r.begin(); background(game)
    visible := game.paused_scene if game.scene == .Pause else game.scene
    if visible == .Sound { visible = game.paused_scene if game.sound_return == .Pause else game.sound_return }
    if visible == .Menu || visible == .Scores {
        r.sprite(.Title, f32(g.GAME_WIDTH-g.SPRITE_RECTS[.Title].w)*.5, 70, 1, 0xffffffff)
        centered("ONE SHIP. ONE BAD INVASION.", 128, 1, CYAN)
        if visible == .Menu {
            items := [g.Menu_Choice]string{.Start = "START MISSION", .Scores = "HIGH SCORES", .Sound = "SOUND", .Quit = "QUIT"}
            for item, choice in items {
                y := f32(int(choice)*30)
                if choice == game.menu_choice { r.rect(102, 211+y, 196, 23, 0x1b294dcc); r.text(">", 110, 219+y, 1, GOLD) }
                centered(item, 219+y, 1, GOLD if choice == game.menu_choice else WHITE)
            }
            centered("WASD MOVE / HOLD SPACE TO FIRE", 390, 1, MUTED)
            centered("ENTER SELECT / ESC PAUSE / V SOUND", 410, 1, MUTED)
            centered("ODIN  /  SOKOL  /  GNARLAXX", 466, 1, CYAN)
        } else {
            centered("HIGH SCORES", 186, 2, GOLD)
            for value, i in table { centered(fmt.tprintf("%d.   %09d", i+1, value), f32(237+i*28), 1, WHITE) }
            centered("ENTER / ESC TO RETURN", 429, 1, MUTED)
        }
    } else {
        world(game)
        if visible == .Briefing {
            panel(191, 104)
            if game.scene_time < g.BRIEFING_GO_TIME { centered("ENEMY BOSS REPORTED", 212, 1, GOLD); centered("TO PREPARE INVASION", 232, 1, GOLD) }
            else { centered("YOU MUST STOPP HIM!", 212, 1, GOLD); centered("GO!", 240, 2, CYAN) }
        }
        if visible == .Victory || visible == .Game_Over {
            panel(174, 158)
            if visible == .Victory { r.sprite(.Level_Cleared, f32(g.GAME_WIDTH-g.SPRITE_RECTS[.Level_Cleared].w)*.5, 192, 1, 0xffffffff) }
            else { centered("GAME OVER", 198, 2, 0xff8e9fff) }
            centered(fmt.tprintf("FINAL SCORE %07d", game.score), 242, 1, GOLD)
            centered("READY FOR THE NEXT MISSION?" if visible == .Victory else "THE INVASION WILL HAVE TO WAIT.", 266, 1, WHITE)
            centered("ENTER REPLAY / ESC MENU", 304, 1, MUTED)
        }
    }
    if game.scene == .Pause {
        r.rect(0, 0, g.GAME_WIDTH, g.GAME_HEIGHT, 0x020510a0); panel(191, 116)
        centered("PAUSED", 214, 2, GOLD); centered("ESC / ENTER RESUME", 253, 1, WHITE); centered("V SOUND / Q MAIN MENU", 278, 1, MUTED)
    }
    if game.scene == .Sound {
        r.rect(0, 0, g.GAME_WIDTH, g.GAME_HEIGHT, 0x020510c0); panel(158, 198)
        centered("SOUND", 179, 2, GOLD)
        labels := [g.Volume_Channel]string{.Master = "MASTER", .Music = "MUSIC", .Effects = "EFFECTS"}
        for label, channel in labels {
            centered(fmt.tprintf("%s %-7s %3d%%",  ">" if game.volume_choice == channel else " ", label, int(math.round(game.volumes[channel]*100))),
                f32(222+int(channel)*28), 1, GOLD if game.volume_choice == channel else WHITE)
        }
        centered("ARROWS ADJUST / ESC RETURN", 328, 1, MUTED)
    }
    if save_failed { centered("HIGH SCORES COULD NOT BE SAVED", 450, 1, 0xff8e9fff) }
    if !audio_available { centered("AUDIO OUTPUT UNAVAILABLE", g.GAME_HEIGHT-g.FONT_CELL_HEIGHT-10, 1, 0xff8e9fff) }
    if game.fade > 0 && (game.scene == .Briefing || game.scene == .Pause) { r.rect(0, 0, g.GAME_WIDTH, g.GAME_HEIGHT, u32(game.fade*255)) }
    r.present()
}
