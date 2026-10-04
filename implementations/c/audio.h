#ifndef GNARLAXX_AUDIO_H
#define GNARLAXX_AUDIO_H
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

typedef enum Sound {
    SOUND_PLAYER_SHOT,
    SOUND_ENEMY_SHOT,
    SOUND_HIT,
    SOUND_EXPLOSION,
    SOUND_BOSS_EXPLOSION,
    SOUND_WARNING,
    SOUND_MENU_CONFIRM,
    SOUND_BOSS_RAM,
    SOUND_INTRO_WARNING,
    SOUND_INTRO_GO,
    SOUND_COUNT
} Sound;

enum { AUDIO_VOICES = 24 };
typedef struct Sample {
    float *data;
    uint64_t frames;
    unsigned channels, rate;
} Sample;
typedef struct Voice {
    Sound sound;
    double cursor;
    float gain;
    bool active;
} Voice;
typedef struct Audio {
    Sample sounds[SOUND_COUNT], music;
    Voice voices[AUDIO_VOICES];
    double music_cursor;
    float master_volume, music_volume, effects_volume;
    size_t decoded_bytes;
    bool paused;
} Audio;

bool audio_load(Audio *audio, const char *asset_root);
void audio_destroy(Audio *audio);
void audio_play(Audio *audio, Sound sound, float gain);
void audio_stop_effects(Audio *audio);
void audio_mix(Audio *audio, float *stereo, int frames, int sample_rate);
#endif
