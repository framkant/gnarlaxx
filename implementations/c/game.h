#ifndef GNARLAXX_GAME_H
#define GNARLAXX_GAME_H
#include "sounds.h"
#include "properties.h"
#include <stdbool.h>

enum { MAX_ENEMIES = 48, MAX_BULLETS = 512, MAX_EXPLOSIONS = 48, MAX_EVENTS = 64 };
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
typedef struct Game {
    Scene scene, paused_scene, sound_return;
    Player player;
    Enemy enemies[MAX_ENEMIES];
    Bullet bullets[MAX_BULLETS];
    Explosion explosions[MAX_EXPLOSIONS];
    Boss boss;
    GameEvent events[MAX_EVENTS];
    int event_count, menu_choice, volume_choice, score, waves_spawned, drones_spawned;
    float volumes[VOLUME_COUNT], ui_time, scene_time, level_time, scroll, fade, damage_flash;
    bool quit_requested;
} Game;

void game_init(Game *game);
void game_start(Game *game);
void game_update(Game *game, Input input, float dt);
void game_pause(Game *game);
Vec2 game_boss_gun(const Boss *boss, bool right);
Vec2 game_boss_core(const Boss *boss);
void game_spawn_boss(Game *game); // Also used by the diagnostic --scene boss.
#endif
