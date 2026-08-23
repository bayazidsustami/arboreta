#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>
#include <unistd.h>

#define MAX_COMMITS 128
#define WIDTH 100
#define HEIGHT 40
#define PI 3.14159265358979323846

typedef struct {
    char hash[8];
    char message[256];
    float x, y;          // Constellation map coordinates
    float brightness;   // Based on message length / activity
    float hue_angle;    // Tone: 0 = Joy/Warm, PI/2 = Energy, PI = Neutral, 3PI/2 = Frustration/Fix
    int syntax_complexity; // Number of clauses, punctuation, or structural complexity
} CommitStar;

typedef struct {
    int star1_idx;
    int star2_idx;
    float tension;      // Line curvature / intensity driven by linguistic tone comparison
    char char_trail;    // Visual character used for light trail
} LightTrail;

CommitStar stars[MAX_COMMITS];
LightTrail trails[MAX_COMMITS * 2];
int star_count = 0;
int trail_count = 0;

// Simple sentiment and linguistic syntax analyzer for commit messages
void analyze_commit_tone(const char *msg, float *hue, float *brightness, int *complexity) {
    int len = strlen(msg);
    int exclamations = 0, questions = 0, uppercase = 0, words = 0;
    
    // Tone markers
    int fix_keywords = 0;   // Frustration / Patching
    int feat_keywords = 0;  // Excitement / Joy / Creation
    
    if (strstr(msg, "fix") || strstr(msg, "bug") || strstr(msg, "error") || strstr(msg, "patch")) fix_keywords++;
    if (strstr(msg, "feat") || strstr(msg, "add") || strstr(msg, "create") || strstr(msg, "init")) feat_keywords++;

    for (int i = 0; i < len; i++) {
        if (msg[i] == '!') exclamations++;
        if (msg[i] == '?') questions++;
        if (msg[i] >= 'A' && msg[i] <= 'Z') uppercase++;
        if (msg[i] == ' ' || msg[i] == '\t') words++;
    }

    // Assign Hue Angle based on emotional spectrum
    if (fix_keywords > 0) {
        *hue = 4.71f; // ~270 deg (Deep Violet/Blue - Frustration/Fix)
    } else if (feat_keywords > 0) {
        *hue = 0.78f; // ~45 deg (Gold/Warm - Creation)
    } else if (exclamations > 0 || uppercase > 3) {
        *hue = 0.0f;  // Red/Orange (Urgent/Energetic)
    } else {
        *hue = 3.14f; // Cyan/Green (Neutral/Stable)
    }

    *brightness = 0.4f + (float)(len % 50) / 80.0f + (exclamations * 0.2f);
    if (*brightness > 1.0f) *brightness = 1.0f;

    // Syntax complexity based on word count, punctuation, and clause structure
    *complexity = (words / 3) + (exclamations * 2) + (questions * 2) + 1;
}

// Read recent git commit log directly using pipe
void fetch_git_commits() {
    FILE *fp = popen("git log -n 30 --pretty=format:\"%h|%s\" 2>/dev/null", "r");
    char line[320];

    // Fallback dummy commits if not in a git repo
    if (!fp || fgets(line, sizeof(line), fp) == NULL) {
        const char *dummy_log[] = {
            "a1b2c3d|feat: add dark ambient visual engine core",
            "e5f6g7h|fix: resolve memory leak in light trail render cycle!",
            "i9j0k1l|docs: update constellation mapping documentation",
            "m2n3o4p|refactor: clean up tone sentiment evaluation",
            "q5r6s7t|style: tweak brightness levels for star nodes",
            "u8v9w0x|fix: critical crash on null git commit message parsing!!!",
            "y1z2a3b|feat: render live generative galaxy projection"
        };
        int dummy_count = sizeof(dummy_log) / sizeof(dummy_log[0]);
        for (int i = 0; i < dummy_count; i++) {
            char hash[16], msg[256];
            sscanf(dummy_log[i], "%[^|]|%[^\n]", hash, msg);
            strcpy(stars[star_count].hash, hash);
            strcpy(stars[star_count].message, msg);
            star_count++;
        }
    } else {
        do {
            char hash[16] = {0}, msg[256] = {0};
            if (sscanf(line, "%15[^|]|%255[^\n]", hash, msg) == 2) {
                strncpy(stars[star_count].hash, hash, 7);
                stars[star_count].hash[7] = '\0';
                strncpy(stars[star_count].message, msg, 255);
                star_count++;
            }
        } while (fgets(line, sizeof(line), fp) && star_count < MAX_COMMITS);
        pclose(fp);
    }

    // Map stars into 2D celestial space based on hash and message properties
    for (int i = 0; i < star_count; i++) {
        analyze_commit_tone(stars[i].message, &stars[i].hue_angle, &stars[i].brightness, &stars[i].syntax_complexity);

        // Derive spatial position pseudo-randomly from hash determinism
        unsigned int hash_val = 0;
        for (int j = 0; stars[i].hash[j]; j++) hash_val = hash_val * 31 + stars[i].hash[j];

        stars[i].x = 5.0f + (hash_val % (WIDTH - 10));
        stars[i].y = 3.0f + ((hash_val / 100) % (HEIGHT - 6));
    }

    // Build light trails between syntactically or emotionally connected stars
    for (int i = 0; i < star_count; i++) {
        for (int j = i + 1; j < star_count; j++) {
            float dx = stars[i].x - stars[j].x;
            float dy = stars[i].y - stars[j].y;
            float dist = sqrtf(dx * dx + dy * dy);

            // Connect stars that are close in distance or share similar tone angles
            if (dist < 22.0f && fabs(stars[i].hue_angle - stars[j].hue_angle) < 1.5f) {
                trails[trail_count].star1_idx = i;
                trails[trail_count].star2_idx = j;
                trails[trail_count].tension = dist / 22.0f;
                
                // Trail light character reflects joint linguistic complexity
                int total_complexity = stars[i].syntax_complexity + stars[j].syntax_complexity;
                if (total_complexity > 8) trails[trail_count].char_trail = '=';
                else if (total_complexity > 5) trails[trail_count].char_trail = '~';
                else trails[trail_count].char_trail = '-';

                trail_count++;
            }
        }
    }
}

