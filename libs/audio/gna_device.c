#include "gna_audio.h"
#define SOKOL_AUDIO_IMPL
#include "sokol_audio.h"
#include <stdio.h>

static GnaAudio *device_owner;

static void log_audio(const char *tag, uint32_t level, uint32_t item, const char *message,
                      uint32_t line, const char *file, void *user) {
    (void)level;
    (void)item;
    (void)line;
    (void)file;
    (void)user;
    fprintf(stderr, "%s: %s\n", tag, message ? message : "audio backend error");
}
int32_t gna_device_open(GnaAudio *a) {
    if (!a || device_owner)
        return 0;
    saudio_setup(&(saudio_desc){.sample_rate = 44100,
                                .num_channels = GNA_CHANNELS,
                                .buffer_frames = 512,
                                .packet_frames = 128,
                                .num_packets = 16,
                                .logger.func = log_audio});
    if (!saudio_isvalid() || saudio_channels() != GNA_CHANNELS) {
        saudio_shutdown();
        return 0;
    }
    device_owner = a;
    return 1;
}
void gna_device_close(GnaAudio *a) {
    if (a && device_owner == a) {
        saudio_shutdown();
        device_owner = NULL;
    }
}
uint32_t gna_device_rate(const GnaAudio *a) {
    return a && device_owner == a ? (uint32_t)saudio_sample_rate() : 0;
}
int32_t gna_device_pump(GnaAudio *a) {
    if (!a || device_owner != a)
        return 0;
    enum { MIX_FRAMES = 1024 };
    float buffer[MIX_FRAMES * GNA_CHANNELS];
    int remaining = saudio_expect();
    while (remaining > 0) {
        int n = remaining > MIX_FRAMES ? MIX_FRAMES : remaining;
        gna_mix(a, buffer, (uint32_t)n, (uint32_t)saudio_sample_rate());
        if (saudio_push(buffer, n) != n)
            return 0;
        remaining -= n;
    }
    return 1;
}
