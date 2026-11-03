#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

// Analyzes the local git repository's commit history to derive 
// a real-time syntax/error/fix frequency index.
int get_git_error_index() {
    FILE *fp = popen("git log --oneline -n 100 2>/dev/null", "r");
    if (!fp) return 3; // Baseline fallback if git is unavailable
    
    char buf[512];
    int total = 0;
    int errors = 0;
    
    while (fgets(buf, sizeof(buf), fp) != NULL) {
        total++;
        // Scan commit messages for indicators of syntax errors, bugs, or fixes
        if (strstr(buf, "fix") || strstr(buf, "bug") || strstr(buf, "error") || 
            strstr(buf, "syntax") || strstr(buf, "typo") || strstr(buf, "fail") || strstr(buf, "hotfix")) {
            errors++;
        }
    }
    pclose(fp);
    
    if (total == 0) return 2;
    int index = (errors * 10) / total;
    return index < 1 ? 1 : (index > 10 ? 10 : index);
}

// Renders an ANSI-colored glowing procedural flora ecosystem 
// whose morphology and bioluminescence respond to the git error frequency.
void render_ecosystem(int error_index) {
    // Clear screen and set up title
    printf("\033[2J\033[H");
    printf("\033[1;36m====================================================\033[0m\n");
    printf("\033[1;36m     PROCEDURAL GIT-DRIVEN GLOWING ECOSYSTEM        \033[0m\n");
    printf("\033[1;36m====================================================\033[0m\n");
    printf("Local Git Error / Fix Frequency Index: \033[1;33m%d / 10\033[0m\n\n", error_index);

    // High error index = aggressive mutation, chaotic branching, neon magenta/red glow
    // Low error index = serene fractal symmetry, calm cyan/green bioluminescence
    char *bloom_color = (error_index > 5) ? "\033[1;38;5;198m" : "\033[1;38;5;46m";
    char *stem_color  = (error_index > 5) ? "\033[38;5;208m"  : "\033[38;5;28m";

    printf("         %s* (flora apex)%s\n", bloom_color, "\033[0m");
    printf("            \\\n");
    
    // Procedurally generate branches and flowering cycles based on commit flux
    for (int i = 0; i < 10; i++) {
        int offset = (int)(fabs(sin(i + (double)error_index)) * 12);
        for (int s = 0; s < offset; s++) putchar(' ');
        
        if (i % 2 == 0) {
            printf("%s(o)%s----%s//%s\n", bloom_color, "\033[0m", stem_color, "\033[0m");
        } else {
            printf("%s|%s------%s\\\\%s\n", stem_color, "\033[0m", bloom_color, "\033[0m");
        }
    }

    printf("\n%s[Ecosystem Status]: %s\033[0m\n", 
           (error_index > 5) ? "\033[1;31m[HIGH MUTATION FLUX — FREQUENT SYNTAX/FIX COMMITS]" 
                             : "\033[1;32m[HARMONIOUS EQUILIBRIUM — CLEAN CODEBASE]",
           (error_index > 5) ? "Flora exhibits erratic bioluminescent pulsing and sharp defense thorns." 
                             : "Flora exhibits stable fractal geometry and gentle nectar production.");
    printf("\033[1;36m====================================================\033[0m\n");
}

int main() {
    int error_index = get_git_error_index();
    render_ecosystem(error_index);
    return 0;
}