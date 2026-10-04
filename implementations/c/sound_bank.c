#include "sound_bank.h"
#include "sounds.h"
#include <stdio.h>

GnaAudio *sound_bank_load(const char *root) {
    static const char *const files[SOUND_COUNT] = {
        "player_shot", "enemy_shot",   "hit",      "explosion",     "boss_explosion",
        "warning",     "menu_confirm", "boss_ram", "intro_warning", "intro_go"};
    char paths[SOUND_COUNT][2048], music[2048], error[2304];
    GnaSoundDesc sounds[SOUND_COUNT] = {0};
    for (int i = 0; i < SOUND_COUNT; i++) {
        if (snprintf(paths[i], sizeof paths[i], "%s/audio/%s.wav", root, files[i]) >=
            (int)sizeof paths[i]) {
            fprintf(stderr, "Audio asset path is too long\n");
            return NULL;
        }
        sounds[i].path = paths[i];
    }
    sounds[SOUND_WARNING].max_seconds = .6;
    sounds[SOUND_BOSS_RAM].max_seconds = 1.2;
    sounds[SOUND_INTRO_WARNING].protected_voice = 1;
    sounds[SOUND_INTRO_GO].protected_voice = 1;
    if (snprintf(music, sizeof music, "%s/audio/music.mp3", root) >= (int)sizeof music) {
        fprintf(stderr, "Music asset path is too long\n");
        return NULL;
    }
    GnaAudio *audio = gna_create(sounds, SOUND_COUNT, music, error, sizeof error);
    if (!audio)
        fprintf(stderr, "Cannot load audio: %s\n", error);
    return audio;
}
