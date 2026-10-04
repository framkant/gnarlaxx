#include "presentation.h"
#include "renderer.h"
#include <math.h>
#include <stdio.h>
#include <string.h>

#define WHITE 0xeaf5ffffu
#define CYAN 0x73dbe8ffu
#define MUTED 0x93a0b8ffu
#define GOLD 0xffdc8affu

enum {
    PANEL_MARGIN = 26,
    LIFE_RIGHT_MARGIN = 14,
    LIFE_GAP = 6,
    BOSS_HEALTH_BAR_WIDTH = 52,
    BOSS_HEALTH_BAR_GAP = 10,
    BOSS_HEALTH_BAR_COUNT = 3
};

static void centered(const char *text, float y, int scale, uint32_t color) {
    renderer_text(text, (GAME_WIDTH - (float)strlen(text) * FONT_ADVANCE * scale) * .5f, y, scale,
                  color);
}
static void sprite_centered(Sprite id, Vec2 pos, float scale, uint32_t color) {
    const AtlasRect rect = SPRITE_RECTS[id];
    renderer_sprite(id, pos.x - rect.w * scale * .5f, pos.y - rect.h * scale * .5f, scale, color);
}
static void panel(float y, float h) {
    const float width = GAME_WIDTH - 2 * PANEL_MARGIN;
    renderer_rect(PANEL_MARGIN, y, width, h, 0x0a1024ee);
    renderer_rect(PANEL_MARGIN, y, width, 1, 0x526389ff);
    renderer_rect(PANEL_MARGIN, y + h - 1, width, 1, 0x526389ff);
}
static void background(const Game *g) {
    const int rows = (GAME_HEIGHT + BACKGROUND_TILE_SIZE - 1) / BACKGROUND_TILE_SIZE;
    const int columns = (GAME_WIDTH + BACKGROUND_TILE_SIZE - 1) / BACKGROUND_TILE_SIZE;
    const int pattern_height = BACKGROUND_PATTERN_ROWS * BACKGROUND_TILE_SIZE;
    for (int layer = 0; layer < 2; layer++) {
        float offset = fmodf(g->scroll * (layer ? BACKGROUND_NEAR_SPEED_RATIO : 1), pattern_height);
        for (int row = -BACKGROUND_PATTERN_ROWS; row < rows; row++)
            for (int col = 0; col < columns; col++) {
                int tile =
                    BACKGROUND_PATTERN[(row + BACKGROUND_PATTERN_ROWS) % BACKGROUND_PATTERN_ROWS]
                                      [col % BACKGROUND_PATTERN_COLUMNS];
                Sprite id = (Sprite)((layer ? SPR_STARS_NEAR_0 : SPR_STARS_FAR_0) + tile);
                renderer_sprite(id, col * BACKGROUND_TILE_SIZE, row * BACKGROUND_TILE_SIZE + offset,
                                1, layer ? 0xaabbdde0 : 0xffffffff);
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
            sprite_centered(side ? SPR_BOSS_GUN_RIGHT : SPR_BOSS_GUN_LEFT, gun, 1, tint);
        }
    sprite_centered(SPR_BOSS_BODY, b->pos, 1, tint);
    if (b->core_open)
        sprite_centered(SPR_BOSS_CORE, game_boss_core(b), 1, tint);
    const char *label = b->core_open                                       ? "CORE EXPOSED"
                        : b->phase == BOSS_RETRACT || b->phase == BOSS_RAM ? "RAM ATTACK"
                                                                           : "DESTROY BOTH GUNS";
    centered(label, 38, 1, b->core_open ? 0xff8e9fff : GOLD);
    const float bar_group_width = BOSS_HEALTH_BAR_COUNT * BOSS_HEALTH_BAR_WIDTH +
                                  (BOSS_HEALTH_BAR_COUNT - 1) * BOSS_HEALTH_BAR_GAP;
    for (int side = 0; side < BOSS_HEALTH_BAR_COUNT; side++) {
        int hp = side == 0 ? b->left_hp : side == 1 ? b->core_hp : b->right_hp;
        if (side == 1 && !b->core_open)
            continue;
        float x = (GAME_WIDTH - bar_group_width) * .5f +
                  side * (BOSS_HEALTH_BAR_WIDTH + BOSS_HEALTH_BAR_GAP);
        float max_hp = side == 1 ? BOSS_CORE_HP : BOSS_GUN_HP;
        renderer_rect(x, 52, BOSS_HEALTH_BAR_WIDTH, 3, 0x30394fff);
        renderer_rect(x, 52, BOSS_HEALTH_BAR_WIDTH * hp / max_hp, 3,
                      side == 1 ? 0xff688aff : 0xa6df64ff);
    }
}
static void world(const Game *g) {
    for (int i = 0; i < MAX_ENEMIES; i++) {
        const Enemy *e = &g->enemies[i];
        if (!e->active)
            continue;
        bool blink = e->kind == ENEMY_DRONE && e->age >= DRONE_APPROACH_TIME &&
                     e->age < DRONE_CHARGE_TIME && ((int)(e->age * 12) % 2 == 0);
        Sprite id =
            e->kind == ENEMY_PAWN
                ? (Sprite)(SPR_PAWN_0 + (int)(e->age * 5) % 2)
                : (Sprite)(SPR_DRONE_0 + (e->age >= DRONE_CHARGE_TIME ? 2 : (int)(e->age * 4) % 2));
        sprite_centered(id, e->pos, 1, blink ? 0xff7777ff : 0xffffffff);
    }
    draw_boss(g);
    for (int i = 0; i < MAX_BULLETS; i++)
        if (g->bullets[i].active) {
            const Bullet *b = &g->bullets[i];
            Sprite id = b->enemy ? (g->boss.core_open ? SPR_ENEMY_BULLET_HOT : SPR_ENEMY_BULLET)
                                 : SPR_PLAYER_BULLET;
            sprite_centered(id, b->pos, 1, 0xffffffff);
        }
    const Player *p = &g->player;
    // Long invulnerability is diagnostic autopilot; ordinary respawns blink.
    if (p->lives > 0 &&
        (p->invincible <= 0 || p->invincible > 10 || (int)(g->ui_time * 12) % 2 == 0)) {
        Sprite id = p->velocity.x < -PLAYER_BANK_SPEED  ? SPR_PLAYER_LEFT
                    : p->velocity.x > PLAYER_BANK_SPEED ? SPR_PLAYER_RIGHT
                                                        : SPR_PLAYER_IDLE;
        sprite_centered(id, p->pos, 1, 0xffffffff);
        renderer_sprite((Sprite)(SPR_PLAYER_FLAME_0 + (int)(g->ui_time * 12) % 2),
                        p->pos.x - SPRITE_RECTS[SPR_PLAYER_FLAME_0].w * .5f,
                        p->pos.y + PLAYER_HALF_HEIGHT, 1, 0xffffffff);
    }
    for (int i = 0; i < MAX_EXPLOSIONS; i++)
        if (g->explosions[i].active) {
            const Explosion *e = &g->explosions[i];
            int frame = (int)(e->age * EXPLOSION_FPS);
            if (frame >= EXPLOSION_FRAMES)
                frame = EXPLOSION_FRAMES - 1;
            sprite_centered((Sprite)(SPR_EXPLOSION_0 + frame), e->pos, e->scale, 0xffffffff);
        }
    renderer_rect(0, 0, GAME_WIDTH, HUD_HEIGHT, 0x080b1cdd);
    char text[80];
    snprintf(text, sizeof text, "SCORE %07d", g->score);
    renderer_text(text, 12, 11, 1, WHITE);
    const AtlasRect life = SPRITE_RECTS[SPR_LIFE];
    const int life_stride = life.w + LIFE_GAP;
    const int life_start = GAME_WIDTH - LIFE_RIGHT_MARGIN - PLAYER_LIVES * life_stride + LIFE_GAP;
    for (int i = 0; i < p->lives; i++)
        renderer_sprite(SPR_LIFE, life_start + i * life_stride, (HUD_HEIGHT - life.h) * .5f, 1,
                        0xffffffff);
    if (!g->boss.active && g->scene != SCENE_BRIEFING) {
        snprintf(text, sizeof text, "WAVES %02d/%d  DRONES %d/%d", g->waves_spawned,
                 PAWN_WAVE_COUNT, g->drones_spawned, DRONE_COUNT);
        renderer_text(text, 12, GAME_HEIGHT - FONT_CELL_HEIGHT - 10, 1, MUTED);
    }
    if (g->damage_flash > 0)
        renderer_rect(0, HUD_HEIGHT, GAME_WIDTH, GAME_HEIGHT - HUD_HEIGHT, 0xa7203030);
}
void presentation_draw(const Game *g, const Scores *scores, bool save_failed,
                       bool audio_available) {
    renderer_begin();
    background(g);
    Scene visible = g->scene == SCENE_PAUSE ? g->paused_scene : g->scene;
    if (visible == SCENE_SOUND)
        visible = g->sound_return == SCENE_PAUSE ? g->paused_scene : g->sound_return;
    if (visible == SCENE_MENU || visible == SCENE_SCORES) {
        renderer_sprite(SPR_TITLE, (GAME_WIDTH - SPRITE_RECTS[SPR_TITLE].w) * .5f, 70, 1,
                        0xffffffff);
        centered("ONE SHIP. ONE BAD INVASION.", 128, 1, CYAN);
        if (visible == SCENE_MENU) {
            const char *items[MENU_COUNT] = {[MENU_START] = "START MISSION",
                                             [MENU_SCORES] = "HIGH SCORES",
                                             [MENU_SOUND] = "SOUND",
                                             [MENU_QUIT] = "QUIT"};
            for (int i = 0; i < MENU_COUNT; i++) {
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
            if (g->scene_time < BRIEFING_GO_TIME) {
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
                renderer_sprite(SPR_LEVEL_CLEARED,
                                (GAME_WIDTH - SPRITE_RECTS[SPR_LEVEL_CLEARED].w) * .5f, 192, 1,
                                0xffffffff);
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
        renderer_rect(0, 0, GAME_WIDTH, GAME_HEIGHT, 0x020510a0);
        panel(191, 116);
        centered("PAUSED", 214, 2, GOLD);
        centered("ESC / ENTER RESUME", 253, 1, WHITE);
        centered("V SOUND / Q MAIN MENU", 278, 1, MUTED);
    }
    if (g->scene == SCENE_SOUND) {
        renderer_rect(0, 0, GAME_WIDTH, GAME_HEIGHT, 0x020510c0);
        panel(158, 198);
        centered("SOUND", 179, 2, GOLD);
        const char *labels[VOLUME_COUNT] = {
            [VOLUME_MASTER] = "MASTER", [VOLUME_MUSIC] = "MUSIC", [VOLUME_EFFECTS] = "EFFECTS"};
        for (int i = 0; i < VOLUME_COUNT; i++) {
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
        centered("AUDIO OUTPUT UNAVAILABLE", GAME_HEIGHT - FONT_CELL_HEIGHT - 10, 1, 0xff8e9fff);
    if (g->fade > 0 && (g->scene == SCENE_BRIEFING || g->scene == SCENE_PAUSE))
        renderer_rect(0, 0, GAME_WIDTH, GAME_HEIGHT, (uint32_t)(g->fade * 255));
    renderer_present();
}
