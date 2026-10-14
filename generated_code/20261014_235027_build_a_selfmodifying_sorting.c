#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

// Opcode definitions for our stack-based AST language
typedef enum {
    OP_PUSH,
    OP_SWAP_MUTATE,
    OP_PRINT,
    OP_HALT
} OpType;

// AST Node representing instructions that can mutate themselves
typedef struct ASTNode {
    OpType op;
    int operand;
    struct ASTNode* left;
    struct ASTNode* right;
} ASTNode;

#define STACK_SIZE 256
#define DATA_SIZE 14

int stack[STACK_SIZE];
int top = -1;
int data[DATA_SIZE] = {10, 4, 12, 2, 8, 14, 6, 13, 1, 9, 3, 11, 5, 7};

void push(int val) {
    if (top < STACK_SIZE - 1) stack[++top] = val;
}

int pop() {
    return top >= 0 ? stack[top--] : 0;
}

// Renders an evolving ASCII landscape of the sorting dataset influenced by AST state
void render_landscape(int mutation_pulse) {
    printf("\033[H\033[J"); // Clear terminal screen for animation
    printf("=== SELF-MODIFYING AST SORTING LANDSCAPE (Pulse: %d) ===\n", mutation_pulse);
    for (int h = 14; h > 0; h--) {
        for (int i = 0; i < DATA_SIZE; i++) {
            if (data[i] >= h) {
                char shades[] = " .:=+*#%@";
                int idx = (data[i] + mutation_pulse) % 9;
                printf("%c ", shades[idx]);
            } else {
                printf("  ");
            }
        }
        printf("\n");
    }
    for (int i = 0; i < DATA_SIZE; i++) printf("--");
    printf("\n\n");
    usleep(120000); // Frame delay
}

// Mutates the AST node dynamically every time a swap operation occurs
void mutate_ast_and_swap(ASTNode* node, int idxA, int idxB, int* pulse) {
    // Perform standard swap
    int temp = data[idxA];
    data[idxA] = data[idxB];
    data[idxB] = temp;

    // Self-modification: alter AST node properties based on data state
    node->operand = (node->operand + data[idxA]) % 100;
    if (node->left) {
        node->left->operand ^= data[idxB];
    }
    (*pulse)++;
}

// Executes the sorting routine via the self-modifying AST engine
void execute_ast(ASTNode* root, int* pulse) {
    int swapped;
    do {
        swapped = 0;
        for (int i = 0; i < DATA_SIZE - 1; i++) {
            render_landscape(*pulse);
            if (data[i] > data[i+1]) {
                // Trigger AST mutation and data swap
                mutate_ast_and_swap(root, i, i + 1, pulse);
                swapped = 1;
            }
        }
    } while (swapped);
}

// Factory to create AST nodes
ASTNode* create_node(OpType op, int operand) {
    ASTNode* node = (ASTNode*)malloc(sizeof(ASTNode));
    node->op = op;
    node->operand = operand;
    node->left = NULL;
    node->right = NULL;
    return node;
}

int main() {
    // Construct the initial program AST
    ASTNode* root = create_node(OP_SWAP_MUTATE, 13);
    root->left = create_node(OP_PUSH, 42);
    root->right = create_node(OP_PRINT, 0);

    int mutation_pulse = 0;

    // Run sorting algorithm backed by self-modifying code
    execute_ast(root, &mutation_pulse);

    // Final output rendering
    render_landscape(mutation_pulse);
    printf("Sorting completed. AST successfully self-modified %d times.\n", mutation_pulse);

    // Cleanup memory
    free(root->left);
    free(root->right);
    free(root);

    return 0;
}