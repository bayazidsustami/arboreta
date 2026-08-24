#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <unistd.h>
#include <time.h>
#include <termios.h>
#include <sys/ioctl.h>
#include <sys/sysinfo.h>
#include <string.h>

#define M_PI 3.14159265358979323846

/* ASCII density spectrum for rendering stellar magnitude and twinkling */
static const char DENSITY_CHARS[] = " .':;=-+*#%@";
static const int DENSITY_LEN = sizeof(DENSITY_CHARS) - 1;

/* 3D vector and star structures */
typedef struct { double x, y, z; } Vec3;
typedef struct {
    Vec3 pos;       /* Celestial sphere coordinate */
    double base_b;  /* Base brightness [0.0 - 1.0] */
    int core_id;    /* CPU core affinity for twinkling */
} Star;

typedef struct {
    int idx_a, idx_b; /* Index pairs connecting stars into constellations */
} Edge;

/* Sample Constellations (Ursa Major, Orion, Cassiopeia, Cygnus) */
static Star g_stars[] = {
    /* Ursa Major */
    {{-0.80,  0.50,  0.32}, 0.95, 0}, {{-0.60,  0.53,  0.60}, 0.85, 1},
    {{-0.45,  0.42,  0.79}, 0.80, 0}, {{-0.25,  0.35,  0.90}, 0.90, 1},
    {{-0.20,  0.15,  0.96}, 0.85, 2}, {{-0.42,  0.10,  0.90}, 0.92, 3},
    {{-0.52,  0.28,  0.81}, 0.88, 2},
    /* Orion */
    {{ 0.30, -0.20, -0.93}, 1.00, 0}, {{ 0.50, -0.18, -0.85}, 0.95, 1},
    {{ 0.38, -0.40, -0.83}, 0.85, 2}, {{ 0.40, -0.41, -0.82}, 0.80, 3},
    {{ 0.42, -0.42, -0.81}, 0.87, 0}, {{ 0.32, -0.62, -0.72}, 0.90, 1},
    {{ 0.52, -0.60, -0.61}, 0.95, 2},
    /* Cassiopeia */
    {{ 0.10,  0.85,  0.52}, 0.90, 0}, {{ 0.25,  0.78,  0.57}, 0.85, 1},
    {{ 0.28,  0.88,  0.38}, 0.95, 2}, {{ 0.45,  0.82,  0.35}, 0.80, 3},
    {{ 0.55,  0.85,  0.15}, 0.90, 0},
    /* Cygnus */
    {{-0.10, -0.80,  0.59}, 1.00, 1}, {{-0.12, -0.65,  0.75}, 0.80, 2},
    {{-0.15, -0.50,  0.85}, 0.90, 3}, {{-0.35, -0.52,  0.78}, 0.85, 0},
    {{ 0.05, -0.48,  0.87}, 0.85, 1}
};
#define NUM_STARS (sizeof(g_stars) / sizeof(g_stars[0]))

static Edge g_edges[] = {
    /* Ursa Major */
    {0,1}, {1,2}, {2,3}, {3,4}, {4,5}, {5,6}, {6,2},
    /* Orion */
    {7,9}, {8,13}, {9,10}, {10,11}, {9,12}, {11,13}, {7,8},
    /* Cassiopeia */
    {14,15}, {15,16}, {16,17}, {17,18},
    /* Cygnus */
    {19,20}, {20,21}, {21,22}, {21,23}
};
#define NUM_EDGES (sizeof(g_edges) / sizeof(g_edges[0]))

/* Read live multi-core CPU usage via /proc/stat */
static void get_cpu_loads(double *loads, int max_cores) {
    FILE *fp = fopen("/proc/stat", "r");
    if (!fp) return;
    char line[256];
    static unsigned long long prev_user[16] = {0}, prev_sum[16] = {0};
    int core = 0;
    
    while (fgets(line, sizeof(line), fp) && core < max_cores) {
        if (strncmp(line, "cpu", 3) == 0 && line[3] >= '0' && line[3] <= '9') {
            unsigned long long u, n, s, idle, iow, irq, sirq, steal;
            sscanf(line, "%*s %llu %llu %llu %llu %llu %llu %llu %llu",
                   &u, &n, &s, &idle, &iow, &irq, &sirq, &steal);
            unsigned long long active = u + n + s + irq + sirq + steal;
            unsigned long long sum = active + idle + iow;
            unsigned long long d_active = active - prev_user[core];
            unsigned long long d_sum = sum - prev_sum[core];
            
            loads[core] = d_sum ? (double)d_active / d_sum : 0.0;
            prev_user[core] = active;
            prev_sum[core] = sum;
            core++;
        }
    }
    fclose(fp);
}

/* Read memory allocation percentage */
static double get_mem_usage(void) {
    struct sysinfo info;
    if (sysinfo(&info) == 0) {
        double total = info.totalram;
        double free = info.freeram;
        return (total - free) / total;
    }
    return 0.5;
}