// Render the celestial field in terminal using ANSI colors
void render_constellation(float time_tick) {
    char buffer[HEIGHT][WIDTH];
    int color_map[HEIGHT][WIDTH];

    // Clear canvas
    for (int y = 0; y < HEIGHT; y++) {
        for (int x = 0; x < WIDTH; x++) {
            buffer[y][x] = ' ';
            color_map[y][x] = 0;
        }
    }

    // Render light trails (Bresenham's line algorithm with wave modulation)
    for (int i = 0; i < trail_count; i++) {
        CommitStar s1 = stars[trails[i].star1_idx];
        CommitStar s2 = stars[trails[i].star2_idx];

        int x0 = (int)s1.x, y0 = (int)s1.y;
        int x1 = (int)s2.x, y1 = (int)s2.y;

        int dx = abs(x1 - x0), sx = x0 < x1 ? 1 : -1;
        int dy = -abs(y1 - y0), sy = y0 < y1 ? 1 : -1;
        int err = dx + dy, e2;

        int step = 0;
        while (1) {
            if (x0 >= 0 && x0 < WIDTH && y0 >= 0 && y0 < HEIGHT) {
                if (buffer[y0][x0] == ' ') {
                    // Pulsing light pulse along the connector trail
                    float wave = sinf(time_tick * 3.0f + step * 0.4f);
                    buffer[y0][x0] = wave > 0.3f ? trails[i].char_trail : '.';
                    color_map[y0][x0] = 36; // Cyan path color
                }
            }
            if (x0 == x1 && y0 == y1) break;
            e2 = 2 * err;
            if (e2 >= dy) { err += dy; x0 += sx; }
            if (e2 <= dx) { err += dx; y0 += sy; }
            step++;
        }
    }

    // Render commit stars
    for (int i = 0; i < star_count; i++) {
        int sx = (int)stars[i].x;
        int sy = (int)stars[i].y;

        if (sx >= 0 && sx < WIDTH && sy >= 0 && sy < HEIGHT) {
            // Pulse star core luminosity
            float pulse = sinf(time_tick * 2.0f + i) * 0.2f;
            float lum = stars[i].brightness + pulse;

            if (lum > 0.8f) buffer[sy][sx] = '*';
            else if (lum > 0.5f) buffer[sy][sx] = '+';
            else buffer[sy][sx] = '.';

            // Map hue angle to ANSI 256 colors
            if (stars[i].hue_angle < 1.0f) color_map[sy][sx] = 208;      // Warm Gold / Orange
            else if (stars[i].hue_angle < 3.2f) color_map[sy][sx] = 82;  // Emerald Green
            else color_map[sy][sx] = 135;                               // Soft Purple / Magenta
        }
    }

    // Output to screen
    printf("\033[H"); // Reset cursor to top-left
    printf("=== LIVE GIT COMMIT GENERATIVE CONSTELLATION MAP ===\n");
    printf("Stars: %d | Light Trails: %d | [Yellow=Feat, Green=Neutral, Purple=Fix]\n\n", star_count, trail_count);

    for (int y = 0; y < HEIGHT; y++) {
        for (int x = 0; x < WIDTH; x++) {
            if (color_map[y][x] != 0) {
                printf("\033[38;5;%dm%c\033[0m", color_map[y][x], buffer[y][x]);
            } else {
                putchar(buffer[y][x]);
            }
        }
        putchar('\n');
    }

    // Legend stream of active commits
    printf("\nRecent Celestial Commit Nodes:\033[2K\n");
    int active_idx = ((int)(time_tick * 0.8f)) % star_count;
    printf(" -> Node [%s] Tone Angle: %.2f rad | Msg: \"%s\"\033[K\n",
           stars[active_idx].hash, stars[active_idx].hue_angle, stars[active_idx].message);
}

int main() {
    srand((unsigned int)time(NULL));
    
    // Hide terminal cursor and clear screen
    printf("\033[?25l\033[2J");

    fetch_git_commits();

    float time_tick = 0.0f;
    for (int frame = 0; frame < 300; frame++) { // Run live animation loop
        render_constellation(time_tick);
        fflush(stdout);
        usleep(100000); // 100ms frame time (~10 FPS)
        time_tick += 0.1f;
    }

    // Restore terminal cursor
    printf("\033[?25h\n");
    return 0;
}