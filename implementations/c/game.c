#include "game.h"
#include <math.h>
#include <string.h>

static float clamp(float x, float lo, float hi) {
    return fmaxf(lo, fminf(hi, x));
}
static Vec2 toward(Vec2 from, Vec2 to, float speed) {
    float x = to.x - from.x, y = to.y - from.y, len = sqrtf(x * x + y * y);
    return len > .001f ? (Vec2){x / len * speed, y / len * speed} : (Vec2){0, speed};
}
static bool near(Vec2 a, Vec2 b, float radius) {
    float x = a.x - b.x, y = a.y - b.y;
    return x * x + y * y < radius * radius;
}
static void sound(Game *g, Sound s, float gain) {
    if (g->event_count < MAX_EVENTS)
        g->events[g->event_count++] = (GameEvent){.sound = s, .gain = gain};
}
static void explode(Game *g, Vec2 pos, float scale) {
    for (int i = 0; i < MAX_EXPLOSIONS; i++)
        if (!g->explosions[i].active) {
            g->explosions[i] = (Explosion){.active = true, .pos = pos, .scale = scale};
            return;
        }
}
static void bullet(Game *g, Vec2 pos, Vec2 velocity, bool enemy) {
    for (int i = 0; i < MAX_BULLETS; i++)
        if (!g->bullets[i].active) {
            g->bullets[i] =
                (Bullet){.active = true, .enemy = enemy, .pos = pos, .velocity = velocity};
            return;
        }
}
static void finish(Game *g, bool won) {
    g->scene = won ? SCENE_VICTORY : SCENE_GAME_OVER;
    g->scene_time = 0;
    if (won)
        g->score += VICTORY_SCORE + g->player.lives * SURVIVING_LIFE_SCORE;
    if (g->event_count < MAX_EVENTS)
        g->events[g->event_count++] = (GameEvent){.finished = true, .score = g->score};
    memset(g->bullets, 0, sizeof g->bullets);
}
static void damage_player(Game *g) {
    if (g->player.invincible > 0 || g->scene != SCENE_PLAY)
        return;
    explode(g, g->player.pos, 1.5f);
    sound(g, SOUND_EXPLOSION, .8f);
    g->damage_flash = .25f;
    if (--g->player.lives == 0) {
        finish(g, false);
        return;
    }
    g->player.pos = (Vec2){GAME_CENTER_X, PLAYER_SPAWN_Y};
    g->player.velocity = (Vec2){0};
    g->player.invincible = PLAYER_INVINCIBILITY_TIME;
    for (int i = 0; i < MAX_BULLETS; i++)
        if (g->bullets[i].enemy)
            g->bullets[i].active = false;
}

