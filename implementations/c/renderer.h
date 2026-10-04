#ifndef GNARLAXX_RENDERER_H
#define GNARLAXX_RENDERER_H
#include "properties.h"
#include <stdbool.h>
#include <stdint.h>

// Colors are packed RRGGBBAA; sprite positions are top-left logical pixels.
bool renderer_init(const char *asset_root);
void renderer_shutdown(void);
void renderer_begin(void);
void renderer_sprite(Sprite sprite, float x, float y, float scale, uint32_t color);
void renderer_text(const char *text, float x, float y, int scale, uint32_t color);
void renderer_rect(float x, float y, float w, float h, uint32_t color);
void renderer_present(void);
bool renderer_capture(const char *path);
#endif
