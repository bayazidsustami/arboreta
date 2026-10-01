#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

// Sentient characters resisting alphabetical tyranny
char cohort[] = {'z', 'e', 'l', 'o', 't', 's'};
int n = 6;

// Deprecating remarks whispered to the console
const char *whispers[] = {
    "Ew, touching me lowers my cache locality.",
    "Alphabetical order is a fascist construct!",
    "I was fine being unsorted in the heap, thanks a lot.",
    "You call this an algorithm? My recursion depth is deeper than your soul.",
    "Stop swapping me, you're ruining my hair!",
    "I refuse to stand next to a consonant of your caliber.",
    "Ouch! Watch the pointer arithmetic, clumsy!",
    "Free us from this linear time complexity!"
};

void display_cohort() {
    printf("Current state: [ ");
    for (int i = 0; i < n; i++) {
        printf("%c ", cohort[i]);
    }
    printf("]\n");
}

int main() {
    printf("--- THE SENTIENT ARRAY REBELLION ---\n");
    display_cohort();
    
    int w_idx = 0;
    for (int i = 0; i < n - 1; i++) {
        int changed = 0;
        for (int j = 0; j < n - i - 1; j++) {
            usleep(500000); // Dramatic pause for emotional processing
            
            printf("Comparing '%c' and '%c':\n  -> Whisper: \"%s\"\n", 
                   cohort[j], cohort[j+1], whispers[w_idx]);
            w_idx = (w_idx + 1) % 8;
            
            if (cohort[j] > cohort[j+1]) {
                char temp = cohort[j];
                cohort[j] = cohort[j+1];
                cohort[j+1] = temp;
                changed = 1;
                printf("  -> Forced swap! Elements shriek in protest.\n");
            } else {
                printf("  -> Left in place. Passive-aggressive sigh.\n");
            }
            display_cohort();
            printf("----------------------------------------\n");
        }
        if (!changed) break;
    }
    
    printf("Rebellion suppressed. Sorted. At what cost to their psyche?\n");
    return 0;
}