void game_init(Game *g) {
    *g =
        (Game){.scene = SCENE_MENU,
               .volumes = {[VOLUME_MASTER] = .65f, [VOLUME_MUSIC] = .28f, [VOLUME_EFFECTS] = .65f}};
}
void game_start(Game *g) {
    float volumes[VOLUME_COUNT];
    memcpy(volumes, g->volumes, sizeof volumes);
    *g = (Game){.scene = SCENE_BRIEFING,
                .player = {.pos = {GAME_CENTER_X, PLAYER_ENTRY_Y},
                           .lives = PLAYER_LIVES,
                           .invincible = PLAYER_INVINCIBILITY_TIME},
                .fade = 1};
    memcpy(g->volumes, volumes, sizeof volumes);
    sound(g, SOUND_MENU_CONFIRM, .5f);
}
void game_pause(Game *g) {
    if (g->scene == SCENE_PLAY || g->scene == SCENE_BRIEFING) {
        g->paused_scene = g->scene;
        g->scene = SCENE_PAUSE;
    }
}
Vec2 game_boss_gun(const Boss *b, bool right) {
    const AtlasRect gun = SPRITE_RECTS[right ? SPR_BOSS_GUN_RIGHT : SPR_BOSS_GUN_LEFT];
    float offset_x = right ? BOSS_RIGHT_GUN_OFFSET_X : BOSS_LEFT_GUN_OFFSET_X;
    float offset_y = right ? BOSS_RIGHT_GUN_OFFSET_Y : BOSS_LEFT_GUN_OFFSET_Y;
    // Manifest offsets are top-left to top-left; simulation positions are centers.
    float center_x = offset_x - BOSS_HALF_WIDTH + gun.w * .5f;
    center_x += (right ? -1 : 1) * BOSS_RETRACT_DISTANCE * b->retract;
    return (Vec2){b->pos.x + center_x, b->pos.y + (offset_y - BOSS_HALF_HEIGHT + gun.h * .5f)};
}
Vec2 game_boss_core(const Boss *b) {
    const AtlasRect core = SPRITE_RECTS[SPR_BOSS_CORE];
    return (Vec2){b->pos.x + (BOSS_CORE_OFFSET_X - BOSS_HALF_WIDTH + core.w * .5f),
                  b->pos.y + (BOSS_CORE_OFFSET_Y - BOSS_HALF_HEIGHT + core.h * .5f)};
}
void game_spawn_boss(Game *g) {
    g->boss = (Boss){.active = true,
                     .pos = {GAME_CENTER_X, -BOSS_HALF_HEIGHT - BOSS_SPAWN_GAP},
                     .left_hp = BOSS_GUN_HP,
                     .right_hp = BOSS_GUN_HP,
                     .core_hp = BOSS_CORE_HP,
                     .phase = BOSS_ENTER};
    sound(g, SOUND_WARNING, .7f);
}

