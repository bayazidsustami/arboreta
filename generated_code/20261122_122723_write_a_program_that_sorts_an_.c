#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

#define CANVAS_W 76
#define CANVAS_H 16
#define MAX_STEPS 240

/* Sum distinct prime factors of |x| to drive tectonic drift speed. */
static int prime_factor_sum(int v) {
    long n = llabs((long)v);
    if (n <= 1) return 1;
    int sum = 0;
    while (n % 2 == 0) {
        if (sum == 0 || (sum & 1) == 0) sum += 2;
        while (n % 2 == 0) n /= 2;
    }
    for (long d = 3; d * d <= n; d += 2) {
        if (n % d == 0) {
            sum += (int)d;
            while (n % d == 0) n /= d;
        }
    }
    if (n > 1) sum += (int)n;
    return sum > 0 ? sum : 1;
}

/* Shift a single element one slot toward target_idx when within drift budget. */
static int shift_toward(int *a, int from, int to) {
    if (from == to) return 0;
    int val = a[from];
    if (from < to) {
        memmove(&a[from], &a[from + 1], (size_t)(to - from) * sizeof(int));
        a[to] = val;
    } else {
        memmove(&a[to + 1], &a[to], (size_t)(from - to) * sizeof(int));
        a[to] = val;
    }
    return 1;
}

/* Check if array is sorted in non-decreasing order. */
static int is_sorted(const int *a, int n) {
    for (int i = 1; i < n; i++) {
        if (a[i - 1] > a[i]) return 0;
    }
    return 1;
}

/* Render fault lines and prime-driven stress as a sumi-e ink-wash landscape. */
static void render_ink_landscape(const int *a, const int *target, int n,
                                 int step, int active_faults, int max_val, int min_val) {
    double ink[CANVAS_H][CANVAS_W];
    char ridge[CANVAS_H][CANVAS_W];

    for (int r = 0; r < CANVAS_H; r++) {
        for (int c = 0; c < CANVAS_W; c++) {
            ink[r][c] = 0.0;
            ridge[r][c] = ' ';
        }
    }

    double span = (double)(max_val - min_val);
    if (span < 1.0) span = 1.0;

    /* Base ink wash: distant mist and mountain silhouettes from array values. */
    for (int c = 0; c < CANVAS_W; c++) {
        double pos = (double)c / (double)(CANVAS_W - 1) * (double)(n - 1);
        int idx = (int)floor(pos);
        if (idx >= n - 1) idx = n - 2;
        double frac = pos - (double)idx;

        double h0 = (double)(a[idx] - min_val) / span;
        double h1 = (double)(a[idx + 1] - min_val) / span;
        double h = h0 * (1.0 - frac) + h1 * frac;

        /* Secondary harmonic wash for atmospheric sumi-e depth. */
        double wash_wave = 0.5 + 0.5 * sin((double)c * 0.11 + (double)step * 0.17);
        int peak_row = (int)floor((1.0 - h) * (CANVAS_H - 3)) + 1;
        if (peak_row < 1) peak_row = 1;
        if (peak_row >= CANVAS_H) peak_row = CANVAS_H - 1;

        for (int r = peak_row; r < CANVAS_H; r++) {
            double depth = (double)(r - peak_row + 1) / (double)(CANVAS_H - peak_row + 1);
            ink[r][c] += depth * (0.35 + 0.45 * wash_wave);
        }

        /* Fault line scarp where adjacent plates disagree or differ from settled order. */
        int fault_here = (idx < n - 1 && a[idx] > a[idx + 1]) || (a[idx] != target[idx]);
        if (fault_here) {
            int pfs = prime_factor_sum(a[idx]) + prime_factor_sum(a[idx + 1]);
            int scarp_span = 1 + (pfs % 5);
            for (int dr = -scarp_span; dr <= scarp_span; dr++) {
                int rr = peak_row + dr;
                if (rr >= 0 && rr < CANVAS_H) {
                    double intensity = 1.0 - (fabs((double)dr) / (double)(scarp_span + 1));
                    ink[rr][c] += intensity * 1.4;
                    if (intensity > 0.55) {
                        ridge[rr][c] = (a[idx] > a[idx + 1]) ? '/' : '~';
                    }
                }
            }
        }
    }

    const char *palette = " .:-=+*#%@";
    int pal_len = (int)strlen(palette) - 1;

    printf("\x1b[H\x1b[2J"); /* Clear screen and home cursor */
    printf("TECTONIC INK-WASH SORT  |  Epoch %03d  |  Active Faults: %d  |  State: %s\n",
           step, active_faults, active_faults == 0 ? "ISOSTATIC EQUILIBRIUM" : "DRIFTING");
    printf("+");
    for (int c = 0; c < CANVAS_W; c++) printf("-");
    printf("+\n");

    for (int r = 0; r < CANVAS_H; r++) {
        printf("|");
        for (int c = 0; c < CANVAS_W; c++) {
            if (ridge[r][c] != ' ') {
                putchar(ridge[r][c]);
            } else {
                double v = ink[r][c];
                if (v < 0.0) v = 0.0;
                if (v > 1.0) v = 1.0;
                int idx = (int)floor(v * pal_len);
                if (idx > pal_len) idx = pal_len;
                putchar(palette[idx]);
            }
        }
        printf("|\n");
    }

    printf("+");
    for (int c = 0; c < CANVAS_W; c++) printf("-");
    printf("+\n");

    printf("Plates: ");
    for (int i = 0; i < n; i++) {
        printf("%d%s", a[i], (i + 1 < n) ? " " : "\n");
    }
    fflush(stdout);
}

