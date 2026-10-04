#ifndef GNA_AUDIO_H
#define GNA_AUDIO_H
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// All calls belong to the application's main thread. No game or Sokol types cross this API.
typedef struct GnaAudio GnaAudio;
enum { GNA_VOICE_COUNT = 24, GNA_CHANNELS = 2 };
typedef struct GnaSoundDesc {
    const char *path;        // Mono WAV; read during create, never retained.
    double max_seconds;      // Zero plays the entire clip; positive values trim it.
    int32_t protected_voice; // Nonzero prevents voice stealing (e.g. spoken dialogue).
} GnaSoundDesc;

// Owns decoded samples until destroy. Music is optional stereo MP3 and loops.
// Returns NULL on failure, releasing partial allocations; error receives a diagnostic.
GnaAudio *gna_create(const GnaSoundDesc *sounds, uint32_t count, const char *music_path,
                     char *error, size_t error_capacity);
void gna_destroy(GnaAudio *audio); // NULL is allowed; closes its device if open.
void gna_set_volume(GnaAudio *audio, float master, float music,
                    float effects); // [0,1], defaults 1.
void gna_set_paused(GnaAudio *audio, int32_t paused);
int32_t gna_play(GnaAudio *audio, uint32_t sound, float gain); // Descriptor index; 0 if rejected.
void gna_stop_effects(GnaAudio *audio);
uint64_t gna_decoded_bytes(const GnaAudio *audio);
uint32_t gna_active_voices(const GnaAudio *audio);

// Device-independent mixer, useful for testing or another output backend.
// Writes frames * GNA_CHANNELS floats. Paused/invalid-rate mixing writes silence without advancing.
void gna_mix(GnaAudio *audio, float *stereo, uint32_t frames, uint32_t sample_rate);

// Optional Sokol push output. One open device per process. Failure leaves the mixer usable.
// Call pump once per application frame; don't also call mix while using this device.
int32_t gna_device_open(GnaAudio *audio);
void gna_device_close(GnaAudio *audio);
int32_t gna_device_pump(GnaAudio *audio);
uint32_t gna_device_rate(const GnaAudio *audio); // Zero if this context has no open device.

#ifdef __cplusplus
}
#endif
#endif
