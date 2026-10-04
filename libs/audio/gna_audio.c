#include "gna_audio.h"
#include "dr_wav.h"
#include "dr_mp3.h"
#include <math.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct Sample {
    float *data;
    uint64_t frames;
    unsigned channels, rate;
    double end;
    bool protected_voice;
} Sample;
typedef struct Voice {
    uint32_t sound;
    double cursor;
    float gain;
    bool active;
} Voice;
struct GnaAudio {
    Sample *sounds, music;
    uint32_t sound_count;
    Voice voices[GNA_VOICE_COUNT];
    double music_cursor;
    float master_volume, music_volume, effects_volume;
    uint64_t decoded_bytes;
    bool paused;
};

GnaAudio *gna_create(const GnaSoundDesc *sounds, uint32_t count, const char *music_path,
                     char *error, size_t error_capacity) {
    const char *problem = "Invalid sound descriptors";
    const char *path = "";
    GnaAudio *a = NULL;
    if (error && error_capacity)
        error[0] = '\0';
    if (count && !sounds)
        goto fail;
    problem = "Cannot allocate audio context";
    a = calloc(1, sizeof *a);
    if (!a)
        goto fail;
    a->master_volume = a->music_volume = a->effects_volume = 1;
    if (count) {
        a->sounds = calloc(count, sizeof *a->sounds);
        if (!a->sounds)
            goto fail;
    }
    a->sound_count = count;
    for (uint32_t i = 0; i < count; i++) {
        path = sounds[i].path ? sounds[i].path : "(null)";
        problem = "Expected a nonempty mono WAV and a finite, nonnegative duration";
        if (!sounds[i].path || !isfinite(sounds[i].max_seconds) || sounds[i].max_seconds < 0)
            goto fail;
        Sample *s = &a->sounds[i];
        drwav_uint64 frames = 0;
        s->data =
            drwav_open_file_and_read_pcm_frames_f32(path, &s->channels, &s->rate, &frames, NULL);
        s->frames = frames;
        if (!s->data || !frames || s->channels != 1 || !s->rate ||
            frames > SIZE_MAX / sizeof(float))
            goto fail;
        s->end = (double)frames;
        if (sounds[i].max_seconds > 0)
            s->end = fmin(s->end, sounds[i].max_seconds * s->rate);
        s->protected_voice = sounds[i].protected_voice != 0;
        a->decoded_bytes += frames * sizeof(float);
    }
    if (music_path) {
        path = music_path;
        problem = "Expected a nonempty stereo MP3";
        drmp3_config config = {0};
        drmp3_uint64 frames = 0;
        a->music.data = drmp3_open_file_and_read_pcm_frames_f32(path, &config, &frames, NULL);
        a->music.frames = frames;
        a->music.channels = config.channels;
        a->music.rate = config.sampleRate;
        if (!a->music.data || !frames || config.channels != GNA_CHANNELS || !config.sampleRate ||
            frames > SIZE_MAX / (GNA_CHANNELS * sizeof(float)))
            goto fail;
        a->decoded_bytes += frames * GNA_CHANNELS * sizeof(float);
    }
    return a;
fail:
    if (error && error_capacity)
        snprintf(error, error_capacity, "%s: %s", problem, path);
    gna_destroy(a);
    return NULL;
}

void gna_destroy(GnaAudio *a) {
    if (!a)
        return;
    gna_device_close(a);
    for (uint32_t i = 0; i < a->sound_count; i++)
        drwav_free(a->sounds[i].data, NULL);
    free(a->sounds);
    drmp3_free(a->music.data, NULL);
    free(a);
}
static float volume(float value) {
    return isfinite(value) ? fmaxf(0, fminf(1, value)) : 0;
}
void gna_set_volume(GnaAudio *a, float master, float music, float effects) {
    a->master_volume = volume(master);
    a->music_volume = volume(music);
    a->effects_volume = volume(effects);
}
void gna_set_paused(GnaAudio *a, int32_t paused) {
    a->paused = paused != 0;
}
int32_t gna_play(GnaAudio *a, uint32_t sound, float gain) {
    if (sound >= a->sound_count || !isfinite(gain) || gain < 0)
        return 0;
    int slot = -1;
    double oldest = -1;
    for (int i = 0; i < GNA_VOICE_COUNT; i++) {
        if (!a->voices[i].active) {
            slot = i;
            break;
        }
        if (!a->sounds[a->voices[i].sound].protected_voice && a->voices[i].cursor > oldest) {
            oldest = a->voices[i].cursor;
            slot = i;
        }
    }
    if (slot < 0)
        return 0;
    a->voices[slot] = (Voice){.sound = sound, .gain = gain, .active = true};
    return 1;
}
void gna_stop_effects(GnaAudio *a) {
    memset(a->voices, 0, sizeof a->voices);
}
uint64_t gna_decoded_bytes(const GnaAudio *a) {
    return a->decoded_bytes;
}
uint32_t gna_active_voices(const GnaAudio *a) {
    uint32_t count = 0;
    for (int i = 0; i < GNA_VOICE_COUNT; i++)
        count += a->voices[i].active;
    return count;
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
void gna_mix(GnaAudio *a, float *out, uint32_t frames, uint32_t rate) {
    if (!out || !frames)
        return;
    memset(out, 0, (size_t)frames * GNA_CHANNELS * sizeof(float));
    if (a->paused || !rate)
        return;
    for (uint32_t n = 0; n < frames; n++) {
        float l = 0, r = 0;
        if (a->music.frames) {
            l = sample_at(&a->music, a->music_cursor, 0, true) * a->music_volume;
            r = sample_at(&a->music, a->music_cursor, 1, true) * a->music_volume;
            a->music_cursor += (double)a->music.rate / rate;
            if (a->music_cursor >= a->music.frames)
                a->music_cursor = fmod(a->music_cursor, (double)a->music.frames);
        }
        for (int i = 0; i < GNA_VOICE_COUNT; i++) {
            Voice *v = &a->voices[i];
            if (!v->active)
                continue;
            const Sample *s = &a->sounds[v->sound];
            const double fade_seconds = .02;
            float fade = (float)fmin(1, fmax(0, (s->end - v->cursor) / (s->rate * fade_seconds)));
            float value = sample_at(s, v->cursor, 0, false) * v->gain * a->effects_volume * fade;
            l += value;
            r += value;
            v->cursor += (double)s->rate / rate;
            if (v->cursor >= s->end)
                v->active = false;
        }
        out[n * GNA_CHANNELS] = fmaxf(-1, fminf(1, l * a->master_volume));
        out[n * GNA_CHANNELS + 1] = fmaxf(-1, fminf(1, r * a->master_volume));
    }
}
