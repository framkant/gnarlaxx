#include "audio.h"
#include "dr_wav.h"
#include "dr_mp3.h"
#include <math.h>
#include <stdio.h>
#include <string.h>

static const char *const SOUND_FILES[SOUND_COUNT] = {
    "player_shot", "enemy_shot",   "hit",      "explosion",     "boss_explosion",
    "warning",     "menu_confirm", "boss_ram", "intro_warning", "intro_go"};

bool audio_load(Audio *a, const char *root) {
    *a = (Audio){.master_volume = .65f, .music_volume = .28f, .effects_volume = .65f};
    char path[2048];
    for (int i = 0; i < SOUND_COUNT; i++) {
        snprintf(path, sizeof path, "%s/audio/%s.wav", root, SOUND_FILES[i]);
        Sample *s = &a->sounds[i];
        drwav_uint64 frames = 0;
        s->data =
            drwav_open_file_and_read_pcm_frames_f32(path, &s->channels, &s->rate, &frames, NULL);
        s->frames = frames;
        if (!s->data || !s->frames || s->channels != 1 || !s->rate)
            goto fail;
        a->decoded_bytes += s->frames * s->channels * sizeof(float);
    }
    snprintf(path, sizeof path, "%s/audio/music.mp3", root);
    drmp3_config config = {0};
    drmp3_uint64 frames = 0;
    a->music.data = drmp3_open_file_and_read_pcm_frames_f32(path, &config, &frames, NULL);
    a->music.frames = frames;
    a->music.channels = config.channels;
    a->music.rate = config.sampleRate;
    if (!a->music.data || !frames || config.channels != 2 || !config.sampleRate)
        goto fail;
    a->decoded_bytes += frames * config.channels * sizeof(float);
    return true;
fail:
    fprintf(stderr, "Cannot decode asset: %s\n", path);
    audio_destroy(a);
    return false;
}

void audio_destroy(Audio *a) {
    for (int i = 0; i < SOUND_COUNT; i++)
        drwav_free(a->sounds[i].data, NULL);
    drmp3_free(a->music.data, NULL);
    *a = (Audio){0};
}

void audio_play(Audio *a, Sound sound, float gain) {
    if (sound < 0 || sound >= SOUND_COUNT)
        return;
    int slot = -1;
    double oldest = -1;
    for (int i = 0; i < AUDIO_VOICES; i++) {
        if (!a->voices[i].active) {
            slot = i;
            break;
        }
        // If full, replace an effect, never an in-progress briefing line.
        if (a->voices[i].sound < SOUND_INTRO_WARNING && a->voices[i].cursor > oldest) {
            oldest = a->voices[i].cursor;
            slot = i;
        }
    }
    if (slot >= 0)
        a->voices[slot] = (Voice){.sound = sound, .gain = gain, .active = true};
}

void audio_stop_effects(Audio *a) {
    memset(a->voices, 0, sizeof a->voices);
}

static float sample_at(const Sample *s, double cursor, unsigned channel, bool loop) {
    uint64_t frame = (uint64_t)cursor;
    if (frame >= s->frames)
        return 0;
    uint64_t next = frame + 1;
    if (next >= s->frames)
        next = loop ? 0 : frame;
    const float blend = (float)(cursor - (double)frame);
    float x = s->data[frame * s->channels + channel];
    return x + (s->data[next * s->channels + channel] - x) * blend;
}

void audio_mix(Audio *a, float *out, int frames, int rate) {
    memset(out, 0, (size_t)frames * 2 * sizeof(float));
    if (a->paused || rate <= 0)
        return;
    for (int n = 0; n < frames; n++) {
        float l = 0, r = 0;
        if (a->music.frames) {
            l = sample_at(&a->music, a->music_cursor, 0, true) * a->music_volume;
            r = sample_at(&a->music, a->music_cursor, 1, true) * a->music_volume;
            a->music_cursor += (double)a->music.rate / rate;
            if (a->music_cursor >= a->music.frames)
                a->music_cursor = fmod(a->music_cursor, (double)a->music.frames);
        }
        for (int i = 0; i < AUDIO_VOICES; i++) {
            Voice *v = &a->voices[i];
            if (!v->active)
                continue;
            const Sample *s = &a->sounds[v->sound];
            // Long source warning/engine recordings become short one-shots.
            double end = (double)s->frames;
            if (v->sound == SOUND_WARNING && end > s->rate * .6)
                end = s->rate * .6;
            if (v->sound == SOUND_BOSS_RAM && end > s->rate * 1.2)
                end = s->rate * 1.2;
            float fade = (float)fmin(1, fmax(0, (end - v->cursor) / (s->rate * .02)));
            float value = sample_at(s, v->cursor, 0, false) * v->gain * a->effects_volume * fade;
            l += value;
            r += value;
            v->cursor += (double)s->rate / rate;
            if (v->cursor >= end)
                v->active = false;
        }
        out[n * 2] = fmaxf(-1, fminf(1, l * a->master_volume));
        out[n * 2 + 1] = fmaxf(-1, fminf(1, r * a->master_volume));
    }
}