/* Rotate a 3D point using axial precession angles */
static Vec3 rotate(Vec3 p, double yaw, double pitch) {
    /* Pitch (X-axis) */
    double y1 = p.y * cos(pitch) - p.z * sin(pitch);
    double z1 = p.y * sin(pitch) + p.z * cos(pitch);
    /* Yaw (Y-axis) */
    double x2 = p.x * cos(yaw) + z1 * sin(yaw);
    double z2 = -p.x * sin(yaw) + z1 * cos(yaw);
    return (Vec3){x2, y1, z2};
}

/* Terminal raw mode setup */
static struct termios g_orig_termios;
static void disable_raw_mode(void) {
    tcsetattr(STDIN_FILENO, TCSAFLUSH, &g_orig_termios);
    printf("\033[?25h\033[0m\033[2J\033[H"); /* Restore cursor and screen */
}
static void enable_raw_mode(void) {
    tcgetattr(STDIN_FILENO, &g_orig_termios);
    atexit(disable_raw_mode);
    struct termios raw = g_orig_termios;
    raw.c_lflag &= ~(ECHO | ICANON);
    tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw);
    printf("\033[?25l"); /* Hide cursor */
}

/* Draw line between two screen coordinates into density buffer */
static void draw_line(double *buf, int w, int h, int x0, int y0, int x1, int y1, double val) {
    int dx = abs(x1 - x0), sx = x0 < x1 ? 1 : -1;
    int dy = -abs(y1 - y0), sy = y0 < y1 ? 1 : -1;
    int err = dx + dy, e2;
    while (1) {
        if (x0 >= 0 && x0 < w && y0 >= 0 && y0 < h) {
            int idx = y0 * w + x0;
            if (val > buf[idx]) buf[idx] = val;
        }
        if (x0 == x1 && y0 == y1) break;
        e2 = 2 * err;
        if (e2 >= dy) { err += dy; x0 += sx; }
        if (e2 <= dx) { err += dx; y0 += sy; }
    }
}

int main(void) {
    enable_raw_mode();
    
    double cpu_loads[16] = {0};
    double yaw = 0.0, pitch = 0.0;
    
    while (1) {
        /* Get Terminal Dimensions */
        struct winsize ws;
        ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws);
        int width = ws.ws_col;
        int height = ws.ws_row;
        if (width <= 0 || height <= 0) { width = 80; height = 24; }

        /* Fetch real-time system metrics */
        get_cpu_loads(cpu_loads, 16);
        double mem_usage = get_mem_usage();

        /* Memory allocation controls the rate of celestial precession */
        double precession_rate = 0.005 + (mem_usage * 0.03);
        yaw += precession_rate;
        pitch += precession_rate * 0.5;

        /* Allocate density buffer */
        double *buffer = calloc(width * height, sizeof(double));

        /* Project stars and render constellations */
        int sx[NUM_STARS], sy[NUM_STARS];
        double star_brightness[NUM_STARS];

        for (size_t i = 0; i < NUM_STARS; i++) {
            Vec3 r = rotate(g_stars[i].pos, yaw, pitch);
            /* Stereographic projection */
            double fov = 1.8;
            sx[i] = (int)((r.x / (r.z + 2.0)) * fov * (height * 1.0) + width / 2.0);
            sy[i] = (int)((r.y / (r.z + 2.0)) * fov * (height * 0.5) + height / 2.0);

            /* CPU Core load modulates star flickering and brightness */
            double load = cpu_loads[g_stars[i].core_id % 16];
            double flicker = ((rand() % 100) / 100.0) * 0.25;
            star_brightness[i] = g_stars[i].base_b * (0.4 + load * 0.6) + flicker;
            if (star_brightness[i] > 1.0) star_brightness[i] = 1.0;

            if (r.z > -1.5 && sx[i] >= 0 && sx[i] < width && sy[i] >= 0 && sy[i] < height) {
                buffer[sy[i] * width + sx[i]] = star_brightness[i];
            }
        }

        /* Render constellation line boundaries using faint ASCII shading */
        for (size_t i = 0; i < NUM_EDGES; i++) {
            int a = g_edges[i].idx_a;
            int b = g_edges[i].idx_b;
            draw_line(buffer, width, height, sx[a], sy[a], sx[b], sy[b], 0.18);
        }

        /* Render frame to terminal using ASCII density map */
        printf("\033[H"); /* Move cursor top-left */
        char *out = malloc(width * height + height + 1);
        int ptr = 0;

        for (int y = 0; y < height; y++) {
            for (int x = 0; x < width; x++) {
                double val = buffer[y * width + x];
                int char_idx = (int)(val * (DENSITY_LEN - 1));
                if (char_idx < 0) char_idx = 0;
                if (char_idx >= DENSITY_LEN) char_idx = DENSITY_LEN - 1;
                out[ptr++] = DENSITY_CHARS[char_idx];
            }
            out[ptr++] = '\n';
        }
        out[ptr] = '\0';
        fputs(out, stdout);
        fflush(stdout);

        free(out);
        free(buffer);

        usleep(50000); /* ~20 FPS refresh rate */
    }
    return 0;
}