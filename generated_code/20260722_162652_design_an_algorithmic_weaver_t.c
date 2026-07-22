#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* --- AST Node Definition --- */
typedef enum {
    NODE_PROGRAM,
    NODE_SCOPE,
    NODE_BRANCH,
    NODE_STATEMENT
} NodeType;

typedef struct ASTNode {
    NodeType type;
    int scope_depth;
    int complexity_weight;
    struct ASTNode** children;
    size_t child_count;
    size_t child_capacity;
} ASTNode;

/* --- AST Helpers --- */
ASTNode* create_node(NodeType type, int scope_depth, int complexity_weight) {
    ASTNode* node = (ASTNode*)malloc(sizeof(ASTNode));
    if (!node) return NULL;
    node->type = type;
    node->scope_depth = scope_depth;
    node->complexity_weight = complexity_weight;
    node->child_count = 0;
    node->child_capacity = 4;
    node->children = (ASTNode**)malloc(node->child_capacity * sizeof(ASTNode*));
    return node;
}

void add_child(ASTNode* parent, ASTNode* child) {
    if (!parent || !child) return;
    if (parent->child_count >= parent->child_capacity) {
        parent->child_capacity *= 2;
        parent->children = (ASTNode**)realloc(parent->children, parent->child_capacity * sizeof(ASTNode*));
    }
    parent->children[parent->child_count++] = child;
}

void free_ast(ASTNode* node) {
    if (!node) return;
    for (size_t i = 0; i < node->child_count; ++i) {
        free_ast(node->children[i]);
    }
    free(node->children);
    free(node);
}

/* --- Color Palette mapped to Variable Scoping Depth --- */
const char* SCOPE_COLORS[] = {
    "\033[38;5;196m", /* Scope Depth 0: Crimson Red */
    "\033[38;5;208m", /* Scope Depth 1: Solar Orange */
    "\033[38;5;220m", /* Scope Depth 2: Bright Yellow */
    "\033[38;5;46m",  /* Scope Depth 3: Neon Green   */
    "\033[38;5;33m",  /* Scope Depth 4: Deep Cyan    */
    "\033[38;5;129m"  /* Scope Depth 5+: Violet      */
};
const char* COLOR_RESET = "\033[0m";

const char* get_scope_color(int depth) {
    int max_idx = (int)(sizeof(SCOPE_COLORS) / sizeof(SCOPE_COLORS[0])) - 1;
    if (depth > max_idx) depth = max_idx;
    if (depth < 0) depth = 0;
    return SCOPE_COLORS[depth];
}

/* --- Knitting Stitches based on Cyclomatic Complexity --- */
/* High complexity generates denser, more structural stitch glyphs */
const char* get_stitch_glyph(int complexity) {
    if (complexity <= 1) return "v";  /* Stockinette (Low density) */
    if (complexity <= 2) return "x";  /* Garter stitch */
    if (complexity <= 4) return "#";  /* Double Cable stitch */
    return "@";                       /* Dense Nupp / Cluster (High density) */
}

/* --- Algorithmic Weaver: Traverses AST & Renders Knitting Pattern --- */
void weave_row(ASTNode* node, int width) {
    if (!node) return;

    const char* color = get_scope_color(node->scope_depth);
    const char* stitch = get_stitch_glyph(node->complexity_weight);

    /* Render a row of the pattern for this AST construct */
    printf("Row %02d [Scope %d | Density %d]: ", node->scope_depth + 1, node->scope_depth, node->complexity_weight);
    for (int i = 0; i < width; ++i) {
        /* Introduce periodic Purling weave variation based on complexity */
        if ((i + node->complexity_weight) % 5 == 0) {
            printf("%s-%s", color, COLOR_RESET);
        } else {
            printf("%s%s%s", color, stitch, COLOR_RESET);
        }
    }
    printf("\n");

    /* Weave deeper AST structures (nested branches / inner scopes) */
    for (size_t i = 0; i < node->child_count; ++i) {
        weave_row(node->children[i], width);
    }
}

/* --- Program Generator / Main --- */
int main(void) {
    /* Build an example AST representing a multi-scoped, complex control flow */
    ASTNode* root = create_node(NODE_PROGRAM, 0, 1);

    ASTNode* main_scope = create_node(NODE_SCOPE, 1, 1);
    ASTNode* loop_branch = create_node(NODE_BRANCH, 2, 3);
    ASTNode* nested_scope = create_node(NODE_SCOPE, 3, 5);
    ASTNode* inner_stmt = create_node(NODE_STATEMENT, 4, 2);

    add_child(nested_scope, inner_stmt);
    add_child(loop_branch, nested_scope);
    add_child(main_scope, loop_branch);
    
    ASTNode* second_branch = create_node(NODE_BRANCH, 1, 4);
    add_child(root, main_scope);
    add_child(root, second_branch);

    printf("====================================================\n");
    printf("       AST GENERATIVE KNITTING PATTERN WEAVER       \n");
    printf("====================================================\n");
    printf("Legend:\n");
    printf("  Color  = Scope Depth (Red -> Orange -> Yellow -> Green -> Cyan)\n");
    printf("  Stitch = Cyclomatic Density ('v'=Low, 'x'=Med, '#'=High, '@'=Dense)\n\n");

    /* Weave the pattern with a fixed width of 40 stitches per row */
    weave_row(root, 40);

    printf("\n====================================================\n");

    free_ast(root);
    return 0;
}