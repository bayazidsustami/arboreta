/*
 * Git Audio-Visual Synthesizer
 * ----------------------------
 * Parses a Git repository's commit history using popen and synthesizes:
 * 1. An organic fractal tree rendered in full 24-bit color ANSI terminal graphics.
 *    - Insertions grow and flourish vibrant green/gold branches.
 *    - Deletions wither and prune branches into muted red/ash wood.
 *    - Files changed mutate branch angle distribution and complexity.
 * 2. An ambient FM/additive soundscape streamed live to system audio (aplay/paplay).
 *    - Pitch, harmonics, and dissonance dynamically respond to commit metrics.
 */

#define _POSIX_C_SOURCE 200809L
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#define WIDTH 100
#define HEIGHT 40
#define MAX_COMMITS 256
#define SAMPLE_RATE 22050
#define PI 3.14159265358979323846f

typedef struct {
    char hash[8];
    int insertions;
    int deletions;
    int files_changed;
    float energy;
} Commit;

typedef struct {
    char ch;
    unsigned char r, g, b;
} Pixel;

static Pixel canvas[HEIGHT][WIDTH];
static float audio_phase[4] = {0.0f, 0.0f, 0.0f, 0.0f};
static float delay_buf[4410]; // 200ms delay/reverb buffer
static int delay_pos = 0;

/* Clear canvas buffer with deep ambient background color */
static void clear_canvas(void) {
    for (int y = 0; y < HEIGHT; y++) {
        for (int x = 0; x < WIDTH; x++) {
            canvas[y][x].ch = ' ';
            canvas[y][x].r = 10;
            canvas[y][x].g = 12;
            canvas[y][x].b = 22;
        }
    }
}

/* Safely place character and color at canvas grid location */
static void set_pixel(int x, int y, char ch, unsigned char r, unsigned char g, unsigned char b) {
    if (x >= 0 && x < WIDTH && y >= 0 && y < HEIGHT) {
        canvas[y][x].ch = ch;
        canvas[y][x].r = r;
        canvas[y][x].g = g;
        canvas[y][x].b = b;
    }
}

/* Bresenham's line algorithm for drawing fractal branches */
static void draw_line(int x0, int y0, int x1, int y1, char ch, unsigned char r, unsigned char g, unsigned char b) {
    int dx = abs(x1 - x0), sx = x0 < x1 ? 1 : -1;
    int dy = -abs(y1 - y0), sy = y0 < y1 ? 1 : -1;
    int err = dx + dy, e2;

    while (1) {
        set_pixel(x0, y0, ch, r, g, b);
        if (x0 == x1 && y0 == y1) break;
        e2 = 2 * err;
        if (e2 >= dy) { err += dy; x0 += sx; }
        if (e2 <= dx) { err += dx; y0 += sy; }
    }
}

/* Recursive fractal tree generator driven by code commit statistics */
static void draw_branch(float x, float y, float angle, float length, int depth, const Commit *c) {
    if (depth <= 0 || length < 0.8f) return;

    float x2 = x + cosf(angle) * length;
    float y2 = y + sinf(angle) * length;

    // Determine color shift: green/gold (growth) vs crimson/ash (deletions)
    float total_diff = (float)(c->insertions + c->deletions + 1);
    float growth_ratio = (float)c->insertions / total_diff;

    unsigned char r = (unsigned char)((1.0f - growth_ratio) * 230.0f + depth * 10);
    unsigned char g = (unsigned char)(growth_ratio * 220.0f + 35);
    unsigned char b = (unsigned char)(80 + (c->files_changed * 25) % 150);

    // Pick branch texture character
    char symbol = (depth > 4) ? '|' : ((depth > 2) ? '/' : '*');
    if (growth_ratio < 0.35f && depth <= 2) symbol = '~'; // Withered twig symbol

    draw_line((int)x, (int)y, (int)x2, (int)y2, symbol, r, g, b);

    // Mutation & angle perturbation based on commit hash
    float spread = 0.42f + (c->files_changed % 5) * 0.07f;
    float decay = 0.74f - (c->deletions > 40 ? 0.08f : 0.0f);
    float hash_mutation = ((c->hash[0] % 11) - 5) * 0.025f;

    // Spawn sub-branches
    draw_branch(x2, y2, angle - spread + hash_mutation, length * decay, depth - 1, c);
    draw_branch(x2, y2, angle + spread + hash_mutation, length * decay, depth - 1, c);

    // Extra sprout for heavy additions
    if (c->insertions > 25 && depth > 2) {
        draw_branch(x2, y2, angle + hash_mutation * 2.0f, length * 0.55f, depth - 2, c);
    }
}

/* Display terminal buffer using ANSI escape sequences */
static void render_terminal(void) {
    printf("\033[H");
    for (int y = 0; y < HEIGHT; y++) {
        for (int x = 0; x < WIDTH; x++) {
            Pixel p = canvas[y][x];
            printf("\033[38;2;%d;%d;%dm%c", p.r, p.g, p.b, p.ch);
        }
        printf("\n");
    }
    fflush(stdout);
}

