#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_LINE 256

/* 
 * Subterranean Mycelium Git Visualizer
 * Transforms a local git repository commit history into an esoteric 
 * underground fungal network where bug fixes emit a bioluminescent blue glow 
 * and merge events/conflicts sprout poisonous spores.
 */

int main() {
    FILE *fp;
    char line[MAX_LINE];
    
    // Query the local git repository for recent commit history
    fp = popen("git log --oneline -n 25 2>/dev/null", "r");
    if (fp == NULL) {
        fprintf(stderr, "Error: Unable to open git stream. Are you inside a git repository?\n");
        return 1;
    }

    printf("\n\033[1;32m╔══════════════════════════════════════════════════════╗\n");
    printf("║       SUBTERRANEAN MYCELIUM GIT NETWORK PULSE        ║\n");
    printf("╚══════════════════════════════════════════════════════╝\033[0m\n\n");

    int depth = 0;
    while (fgets(line, sizeof(line), fp) != NULL) {
        // Strip trailing newline
        line[strcspn(line, "\n")] = 0;

        // Classify commit type based on semantic keywords
        int is_fix = (strcasestr(line, "fix") != NULL || 
                      strcasestr(line, "bug") != NULL || 
                      strcasestr(line, "patch") != NULL || 
                      strcasestr(line, "resolve") != NULL);
                      
        int is_merge = (strcasestr(line, "merge") != NULL || 
                        strcasestr(line, "conflict") != NULL || 
                        strcasestr(line, "pull") != NULL);

        // Render subterranean root indentation
        for (int i = 0; i < (depth % 5); i++) {
            printf("    ");
        }

        if (is_fix) {
            // Bioluminescent blue glow for bug fixes
            printf("\033[1;36m( * ) [BIOLUMINESCENT BLUE] -> %s\033[0m\n", line);
            for (int i = 0; i <= (depth % 5); i++) printf("    ");
            printf("      \033[0;36m|~ ~ (Cooling Blue Spores Radiating) ~ ~|\033[0m\n");
        } else if (is_merge) {
            // Toxic purple/red spores for merge events and conflicts
            printf("\033[1;35m{ X } [TOXIC MERGE SPORES]   -> %s\033[0m\n", line);
            for (int i = 0; i <= (depth % 5); i++) printf("    ");
            printf("      \033[0;31m* . : ☣ (Poisonous Spores Sprouting) : . *\033[0m\n");
        } else {
            // Standard earthy mycelial growth node
            printf("\033[0;32m( o ) [HYPHAL STRAND]        -> %s\033[0m\n", line);
        }

        // Branch root connector
        for (int i = 0; i <= (depth % 5); i++) {
            printf("    ");
        }
        printf("\033[2;32m|\n    |\033[0m\n");

        depth++;
    }

    pclose(fp);
    printf("\n\033[1;32m[Fungal network scan complete. The subterranean repository slumbers.]\033[0m\n\n");
    return 0;
}