#include "presentation.h"
#include "renderer.h"
#include <math.h>
#include <stdio.h>
#include <string.h>

#define WHITE 0xeaf5ffffu
#define CYAN 0x73dbe8ffu
#define MUTED 0x93a0b8ffu
#define GOLD 0xffdc8affu

static void centered(const char *text, float y, int scale, uint32_t color) {
    renderer_text(text, (400 - (float)strlen(text) * 8 * scale) * .5f, y, scale, color);
}
static void panel(float y, float h) {
    renderer_rect(26, y, 348, h, 0x0a1024ee);
    renderer_rect(26, y, 348, 1, 0x526389ff);
    renderer_rect(26, y + h - 1, 348, 1, 0x526389ff);
}
static void background(const Game *g) {
    for (int layer = 0; layer < 2; layer++) {
        float offset = fmodf(g->scroll * (layer ? 2.7f : 1), 64);
        for (int row = -2; row < 16; row++)
            for (int col = 0; col < 13; col++) {
                Sprite id = (Sprite)((layer ? SPR_STARS_NEAR_0 : SPR_STARS_FAR_0) +
                                     ((row + 2) % 2) * 2 + col % 2);
                renderer_sprite(id, col * 32, row * 32 + offset, 1,
                                layer ? 0xaabbdde0 : 0xffffffff);
            }
    }
}
static void draw_boss(const Game *g) {
    const Boss *b = &g->boss;
    if (!b->active)
        return;
    bool warn =
        (b->phase == BOSS_WARN || b->phase == BOSS_RETRACT) && ((int)(b->timer * 10) % 2 == 0);
    uint32_t tint = b->flash > 0 ? 0xffaaaaff : warn ? 0xff5555ff : 0xffffffff;
    for (int side = 0; side < 2; side++)
        if ((side ? b->right_hp : b->left_hp) > 0) {
            Vec2 gun = game_boss_gun(b, side != 0);
            renderer_sprite(side ? SPR_BOSS_GUN_RIGHT : SPR_BOSS_GUN_LEFT, gun.x - 16, gun.y - 24,
                            1, tint);
        }
    renderer_sprite(SPR_BOSS_BODY, b->pos.x - 48, b->pos.y - 48, 1, tint);
    if (b->core_open)
        renderer_sprite(SPR_BOSS_CORE, b->pos.x - 16, b->pos.y - 22, 1, tint);
    const char *label = b->core_open                                       ? "CORE EXPOSED"
                        : b->phase == BOSS_RETRACT || b->phase == BOSS_RAM ? "RAM ATTACK"
                                                                           : "DESTROY BOTH GUNS";
    centered(label, 38, 1, b->core_open ? 0xff8e9fff : GOLD);
    for (int side = 0; side < 3; side++) {
        int hp = side == 0 ? b->left_hp : side == 1 ? b->core_hp : b->right_hp;
        if (side == 1 && !b->core_open)
            continue;
        renderer_rect(112 + side * 62, 52, 52, 3, 0x30394fff);
        renderer_rect(112 + side * 62, 52, 52 * hp / 10.f, 3, side == 1 ? 0xff688aff : 0xa6df64ff);
    }
}
static void world(const Game *g) {
    for (int i = 0; i < MAX_ENEMIES; i++) {
        const Enemy *e = &g->enemies[i];
        if (!e->active)
            continue;
        bool blink = e->kind == ENEMY_DRONE && e->age >= 1.4f && e->age < 2.1f &&
                     ((int)(e->age * 12) % 2 == 0);
        Sprite id = e->kind == ENEMY_PAWN
                        ? (Sprite)(SPR_PAWN_0 + (int)(e->age * 5) % 2)
                        : (Sprite)(SPR_DRONE_0 + (e->age >= 2.1f ? 2 : (int)(e->age * 4) % 2));
        renderer_sprite(id, e->pos.x - 16, e->pos.y - 16, 1, blink ? 0xff7777ff : 0xffffffff);
    }
    draw_boss(g);
    for (int i = 0; i < MAX_BULLETS; i++)
        if (g->bullets[i].active) {
            const Bullet *b = &g->bullets[i];
            Sprite id = b->enemy ? (g->boss.core_open ? SPR_ENEMY_BULLET_HOT : SPR_ENEMY_BULLET)
                                 : SPR_PLAYER_BULLET;
            renderer_sprite(id, b->pos.x - 4, b->pos.y - (b->enemy ? 4 : 8), 1, 0xffffffff);
        }
    const Player *p = &g->player;
    // Long invulnerability is diagnostic autopilot; ordinary respawns blink.
    if (p->lives > 0 &&
        (p->invincible <= 0 || p->invincible > 10 || (int)(g->ui_time * 12) % 2 == 0)) {
        Sprite id = p->velocity.x < -35  ? SPR_PLAYER_LEFT
                    : p->velocity.x > 35 ? SPR_PLAYER_RIGHT
                                         : SPR_PLAYER_IDLE;
        renderer_sprite(id, p->pos.x - 16, p->pos.y - 16, 1, 0xffffffff);
        renderer_sprite((Sprite)(SPR_PLAYER_FLAME_0 + (int)(g->ui_time * 12) % 2), p->pos.x - 16,
                        p->pos.y + 16, 1, 0xffffffff);
    }
    for (int i = 0; i < MAX_EXPLOSIONS; i++)
        if (g->explosions[i].active) {
            const Explosion *e = &g->explosions[i];
            int frame = (int)(e->age * 10);
            if (frame > 4)
                frame = 4;
            renderer_sprite((Sprite)(SPR_EXPLOSION_0 + frame), e->pos.x - 16 * e->scale,
                            e->pos.y - 16 * e->scale, e->scale, 0xffffffff);
        }
    renderer_rect(0, 0, 400, 30, 0x080b1cdd);
    char text[80];
    snprintf(text, sizeof text, "SCORE %07d", g->score);
    renderer_text(text, 12, 11, 1, WHITE);
    for (int i = 0; i < p->lives; i++)
        renderer_sprite(SPR_LIFE, 326 + i * 22, 7, 1, 0xffffffff);
    if (!g->boss.active && g->scene != SCENE_BRIEFING) {
        snprintf(text, sizeof text, "WAVES %02d/10  DRONES %d/5", g->waves_spawned,
                 g->drones_spawned);
        renderer_text(text, 12, 482, 1, MUTED);
    }
    if (g->damage_flash > 0)
        renderer_rect(0, 30, 400, 470, 0xa7203030);
}
void presentation_draw(const Game *g, const Scores *scores, bool save_failed,
                       bool audio_available) {
    renderer_begin();
    background(g);
    Scene visible = g->scene == SCENE_PAUSE ? g->paused_scene : g->scene;
    if (visible == SCENE_SOUND)
        visible = g->sound_return == SCENE_PAUSE ? g->paused_scene : g->sound_return;
    if (visible == SCENE_MENU || visible == SCENE_SCORES) {
        renderer_sprite(SPR_TITLE, 68, 70, 1, 0xffffffff);
        centered("ONE SHIP. ONE BAD INVASION.", 128, 1, CYAN);
        if (visible == SCENE_MENU) {
            const char *items[] = {"START MISSION", "HIGH SCORES", "SOUND", "QUIT"};
            for (int i = 0; i < 4; i++) {
                if (i == g->menu_choice) {
                    renderer_rect(102, 211 + i * 30, 196, 23, 0x1b294dcc);
                    renderer_text(">", 110, 219 + i * 30, 1, GOLD);
                }
                centered(items[i], 219 + i * 30, 1, i == g->menu_choice ? GOLD : WHITE);
            }
            centered("WASD MOVE / HOLD SPACE TO FIRE", 390, 1, MUTED);
            centered("ENTER SELECT / ESC PAUSE / V SOUND", 410, 1, MUTED);
            centered("C  /  SOKOL  /  GNARLAXX", 466, 1, CYAN);
        } else {
            centered("HIGH SCORES", 186, 2, GOLD);
            for (int i = 0; i < SCORE_COUNT; i++) {
                char text[64];
                snprintf(text, sizeof text, "%d.   %09d", i + 1, scores->values[i]);
                centered(text, 237 + i * 28, 1, WHITE);
            }
            centered("ENTER / ESC TO RETURN", 429, 1, MUTED);
        }
    } else {
        world(g);
        if (visible == SCENE_BRIEFING) {
            panel(191, 104);
            if (g->scene_time < 4) {
                centered("ENEMY BOSS REPORTED", 212, 1, GOLD);
                centered("TO PREPARE INVASION", 232, 1, GOLD);
            } else {
                centered("YOU MUST STOPP HIM!", 212, 1, GOLD);
                centered("GO!", 240, 2, CYAN);
            }
        }
        if (visible == SCENE_VICTORY || visible == SCENE_GAME_OVER) {
            panel(174, 158);
            if (visible == SCENE_VICTORY)
                renderer_sprite(SPR_LEVEL_CLEARED, 92, 192, 1, 0xffffffff);
            else
                centered("GAME OVER", 198, 2, 0xff8e9fff);
            char text[64];
            snprintf(text, sizeof text, "FINAL SCORE %07d", g->score);
            centered(text, 242, 1, GOLD);
            centered(visible == SCENE_VICTORY ? "READY FOR THE NEXT MISSION?"
                                              : "THE INVASION WILL HAVE TO WAIT.",
                     266, 1, WHITE);
            centered("ENTER REPLAY / ESC MENU", 304, 1, MUTED);
        }
    }
    if (g->scene == SCENE_PAUSE) {
        renderer_rect(0, 0, 400, 500, 0x020510a0);
        panel(191, 116);
        centered("PAUSED", 214, 2, GOLD);
        centered("ESC / ENTER RESUME", 253, 1, WHITE);
        centered("V SOUND / Q MAIN MENU", 278, 1, MUTED);
    }
    if (g->scene == SCENE_SOUND) {
        renderer_rect(0, 0, 400, 500, 0x020510c0);
        panel(158, 198);
        centered("SOUND", 179, 2, GOLD);
        const char *labels[] = {"MASTER", "MUSIC", "EFFECTS"};
        for (int i = 0; i < 3; i++) {
            char text[64];
            snprintf(text, sizeof text, "%s %-7s %3d%%", g->volume_choice == i ? ">" : " ",
                     labels[i], (int)lroundf(g->volumes[i] * 100));
            centered(text, 222 + i * 28, 1, g->volume_choice == i ? GOLD : WHITE);
        }
        centered("ARROWS ADJUST / ESC RETURN", 328, 1, MUTED);
    }
    if (save_failed)
        centered("HIGH SCORES COULD NOT BE SAVED", 450, 1, 0xff8e9fff);
    if (!audio_available)
        centered("AUDIO OUTPUT UNAVAILABLE", 482, 1, 0xff8e9fff);
    if (g->fade > 0 && (g->scene == SCENE_BRIEFING || g->scene == SCENE_PAUSE))
        renderer_rect(0, 0, 400, 500, (uint32_t)(g->fade * 255));
    renderer_present();
}
