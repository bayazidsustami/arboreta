#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAXLEN 1024   // maximum cells per generation

/* Simple 1‑dimensional cellular automaton (Rule 30)
 * '.' = dead cell, '#' = alive cell
 * The automaton wraps around (periodic boundary).
 */

static void next_gen(const char *cur, char *next, int n) {
    for (int i = 0; i < n; ++i) {
        // neighbourhood bits: left, center, right
        int l = cur[(i - 1 + n) % n] == '#';
        int c = cur[i] == '#';
        int r = cur[(i + 1) % n] == '#';
        int idx = (l << 2) | (c << 1) | r;   // 0..7
        // Rule 30 table (binary 00011110)
        next[i] = (idx == 0 || idx == 1 || idx == 2 || idx == 7) ? '.' : '#';
    }
    next[n] = '\0';
}

/* Initialise with a single live cell in the centre */
static void init_state(char *buf, int n) {
    memset(buf, '.', n);
    buf[n / 2] = '#';
    buf[n] = '\0';
}

int main(int argc, char *argv[]) {
    if (argc != 3) {
        fprintf(stderr, "Usage: %s <cells> <generations>\n", argv[0]);
        return EXIT_FAILURE;
    }

    int cells = atoi(argv[1]);
    int gens  = atoi(argv[2]);
    if (cells <= 0 || cells > MAXLEN || gens < 0) {
        fprintf(stderr, "Invalid parameters.\n");
        return EXIT_FAILURE;
    }

    char *cur  = malloc(cells + 1);
    char *next = malloc(cells + 1);
    if (!cur || !next) {
        perror("malloc");
        return EXIT_FAILURE;
    }

    init_state(cur, cells);
    printf("%s\n", cur);

    for (int g = 0; g < gens; ++g) {
        next_gen(cur, next, cells);
        printf("%s\n", next);
        char *tmp = cur; cur = next; next = tmp;
    }

    free(cur);
    free(next);
    return EXIT_SUCCESS;
}