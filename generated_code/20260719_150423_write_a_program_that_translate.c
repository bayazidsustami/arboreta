#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <time.h>

/* Define constants for the simulation grid */
#define WIDTH 70
#define HEIGHT 24
#define MAX_SPIRES 4

/* Weather Telemetry Structure */
typedef struct {
    float wind_speed_mph;     /* Controls structural decay / collapse */
    float humidity_pct;       /* Breeds digital moss ('%') */
    float barometric_press;   /* Shifts stained-glass color/character palette */
} WeatherTelemetry;

/* Simulation State representing the Cathedral */
typedef struct {
    char grid[HEIGHT][WIDTH];
    int color_palette[HEIGHT][WIDTH]; /* 0: Normal, 1: Moss, 2: Stained Glass */
    int spire_heights[MAX_SPIRES];
} GothicCathedral;

/* Mock function to simulate real-time global weather telemetry data */
void fetch_weather_telemetry(WeatherTelemetry *telemetry) {
    /* Randomly fluctuate weather data to simulate real-time updates */
    telemetry->wind_speed_mph = 10.0f + (rand() % 65);  /* 10 to 75 mph */
    telemetry->humidity_pct = 20.0f + (rand() % 80);    /* 20% to 100% */
    telemetry->barometric_press = 980.0f + (rand() % 50); /* 980 to 1030 hPa */
}

/* Procedurally generates the architecture based on the current weather environment */
void generate_cathedral(GothicCathedral *cathedral, const WeatherTelemetry *weather) {
    int i, j;

    /* Reset grid and palette mapping */
    for (i = 0; i < HEIGHT; i++) {
        for (j = 0; j < WIDTH; j++) {
            cathedral->grid[i][j] = ' ';
            cathedral->color_palette[i][j] = 0;
        }
    }

    /* 1. STRUCTURAL DECAY: Calculate spire degradation based on wind speed */
    /* Higher wind speed reduces the maximum possible height of the spires */
    float wind_decay_factor = weather->wind_speed_mph / 75.0f; 
    int base_spire_height = 12;
    int max_allowed_height = base_spire_height - (int)(wind_decay_factor * 8.0f);
    if (max_allowed_height < 3) max_allowed_height = 3;

    int spire_positions[MAX_SPIRES] = {15, 28, 42, 55};
    for (i = 0; i < MAX_SPIRES; i++) {
        cathedral->spire_heights[i] = max_allowed_height + (rand() % 3);
    }

    /* 2. ARCHITECTURAL ASSEMBLY: Draw Spires, Buttresses, and Nave */
    int ground = HEIGHT - 2;

    /* Draw Ground Foundation */
    for (j = 0; j < WIDTH; j++) {
        cathedral->grid[ground][j] = '=';
        cathedral->grid[ground + 1][j] = '#';
    }

    /* Draw Main Cathedral Walls and Rose Window Frame */
    int nave_left = 20, nave_right = 50;
    int nave_top = 10;
    for (i = nave_top; i < ground; i++) {
        cathedral->grid[i][nave_left] = '|';
        cathedral->grid[i][nave_right] = '|';
    }

    /* Procedural Stained Glass Window Generation shifted by Barometric Pressure */
    int glass_center_x = (nave_left + nave_right) / 2;
    int glass_center_y = nave_top + 4;
    int radius = 4;

    /* Choose stained-glass character set based on Barometric Pressure */
    char glass_char;
    if (weather->barometric_press < 1000.0f) {
        glass_char = 'X'; /* Low pressure: Stormy, dense patterns */
    } else if (weather->barometric_press < 1015.0f) {
        glass_char = '*'; /* Standard pressure: Intricate geometric stars */
    } else {
        glass_char = '@'; /* High pressure: Heavy, luminous circles */
    }

    for (i = glass_center_y - radius; i <= glass_center_y + radius; i++) {
        for (j = glass_center_x - radius * 2; j <= glass_center_x + radius * 2; j++) {
            float dx = (j - glass_center_x) / 2.0f;
            float dy = (i - glass_center_y);
            if ((dx * dx + dy * dy) <= (radius * radius)) {
                if (i >= 0 && i < HEIGHT && j >= 0 && j < WIDTH) {
                    cathedral->grid[i][j] = glass_char;
                    cathedral->color_palette[i][j] = 2; /* Tag as stained glass */
                }
            }
        }
    }

    /* Build Spires */
    for (int s = 0; s < MAX_SPIRES; s++) {
        int pos = spire_positions[s];
        int height = cathedral->spire_heights[s];
        int peak = ground - height;

        for (i = ground - 1; i >= peak; i--) {
            if (i >= 0 && i < HEIGHT) {
                if (i == peak) {
                    cathedral->grid[i][pos] = '^'; /* Spire tip */
                } else {
                    cathedral->grid[i][pos - 1] = '/';
                    cathedral->grid[i][pos] = '|';
                    cathedral->grid[i][pos + 1] = '\\';
                }
            }
        }
    }

    /* Flying Buttresses */
    for (i = 0; i < 4; i++) {
        if (nave_top + 2 + i < ground) {
            cathedral->grid[nave_top + 2 + i][nave_left - 4 + i] = '/';
            cathedral->grid[nave_top + 2 + i][nave_right + 4 - i] = '\\';
        }
    }

    /* 3. DIGITAL MOSS INFESTATION: Propagated via Humidity */
    /* Higher humidity increases the likelihood of moss '%' taking over surfaces */
    float moss_probability = weather->humidity_pct / 100.0f;
    for (i = 0; i < HEIGHT; i++) {
        for (j = 0; j < WIDTH; j++) {
            char current_char = cathedral->grid[i][j];
            /* Moss grows on structural wireframe components but avoids empty air and glass */
            if (current_char == '|' || current_char == '/' || current_char == '\\' || current_char == '=') {
                float roll = (float)rand() / RAND_MAX;
                if (roll < (moss_probability * 0.4f)) { /* Weight growth density */
                    cathedral->grid[i][j] = '%';
                    cathedral->color_palette[i][j] = 1; /* Tag as digital moss */
                }
            }
        }
    }
}

