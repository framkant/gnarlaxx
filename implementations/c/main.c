#include "audio.h"
#include "game.h"
#include "presentation.h"
#include "renderer.h"
#include "scores.h"
#include "sokol_app.h"
#include "sokol_audio.h"
#include "sokol_log.h"
#include "sokol_time.h"
#include <errno.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/resource.h>
#include <sys/stat.h>

static struct {
    Game game;
    Audio audio;
    Scores scores;
    bool held[SAPP_MAX_KEYCODES], pressed[SAPP_MAX_KEYCODES];
    bool save_failed, audio_available, demo, mute;
    double accumulator, work_seconds, max_work_seconds;
    uint64_t started;
    int frames, frame_limit;
    const char *asset_root, *capture, *score_override, *diagnostic_scene;
    char score_path[2048];
} app;

static void score_path(void) {
    if (app.score_override) {
        if (snprintf(app.score_path, sizeof app.score_path, "%s", app.score_override) >=
            (int)sizeof app.score_path) {
            fprintf(stderr, "Score path is too long\n");
            exit(1);
        }
        return;
    }
    const char *home = getenv("HOME");
    char directory[1800];
    if (!home || snprintf(directory, sizeof directory, "%s/Library/Application Support/Gnarlaxx",
                          home) >= (int)sizeof directory) {
        fprintf(stderr, "Cannot locate the save directory; use --scores PATH\n");
        exit(1);
    }
    if (mkdir(directory, 0700) != 0 && errno != EEXIST)
        app.save_failed = true;
    snprintf(app.score_path, sizeof app.score_path, "%s/scores.txt", directory);
}

static void set_diagnostic_scene(void) {
    if (!app.diagnostic_scene)
        return;
    Game *g = &app.game;
    const char *scene = app.diagnostic_scene;
    if (!strcmp(scene, "menu"))
        return;
    game_start(g);
    if (!strcmp(scene, "briefing"))
        return;
    g->scene = SCENE_PLAY;
    g->fade = 0;
    g->player.pos = (Vec2){GAME_CENTER_X, PLAYER_SPAWN_Y};
    if (!strcmp(scene, "play"))
        return;
    g->waves_spawned = PAWN_WAVE_COUNT;
    g->drones_spawned = DRONE_COUNT;
    game_spawn_boss(g);
    g->boss.pos = (Vec2){GAME_CENTER_X, BOSS_REST_Y};
    g->boss.phase = BOSS_ROAM;
    if (!strcmp(scene, "core")) {
        g->boss.left_hp = 0;
        g->boss.right_hp = 0;
        g->boss.core_open = true;
    } else if (!strcmp(scene, "pause"))
        game_pause(g);
    else if (!strcmp(scene, "victory")) {
        g->scene = SCENE_VICTORY;
        g->boss.active = false;
        g->score = 10000;
    } else if (strcmp(scene, "boss")) {
        fprintf(stderr, "Unknown --scene: %s\n", scene);
        exit(1);
    }
}

static void init(void) {
    stm_setup();
    game_init(&app.game);
    score_path();
    scores_load(&app.scores, app.score_path);
    if (!renderer_init(app.asset_root) || !audio_load(&app.audio, app.asset_root))
        exit(1);
    saudio_setup(&(saudio_desc){.sample_rate = 44100,
                                .num_channels = 2,
                                .buffer_frames = 512,
                                .packet_frames = 128,
                                .num_packets = 16,
                                .logger.func = slog_func});
    app.audio_available = saudio_isvalid();
    if (app.mute)
        app.game.volumes[VOLUME_MASTER] = 0;
    set_diagnostic_scene();
    if (app.demo && !app.diagnostic_scene)
        game_start(&app.game);
    printf("Gnarlaxx C: Metal; audio=%s (%d Hz); decoded audio=%.2f MiB; game state=%zu bytes\n",
           app.audio_available ? "ready" : "unavailable", saudio_sample_rate(),
           app.audio.decoded_bytes / 1048576.0, sizeof(Game));
    fflush(stdout);
    app.started = stm_now();
}

