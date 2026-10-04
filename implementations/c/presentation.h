#ifndef GNARLAXX_PRESENTATION_H
#define GNARLAXX_PRESENTATION_H
#include "game.h"
#include "scores.h"
void presentation_draw(const Game *game, const Scores *scores, bool save_failed,
                       bool audio_available);
#endif
