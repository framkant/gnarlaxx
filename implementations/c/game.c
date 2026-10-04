#include "game.h"
#include <math.h>
#include <stdlib.h>
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
        g->score += 2000 + g->player.lives * 250;
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
    g->player.pos = (Vec2){200, 420};
    g->player.velocity = (Vec2){0};
    g->player.invincible = 2.5f;
    for (int i = 0; i < MAX_BULLETS; i++)
        if (g->bullets[i].enemy)
            g->bullets[i].active = false;
}

void game_init(Game *g) {
    *g = (Game){.scene = SCENE_MENU, .volumes = {.65f, .28f, .65f}};
}
void game_start(Game *g) {
    float volumes[3];
    memcpy(volumes, g->volumes, sizeof volumes);
    *g = (Game){.scene = SCENE_BRIEFING,
                .player = {.pos = {200, 535}, .lives = 3, .invincible = 2.5f},
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
    return (Vec2){b->pos.x + (right ? 1 : -1) * (59 - 35 * b->retract), b->pos.y + 26};
}
void game_spawn_boss(Game *g) {
    g->boss = (Boss){.active = true,
                     .pos = {200, -70},
                     .left_hp = 10,
                     .right_hp = 10,
                     .core_hp = 10,
                     .phase = BOSS_ENTER};
    sound(g, SOUND_WARNING, .7f);
}

static void spawn_wave(Game *g) {
    int wave = g->waves_spawned++;
    for (int slot = 0; slot < 5; slot++)
        for (int i = 0; i < MAX_ENEMIES; i++)
            if (!g->enemies[i].active) {
                g->enemies[i] = (Enemy){.active = true,
                                        .kind = ENEMY_PAWN,
                                        .pos = {60 + 70 * slot, -28 - 18 * abs(2 - slot)},
                                        .base_x = 60 + 70 * slot,
                                        .wave = wave,
                                        .slot = slot,
                                        .shot_timer = 1.4f + slot * .18f};
                break;
            }
}
static void spawn_drone(Game *g) {
    int n = g->drones_spawned++;
    for (int i = 0; i < MAX_ENEMIES; i++)
        if (!g->enemies[i].active) {
            g->enemies[i] =
                (Enemy){.active = true, .kind = ENEMY_DRONE, .pos = {70 + 65 * (n % 5), -24}};
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
            e->pos.y += 55 * dt;
            e->pos.x = e->base_x + sinf(e->age * 1.6f + e->wave * .7f) * 32;
            e->shot_timer -= dt;
            if (e->shot_timer <= 0 && e->pos.y > 30 && e->pos.y < 360) {
                Vec2 direction = toward(e->pos, g->player.pos, 95);
                direction.y = fmaxf(direction.y, 65); // No surprise upward/backward shots.
                bullet(g, e->pos, direction, true);
                sound(g, SOUND_ENEMY_SHOT, .18f);
                e->shot_timer = 2.7f;
            }
        } else {
            if (e->age < 1.4f)
                e->pos.y += 85 * dt;
            if (previous < 1.4f && e->age >= 1.4f)
                sound(g, SOUND_WARNING, .3f);
            if (previous < 2.1f && e->age >= 2.1f)
                e->velocity = toward(e->pos, g->player.pos, 260);
            if (e->age >= 2.1f) {
                if (e->age < 2.7f) {
                    Vec2 desired = toward(e->pos, g->player.pos, 260);
                    e->velocity.x += (desired.x - e->velocity.x) * dt * 3;
                    e->velocity.y += (desired.y - e->velocity.y) * dt * 3;
                }
                e->pos.x += e->velocity.x * dt;
                e->pos.y += e->velocity.y * dt;
            }
            if (e->age > 7)
                e->active = false;
        }
        if (e->pos.y > 540 || e->pos.x < -60 || e->pos.x > 460)
            e->active = false;
        if (e->active && near(e->pos, g->player.pos, 22))
            damage_player(g);
    }
}
static void boss_phase(Boss *b, BossPhase phase) {
    b->phase = phase;
    b->timer = 0;
}
static void boss_shoot(Game *g) {
    Boss *b = &g->boss;
    float sweep = sinf(b->timer * 2.3f) * .55f;
    if (b->core_open) {
        for (int i = -2; i <= 2; i++) {
            float a = sweep + i * .24f;
            bullet(g, (Vec2){b->pos.x, b->pos.y + 18}, (Vec2){sinf(a) * 125, cosf(a) * 125}, true);
        }
    } else
        for (int side = 0; side < 2; side++) {
            if ((side ? b->right_hp : b->left_hp) <= 0)
                continue;
            Vec2 origin = game_boss_gun(b, side != 0);
            origin.y += 22;
            for (int i = -1; i <= 1; i++) {
                float a = sweep + i * .28f;
                bullet(g, origin, (Vec2){sinf(a) * 105, cosf(a) * 105}, true);
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
            b->pos.y += 65 * dt;
            if (b->pos.y >= 92) {
                b->pos.y = 92;
                boss_phase(b, BOSS_ROAM);
            }
            break;
        case BOSS_ROAM:
            b->retract = fmaxf(0, b->retract - dt * 2);
            b->pos.x = 200 + sinf(g->level_time * 1.2f) * 85;
            if (b->timer > .8f) {
                boss_phase(b, BOSS_WARN);
                sound(g, SOUND_WARNING, .6f);
            }
            break;
        case BOSS_WARN:
            if (b->timer > .9f) {
                boss_phase(b, BOSS_FIRE);
                b->shot_timer = 0;
            }
            break;
        case BOSS_FIRE:
            b->pos.x += sinf(g->level_time * 1.2f) * 35 * dt;
            b->pos.x = clamp(b->pos.x, 95, 305);
            b->shot_timer -= dt;
            if (b->shot_timer <= 0) {
                boss_shoot(g);
                b->shot_timer += b->core_open ? .18f : .38f;
            }
            if (b->timer > 3) {
                boss_phase(b, BOSS_RETRACT);
                sound(g, SOUND_WARNING, .55f);
            }
            break;
        case BOSS_RETRACT:
            b->retract = clamp(b->timer / .65f, 0, 1);
            if (b->timer > .65f) {
                b->move_start = b->pos;
                b->target =
                    (Vec2){clamp(g->player.pos.x, 65, 335), clamp(g->player.pos.y, 190, 420)};
                boss_phase(b, BOSS_RAM);
                sound(g, SOUND_BOSS_RAM, .65f);
            }
            break;
        case BOSS_RAM: {
            float t = clamp(b->timer / .75f, 0, 1);
            b->pos = (Vec2){b->move_start.x + (b->target.x - b->move_start.x) * t,
                            b->move_start.y + (b->target.y - b->move_start.y) * t};
            if (b->timer > 1) {
                b->move_start = b->pos;
                boss_phase(b, BOSS_RETURN);
            }
            break;
        }
        case BOSS_RETURN: {
            float t = clamp(b->timer / 1.5f, 0, 1);
            b->pos = (Vec2){b->move_start.x + (200 - b->move_start.x) * t,
                            b->move_start.y + (92 - b->move_start.y) * t};
            if (b->timer > 1.5f) {
                b->retract = 0;
                boss_phase(b, BOSS_ROAM);
            }
            break;
        }
    }
    if (fabsf(g->player.pos.x - b->pos.x) < 47 && fabsf(g->player.pos.y - b->pos.y) < 45)
        damage_player(g);
    for (int side = 0; side < 2; side++)
        if ((side ? b->right_hp : b->left_hp) > 0 &&
            near(g->player.pos, game_boss_gun(b, side != 0), 25))
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
        if (*hp > 0 && hit_box(pos, gun, 18, 26)) {
            --*hp;
            b->flash = .10f;
            sound(g, SOUND_HIT, .4f);
            if (*hp == 0) {
                g->score += 500;
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
    if (b->core_open && hit_box(pos, (Vec2){b->pos.x, b->pos.y - 2}, 18, 22)) {
        --b->core_hp;
        b->flash = .10f;
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
    if (b->core_open && fabsf(pos.x - b->pos.x) < 18)
        return false;
    return hit_box(pos, b->pos, 43, 42); // Closed hull blocks shots without taking damage.
}
static void update_bullets(Game *g, float dt) {
    for (int i = 0; i < MAX_BULLETS; i++) {
        Bullet *b = &g->bullets[i];
        if (!b->active)
            continue;
        b->pos.x += b->velocity.x * dt;
        b->pos.y += b->velocity.y * dt;
        if (b->pos.x < -20 || b->pos.x > 420 || b->pos.y < -24 || b->pos.y > 524) {
            b->active = false;
            continue;
        }
        if (b->enemy) {
            if (near(b->pos, g->player.pos, 10)) {
                b->active = false;
                damage_player(g);
            }
        } else {
            for (int j = 0; j < MAX_ENEMIES; j++) {
                Enemy *e = &g->enemies[j];
                if (e->active && near(b->pos, e->pos, 16)) {
                    e->active = false;
                    b->active = false;
                    g->score += e->kind == ENEMY_PAWN ? 100 : 250;
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
    float drag = expf(-8 * dt);
    p->velocity.x = (p->velocity.x + in.x * 1800 * dt) * drag;
    p->velocity.y = (p->velocity.y + in.y * 1800 * dt) * drag;
    p->pos.x = clamp(p->pos.x + p->velocity.x * dt, 16, 384);
    p->pos.y = clamp(p->pos.y + p->velocity.y * dt, 46, 468);
    p->invincible = fmaxf(0, p->invincible - dt);
    p->shot_timer -= dt;
    if (in.fire && p->shot_timer <= 0) {
        bullet(g, (Vec2){p->pos.x, p->pos.y - 18}, (Vec2){0, -620}, false);
        sound(g, SOUND_PLAYER_SHOT, .35f);
        p->shot_timer = .14f;
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
            g->volume_choice = (g->volume_choice + 2) % 3;
        if (in.down)
            g->volume_choice = (g->volume_choice + 1) % 3;
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
        g->scroll += dt * 9;
        if (in.up)
            g->menu_choice = (g->menu_choice + 3) % 4;
        if (in.down)
            g->menu_choice = (g->menu_choice + 1) % 4;
        if (in.cancel)
            g->quit_requested = true;
        if (in.confirm) {
            sound(g, SOUND_MENU_CONFIRM, .4f);
            switch (g->menu_choice) {
                case 0:
                    game_start(g);
                    break;
                case 1:
                    g->scene = SCENE_SCORES;
                    break;
                case 2:
                    g->sound_return = SCENE_MENU;
                    g->scene = SCENE_SOUND;
                    break;
                case 3:
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
                if (g->explosions[i].age > .6f)
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
    g->scroll += dt * 9;
    if (g->scene == SCENE_BRIEFING) {
        float before = g->scene_time - dt;
        g->fade = clamp(1 - g->scene_time / .7f, 0, 1);
        g->player.pos.y = 535 - clamp((g->scene_time - .3f) / 1.5f, 0, 1) * 115;
        if (before < .8f && g->scene_time >= .8f)
            sound(g, SOUND_INTRO_WARNING, .85f);
        if (before < 4.0f && g->scene_time >= 4.0f)
            sound(g, SOUND_INTRO_GO, .85f);
        if (g->scene_time > 6.8f) {
            g->scene = SCENE_PLAY;
            g->scene_time = 0;
            g->player.invincible = 2.5f;
        }
        return;
    }
    g->level_time += dt;
    g->damage_flash = fmaxf(0, g->damage_flash - dt);
    update_player(g, in, dt);
    if (g->waves_spawned < 10 && g->level_time >= .5f + g->waves_spawned * 4.5f)
        spawn_wave(g);
    if (g->drones_spawned < 5 && g->level_time >= 7 + g->drones_spawned * 9)
        spawn_drone(g);
    update_enemies(g, dt);
    if (g->scene != SCENE_PLAY)
        return;
    bool any = false;
    for (int i = 0; i < MAX_ENEMIES; i++)
        any |= g->enemies[i].active;
    if (g->waves_spawned == 10 && g->drones_spawned == 5 && !any && !g->boss.active)
        game_spawn_boss(g);
    update_boss(g, dt);
    if (g->scene != SCENE_PLAY)
        return;
    update_bullets(g, dt);
    for (int i = 0; i < MAX_EXPLOSIONS; i++)
        if (g->explosions[i].active) {
            g->explosions[i].age += dt;
            if (g->explosions[i].age > .5f)
                g->explosions[i].active = false;
        }
}