static Input input(void) {
    Input in = {.x = (app.held[SAPP_KEYCODE_D] || app.held[SAPP_KEYCODE_RIGHT]) -
                     (app.held[SAPP_KEYCODE_A] || app.held[SAPP_KEYCODE_LEFT]),
                .y = (app.held[SAPP_KEYCODE_S] || app.held[SAPP_KEYCODE_DOWN]) -
                     (app.held[SAPP_KEYCODE_W] || app.held[SAPP_KEYCODE_UP]),
                .fire = app.held[SAPP_KEYCODE_SPACE],
                .confirm = app.pressed[SAPP_KEYCODE_ENTER],
                .cancel = app.pressed[SAPP_KEYCODE_ESCAPE],
                .up = app.pressed[SAPP_KEYCODE_UP] || app.pressed[SAPP_KEYCODE_W],
                .down = app.pressed[SAPP_KEYCODE_DOWN] || app.pressed[SAPP_KEYCODE_S],
                .left = app.pressed[SAPP_KEYCODE_LEFT] || app.pressed[SAPP_KEYCODE_A],
                .right = app.pressed[SAPP_KEYCODE_RIGHT] || app.pressed[SAPP_KEYCODE_D],
                .sound = app.pressed[SAPP_KEYCODE_V],
                .menu = app.pressed[SAPP_KEYCODE_Q]};
    if (app.demo && app.game.scene == SCENE_PLAY) {
        // A diagnostic autopilot for captures/profiling; it never records scores.
        float target = GAME_CENTER_X + sinf(app.game.level_time * .9f) * 125;
        if (app.game.boss.active) {
            const Boss *b = &app.game.boss;
            target = b->core_open ? b->pos.x : game_boss_gun(b, b->left_hp == 0).x;
        }
        in.x = fmaxf(-1, fminf(1, (target - app.game.player.pos.x) * .03f));
        in.fire = true;
        app.game.player.invincible = 1000;
    }
    memset(app.pressed, 0, sizeof app.pressed);
    return in;
}

static void process_events(void) {
    for (int i = 0; i < app.game.event_count; i++) {
        const GameEvent *e = &app.game.events[i];
        if (e->finished) {
            printf("Run finished: %s, score=%d, mission time=%.2fs\n",
                   app.game.scene == SCENE_VICTORY ? "victory" : "game over", e->score,
                   app.game.level_time);
            if (!app.demo && !app.diagnostic_scene) {
                scores_insert(&app.scores, e->score);
                app.save_failed = !scores_save(&app.scores, app.score_path);
                if (app.save_failed)
                    fprintf(stderr, "Could not save scores to %s\n", app.score_path);
            }
        } else
            audio_play(&app.audio, e->sound, e->gain);
    }
    app.game.event_count = 0;
}

static void frame(void) {
    uint64_t begin = stm_now();
    app.accumulator += fmin(sapp_frame_duration(), .1);
    while (app.accumulator >= GAME_STEP) {
        Scene previous = app.game.scene;
        game_update(&app.game, input(), GAME_STEP);
        if ((app.game.scene == SCENE_BRIEFING && previous != SCENE_BRIEFING &&
             previous != SCENE_PAUSE && previous != SCENE_SOUND) ||
            (app.game.scene == SCENE_MENU && previous != SCENE_MENU))
            audio_stop_effects(&app.audio);
        process_events();
        app.accumulator -= GAME_STEP;
    }
    app.audio.master_volume = app.game.volumes[VOLUME_MASTER];
    app.audio.music_volume = app.game.volumes[VOLUME_MUSIC];
    app.audio.effects_volume = app.game.volumes[VOLUME_EFFECTS];
    app.audio.paused = app.game.scene == SCENE_PAUSE;
    if (app.audio_available) {
        int remaining = saudio_expect();
        float buffer[2048];
        while (remaining > 0) {
            int n = remaining > 1024 ? 1024 : remaining;
            audio_mix(&app.audio, buffer, n, saudio_sample_rate());
            int pushed = saudio_push(buffer, n);
            if (pushed != n) {
                fprintf(stderr, "Audio queue accepted %d/%d frames\n", pushed, n);
                break;
            }
            remaining -= n;
        }
    }
    presentation_draw(&app.game, &app.scores, app.save_failed, app.audio_available);
    double work = stm_sec(stm_since(begin));
    app.work_seconds += work;
    if (work > app.max_work_seconds)
        app.max_work_seconds = work;
    app.frames++;
    if (app.frame_limit && app.frames >= app.frame_limit) {
        if (app.capture && !renderer_capture(app.capture)) {
            fprintf(stderr, "Capture failed: %s\n", app.capture);
            exit(2);
        }
        sapp_request_quit();
    }
    if (app.game.quit_requested)
        sapp_request_quit();
}

