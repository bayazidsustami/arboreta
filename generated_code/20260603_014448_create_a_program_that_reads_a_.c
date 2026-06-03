#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <unistd.h>
#include <time.h>

/* Simple 3‑D L‑system point generator.
   Each unique hashtag gets a deterministic 3‑D coordinate
   derived from a 32‑bit FNV‑1a hash.                     */
typedef struct {
    unsigned int id;      /* hash of the tag            */
    double      x, y, z;  /* position in 3‑D space      */
    int         cnt;      /* occurrence count           */
    double      sentiment;/* mock sentiment (-1..1)    */
} Node;

/* Very small hash table (power of two) */
#define HTSIZE 1024
static Node *htable[HTSIZE];

/* FNV‑1a 32‑bit hash */
static unsigned int fnv1a(const char *s)
{
    unsigned int h = 2166136261U;
    while (*s) {
        h ^= (unsigned char)*s++;
        h *= 16777619U;
    }
    return h;
}

/* Retrieve or create a node for a hashtag */
static Node *get_node(const char *tag)
{
    unsigned int h = fnv1a(tag);
    unsigned int idx = h & (HTSIZE - 1);
    while (htable[idx]) {
        if (htable[idx]->id == h) {
            return htable[idx];
        }
        idx = (idx + 1) & (HTSIZE - 1);
    }
    Node *n = calloc(1, sizeof(Node));
    n->id = h;
    /* map hash to a point on a unit cube */
    n->x = ((h >>  0) & 0xFF) / 255.0;
    n->y = ((h >>  8) & 0xFF) / 255.0;
    n->z = ((h >> 16) & 0xFF) / 255.0;
    n->sentiment = ((h >> 24) & 0xFF) / 255.0 * 2.0 - 1.0; /* mock */
    htable[idx] = n;
    return n;
}

/* Convert 3‑D point to 2‑D screen coordinates (simple orthographic projection) */
static void project(double x, double y, double z, int *sx, int *sy, int w, int h)
{
    double scale = 2.0;
    *sx = (int)((x - 0.5) * scale * w) + w/2;
    *sy = (int)((y - 0.5) * scale * h) + h/2;
}

/* Generate a colour from sentiment (green=positive, red=negative) */
static void sentiment_color(double s, int *r, int *g, int *b)
{
    if (s < 0) {
        *r = 255;
        *g = (int)((1.0 + s) * 255);
    } else {
        *g = 255;
        *r = (int)((1.0 - s) * 255);
    }
    *b = 64;
}

/* Emit a short beep whose pitch depends on frequency */
static void play_tone(int freq)
{
    /* Use the PC speaker via the terminal bell.
       Frequency modulates the delay between toggles. */
    int period = 1000000 / freq; /* microseconds */
    for (int i = 0; i < 5; ++i) {
        putchar('\a'); /* beep */
        usleep(period);
    }
}

/* Main loop: read hashtags from stdin, update, render */
int main(void)
{
    const int WIDTH  = 80;
    const int HEIGHT = 24;
    char line[256];

    /* clear screen */
    printf("\033[2J");
    printf("\033[?25l"); /* hide cursor */

    while (fgets(line, sizeof(line), stdin)) {
        char *p = strtok(line, " \t\r\n");
        while (p) {
            if (p[0] == '#') {
                Node *n = get_node(p);
                n->cnt++;

                /* render */
                int sx, sy;
                project(n->x, n->y, n->z, &sx, &sy, WIDTH, HEIGHT);
                if (sx >= 0 && sx < WIDTH && sy >= 0 && sy < HEIGHT) {
                    int r,g,b;
                    sentiment_color(n->sentiment, &r,&g,&b);
                    printf("\033[%d;%dH\033[38;2;%d;%d;%dm#\033[0m", sy+1, sx+1, r,g,b);
                    fflush(stdout);
                }

                /* sonify: pitch proportional to count */
                int pitch = 200 + (n->cnt % 20) * 30;
                play_tone(pitch);
            }
            p = strtok(NULL, " \t\r\n");
        }
        /* simple decay visual effect */
        usleep(50000);
    }

    /* restore cursor */
    printf("\033[?25h");
    printf("\n");
    return 0;
}