/* Sort purely by shifting elements across prime-speed tectonic plates. */
static void tectonic_sort(int *a, int n) {
    int *target = (int *)malloc((size_t)n * sizeof(int));
    int *budget = (int *)calloc((size_t)n, sizeof(int));
    if (!target || !budget) {
        free(target);
        free(budget);
        return;
    }

    memcpy(target, a, (size_t)n * sizeof(int));
    /* Build reference sorted order via simple selection into target. */
    for (int i = 0; i < n - 1; i++) {
        int min_i = i;
        for (int j = i + 1; j < n; j++) {
            if (target[j] < target[min_i]) min_i = j;
        }
        int tmp = target[i];
        target[i] = target[min_i];
        target[min_i] = tmp;
    }

    int min_val = target[0];
    int max_val = target[n - 1];

    int step = 0;
    while (step < MAX_STEPS) {
        int faults = 0;
        for (int i = 0; i < n - 1; i++) {
            if (a[i] > a[i + 1]) faults++;
        }

        render_ink_landscape(a, target, n, step, faults, max_val, min_val);
        if (is_sorted(a, n)) break;

        /* Accumulate plate drift speed from prime factors of neighboring crust. */
        for (int i = 0; i < n; i++) {
            int left_v = (i > 0) ? a[i - 1] : a[i];
            int right_v = (i < n - 1) ? a[i + 1] : a[i];
            int pf_local = prime_factor_sum(a[i]);
            int pf_neighbors = prime_factor_sum(left_v) + prime_factor_sum(right_v);
            int speed = 1 + ((pf_local + pf_neighbors) % 5);
            budget[i] += speed;
        }

        /* Find the plate most out of place and shift it across the crust. */
        int chosen = -1;
        int best_displacement = 0;
        for (int i = 0; i < n; i++) {
            /* Find where a[i] belongs relative to current neighbors. */
            int desired = i;
            if (i > 0 && a[i] < a[i - 1]) {
                desired = i - 1;
                while (desired > 0 && a[desired - 1] > a[i]) desired--;
            } else if (i < n - 1 && a[i] > a[i + 1]) {
                desired = i + 1;
                while (desired < n - 1 && a[desired + 1] < a[i]) desired++;
            }
            int disp = abs(desired - i);
            if (disp > best_displacement && budget[i] >= 3) {
                best_displacement = disp;
                chosen = i;
            }
        }

        if (chosen >= 0) {
            int desired = chosen;
            if (chosen > 0 && a[chosen] < a[chosen - 1]) {
                desired = chosen - 1;
                while (desired > 0 && a[desired - 1] > a[chosen]) desired--;
            } else if (chosen < n - 1 && a[chosen] > a[chosen + 1]) {
                desired = chosen + 1;
                while (desired < n - 1 && a[desired + 1] < a[chosen]) desired++;
            }
            /* Shift one step along the fault toward desired position. */
            int next_pos = chosen + (desired > chosen ? 1 : -1);
            shift_toward(a, chosen, next_pos);
            budget[chosen] = 0;
        } else {
            /* Release stress by shifting the first out-of-order element one step. */
            for (int i = 0; i < n - 1; i++) {
                if (a[i] > a[i + 1]) {
                    shift_toward(a, i, i + 1);
                    budget[i] = 0;
                    break;
                }
            }
        }

        /* Brief pacing pause (~45 ms) so evolution is visible in terminal. */
        for (volatile long d = 0; d < 28000000L; d++) {
            /* busy wait for portable standard C */
        }
        step++;
    }

    free(target);
    free(budget);
}

int main(void) {
    int data[] = {42, 17, 89, 12, 63, 25, 91, 8, 54, 31, 77, 19, 68, 5};
    int n = (int)(sizeof(data) / sizeof(data[0]));

    tectonic_sort(data, n);

    printf("\nSorted crust: ");
    for (int i = 0; i < n; i++) {
        printf("%d%s", data[i], (i + 1 < n) ? ", " : "\n");
    }
    return 0;
}