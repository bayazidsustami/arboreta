#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Helper to execute a git command and parse an integer metric */
int get_git_metric(const char *repo_path, const char *cmd_fmt) {
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "git -C \"%s\" %s 2>/dev/null", repo_path, cmd_fmt);
    FILE *fp = popen(cmd, "r");
    if (!fp) return 0;
    char buf[128];
    int val = 0;
    if (fgets(buf, sizeof(buf), fp)) {
        val = atoi(buf);
    }
    pclose(fp);
    return val;
}

/* Recursive fractal tree generator influenced by repository history */
void grow_branch(int depth, int max_depth, int blossoms, int conflicts) {
    if (depth > max_depth || depth > 7) return;
    
    for (int i = 0; i < depth; i++) printf("    ");
    printf(" └── 🌿 commit_node\n");

    if (depth == max_depth || depth == 7) {
        for (int i = 0; i <= depth; i++) printf("    ");
        if (blossoms > 0) {
            printf("🌸 [Merge Blossom: harmony integrated]\n");
            blossoms--;
        }
        if (conflicts > 0) {
            for (int j = 0; j < conflicts && j < 2; j++) {
                for (int i = 0; i <= depth; i++) printf("    ");
                printf("💥🍂 ~ (petal torn by conflict)\n");
            }
        }
    } else {
        grow_branch(depth + 1, max_depth, blossoms, conflicts);
        grow_branch(depth + 1, max_depth, blossoms, conflicts);
    }
}

int main(int argc, char *argv[]) {
    const char *repo_path = (argc > 1) ? argv[1] : ".";
    
    printf("=== Git Fractal Tree Visualizer ===\n");
    printf("Target Repository: %s\n\n", repo_path);
    
    int total_commits = get_git_metric(repo_path, "rev-list --count HEAD");
    int total_merges = get_git_metric(repo_path, "rev-list --merges --count HEAD");
    int total_conflicts = get_git_metric(repo_path, "log --grep='conflict' --oneline | wc -l");

    if (total_commits <= 0) {
        total_commits = 42;
        total_merges = 5;
        total_conflicts = 2;
    }
    
    printf("Repository DNA -> Commits: %d | Merges: %d | Conflicts: %d\n", 
           total_commits, total_merges, total_conflicts);
    printf("--------------------------------------------------\n\n");

    int max_depth = 4;
    if (total_commits > 500) max_depth = 5;
    if (total_commits > 2000) max_depth = 6;

    grow_branch(1, max_depth, total_merges > 0 ? total_merges : 3, total_conflicts);

    printf("\nTree successfully cultivated from commit history.\n");
    return 0;
}