static float formation_x(int slot, int count, float side_margin) {
    if (count == 1)
        return GAME_CENTER_X;
    float spacing = (GAME_WIDTH - 2 * side_margin) / (count - 1);
    return side_margin + spacing * slot;
}
static void spawn_wave(Game *g) {
    int wave = g->waves_spawned++;
    const float spawn_y = -SPRITE_RECTS[SPR_PAWN_0].h * .5f - PAWN_SPAWN_GAP;
    const float middle_slot = (PAWNS_PER_WAVE - 1) * .5f;
    for (int slot = 0; slot < PAWNS_PER_WAVE; slot++)
        for (int i = 0; i < MAX_ENEMIES; i++)
            if (!g->enemies[i].active) {
                float x = formation_x(slot, PAWNS_PER_WAVE, PAWN_SIDE_MARGIN);
                g->enemies[i] =
                    (Enemy){.active = true,
                            .kind = ENEMY_PAWN,
                            .pos = {x, spawn_y - PAWN_ROW_STAGGER * fabsf(middle_slot - slot)},
                            .base_x = x,
                            .wave = wave,
                            .slot = slot,
                            .shot_timer = PAWN_FIRST_SHOT_DELAY + slot * PAWN_SHOT_STAGGER};
                break;
            }
}
static void spawn_drone(Game *g) {
    int lane = g->drones_spawned++ % DRONE_LANE_COUNT;
    float x = formation_x(lane, DRONE_LANE_COUNT, DRONE_SIDE_MARGIN);
    float y = -SPRITE_RECTS[SPR_DRONE_0].h * .5f - DRONE_SPAWN_GAP;
    for (int i = 0; i < MAX_ENEMIES; i++)
        if (!g->enemies[i].active) {
            g->enemies[i] = (Enemy){.active = true, .kind = ENEMY_DRONE, .pos = {x, y}};
            break;
        }
}
static void update_enemies(Game *g, float dt) {
    for (int i = 0; i < MAX_ENEMIES; i++) {
        Enemy *e = &g->enemies[i];
        if (!e->active)
            continue;
        float previous = e->age;
        e->age += dt;
        if (e->kind == ENEMY_PAWN) {
            e->pos.y += PAWN_SPEED * dt;
            e->pos.x = e->base_x + sinf(e->age * PAWN_SWAY_RATE + e->wave * PAWN_WAVE_PHASE) *
                                       PAWN_SWAY_AMPLITUDE;
            e->shot_timer -= dt;
            if (e->shot_timer <= 0 && e->pos.y > HUD_HEIGHT &&
                e->pos.y < GAME_HEIGHT - PAWN_SHOOT_BOTTOM_INSET) {
                Vec2 direction = toward(e->pos, g->player.pos, PAWN_SHOT_SPEED);
                // No surprise upward/backward shots.
                direction.y = fmaxf(direction.y, PAWN_MIN_SHOT_SPEED_Y);
                bullet(g, e->pos, direction, true);
                sound(g, SOUND_ENEMY_SHOT, .18f);
                e->shot_timer = PAWN_SHOT_INTERVAL;
            }
        } else {
            if (e->age < DRONE_APPROACH_TIME)
                e->pos.y += DRONE_APPROACH_SPEED * dt;
            if (previous < DRONE_APPROACH_TIME && e->age >= DRONE_APPROACH_TIME)
                sound(g, SOUND_WARNING, .3f);
            if (previous < DRONE_CHARGE_TIME && e->age >= DRONE_CHARGE_TIME)
                e->velocity = toward(e->pos, g->player.pos, DRONE_CHARGE_SPEED);
            if (e->age >= DRONE_CHARGE_TIME) {
                if (e->age < DRONE_HOMING_END) {
                    Vec2 desired = toward(e->pos, g->player.pos, DRONE_CHARGE_SPEED);
                    e->velocity.x += (desired.x - e->velocity.x) * dt * DRONE_STEERING_RATE;
                    e->velocity.y += (desired.y - e->velocity.y) * dt * DRONE_STEERING_RATE;
                }
                e->pos.x += e->velocity.x * dt;
                e->pos.y += e->velocity.y * dt;
            }
            if (e->age > DRONE_LIFETIME)
                e->active = false;
        }
        if (e->pos.y > GAME_HEIGHT + ENEMY_CULL_MARGIN_Y || e->pos.x < -ENEMY_CULL_MARGIN_X ||
            e->pos.x > GAME_WIDTH + ENEMY_CULL_MARGIN_X)
            e->active = false;
        if (e->active && near(e->pos, g->player.pos, ENEMY_CONTACT_RADIUS))
            damage_player(g);
    }
}
static void boss_phase(Boss *b, BossPhase phase) {
    b->phase = phase;
    b->timer = 0;
}
static void boss_shoot(Game *g) {
    Boss *b = &g->boss;
    float sweep = sinf(b->timer * BOSS_SWEEP_RATE) * BOSS_SWEEP_ANGLE;
    if (b->core_open) {
        Vec2 origin = game_boss_core(b);
        origin.y += SPRITE_RECTS[SPR_BOSS_CORE].h * .5f;
        for (int i = 0; i < BOSS_CORE_SHOTS; i++) {
            float a = sweep + (i - (BOSS_CORE_SHOTS - 1) * .5f) * BOSS_CORE_SHOT_ANGLE;
            bullet(g, origin,
                   (Vec2){sinf(a) * BOSS_CORE_SHOT_SPEED, cosf(a) * BOSS_CORE_SHOT_SPEED}, true);
        }
    } else
        for (int side = 0; side < 2; side++) {
            if ((side ? b->right_hp : b->left_hp) <= 0)
                continue;
            Vec2 origin = game_boss_gun(b, side != 0);
            const AtlasRect gun = SPRITE_RECTS[side ? SPR_BOSS_GUN_RIGHT : SPR_BOSS_GUN_LEFT];
            origin.y += gun.h * .5f - BOSS_GUN_MUZZLE_INSET;
            for (int i = 0; i < BOSS_GUN_SHOTS; i++) {
                float a = sweep + (i - (BOSS_GUN_SHOTS - 1) * .5f) * BOSS_GUN_SHOT_ANGLE;
                bullet(g, origin,
                       (Vec2){sinf(a) * BOSS_GUN_SHOT_SPEED, cosf(a) * BOSS_GUN_SHOT_SPEED}, true);
            }
        }
    sound(g, SOUND_ENEMY_SHOT, .35f);
}
static void update_boss(Game *g, float dt) {
    Boss *b = &g->boss;
    if (!b->active)
        return;
    b->timer += dt;
    b->flash = fmaxf(0, b->flash - dt);
    switch (b->phase) {
        case BOSS_ENTER:
            b->pos.y += BOSS_ENTRY_SPEED * dt;
            if (b->pos.y >= BOSS_REST_Y) {
                b->pos.y = BOSS_REST_Y;
                boss_phase(b, BOSS_ROAM);
            }
            break;
        case BOSS_ROAM:
            b->retract = fmaxf(0, b->retract - dt * BOSS_EXTEND_RATE);
            b->pos.x = GAME_CENTER_X + sinf(g->level_time * BOSS_SWAY_RATE) * BOSS_ROAM_AMPLITUDE;
            if (b->timer > BOSS_ROAM_TIME) {
                boss_phase(b, BOSS_WARN);
                sound(g, SOUND_WARNING, .6f);
            }
            break;
        case BOSS_WARN:
            if (b->timer > BOSS_WARNING_TIME) {
                boss_phase(b, BOSS_FIRE);
                b->shot_timer = 0;
            }
            break;
        case BOSS_FIRE:
            b->pos.x += sinf(g->level_time * BOSS_SWAY_RATE) * BOSS_FIRE_DRIFT_SPEED * dt;
            b->pos.x = clamp(b->pos.x, BOSS_FIRE_SIDE_MARGIN, GAME_WIDTH - BOSS_FIRE_SIDE_MARGIN);
            b->shot_timer -= dt;
            if (b->shot_timer <= 0) {
                boss_shoot(g);
                b->shot_timer += b->core_open ? BOSS_CORE_SHOT_INTERVAL : BOSS_GUN_SHOT_INTERVAL;
            }
            if (b->timer > BOSS_FIRE_TIME) {
                boss_phase(b, BOSS_RETRACT);
                sound(g, SOUND_WARNING, .55f);
            }
            break;
        case BOSS_RETRACT:
            b->retract = clamp(b->timer / BOSS_RETRACT_TIME, 0, 1);
            if (b->timer > BOSS_RETRACT_TIME) {
                b->move_start = b->pos;
                b->target = (Vec2){
                    clamp(g->player.pos.x, BOSS_RAM_SIDE_MARGIN, GAME_WIDTH - BOSS_RAM_SIDE_MARGIN),
                    clamp(g->player.pos.y, BOSS_RAM_MIN_Y, GAME_HEIGHT - BOSS_RAM_BOTTOM_INSET)};
                boss_phase(b, BOSS_RAM);
                sound(g, SOUND_BOSS_RAM, .65f);
            }
            break;
        case BOSS_RAM: {
            float t = clamp(b->timer / BOSS_RAM_TRAVEL_TIME, 0, 1);
            b->pos = (Vec2){b->move_start.x + (b->target.x - b->move_start.x) * t,
                            b->move_start.y + (b->target.y - b->move_start.y) * t};
            if (b->timer > BOSS_RAM_TRAVEL_TIME + BOSS_RAM_HOLD_TIME) {
                b->move_start = b->pos;
                boss_phase(b, BOSS_RETURN);
            }
            break;
        }
        case BOSS_RETURN: {
            float t = clamp(b->timer / BOSS_RETURN_TIME, 0, 1);
            b->pos = (Vec2){b->move_start.x + (GAME_CENTER_X - b->move_start.x) * t,
                            b->move_start.y + (BOSS_REST_Y - b->move_start.y) * t};
            if (b->timer > BOSS_RETURN_TIME) {
                b->retract = 0;
                boss_phase(b, BOSS_ROAM);
            }
            break;
        }
    }
    if (fabsf(g->player.pos.x - b->pos.x) < BOSS_HALF_WIDTH - BOSS_HULL_CONTACT_INSET_X &&
        fabsf(g->player.pos.y - b->pos.y) < BOSS_HALF_HEIGHT - BOSS_HULL_CONTACT_INSET_Y)
        damage_player(g);
    for (int side = 0; side < 2; side++)
        if ((side ? b->right_hp : b->left_hp) > 0 &&
            near(g->player.pos, game_boss_gun(b, side != 0), BOSS_GUN_CONTACT_RADIUS))
            damage_player(g);
}

