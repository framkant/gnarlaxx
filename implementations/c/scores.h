#ifndef GNARLAXX_SCORES_H
#define GNARLAXX_SCORES_H
#include <stdbool.h>
enum { SCORE_COUNT = 5 };
typedef struct Scores {
    int values[SCORE_COUNT];
} Scores;
bool scores_load(Scores *scores, const char *path);
void scores_insert(Scores *scores, int score);
bool scores_save(const Scores *scores, const char *path);
#endif