static void event(const sapp_event *e) {
    if (e->type == SAPP_EVENTTYPE_UNFOCUSED || e->type == SAPP_EVENTTYPE_ICONIFIED) {
        memset(app.held, 0, sizeof app.held);
        memset(app.pressed, 0, sizeof app.pressed);
        if (!app.demo)
            game_pause(&app.game);
        return;
    }
    if (e->key_code < 0 || e->key_code >= SAPP_MAX_KEYCODES)
        return;
    if (e->type == SAPP_EVENTTYPE_KEY_DOWN) {
        app.held[e->key_code] = true;
        if (!e->key_repeat)
            app.pressed[e->key_code] = true;
    } else if (e->type == SAPP_EVENTTYPE_KEY_UP)
        app.held[e->key_code] = false;
}

static void cleanup(void) {
    struct rusage usage = {0};
    getrusage(RUSAGE_SELF, &usage);
    double elapsed = stm_sec(stm_since(app.started));
    double cpu = usage.ru_utime.tv_sec + usage.ru_utime.tv_usec / 1e6 + usage.ru_stime.tv_sec +
                 usage.ru_stime.tv_usec / 1e6;
    printf("Stats: %d frames / %.2fs = %.1f fps; frame work avg %.3fms max %.3fms; CPU %.3fs; peak "
           "RSS %.2f MiB\n",
           app.frames, elapsed, elapsed > 0 ? app.frames / elapsed : 0,
           app.frames ? app.work_seconds * 1000 / app.frames : 0, app.max_work_seconds * 1000, cpu,
           usage.ru_maxrss / 1048576.0);
    saudio_shutdown();
    audio_destroy(&app.audio);
    renderer_shutdown();
}

sapp_desc sokol_main(int argc, char **argv) {
    app.asset_root = GNARLAXX_ASSET_ROOT;
    for (int i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "--demo"))
            app.demo = true;
        else if (!strcmp(argv[i], "--mute"))
            app.mute = true;
        else if (!strcmp(argv[i], "--frames") && i + 1 < argc) {
            app.frame_limit = atoi(argv[++i]);
            if (app.frame_limit <= 0) {
                fprintf(stderr, "--frames requires a positive integer\n");
                exit(1);
            }
        } else if (!strcmp(argv[i], "--capture") && i + 1 < argc)
            app.capture = argv[++i];
        else if (!strcmp(argv[i], "--assets") && i + 1 < argc)
            app.asset_root = argv[++i];
        else if (!strcmp(argv[i], "--scores") && i + 1 < argc)
            app.score_override = argv[++i];
        else if (!strcmp(argv[i], "--scene") && i + 1 < argc)
            app.diagnostic_scene = argv[++i];
        else if (!strcmp(argv[i], "--help")) {
            puts("Gnarlaxx: WASD/arrows move, Space fires, Enter selects, Esc pauses, V sound, Q "
                 "leaves paused run.\n"
                 "Options: --assets PATH --scores PATH --mute\n"
                 "Diagnostics: --frames N --capture PNG --demo (invulnerable autopilot, no score "
                 "saving)\n"
                 "             --scene menu|briefing|play|boss|core|pause|victory (no score "
                 "saving)");
            exit(0);
        } else {
            fprintf(stderr, "Unknown or incomplete option: %s\n", argv[i]);
            exit(1);
        }
    }
    if (app.capture && !app.frame_limit) {
        fprintf(stderr, "--capture requires --frames\n");
        exit(1);
    }
    return (sapp_desc){.init_cb = init,
                       .frame_cb = frame,
                       .event_cb = event,
                       .cleanup_cb = cleanup,
                       .width = GAME_WIDTH * WINDOW_SCALE,
                       .height = GAME_HEIGHT * WINDOW_SCALE,
                       .window_title = "Gnarlaxx - C",
                       .high_dpi = true,
                       .sample_count = 1,
                       .icon.sokol_default = true,
                       .logger.func = slog_func};
}
