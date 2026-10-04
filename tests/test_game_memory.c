#include "game.h"
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

typedef struct Heap {
    size_t calls, fail_at, live_bytes, peak_bytes;
} Heap;
static void *moving_resize(void *context, void *memory, size_t old_bytes, size_t new_bytes) {
    Heap *heap = context;
    CHECK(heap->live_bytes >= old_bytes);
    if (!new_bytes) {
        free(memory);
        heap->live_bytes -= old_bytes;
        return NULL;
    }
    if (++heap->calls == heap->fail_at)
        return NULL;
    // Always move: stale element pointers must fail under ASan, even if realloc would stay put.
    void *next = malloc(new_bytes);
    CHECK(next);
    if (memory)
        memcpy(next, memory, old_bytes < new_bytes ? old_bytes : new_bytes);
    free(memory);
    heap->live_bytes += new_bytes - old_bytes;
    if (heap->live_bytes > heap->peak_bytes)
        heap->peak_bytes = heap->live_bytes;
    return next;
}
static void init(Game *g, Heap *heap) {
    game_init_with_allocator(g, (GameAllocator){.resize = moving_resize, .context = heap});
}
static bool populate(Game *g) {
    // Exceed every old pool: 48 enemies/explosions, 512 bullets, 64 events.
    for (int i = 0; i < 1100; i++) {
        if (!game_add_enemy(g, (Enemy){.active = true, .kind = ENEMY_PAWN, .pos = {(float)i, 0}}) ||
            !game_add_bullet(g, (Bullet){.active = true, .pos = {(float)i, 0}}) ||
            !game_add_explosion(g, (Explosion){.active = true, .pos = {(float)i, 0}, .scale = 1}))
            return false;
    }
    // Accumulate events until the host consumes them, without advancing the world.
    if (!game_update(g, (Input){.sound = true}, GAME_STEP))
        return false;
    for (int i = 0; i < 100; i++)
        if (!game_update(g, (Input){.right = true}, GAME_STEP))
            return false;
    return true;
}
static void test_growth_removal_replay(void) {
    Heap heap = {0};
    Game g;
    init(&g, &heap);
    CHECK(game_heap_bytes(&g) == 0);
    CHECK(populate(&g));
    CHECK(g.enemies.count == 1100 && g.bullets.count == 1100 && g.explosions.count == 1100);
    CHECK(g.events.count == 100 && g.events.capacity >= 100);
    for (int i = 0; i < 1100; i++) {
        CHECK(g.enemies.data[i].pos.x == i && g.bullets.data[i].pos.x == i &&
              g.explosions.data[i].pos.x == i);
        if (i % 3 == 0)
            g.enemies.data[i].active = g.bullets.data[i].active = g.explosions.data[i].active =
                false;
    }
    CHECK(game_update(&g, (Input){0}, GAME_STEP));
    size_t alive = 0;
    for (int i = 0; i < 1100; i++)
        if (i % 3 != 0) {
            CHECK(g.enemies.data[alive].pos.x == i && g.bullets.data[alive].pos.x == i &&
                  g.explosions.data[alive].pos.x == i);
            alive++;
        }
    CHECK(g.enemies.count == alive && g.bullets.count == alive && g.explosions.count == alive);
    size_t calls = heap.calls, bytes = heap.live_bytes;
    CHECK(game_heap_bytes(&g) == bytes);
    g.volumes[VOLUME_MUSIC] = .42f;
    for (int run = 0; run < 100; run++) {
        CHECK(game_start(&g));
        CHECK(g.enemies.count == 0 && g.bullets.count == 0 && g.explosions.count == 0);
        CHECK(g.events.count == 1 && g.score == 0 && g.volumes[VOLUME_MUSIC] == .42f);
        CHECK(game_add_bullet(&g, (Bullet){.active = true}));
        CHECK(heap.calls == calls && heap.live_bytes == bytes);
    }
    game_destroy(&g);
    CHECK(heap.live_bytes == 0 && game_heap_bytes(&g) == 0);
    game_destroy(&g);
    CHECK(heap.live_bytes == 0);
    puts("dynamic state: all four collections exceed old limits; values survive moving growth, "
         "stable removal, 100 resets, and teardown");
}
static void test_failed_growth(void) {
    Heap heap = {0};
    Game g;
    init(&g, &heap);
    CHECK(game_add_bullet(&g, (Bullet){.active = true}));
    while (g.bullets.count < g.bullets.capacity)
        CHECK(game_add_bullet(&g, (Bullet){.active = true, .pos = {(float)g.bullets.count, 0}}));
    Bullet *old = g.bullets.data;
    size_t capacity = g.bullets.capacity;
    heap.fail_at = heap.calls + 1;
    CHECK(!game_add_bullet(&g, (Bullet){.active = true}));
    CHECK(g.allocation_failed && g.bullets.data == old && g.bullets.capacity == capacity &&
          g.bullets.count == capacity);
    for (size_t i = 0; i < g.bullets.count; i++)
        CHECK(g.bullets.data[i].pos.x == (float)i);
    CHECK(!game_update(&g, (Input){0}, GAME_STEP) && !game_start(&g));
    CHECK(!game_spawn_boss(&g) && !game_add_enemy(&g, (Enemy){0}));
    game_destroy(&g);
    CHECK(heap.live_bytes == 0);

    heap = (Heap){0};
    init(&g, &heap);
    CHECK(populate(&g));
    size_t allocation_count = heap.calls;
    game_destroy(&g);
    CHECK(heap.live_bytes == 0);
    for (size_t fail_at = 1; fail_at <= allocation_count; fail_at++) {
        heap = (Heap){.fail_at = fail_at};
        init(&g, &heap);
        CHECK(!populate(&g) && g.allocation_failed && heap.calls == fail_at);
        CHECK(!game_update(&g, (Input){.confirm = true}, GAME_STEP));
        game_destroy(&g);
        CHECK(heap.live_bytes == 0);
    }
    heap = (Heap){.fail_at = 1};
    init(&g, &heap);
    CHECK(!game_start(&g) && g.allocation_failed);
    game_destroy(&g);
    CHECK(heap.live_bytes == 0);
    printf("dynamic state: failed growth preserves old allocation; all %zu allocation failure "
           "points plus "
           "initial-start failure release ownership\n",
           allocation_count);
}
static void test_mission_with_moving_allocations(void) {
    Heap heap = {0};
    Game g;
    init(&g, &heap);
    for (int run = 0; run < 3; run++) {
        CHECK(game_start(&g));
        for (int step = 0; step < 120 * 95 && g.scene != SCENE_VICTORY; step++) {
            Input input = {0};
            if (g.scene == SCENE_PLAY) {
                float target = GAME_CENTER_X + sinf(g.level_time * .9f) * 125;
                if (g.boss.active)
                    target = g.boss.core_open ? g.boss.pos.x
                                              : game_boss_gun(&g.boss, g.boss.left_hp == 0).x;
                input.x = fmaxf(-1, fminf(1, (target - g.player.pos.x) * .03f));
                input.fire = true;
                g.player.invincible = 1000;
            }
            g.events.count = 0;
            CHECK(game_update(&g, input, GAME_STEP));
        }
        CHECK(g.scene == SCENE_VICTORY && g.player.lives == 3 && g.bullets.count == 0);
        CHECK(g.waves_spawned == 10 && g.drones_spawned == 5 && g.score >= 3750);
        int finished = 0;
        for (size_t i = 0; i < g.events.count; i++)
            finished += g.events.data[i].finished;
        CHECK(finished == 1);
        printf("dynamic mission %d: victory, score=%d, time=%.2fs, heap=%zu bytes, growths=%zu\n",
               run + 1, g.score, g.level_time, heap.live_bytes, heap.calls);
    }
    game_destroy(&g);
    CHECK(heap.live_bytes == 0);
}
int main(void) {
    test_growth_removal_replay();
    test_failed_growth();
    test_mission_with_moving_allocations();
    return 0;
}
