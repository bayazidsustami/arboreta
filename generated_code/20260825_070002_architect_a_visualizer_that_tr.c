#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>
#include <GL/glut.h>

#define MAX_COMMITS 128
#define MAX_PANELS 16

typedef struct {
    float r, g, b;
    float x1, y1, x2, y2, x3, y3;
} GlassPanel;

typedef struct {
    char hash[41];
    char author[64];
    int panel_count;
    GlassPanel panels[MAX_PANELS];
    float rotation_offset;
} StainedGlassWindow;

StainedGlassWindow windows[MAX_COMMITS];
int commit_count = 0;
int current_window = 0;
float global_rotation = 0.0f;
float pulse_time = 0.0f;

/* Hash string into a pseudo-random floating point value in [0, 1] */
float hash_to_float(const char *hash, int offset) {
    unsigned int val = 0;
    for (int i = 0; i < 8 && hash[offset + i]; ++i) {
        val = (val << 4) ^ (val >> 28) ^ hash[offset + i];
    }
    return (float)(val % 10000) / 10000.0f;
}

/* Parse git log output to generate stained-glass window geometry & color palette */
void generate_stained_glass() {
    FILE *fp = popen("git log --pretty=format:\"%H|%an\" -n 64 2>/dev/null", "r");
    char line[256];

    if (!fp) return;

    while (fgets(line, sizeof(line), fp) && commit_count < MAX_COMMITS) {
        StainedGlassWindow *w = &windows[commit_count];
        char *token = strtok(line, "|");
        if (!token) continue;
        
        strncpy(w->hash, token, 40);
        w->hash[40] = '\0';
        
        token = strtok(NULL, "\n");
        if (token) strncpy(w->author, token, 63);

        /* Generate panels based on commit diff hash bytes */
        w->panel_count = 6 + (int)(hash_to_float(w->hash, 0) * 10);
        w->rotation_offset = hash_to_float(w->hash, 4) * 360.0f;

        for (int i = 0; i < w->panel_count; ++i) {
            GlassPanel *p = &w->panels[i];
            float angle1 = (i * 2.0f * M_PI) / w->panel_count;
            float angle2 = ((i + 1) * 2.0f * M_PI) / w->panel_count;

            float r1 = 0.2f + 0.3f * hash_to_float(w->hash, (i * 2) % 30);
            float r2 = 0.6f + 0.3f * hash_to_float(w->hash, (i * 2 + 1) % 30);

            p->x1 = 0.0f; p->y1 = 0.0f;
            p->x2 = cosf(angle1) * r1; p->y2 = sinf(angle1) * r1;
            p->x3 = cosf(angle2) * r2; p->y3 = sinf(angle2) * r2;

            /* Chromatic spectrum based on hash bytes */
            p->r = hash_to_float(w->hash, (i + 1) % 32);
            p->g = hash_to_float(w->hash, (i + 3) % 32);
            p->b = hash_to_float(w->hash, (i + 5) % 32);
        }
        commit_count++;
    }
    pclose(fp);

    /* Fallback synthetic window if not inside a live Git repository */
    if (commit_count == 0) {
        commit_count = 1;
        StainedGlassWindow *w = &windows[0];
        strcpy(w->hash, "0000000000000000000000000000000000000000");
        strcpy(w->author, "No Git Repo Found (Demo Mode)");
        w->panel_count = 12;
        for (int i = 0; i < w->panel_count; ++i) {
            GlassPanel *p = &w->panels[i];
            float angle1 = (i * 2.0f * M_PI) / w->panel_count;
            float angle2 = ((i + 1) * 2.0f * M_PI) / w->panel_count;
            p->x1 = 0.0f; p->y1 = 0.0f;
            p->x2 = cosf(angle1) * 0.8f; p->y2 = sinf(angle1) * 0.8f;
            p->x3 = cosf(angle2) * 0.8f; p->y3 = sinf(angle2) * 0.8f;
            p->r = 0.5f + 0.5f * sinf(i);
            p->g = 0.5f + 0.5f * cosf(i * 2);
            p->b = 0.8f;
        }
    }
}

/* Render OpenGL stained-glass illuminated by dynamic light source */
void display() {
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glLoadIdentity();

    StainedGlassWindow *w = &windows[current_window];
    
    glPushMatrix();
    glRotatef(global_rotation + w->rotation_offset, 0.0f, 0.0f, 1.0f);
    float glow = 0.8f + 0.2f * sinf(pulse_time * 3.0f);

    /* Render translucent colored glass facets */
    glBegin(GL_TRIANGLES);
    for (int i = 0; i < w->panel_count; ++i) {
        GlassPanel *p = &w->panels[i];
        glColor4f(p->r * glow, p->g * glow, p->b * glow, 0.75f);
        glVertex2f(p->x1, p->y1);
        glVertex2f(p->x2, p->y2);
        glVertex2f(p->x3, p->y3);
    }
    glEnd();

    /* Render dark lead came framing lines */
    glLineWidth(3.0f);
    glColor4f(0.05f, 0.05f, 0.08f, 1.0f);
    glBegin(GL_LINES);
    for (int i = 0; i < w->panel_count; ++i) {
        GlassPanel *p = &w->panels[i];
        glVertex2f(p->x1, p->y1); glVertex2f(p->x2, p->y2);
        glVertex2f(p->x2, p->y2); glVertex2f(p->x3, p->y3);
        glVertex2f(p->x3, p->y3); glVertex2f(p->x1, p->y1);
    }
    glEnd();
    glPopMatrix();

    glutSwapBuffers();
}

void timer(int val) {
    global_rotation += 0.2f;
    pulse_time += 0.016f;
    glutPostRedisplay();
    glutTimerFunc(16, timer, 0);
}

void keyboard(unsigned char key, int x, int y) {
    if (key == 27) exit(0); /* ESC */
    if (key == ' ') {
        current_window = (current_window + 1) % commit_count;
        printf("Commit [%d/%d]: %s (By %s)\n", current_window + 1, commit_count, windows[current_window].hash, windows[current_window].author);
    }
}

int main(int argc, char **argv) {
    printf("=== Git Stained-Glass Window Visualizer ===\n");
    printf("Controls: SPACE to cycle commits, ESC to exit.\n");

    generate_stained_glass();

    glutInit(&argc, argv);
    glutInitDisplayMode(GLUT_DOUBLE | GLUT_RGB | GLUT_DEPTH);
    glutInitWindowSize(800, 800);
    glutCreateWindow("Git Commit Stained-Glass Visualizer");

    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glClearColor(0.02f, 0.02f, 0.04f, 1.0f);

    glutDisplayFunc(display);
    glutKeyboardFunc(keyboard);
    glutTimerFunc(0, timer, 0);

    glutMainLoop();
    return 0;
}