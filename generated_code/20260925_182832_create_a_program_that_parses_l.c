#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <time.h>

// ASCII Art components for our floating butterfly
const char *bf_top = "  \\   /  ";
const char *bf_mid = "   (o.o)   ";
const char *bf_bot = "  /  |  \\  ";

// Structure to hold parsed local weather parameters
typedef struct {
    int temperature;
    int humidity;
    int wind_speed;
} WeatherData;

// Simulate parsing local weather data (e.g., from a sensor or system file)
WeatherData parse_local_weather() {
    WeatherData w;
    // In a full implementation, this could read from /sys/class/thermal or an API endpoint.
    w.temperature = 12 + (rand() % 18);
    w.humidity = 40 + (rand() % 50);
    w.wind_speed = rand() % 15;
    return w;
}

// Check if a character is a vowel
int is_vowel(char c) {
    char lower = c | 32; // Quick lowercase conversion
    return lower == 'a' || lower == 'e' || lower == 'i' || lower == 'o' || lower == 'u';
}

// Render an ASCII butterfly at specific screen coordinates using ANSI escapes
void spawn_butterfly(int x, int y) {
    printf("\033[%d;%dH\033[35m%s\033[0m", y, x, bf_top);
    printf("\033[%d;%dH\033[35m%s\033[0m", y + 1, x, bf_mid);
    printf("\033[%d;%dH\033[35m%s\033[0m", y + 2, x, bf_bot);
    fflush(stdout);
}

int main() {
    srand(time(NULL));
    
    // Initial setup: Clear screen and hide cursor optionally
    printf("\033[2J\033[H");

    // Seed lines for our procedural haiku (5-7-5 syllable structure targets)
    char *haiku1 = strdup("frost upon the pane");
    char *haiku2 = strdup("whispering winds wake the dawn");
    char *haiku3 = strdup("spring returns anew");

    // Parse environmental weather data
    WeatherData weather = parse_local_weather();

    // Run mutation loop
    for (int cycle = 0; cycle < 8; cycle++) {
        // Mutate haiku based on weather conditions and random drops
        int target_line = rand() % 3;
        char *target_str = (target_line == 0) ? haiku1 : (target_line == 1) ? haiku2 : haiku3;
        
        int len = strlen(target_str);
        int idx = rand() % len;

        // If we hit a vowel, drop it and spawn a butterfly!
        if (is_vowel(target_str[idx])) {
            target_str[idx] = '_'; // Vowel drop representation
            
            // Clear screen for fresh frame
            printf("\033[H\033[J");
            
            // Display weather telemetry
            printf("=== LOCAL WEATHER TELEMETRY ===\n");
            printf("Temp: %d°C | Humidity: %d%% | Wind: %d km/h\n\n", 
                   weather.temperature, weather.humidity, weather.wind_speed);

            // Display mutating haiku
            printf("--- MUTATING HAIKU ---\n");
            printf("  %s\n", haiku1);
            printf("  %s\n", haiku2);
            printf("  %s\n\n", haiku3);
            
            // Spawn floating butterfly across the monitor
            int posX = 10 + (cycle * 4) % 40;
            int posY = 10 + (cycle % 3);
            spawn_butterfly(posX, posY);
        }

        // Adjust weather dynamically per cycle
        weather.temperature += (rand() % 3) - 1;
        weather.humidity += (rand() % 5) - 2;

        usleep(900000); // Wait 0.9 seconds per mutation frame
    }

    // Cleanup allocated memory
    free(haiku1);
    free(haiku2);
    free(haiku3);

    printf("\n\n");
    return 0;
}