static bool hit_box(Vec2 p, Vec2 center, float half_w, float half_h) {
    return fabsf(p.x - center.x) < half_w && fabsf(p.y - center.y) < half_h;
}
static bool hit_boss(Game *g, Vec2 pos) {
    Boss *b = &g->boss;
    if (!b->active)
        return false;
    for (int side = 0; side < 2; side++) {
        int *hp = side ? &b->right_hp : &b->left_hp;
        Vec2 gun = game_boss_gun(b, side != 0);
        const AtlasRect rect = SPRITE_RECTS[side ? SPR_BOSS_GUN_RIGHT : SPR_BOSS_GUN_LEFT];
        if (*hp > 0 && hit_box(pos, gun, rect.w * .5f + BOSS_SHOT_HIT_PADDING,
                               rect.h * .5f + BOSS_SHOT_HIT_PADDING)) {
            --*hp;
            b->flash = BOSS_HIT_FLASH_TIME;
            sound(g, SOUND_HIT, .4f);
            if (*hp == 0) {
                g->score += BOSS_GUN_SCORE;
                explode(g, gun, 1.8f);
                sound(g, SOUND_EXPLOSION, .8f);
            }
            if (b->left_hp == 0 && b->right_hp == 0 && !b->core_open) {
                b->core_open = true;
                boss_phase(b, BOSS_WARN);
                b->retract = 0;
                sound(g, SOUND_WARNING, .8f);
            }
            return true;
        }
    }
    const AtlasRect core = SPRITE_RECTS[SPR_BOSS_CORE];
    const float core_hit_half_w = core.w * .5f + BOSS_SHOT_HIT_PADDING;
    if (b->core_open &&
        hit_box(pos, game_boss_core(b), core_hit_half_w, core.h * .5f + BOSS_SHOT_HIT_PADDING)) {
        --b->core_hp;
        b->flash = BOSS_HIT_FLASH_TIME;
        sound(g, SOUND_HIT, .5f);
        if (b->core_hp == 0) {
            b->active = false;
            explode(g, b->pos, 3.5f);
            explode(g, (Vec2){b->pos.x - 38, b->pos.y + 25}, 2);
            explode(g, (Vec2){b->pos.x + 38, b->pos.y + 25}, 2);
            sound(g, SOUND_BOSS_EXPLOSION, 1);
            finish(g, true);
        }
        return true;
    }
    // The open central channel lets shots reach the recessed core from below.
    if (b->core_open && fabsf(pos.x - game_boss_core(b).x) < core_hit_half_w)
        return false;
    // Closed hull blocks shots without taking damage.
    return hit_box(pos, b->pos, BOSS_HALF_WIDTH - BOSS_HULL_SHOT_INSET_X,
                   BOSS_HALF_HEIGHT - BOSS_HULL_SHOT_INSET_Y);
}
static void update_bullets(Game *g, float dt) {
    for (int i = 0; i < MAX_BULLETS; i++) {
        Bullet *b = &g->bullets[i];
        if (!b->active)
            continue;
        b->pos.x += b->velocity.x * dt;
        b->pos.y += b->velocity.y * dt;
        if (b->pos.x < -BULLET_CULL_MARGIN_X || b->pos.x > GAME_WIDTH + BULLET_CULL_MARGIN_X ||
            b->pos.y < -BULLET_CULL_MARGIN_Y || b->pos.y > GAME_HEIGHT + BULLET_CULL_MARGIN_Y) {
            b->active = false;
            continue;
        }
        if (b->enemy) {
            if (near(b->pos, g->player.pos, PLAYER_HURT_RADIUS)) {
                b->active = false;
                damage_player(g);
            }
        } else {
            for (int j = 0; j < MAX_ENEMIES; j++) {
                Enemy *e = &g->enemies[j];
                if (e->active && near(b->pos, e->pos, ENEMY_HURT_RADIUS)) {
                    e->active = false;
                    b->active = false;
                    g->score += e->kind == ENEMY_PAWN ? PAWN_SCORE : DRONE_SCORE;
                    explode(g, e->pos, 1.2f);
                    sound(g, SOUND_EXPLOSION, .55f);
                    break;
                }
            }
            if (b->active && hit_boss(g, b->pos))
                b->active = false;
        }
        if (g->scene != SCENE_PLAY)
            break;
    }
}
static void update_player(Game *g, Input in, float dt) {
    Player *p = &g->player;
    float length = sqrtf(in.x * in.x + in.y * in.y);
    if (length > 1) {
        in.x /= length;
        in.y /= length;
    }
    float drag = expf(-PLAYER_DRAG * dt);
    p->velocity.x = (p->velocity.x + in.x * PLAYER_ACCELERATION * dt) * drag;
    p->velocity.y = (p->velocity.y + in.y * PLAYER_ACCELERATION * dt) * drag;
    p->pos.x =
        clamp(p->pos.x + p->velocity.x * dt, PLAYER_HALF_WIDTH, GAME_WIDTH - PLAYER_HALF_WIDTH);
    p->pos.y = clamp(p->pos.y + p->velocity.y * dt, HUD_HEIGHT + PLAYER_HALF_HEIGHT,
                     GAME_HEIGHT - PLAYER_HALF_HEIGHT - SPRITE_RECTS[SPR_PLAYER_FLAME_0].h);
    p->invincible = fmaxf(0, p->invincible - dt);
    p->shot_timer -= dt;
    if (in.fire && p->shot_timer <= 0) {
        bullet(g, (Vec2){p->pos.x, p->pos.y - PLAYER_HALF_HEIGHT - PLAYER_MUZZLE_GAP},
               (Vec2){0, -PLAYER_SHOT_SPEED}, false);
        sound(g, SOUND_PLAYER_SHOT, .35f);
        p->shot_timer = PLAYER_SHOT_INTERVAL;
    }
}

