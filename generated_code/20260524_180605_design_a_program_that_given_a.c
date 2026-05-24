#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <SDL2/SDL.h>

/* Simple mandala visualiser.
 * Each line of input becomes a petal; the petal angle is proportional
 * to the line's syllable count (estimated by vowel groups).
 * A reversible Befunge program representing the poem is generated
 * and re‑executed each frame (simulated by reinterpretation of the string).
 * The program rewires itself by rotating the Befunge code matrix.
 */

#define WIN_W 800
#define WIN_H 600
#define MAX_LINES 64
#define MAX_LINE_LEN 256
#define BEFUNGE_SIZE 20

typedef struct {
    char text[MAX_LINE_LEN];
    int syllables;
} Line;

static Line poem[MAX_LINES];
static int line_cnt = 0;

/* Very naive syllable estimator: count vowel groups */
static int estimate_syllables(const char *s) {
    int cnt = 0;
    int in_vowel = 0;
    while (*s) {
        char c = tolower(*s);
        int is_vowel = (c=='a'||c=='e'||c=='i'||c=='o'||c=='u');
        if (is_vowel && !in_vowel) {
            cnt++;
            in_vowel = 1;
        } else if (!is_vowel) {
            in_vowel = 0;
        }
        s++;
    }
    if (cnt==0) cnt = 1;
    return cnt;
}

/* Build a tiny Befunge program that pushes each line length */
static void build_befunge(char code[BEFUNGE_SIZE][BEFUNGE_SIZE]) {
    memset(code, ' ', sizeof(char)*BEFUNGE_SIZE*BEFUNGE_SIZE);
    int x = 0, y = 0, dir = 0; /* 0=right,1=down,2=left,3=up */
    for (int i=0;i<line_cnt;i++) {
        int n = (int)strlen(poem[i].text) % 10; /* push digit */
        code[y][x] = '0'+n;
        x++;                     /* move right */
        if (x>=BEFUNGE_SIZE) { x=0; y = (y+1)%BEFUNGE_SIZE; }
        code[y][x] = '+';        /* add to accumulator */
    }
    code[y][x] = '@';            /* end */
}

/* Simulate a single step of Befunge (very limited) */
static int simulate_befunge(char code[BEFUNGE_SIZE][BEFUNGE_SIZE]) {
    int ipx=0, ipy=0, dir=0, acc=0;
    for (int steps=0; steps<1000; steps++) {
        char c = code[ipy][ipx];
        if (c>='0' && c<='9') acc += c-'0';
        else if (c=='+') acc += 1;
        else if (c=='@') break;
        /* move */
        if (dir==0) ipx = (ipx+1)%BEFUNGE_SIZE;
        else if (dir==1) ipy = (ipy+1)%BEFUNGE_SIZE;
        else if (dir==2) ipx = (ipx-1+BEFUNGE_SIZE)%BEFUNGE_SIZE;
        else ipy = (ipy-1+BEFUNGE_SIZE)%BEFUNGE_SIZE;
    }
    return acc; /* used to colour the mandala */
}

/* Draw a petal for a line */
static void draw_petal(SDL_Renderer *ren, int cx, int cy, double angle, double radius, SDL_Color col) {
    const int SEG = 30;
    double a0 = angle - M_PI/12;
    double a1 = angle + M_PI/12;
    for (int i=0;i<SEG;i++) {
        double t0 = (double)i/SEG;
        double t1 = (double)(i+1)/SEG;
        double r0 = radius * (1 - t0*t0);
        double r1 = radius * (1 - t1*t1);
        double x0 = cx + r0*cos(a0 + (a1-a0)*t0);
        double y0 = cy + r0*sin(a0 + (a1-a0)*t0);
        double x1 = cx + r1*cos(a0 + (a1-a0)*t1);
        double y1 = cy + r1*sin(a0 + (a1-a0)*t1);
        SDL_SetRenderDrawColor(ren, col.r, col.g, col.b, 255);
        SDL_RenderDrawLine(ren, (int)x0,(int)y0,(int)x1,(int)y1);
    }
}

/* Main loop: read poem, render, regenerate Befunge */
int main(void) {
    char linebuf[MAX_LINE_LEN];
    printf("Enter poem (empty line to finish):\n");
    while (line_cnt < MAX_LINES && fgets(linebuf, sizeof(linebuf), stdin)) {
        size_t l = strlen(linebuf);
        if (l && linebuf[l-1]=='\n') linebuf[--l]=0;
        if (l==0) break;
        strncpy(poem[line_cnt].text, linebuf, MAX_LINE_LEN);
        poem[line_cnt].syllables = estimate_syllables(linebuf);
        line_cnt++;
    }
    if (SDL_Init(SDL_INIT_VIDEO) != 0) { fprintf(stderr,"SDL error: %s\n",SDL_GetError()); return 1; }
    SDL_Window *win = SDL_CreateWindow("Poetic Mandala",SDL_WINDOWPOS_CENTERED,SDL_WINDOWPOS_CENTERED,WIN_W,WIN_H,0);
    SDL_Renderer *ren = SDL_CreateRenderer(win,-1,SDL_RENDERER_ACCELERATED);
    int quit = 0;
    SDL_Event e;
    while (!quit) {
        while (SDL_PollEvent(&e)) {
            if (e.type==SDL_QUIT) quit=1;
            if (e.type==SDL_KEYDOWN && e.key.keysym.sym==SDLK_r) { /* rewrite mode */
                line_cnt=0;
                printf("\nRewrite poem (empty line to finish):\n");
                while (line_cnt < MAX_LINES && fgets(linebuf, sizeof(linebuf), stdin)) {
                    size_t l = strlen(linebuf);
                    if (l && linebuf[l-1]=='\n') linebuf[--l]=0;
                    if (l==0) break;
                    strncpy(poem[line_cnt].text, linebuf, MAX_LINE_LEN);
                    poem[line_cnt].syllables = estimate_syllables(linebuf);
                    line_cnt++;
                }
            }
        }
        char befunge[BEFUNGE_SIZE][BEFUNGE_SIZE];
        build_befunge(befunge);
        int acc = simulate_befunge(befunge); /* influences colour */
        SDL_SetRenderDrawColor(ren,30,30,30,255);
        SDL_RenderClear(ren);
        int cx=WIN_W/2, cy=WIN_H/2;
        double base_radius = 200.0;
        for (int i=0;i<line_cnt;i++) {
            double angle = 2*M_PI*i/line_cnt;
            double radius = base_radius * (1.0 + 0.5*sin(acc*0.1));
            SDL_Color col = { (Uint8)(50+acc*10%200), (Uint8)(80+i*30%200), (Uint8)(150+acc*5%200),255 };
            draw_petal(ren,cx,cy,angle,radius,col);
        }
        SDL_RenderPresent(ren);
        SDL_Delay(30);
    }
    SDL_DestroyRenderer(ren);
    SDL_DestroyWindow(win);
    SDL_Quit();
    return 0;
}