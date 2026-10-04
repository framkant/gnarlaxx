#include "gna_audio.h"
#include "sound_bank.h"
#include "sounds.h"
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
static void little(FILE *f, unsigned value, int bytes) {
    for (int i = 0; i < bytes; i++) {
        fputc(value & 255, f);
        value >>= 8;
    }
}
static void fixture(const char *path) {
    FILE *f = fopen(path, "wb");
    CHECK(f);
    // 512 mono 16-bit samples, rising by 16/32768 each frame, at 8 kHz.
    fwrite("RIFF", 1, 4, f);
    little(f, 36 + 1024, 4);
    fwrite("WAVEfmt ", 1, 8, f);
    little(f, 16, 4);
    little(f, 1, 2);
    little(f, 1, 2);
    little(f, 8000, 4);
    little(f, 16000, 4);
    little(f, 2, 2);
    little(f, 16, 2);
    fwrite("data", 1, 4, f);
    little(f, 1024, 4);
    for (unsigned i = 0; i < 512; i++)
        little(f, i * 16, 2);
    CHECK(fclose(f) == 0);
}
static void silence(const float *samples, size_t count) {
    for (size_t i = 0; i < count; i++)
        CHECK(samples[i] == 0);
}
static void test_mixer(void) {
    const char *path = TEST_BINARY_DIR "/audio-fixture.wav";
    fixture(path);
    GnaSoundDesc clips[] = {{.path = path},
                            {.path = path, .max_seconds = .03, .protected_voice = 1}};
    char error[256];
    GnaAudio *a = gna_create(clips, 2, NULL, error, sizeof error);
    CHECK(a && !error[0] && gna_decoded_bytes(a) == 4096);
    CHECK(gna_device_rate(a) == 0 && !gna_device_pump(a));
    CHECK(!gna_play(a, 2, 1) && !gna_play(a, 0, NAN));
    for (int i = 0; i < 8; i++)
        CHECK(gna_play(a, 0, .5f));
    float out[1024], reference[128];
    gna_set_volume(a, .5f, 0, .5f);
    gna_mix(a, out, 64, 4000);
    CHECK(gna_active_voices(a) == 8);
    for (int i = 0; i < 64; i++) {
        float expected = i * 32 / 32768.f; // Eight .5-gain voices, .5 master and effects.
        CHECK(out[i * 2] == expected && out[i * 2 + 1] == expected);
    }
    gna_set_paused(a, 1);
    gna_mix(a, out, 64, 4000);
    silence(out, 128);
    gna_set_paused(a, 0);
    gna_mix(a, out, 64, 0);
    silence(out, 128);
    gna_mix(a, out, 64, 4000);
    CHECK(out[0] == 128 * 16 / 32768.f); // Neither silence call advanced the voices.
    gna_stop_effects(a);
    for (int i = 0; i < GNA_VOICE_COUNT; i++)
        CHECK(gna_play(a, 1, 1));
    CHECK(!gna_play(a, 0, 1)); // All voices are protected.
    gna_mix(a, out, 240, 8000);
    CHECK(gna_active_voices(a) == 0); // Per-clip duration, including fade-out.
    gna_stop_effects(a);
    for (int i = 0; i < GNA_VOICE_COUNT + 10; i++)
        CHECK(gna_play(a, 0, 100));
    CHECK(gna_active_voices(a) == GNA_VOICE_COUNT);
    gna_mix(a, out, 64, 8000);
    CHECK(out[126] == 1);
    for (int i = 0; i < 128; i++)
        CHECK(isfinite(out[i]) && fabsf(out[i]) <= 1);
    gna_stop_effects(a);
    gna_set_volume(a, 1, 0, 1);
    CHECK(gna_play(a, 0, 1));
    gna_mix(a, reference, 64, 8000);
    gna_stop_effects(a);
    CHECK(gna_play(a, 0, 1));
    gna_mix(a, out, 64, 8000);
    CHECK(memcmp(out, reference, sizeof reference) == 0);
    gna_set_volume(a, 0, 1, 1);
    gna_mix(a, out, 64, 8000);
    silence(out, 128);
    gna_destroy(a);
    clips[1].path = TEST_BINARY_DIR "/missing-audio.wav";
    CHECK(!gna_create(clips, 2, NULL, error, sizeof error) && error[0]); // Partial-load cleanup.
    CHECK(!gna_create(NULL, 1, NULL, error, sizeof error));
    CHECK(!gna_create(clips, 1, clips[1].path, error, sizeof error));
    clips[0].max_seconds = NAN;
    CHECK(!gna_create(clips, 1, NULL, error, sizeof error));
    gna_destroy(NULL);
    CHECK(remove(path) == 0);
    puts("audio API: eight voices, resampling, pause, trim, protection, stealing, clipping, mute, "
         "errors: passed");
}
static void test_assets_and_music(void) {
    GnaAudio *a = sound_bank_load(TEST_ASSET_ROOT);
    CHECK(a && gna_decoded_bytes(a) > 0);
    gna_set_volume(a, .65f, .28f, .65f);
    for (int i = 0; i < SOUND_COUNT; i++)
        CHECK(gna_play(a, i, .5f));
    float out[2048];
    gna_mix(a, out, 1024, 48000);
    CHECK(gna_active_voices(a) == SOUND_COUNT);
    float peak = 0;
    for (int i = 0; i < 2048; i++) {
        CHECK(isfinite(out[i]) && fabsf(out[i]) <= 1);
        peak = fmaxf(peak, fabsf(out[i]));
    }
    CHECK(peak > .001f);
    gna_destroy(a);
    char error[256];
    a = gna_create(NULL, 0, TEST_ASSET_ROOT "/audio/music.mp3", error, sizeof error);
    CHECK(a);
    const uint64_t frames = gna_decoded_bytes(a) / (GNA_CHANNELS * sizeof(float));
    float beginning[20];
    gna_mix(a, beginning, 10, 44100);
    uint64_t remaining = frames - 10;
    while (remaining) {
        uint32_t n = remaining < 1024 ? (uint32_t)remaining : 1024;
        gna_mix(a, out, n, 44100);
        remaining -= n;
    }
    gna_mix(a, out, 10, 44100);
    CHECK(memcmp(beginning, out, sizeof beginning) == 0);
    gna_destroy(a);
    puts("real game assets, overlapping effects and music, complete MP3 loop: passed");
}
int main(void) {
    test_mixer();
    test_assets_and_music();
    return 0;
}
