#include "scores.h"
#include <ctype.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

bool scores_load(Scores *scores, const char *path) {
    *scores = (Scores){0};
    FILE *file = fopen(path, "r");
    if (!file)
        return false;
    Scores result = {0};
    char line[64];
    bool valid = false;
    if (!fgets(line, sizeof line, file) || strcmp(line, "GNARLAXX 1\n"))
        goto done;
    for (int i = 0; i < SCORE_COUNT; i++) {
        if (!fgets(line, sizeof line, file))
            goto done;
        char *end;
        errno = 0;
        long n = strtol(line, &end, 10);
        if (end == line || errno || n < 0 || n > 999999999)
            goto done;
        while (isspace((unsigned char)*end))
            end++;
        if (*end || (i && n > result.values[i - 1]))
            goto done;
        result.values[i] = (int)n;
    }
    int ch;
    while ((ch = fgetc(file)) != EOF)
        if (!isspace((unsigned char)ch))
            goto done;
    if (ferror(file))
        goto done;
    *scores = result;
    valid = true;
done:
    fclose(file);
    return valid;
}
void scores_insert(Scores *scores, int score) {
    if (score < 1 || score > 999999999)
        return;
    for (int i = 0; i < SCORE_COUNT; i++)
        if (score > scores->values[i]) {
            for (int j = SCORE_COUNT - 1; j > i; j--)
                scores->values[j] = scores->values[j - 1];
            scores->values[i] = score;
            break;
        }
}
bool scores_save(const Scores *scores, const char *path) {
    char tmp[2048];
    if (snprintf(tmp, sizeof tmp, "%s.tmp", path) >= (int)sizeof tmp)
        return false;
    FILE *file = fopen(tmp, "w");
    if (!file)
        return false;
    bool ok = fputs("GNARLAXX 1\n", file) >= 0;
    for (int i = 0; i < SCORE_COUNT; i++)
        if (fprintf(file, "%d\n", scores->values[i]) < 0)
            ok = false;
    if (fclose(file) != 0)
        ok = false;
    if (ok && rename(tmp, path) == 0)
        return true;
    remove(tmp);
    return false;
}
