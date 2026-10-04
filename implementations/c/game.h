#ifndef GNARLAXX_GAME_H
#define GNARLAXX_GAME_H
#include "sounds.h"
#include "properties.h"
#include <stdbool.h>
#include <stddef.h>

typedef struct Vec2 {
    float x, y;
} Vec2;
typedef enum Scene {
    SCENE_MENU,
    SCENE_BRIEFING,
    SCENE_PLAY,
    SCENE_PAUSE,
    SCENE_SCORES,
    SCENE_SOUND,
    SCENE_VICTORY,
    SCENE_GAME_OVER
} Scene;
enum { MENU_START, MENU_SCORES, MENU_SOUND, MENU_QUIT, MENU_COUNT };
enum { VOLUME_MASTER, VOLUME_MUSIC, VOLUME_EFFECTS, VOLUME_COUNT };
typedef enum EnemyKind { ENEMY_PAWN, ENEMY_DRONE } EnemyKind;
typedef enum BossPhase {
    BOSS_ENTER,
    BOSS_ROAM,
    BOSS_WARN,
    BOSS_FIRE,
    BOSS_RETRACT,
    BOSS_RAM,
    BOSS_RETURN
} BossPhase;
typedef struct Input {
    float x, y;
    bool fire, confirm, cancel, up, down, left, right, sound, menu;
} Input;
typedef struct Player {
    Vec2 pos, velocity;
    float invincible, shot_timer;
    int lives;
} Player;
typedef struct Enemy {
    bool active;
    EnemyKind kind;
    Vec2 pos, velocity;
    float age, base_x, shot_timer;
    int wave, slot;
} Enemy;
typedef struct Bullet {
    bool active, enemy;
    Vec2 pos, velocity;
} Bullet;
typedef struct Explosion {
    bool active;
    Vec2 pos;
    float age, scale;
} Explosion;
typedef struct Boss {
    bool active, core_open;
    Vec2 pos, move_start, target;
    int left_hp, right_hp, core_hp;
    BossPhase phase;
    float timer, shot_timer, retract, flash;
} Boss;
typedef struct GameEvent {
    bool finished;
    Sound sound;
    float gain;
    int score;
} GameEvent;
typedef struct EnemyList {
    Enemy *data;
    size_t count, capacity;
} EnemyList;
typedef struct BulletList {
    Bullet *data;
    size_t count, capacity;
} BulletList;
typedef struct ExplosionList {
    Explosion *data;
    size_t count, capacity;
} ExplosionList;
typedef struct EventList {
    GameEvent *data;
    size_t count, capacity;
} EventList;
typedef struct GameAllocator {
    // realloc semantics: failure retains old storage; new_bytes == 0 frees it.
    // Storage must have malloc alignment. Context must outlive the Game.
    void *(*resize)(void *context, void *memory, size_t old_bytes, size_t new_bytes);
    void *context;
} GameAllocator;
// Owns its collections. Do not copy a live Game or keep element pointers across updates/adds.
typedef struct Game {
    Scene scene, paused_scene, sound_return;
    Player player;
    EnemyList enemies;
    BulletList bullets;
    ExplosionList explosions;
    Boss boss;
    EventList events;
    GameAllocator allocator;
    int menu_choice, volume_choice, score, waves_spawned, drones_spawned;
    float volumes[VOLUME_COUNT], ui_time, scene_time, level_time, scroll, fade, damage_flash;
    bool quit_requested, allocation_failed;
} Game;

// No allocations until first use. Initialize only a fresh/destroyed Game.
void game_init(Game *game);
void game_init_with_allocator(Game *game, GameAllocator allocator); // NULL resize uses the heap.
void game_destroy(Game *game); // Frees all owned storage; safe to repeat.
size_t game_heap_bytes(const Game *game);
bool game_start(Game *game); // Resets the run, retaining collection capacity and volume settings.
// False means terminal allocation failure: stop processing this run and destroy it.
bool game_update(Game *game, Input input, float dt);
// Adds copy their value. Removal is marked with active=false and compacted after each update.
bool game_add_enemy(Game *game, Enemy enemy);
bool game_add_bullet(Game *game, Bullet bullet);
bool game_add_explosion(Game *game, Explosion explosion);
void game_pause(Game *game);
Vec2 game_boss_gun(const Boss *boss, bool right);
Vec2 game_boss_core(const Boss *boss);
bool game_spawn_boss(Game *game); // Also used by the diagnostic --scene boss.
#endif
