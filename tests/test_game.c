#include "game.h"
#include "scores.h"
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define CHECK(c)                                                                                   \
    do {                                                                                           \
        if (!(c)) {                                                                                \
            fprintf(stderr, "FAIL %s:%d: %s\n", __FILE__, __LINE__, #c);                           \
            exit(1);                                                                               \
        }                                                                                          \
    } while (0)

static Game playing(void) {
    Game g;
    game_init(&g);
    game_start(&g);
    g.scene = SCENE_PLAY;
    g.fade = 0;
    g.player.pos = (Vec2){200, 420};
    g.event_count = 0;
    return g;
}
static void advance(Game *g, int steps, Input input) {
    for (int i = 0; i < steps; i++) {
        g->event_count = 0;
        game_update(g, input, GAME_STEP);
    }
}
static int bullets(const Game *g, bool enemy) {
    int n = 0;
    for (int i = 0; i < MAX_BULLETS; i++)
        n += g->bullets[i].active && g->bullets[i].enemy == enemy;
    return n;
}
static void test_movement_and_firing(void) {
    Game g = playing();
    advance(&g, 60, (Input){.x = 1});
    CHECK(g.player.pos.x > 250 && g.player.velocity.x > 150);
    float x = g.player.pos.x, speed = g.player.velocity.x;
    advance(&g, 12, (Input){0});
    CHECK(g.player.pos.x > x && g.player.velocity.x < speed); // Drift with drag.
    advance(&g, 300, (Input){.x = 1, .y = 1, .fire = true});
    CHECK(g.player.pos.x <= 384 && g.player.pos.y <= 468);
    CHECK(bullets(&g, false) > 0 && bullets(&g, false) < 10);
    puts("movement, drag, boundaries, held firing: passed");
}
static void test_briefing_and_menu(void) {
    Game g;
    game_init(&g);
    game_update(&g, (Input){.down = true}, GAME_STEP);
    CHECK(g.menu_choice == 1);
    game_update(&g, (Input){.confirm = true}, GAME_STEP);
    CHECK(g.scene == SCENE_SCORES);
    game_update(&g, (Input){.cancel = true}, GAME_STEP);
    CHECK(g.scene == SCENE_MENU);
    game_start(&g);
    int warning = 0, go = 0;
    for (int i = 0; i < 840; i++) {
        g.event_count = 0;
        game_update(&g, (Input){0}, GAME_STEP);
        for (int j = 0; j < g.event_count; j++) {
            warning += !g.events[j].finished && g.events[j].sound == SOUND_INTRO_WARNING;
            go += !g.events[j].finished && g.events[j].sound == SOUND_INTRO_GO;
        }
    }
    CHECK(warning == 1 && go == 1 && g.scene == SCENE_PLAY && g.fade == 0);
    CHECK(g.player.pos.y == 420 && g.player.lives == 3);
    puts("menu navigation, fade, briefing voice cues, player entry: passed");
}
static void test_pause_and_options(void) {
    Game g = playing();
    advance(&g, 120, (Input){.fire = true});
    game_update(&g, (Input){.cancel = true}, GAME_STEP);
    CHECK(g.scene == SCENE_PAUSE);
    float t = g.level_time, x = g.player.pos.x, bullet_y = g.bullets[0].pos.y;
    advance(&g, 120, (Input){.x = 1, .fire = true});
    CHECK(g.level_time == t && g.player.pos.x == x && g.bullets[0].pos.y == bullet_y);
    game_update(&g, (Input){.sound = true}, GAME_STEP);
    CHECK(g.scene == SCENE_SOUND);
    float volume = g.volumes[0];
    game_update(&g, (Input){.left = true}, GAME_STEP);
    CHECK(g.volumes[0] < volume);
    advance(&g, 40, (Input){.right = true});
    CHECK(g.volumes[0] == 1);
    game_update(&g, (Input){.cancel = true}, GAME_STEP);
    CHECK(g.scene == SCENE_PAUSE);
    game_update(&g, (Input){.confirm = true}, GAME_STEP);
    CHECK(g.scene == SCENE_PLAY);
    game_update(&g, (Input){0}, GAME_STEP);
    CHECK(g.level_time > t);
    game_pause(&g);
    game_update(&g, (Input){.menu = true}, GAME_STEP);
    CHECK(g.scene == SCENE_MENU);
    game_start(&g);
    CHECK(g.volumes[0] == 1);
    puts("pause freezes simulation; volume limits, return, and replay preserve settings: passed");
}
static void test_mission_and_boss_cycle(void) {
    Game g = playing();
    g.player.invincible = 1000;
    unsigned phases = 0;
    int pawns_spawned = 0, drones_spawned = 0, last_wave = 0, last_drone = 0;
    for (int i = 0; i < 120 * 85; i++) {
        g.event_count = 0;
        game_update(&g, (Input){0}, GAME_STEP);
        if (g.waves_spawned != last_wave) {
            pawns_spawned += 5;
            last_wave = g.waves_spawned;
        }
        if (g.drones_spawned != last_drone) {
            drones_spawned++;
            last_drone = g.drones_spawned;
        }
        if (g.boss.active)
            phases |= 1u << g.boss.phase;
    }
    CHECK(pawns_spawned == 50 && drones_spawned == 5 && g.waves_spawned == 10);
    CHECK(g.boss.active && phases == 127 && g.player.lives == 3);
    puts("complete schedule: ten five-pawn waves, five drones, all seven boss states: passed");
}
static void inject_hit(Game *g, Vec2 at) {
    g->event_count = 0;
    g->bullets[0] = (Bullet){.active = true, .pos = at};
    game_update(g, (Input){0}, GAME_STEP);
}
static void test_boss_damage_and_victory(void) {
    Game g = playing();
    g.waves_spawned = 10;
    g.drones_spawned = 5;
    game_spawn_boss(&g);
    g.boss.pos = (Vec2){200, 92};
    g.boss.phase = BOSS_WARN;
    inject_hit(&g, g.boss.pos);
    CHECK(g.boss.core_hp == 10 && !g.boss.core_open);
    for (int i = 0; i < 9; i++)
        inject_hit(&g, game_boss_gun(&g.boss, false));
    CHECK(g.boss.left_hp == 1 && !g.boss.core_open);
    inject_hit(&g, game_boss_gun(&g.boss, false));
    CHECK(g.boss.left_hp == 0 && !g.boss.core_open);
    for (int i = 0; i < 10; i++)
        inject_hit(&g, game_boss_gun(&g.boss, true));
    CHECK(g.boss.right_hp == 0 && g.boss.core_open && g.boss.core_hp == 10);
    // A real moving shot must reach the recessed core through the lower hull.
    g.bullets[0] =
        (Bullet){.active = true, .pos = {g.boss.pos.x, g.boss.pos.y + 65}, .velocity = {0, -620}};
    advance(&g, 12, (Input){0});
    CHECK(g.boss.core_hp == 9);
    for (int i = 0; i < 9; i++)
        inject_hit(&g, (Vec2){g.boss.pos.x, g.boss.pos.y - 2});
    CHECK(g.scene == SCENE_VICTORY && !g.boss.active && g.score == 3750);
    int finishes = 0;
    for (int i = 0; i < g.event_count; i++)
        finishes += g.events[i].finished;
    CHECK(finishes == 1);
    advance(&g, 120, (Input){0});
    CHECK(g.event_count == 0 && g.scene == SCENE_VICTORY);
    game_update(&g, (Input){.confirm = true}, GAME_STEP);
    CHECK(g.scene == SCENE_BRIEFING && g.score == 0 && g.player.lives == 3 && !g.boss.active);
    puts("10+10 protected gun hits, reachable ten-hit core, one victory event, clean replay: "
         "passed");
}
static void test_player_damage(void) {
    Game g = playing();
    g.player.invincible = 0;
    g.bullets[0] = (Bullet){.active = true, .enemy = true, .pos = g.player.pos};
    g.bullets[1] = g.bullets[0];
    game_update(&g, (Input){0}, GAME_STEP);
    CHECK(g.player.lives == 2 && g.player.invincible > 2 && g.scene == SCENE_PLAY);
    for (int i = 0; i < 2; i++) {
        g.player.invincible = 0;
        g.bullets[0] = (Bullet){.active = true, .enemy = true, .pos = g.player.pos};
        game_update(&g, (Input){0}, GAME_STEP);
    }
    CHECK(g.scene == SCENE_GAME_OVER && g.player.lives == 0);
    puts("overlapping hits cost one life; third death ends the run: passed");
}
static void test_scores(void) {
    const char *path = TEST_BINARY_DIR "/score-test.txt";
    remove(path);
    Scores scores;
    CHECK(!scores_load(&scores, path) && scores.values[0] == 0);
    scores_insert(&scores, 100);
    scores_insert(&scores, 400);
    scores_insert(&scores, 200);
    CHECK(scores_save(&scores, path));
    Scores loaded;
    CHECK(scores_load(&loaded, path) && loaded.values[0] == 400 && loaded.values[1] == 200 &&
          loaded.values[2] == 100);
    FILE *f = fopen(path, "w");
    CHECK(f);
    fputs("GNARLAXX 1\n99999999999999999999999999999\n", f);
    fclose(f);
    CHECK(!scores_load(&loaded, path) && loaded.values[0] == 0);
    f = fopen(path, "w");
    CHECK(f);
    fputs("GNARLAXX 1\n1\n5\n0\n0\n0\n", f);
    fclose(f);
    CHECK(!scores_load(&loaded, path));
    CHECK(!scores_save(&scores, TEST_BINARY_DIR "/nonexistent-directory/scores.txt"));
    remove(path);
    puts("score sorting, round-trip persistence, corrupt/missing files, write failure: passed");
}
int main(void) {
    test_movement_and_firing();
    test_briefing_and_menu();
    test_pause_and_options();
    test_mission_and_boss_cycle();
    test_boss_damage_and_victory();
    test_player_damage();
    test_scores();
    puts("All C simulation and persistence checks passed.");
    return 0;
}
