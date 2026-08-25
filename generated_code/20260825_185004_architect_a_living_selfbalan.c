#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#define MAX_DEPTH 6
#define CANVAS_WIDTH 80
#define CANVAS_HEIGHT 24

// Data structure for the Bonsai Tree Node (AVL-based self-balancing concept)
typedef struct Node {
    int id;
    int sentiment_score; // Negative = error/stress, Positive = recovery/growth
    int height;
    struct Node *left;
    struct Node *right;
} Node;

// Simulated system error logs with inherent sentiment values
typedef struct {
    const char *log_message;
    int sentiment; // Negative value = bad log (needs pruning/stress), Positive = good (grows branch)
} LogEntry;

static LogEntry log_pool[] = {
    {"[CRITICAL] Out of memory exception on heap allocation", -3},
    {"[ERROR] Database connection timed out after 5000ms", -2},
    {"[WARN] CPU temperature reaching thermal limit: 85C", -1},
    {"[INFO] Garbage collection completed successfully", +1},
    {"[INFO] Health check passed: All services nominal", +2},
    {"[SUCCESS] Auto-scaler expanded cluster capacity (+4 nodes)", +3},
    {"[FATAL] Kernel panic - segment violation at 0x000000", -4},
    {"[RECOVERY] Failover node took over primary role", +2}
};

int max(int a, int b) {
    return (a > b) ? a : b;
}

int getHeight(Node *n) {
    return n ? n->height : 0;
}

int getBalance(Node *n) {
    return n ? getHeight(n->left) - getHeight(n->right) : 0;
}

Node* createNode(int id, int sentiment) {
    Node *n = (Node*)malloc(sizeof(Node));
    n->id = id;
    n->sentiment_score = sentiment;
    n->height = 1;
    n->left = NULL;
    n->right = NULL;
    return n;
}

Node* rotateRight(Node *y) {
    Node *x = y->left;
    Node *T2 = x->right;

    x->right = y;
    y->left = T2;

    y->height = max(getHeight(y->left), getHeight(y->right)) + 1;
    x->height = max(getHeight(x->left), getHeight(x->right)) + 1;

    return x;
}

Node* rotateLeft(Node *x) {
    Node *y = x->right;
    Node *T2 = y->left;

    y->left = x;
    x->right = T2;

    x->height = max(getHeight(x->left), getHeight(x->right)) + 1;
    y->height = max(getHeight(y->left), getHeight(y->right)) + 1;

    return y;
}

// Self-balancing tree insertion driven by log sentiment data
Node* insert(Node *node, int id, int sentiment) {
    if (node == NULL) return createNode(id, sentiment);

    if (id < node->id)
        node->left = insert(node->left, id, sentiment);
    else if (id > node->id)
        node->right = insert(node->right, id, sentiment);
    else
        return node;

    node->height = 1 + max(getHeight(node->left), getHeight(node->right));
    int balance = getBalance(node);

    // Self-balancing AVL rotations
    if (balance > 1 && id < node->left->id)
        return rotateRight(node);
    if (balance < -1 && id > node->right->id)
        return rotateLeft(node);
    if (balance > 1 && id > node->left->id) {
        node->left = rotateLeft(node->left);
        return rotateRight(node);
    }
    if (balance < -1 && id < node->right->id) {
        node->right = rotateRight(node->right);
        return rotateLeft(node);
    }

    return node;
}

Node* minValueNode(Node *node) {
    Node *current = node;
    while (current->left != NULL)
        current = current->left;
    return current;
}

// Pruning nodes when error sentiment drops below critical thresholds
Node* prune(Node *root, int id) {
    if (root == NULL) return root;

    if (id < root->id)
        root->left = prune(root->left, id);
    else if (id > root->id)
        root->right = prune(root->right, id);
    else {
        if ((root->left == NULL) || (root->right == NULL)) {
            Node *temp = root->left ? root->left : root->right;
            if (temp == NULL) {
                temp = root;
                root = NULL;
            } else
                *root = *temp;
            free(temp);
        } else {
            Node *temp = minValueNode(root->right);
            root->id = temp->id;
            root->sentiment_score = temp->sentiment_score;
            root->right = prune(root->right, temp->id);
        }
    }

    if (root == NULL) return root;

    root->height = 1 + max(getHeight(root->left), getHeight(root->right));
    int balance = getBalance(root);

    if (balance > 1 && getBalance(root->left) >= 0)
        return rotateRight(root);
    if (balance > 1 && getBalance(root->left) < 0) {
        root->left = rotateLeft(root->left);
        return rotateRight(root);
    }
    if (balance < -1 && getBalance(root->right) <= 0)
        return rotateLeft(root);
    if (balance < -1 && getBalance(root->right) > 0) {
        root->right = rotateRight(root->right);
        return rotateLeft(root);
    }

    return root;
}

void freeTree(Node *root) {
    if (root != NULL) {
        freeTree(root->left);
        freeTree(root->right);
        free(root);
    }
}

// ASCII Rendering Canvas
char canvas[CANVAS_HEIGHT][CANVAS_WIDTH];

void clearCanvas() {
    for (int r = 0; r < CANVAS_HEIGHT; r++) {
        for (int c = 0; c < CANVAS_WIDTH; c++) {
            canvas[r][c] = ' ';
        }
    }
}