/* Synthesize ambient audio buffer and stream to external audio pipeline */
static void generate_ambient_audio(FILE *audio_pipe, const Commit *c, int samples) {
    if (!audio_pipe) return;

    // Frequency root mapped to files changed; pentatonic ratios map harmony
    float base_freq = 110.0f + (c->files_changed % 8) * 27.5f;
    float chord_ratios[4] = { 1.0f, 1.25f, 1.5f, 1.875f };

    // Shift to minor/dissonant intervals if deletions dominate
    if (c->deletions > c->insertions) {
        chord_ratios[1] = 1.20f;  // Minor third
        chord_ratios[3] = 1.6875f;
    }

    short pcm_buffer[512];
    int buf_idx = 0;

    for (int i = 0; i < samples; i++) {
        float mix = 0.0f;

        // Additive FM harmonic drone
        for (int osc = 0; osc < 4; osc++) {
            float freq = base_freq * chord_ratios[osc];
            audio_phase[osc] += (2.0f * PI * freq) / SAMPLE_RATE;
            if (audio_phase[osc] >= 2.0f * PI) audio_phase[osc] -= 2.0f * PI;

            float mod = sinf(audio_phase[(osc + 1) % 4] * 0.5f) * 0.25f;
            mix += sinf(audio_phase[osc] + mod) * 0.12f;
        }

        // Reverb / delay feedback
        delay_buf[delay_pos] = mix + delay_buf[delay_pos] * 0.45f;
        mix += delay_buf[delay_pos] * 0.35f;
        delay_pos = (delay_pos + 1) % 4410;

        pcm_buffer[buf_idx++] = (short)(mix * 14000.0f * c->energy);

        if (buf_idx >= 512) {
            fwrite(pcm_buffer, sizeof(short), buf_idx, audio_pipe);
            buf_idx = 0;
        }
    }
    if (buf_idx > 0) {
        fwrite(pcm_buffer, sizeof(short), buf_idx, audio_pipe);
    }
}

/* Extract real Git commit history or build fallback synthetic commits */
static int parse_git_history(Commit *commits) {
    FILE *fp = popen("git log --pretty=format:'%h' --shortstat 2>/dev/null", "r");
    int count = 0;

    if (fp) {
        char line[256];
        char current_hash[8] = "0000000";

        while (fgets(line, sizeof(line), fp) && count < MAX_COMMITS) {
            if (strlen(line) >= 7 && strchr(line, ' ') == NULL && strchr(line, ',') == NULL) {
                strncpy(current_hash, line, 7);
                current_hash[7] = '\0';
            } else if (strstr(line, "changed") || strstr(line, "insertion") || strstr(line, "deletion")) {
                int files = 0, ins = 0, del = 0;
                char *p_files = strstr(line, "file");
                char *p_ins = strstr(line, "insertion");
                char *p_del = strstr(line, "deletion");

                if (p_files) sscanf(line, "%d", &files);
                if (p_ins) {
                    char *sub = p_files ? p_files : line;
                    sscanf(sub, "%*[^0-9]%d", &ins);
                }
                if (p_del) {
                    char *sub = p_ins ? p_ins : (p_files ? p_files : line);
                    sscanf(sub, "%*[^0-9]%d", &del);
                }

                strncpy(commits[count].hash, current_hash, 8);
                commits[count].files_changed = files > 0 ? files : 1;
                commits[count].insertions = ins;
                commits[count].deletions = del;
                commits[count].energy = 0.5f + (ins + del) / 200.0f;
                if (commits[count].energy > 1.0f) commits[count].energy = 1.0f;
                count++;
            }
        }
        pclose(fp);
    }

    // Fallback pseudo-history if git is unavailable or repo is empty
    if (count == 0) {
        srand((unsigned int)time(NULL));
        count = 32;
        for (int i = 0; i < count; i++) {
            snprintf(commits[i].hash, 8, "%07x", rand() % 0xFFFFFF);
            commits[i].insertions = rand() % 90 + 5;
            commits[i].deletions = (rand() % 100 < 35) ? (rand() % 70 + 5) : (rand() % 8);
            commits[i].files_changed = rand() % 7 + 1;
            commits[i].energy = 0.5f + (rand() % 50) / 100.0f;
        }
    }
    return count;
}

int main(void) {
    Commit commits[MAX_COMMITS];
    int total_commits = parse_git_history(commits);

    // Audio output pipe targeting Linux (aplay) or macOS/Pulse (paplay)
    FILE *audio_pipe = popen("aplay -q -f S16_LE -r 22050 -c 1 2>/dev/null || "
                             "paplay --raw --channels=1 --rate=22050 --format=s16le 2>/dev/null", "w");

    // Hide terminal cursor and clear screen
    printf("\033[?25l\033[2J");

    int commit_idx = 0;

    while (1) {
        const Commit *c = &commits[commit_idx];

        clear_canvas();

        // Calculate dynamic tree parameters
        float trunk_len = 9.5f + (c->files_changed * 0.7f);
        int max_depth = 4 + (c->insertions / 18);
        if (max_depth > 8) max_depth = 8;

        // Render generative fractal tree from screen bottom
        draw_branch(WIDTH / 2.0f, HEIGHT - 2.0f, -PI / 2.0f, trunk_len, max_depth, c);

        // Header status overlay
        char status[128];
        snprintf(status, sizeof(status), "[Commit %d/%d | Hash: %s]  +%d  -%d  (%d files modified)",
                 commit_idx + 1, total_commits, c->hash, c->insertions, c->deletions, c->files_changed);
        for (int i = 0; status[i] != '\0' && i < WIDTH - 4; i++) {
            set_pixel(2 + i, 1, status[i], 180, 220, 255);
        }

        render_terminal();
        generate_ambient_audio(audio_pipe, c, SAMPLE_RATE / 4); // 250ms audio chunk per step

        usleep(250000); // 250ms per frame tick
        commit_idx = (commit_idx + 1) % total_commits;
    }

    if (audio_pipe) pclose(audio_pipe);
    printf("\033[?25h\n"); // Restore cursor
    return 0;
}