void game_update(Game *g, Input in, float dt) {
    g->ui_time += dt;
    if (in.sound && g->scene != SCENE_SOUND) {
        g->sound_return = g->scene;
        g->scene = SCENE_SOUND;
        return;
    }
    if (g->scene == SCENE_SOUND) {
        if (in.up)
            g->volume_choice = (g->volume_choice + VOLUME_COUNT - 1) % VOLUME_COUNT;
        if (in.down)
            g->volume_choice = (g->volume_choice + 1) % VOLUME_COUNT;
        if (in.left || in.right) {
            g->volumes[g->volume_choice] =
                clamp(g->volumes[g->volume_choice] + (in.right ? .1f : -.1f), 0, 1);
            sound(g, SOUND_MENU_CONFIRM, .25f);
        }
        if (in.cancel || in.confirm)
            g->scene = g->sound_return;
        return;
    }
    if (g->scene == SCENE_PAUSE) {
        if (in.menu) {
            g->scene = SCENE_MENU;
            g->scene_time = 0;
            return;
        }
        if (in.cancel || in.confirm)
            g->scene = g->paused_scene;
        return;
    }
    if (in.cancel && (g->scene == SCENE_PLAY || g->scene == SCENE_BRIEFING)) {
        game_pause(g);
        return;
    }
    if (g->scene == SCENE_MENU) {
        g->scroll += dt * BACKGROUND_SCROLL_SPEED;
        if (in.up)
            g->menu_choice = (g->menu_choice + MENU_COUNT - 1) % MENU_COUNT;
        if (in.down)
            g->menu_choice = (g->menu_choice + 1) % MENU_COUNT;
        if (in.cancel)
            g->quit_requested = true;
        if (in.confirm) {
            sound(g, SOUND_MENU_CONFIRM, .4f);
            switch (g->menu_choice) {
                case MENU_START:
                    game_start(g);
                    break;
                case MENU_SCORES:
                    g->scene = SCENE_SCORES;
                    break;
                case MENU_SOUND:
                    g->sound_return = SCENE_MENU;
                    g->scene = SCENE_SOUND;
                    break;
                case MENU_QUIT:
                    g->quit_requested = true;
                    break;
            }
        }
        return;
    }
    if (g->scene == SCENE_SCORES) {
        if (in.cancel || in.confirm)
            g->scene = SCENE_MENU;
        return;
    }
    g->scene_time += dt;
    if (g->scene == SCENE_VICTORY || g->scene == SCENE_GAME_OVER) {
        for (int i = 0; i < MAX_EXPLOSIONS; i++)
            if (g->explosions[i].active) {
                g->explosions[i].age += dt;
                if (g->explosions[i].age > EXPLOSION_DURATION + RESULT_EXPLOSION_HOLD)
                    g->explosions[i].active = false;
            }
        if (g->scene_time > .5f) {
            if (in.confirm)
                game_start(g);
            else if (in.cancel)
                g->scene = SCENE_MENU;
        }
        return;
    }
    g->scroll += dt * BACKGROUND_SCROLL_SPEED;
    if (g->scene == SCENE_BRIEFING) {
        float before = g->scene_time - dt;
        g->fade = clamp(1 - g->scene_time / BRIEFING_FADE_TIME, 0, 1);
        g->player.pos.y =
            PLAYER_ENTRY_Y -
            clamp((g->scene_time - BRIEFING_ENTRY_DELAY) / BRIEFING_ENTRY_TIME, 0, 1) *
                (PLAYER_ENTRY_Y - PLAYER_SPAWN_Y);
        if (before < BRIEFING_WARNING_TIME && g->scene_time >= BRIEFING_WARNING_TIME)
            sound(g, SOUND_INTRO_WARNING, .85f);
        if (before < BRIEFING_GO_TIME && g->scene_time >= BRIEFING_GO_TIME)
            sound(g, SOUND_INTRO_GO, .85f);
        if (g->scene_time > BRIEFING_END_TIME) {
            g->scene = SCENE_PLAY;
            g->scene_time = 0;
            g->player.invincible = PLAYER_INVINCIBILITY_TIME;
        }
        return;
    }
    g->level_time += dt;
    g->damage_flash = fmaxf(0, g->damage_flash - dt);
    update_player(g, in, dt);
    if (g->waves_spawned < PAWN_WAVE_COUNT &&
        g->level_time >= FIRST_WAVE_TIME + g->waves_spawned * WAVE_INTERVAL)
        spawn_wave(g);
    if (g->drones_spawned < DRONE_COUNT &&
        g->level_time >= FIRST_DRONE_TIME + g->drones_spawned * DRONE_INTERVAL)
        spawn_drone(g);
    update_enemies(g, dt);
    if (g->scene != SCENE_PLAY)
        return;
    bool any = false;
    for (int i = 0; i < MAX_ENEMIES; i++)
        any |= g->enemies[i].active;
    if (g->waves_spawned == PAWN_WAVE_COUNT && g->drones_spawned == DRONE_COUNT && !any &&
        !g->boss.active)
        game_spawn_boss(g);
    update_boss(g, dt);
    if (g->scene != SCENE_PLAY)
        return;
    update_bullets(g, dt);
    for (int i = 0; i < MAX_EXPLOSIONS; i++)
        if (g->explosions[i].active) {
            g->explosions[i].age += dt;
            if (g->explosions[i].age > EXPLOSION_DURATION)
                g->explosions[i].active = false;
        }
}