/* Outputs the fully rendered telemetry and cathedral geometry to the console */
void render_cathedral(const GothicCathedral *cathedral, const WeatherTelemetry *weather) {
    /* Clear Screen */
    printf("\033[H\033[J");

    /* Render Real-Time Telemetry Dashboard */
    printf("======================================================================\n");
    printf(" GOTHIC TELEMETRY ENGINE v1.0 | MONITORING GLOBAL ATMOSPHERIC FLUX\n");
    printf("======================================================================\n");
    printf(" Wind Speed:   %-5.1f mph  [Spire Decay Factor: %0.2f]\n", 
           weather->wind_speed_mph, weather->wind_speed_mph / 75.0f);
    printf(" Humidity:     %-5.1f %%    [Digital Moss Breeding Rate: %0.1f%%]\n", 
           weather->humidity_pct, weather->humidity_pct);
    printf(" Barometric:   %-5.1f hPa  [Stained-Glass Phase Shift Mode]\n", 
           weather->barometric_press);
    printf("======================================================================\n\n");

    /* Render Cathedral Matrix using ANSI terminal escape sequences for colors */
    for (int i = 0; i < HEIGHT; i++) {
        for (int j = 0; j < WIDTH; j++) {
            int type = cathedral->color_palette[i][j];
            char cell = cathedral->grid[i][j];

            if (type == 1) {
                /* Moss Matrix: Vivid Green */
                printf("\033[1;32m%c\033[0m", cell);
            } else if (type == 2) {
                /* Stained Glass Shaders: Dynamic Colors mapped to pressure range */
                if (weather->barometric_press < 1000.0f) {
                    printf("\033[1;31m%c\033[0m", cell); /* Low Pressure Crimson Deep Sky */
                } else if (weather->barometric_press < 1015.0f) {
                    printf("\033[1;35m%c\033[0m", cell); /* Normal Pressure Gothic Violet */
                } else {
                    printf("\033[1;36m%c\033[0m", cell); /* High Pressure Ethereal Cyan */
                }
            } else {
                /* Structural Stone: Monochromatic Ash */
                if (cell == '^' || cell == '#' || cell == '=') {
                    printf("\033[1;37m%c\033[0m", cell);
                } else {
                    printf("\033[0;37m%c\033[0m", cell);
                }
            }
        }
        printf("\n");
    }
    printf("\n[Press Ctrl+C to terminate transmission or wait for the next cycle...]\n");
}

/* Sleep abstraction layer for cross-platform processing */
void cycle_delay(int milliseconds) {
    struct timespec ts;
    ts.tv_sec = milliseconds / 1000;
    ts.tv_nsec = (milliseconds % 1000) * 1000000;
    nanosleep(&ts, NULL);
}

int main(void) {
    WeatherTelemetry current_weather;
    GothicCathedral cathedral_instance;

    /* Initialize seed for procedural variations */
    srand((unsigned int)time(NULL));

    /* Continuous real-time translation loop */
    while (1) {
        fetch_weather_telemetry(&current_weather);
        generate_cathedral(&cathedral_instance, &current_weather);
        render_cathedral(&cathedral_instance, &current_weather);
        
        cycle_delay(2500); /* Sample and morph geometry every 2.5 seconds */
    }

    return 0;
}