// Recursive projection of the tree nodes into a natural organic bonsai structure
void projectBonsai(Node *node, int row, int col, int branch_len) {
    if (!node || row < 0 || row >= CANVAS_HEIGHT - 3 || col <= 2 || col >= CANVAS_WIDTH - 3) return;

    // Foliage or trunk rendering based on depth and node sentiment
    char leaf = (node->sentiment_score >= 0) ? '*' : 'x';
    if (node->left == NULL && node->right == NULL) {
        canvas[row][col] = (node->sentiment_score > 0) ? '@' : '!'; // Blossoms or dead leaves
    } else {
        canvas[row][col] = '|';
    }

    // Branch left (negative sentiment skews branches left, positive skews right)
    if (node->left) {
        int next_col = col - branch_len;
        int next_row = row - 2;
        for (int i = 1; i <= branch_len; i++) {
            int r = row - (i * 2 / (branch_len > 0 ? branch_len : 1));
            int c = col - i;
            if (r >= 0 && r < CANVAS_HEIGHT && c >= 0 && c < CANVAS_WIDTH)
                canvas[r][c] = '/';
        }
        projectBonsai(node->left, next_row, next_col, max(1, branch_len - 1));
    }

    // Branch right
    if (node->right) {
        int next_col = col + branch_len;
        int next_row = row - 2;
        for (int i = 1; i <= branch_len; i++) {
            int r = row - (i * 2 / (branch_len > 0 ? branch_len : 1));
            int c = col + i;
            if (r >= 0 && r < CANVAS_HEIGHT && c >= 0 && c < CANVAS_WIDTH)
                canvas[r][c] = '\\';
        }
        projectBonsai(node->right, next_row, next_col, max(1, branch_len - 1));
    }
}

void drawPotAndBase() {
    int pot_row = CANVAS_HEIGHT - 3;
    // Pot rim
    for (int c = CANVAS_WIDTH / 2 - 12; c <= CANVAS_WIDTH / 2 + 12; c++) {
        canvas[pot_row][c] = '=';
    }
    // Pot body
    canvas[pot_row + 1][CANVAS_WIDTH / 2 - 10] = '\\';
    for (int c = CANVAS_WIDTH / 2 - 9; c <= CANVAS_WIDTH / 2 + 9; c++) {
        canvas[pot_row + 1][c] = '_';
    }
    canvas[pot_row + 1][CANVAS_WIDTH / 2 + 10] = '/';
}

void renderScreen(const char* current_log, int sentiment) {
    printf("\033[H\033[J"); // Clear ANSI terminal screen
    printf("==================== DIGITAL BONSAI LOG MONITOR ====================\n");
    printf("LIVE FEED: %s\n", current_log);
    printf("SENTIMENT IMPACT: [%s%d\033[0m]\n", 
           sentiment < 0 ? "\033[31m" : "\033[32m", sentiment);
    printf("--------------------------------------------------------------------\n");

    for (int r = 0; r < CANVAS_HEIGHT; r++) {
        for (int c = 0; c < CANVAS_WIDTH; c++) {
            char ch = canvas[r][c];
            // Colorizing the rendering output dynamically
            if (ch == '@' || ch == '*') {
                printf("\033[32m%c\033[0m", ch); // Green leaves/blossoms
            } else if (ch == '!') {
                printf("\033[31m%c\033[0m", ch); // Red error leaves
            } else if (ch == '/' || ch == '\\' || ch == '|') {
                printf("\033[33m%c\033[0m", ch); // Brown wood
            } else {
                putchar(ch);
            }
        }
        putchar('\n');
    }
    printf("====================================================================\n");
    printf("Legend: (@/*) Healthy Leaf/Bloom | (!) Stressed Node | (=/\\) Pot\n");
}

int main() {
    srand(time(NULL));
    Node *root = NULL;
    int node_counter = 0;

    // Initialize root trunk
    root = insert(root, 50, 0);

    for (int cycle = 0; cycle < 30; cycle++) {
        clearCanvas();

        // Pick a random log entry from the real-time simulation pool
        int log_idx = rand() % (sizeof(log_pool) / sizeof(log_pool[0]));
        LogEntry entry = log_pool[log_idx];

        // Sentiment dictates tree evolution (Growth vs Pruning)
        if (entry.sentiment > 0) {
            // Positive sentiment grows new nodes
            int id = rand() % 100;
            root = insert(root, id, entry.sentiment);
            node_counter++;
        } else {
            // Negative sentiment prunes weak nodes to maintain balance under stress
            int prune_id = rand() % 100;
            root = prune(root, prune_id);
        }

        // Draw organic trunk base stem
        int trunk_col = CANVAS_WIDTH / 2;
        canvas[CANVAS_HEIGHT - 4][trunk_col] = '|';
        canvas[CANVAS_HEIGHT - 5][trunk_col] = '|';

        // Project the balance tree into the ASCII Bonsai Canvas
        projectBonsai(root, CANVAS_HEIGHT - 6, trunk_col, 6);
        drawPotAndBase();

        // Display frame
        renderScreen(entry.log_message, entry.sentiment);

        usleep(800000); // Wait 800ms between frames
    }

    freeTree(root);
    return 0;
}