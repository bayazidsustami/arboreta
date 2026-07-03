#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>
#include <pthread.h>
#include <unistd.h>
#include <curl/curl.h>
#include <GL/glut.h>
#include "RtMidi.h"   // Requires RtMidi library

/* -------------------------------------------------
   Simple data structures
   ------------------------------------------------- */
#define MAX_SYM 64
#define CA_STEPS 12
#define LATTICE_SIZE 8   // 8x8x8 lattice of tetrahedra

typedef struct {
    char symbol[8];
    double price;
    int digits[10];   // decimal digits of price * 100 (2 decimal places)
} Stock;

typedef struct {
    int cells[LATTICE_SIZE][LATTICE_SIZE][LATTICE_SIZE];
    float hue[LATTICE_SIZE][LATTICE_SIZE][LATTICE_SIZE];
} Lattice;

/* -------------------------------------------------
   Global state (for demo purposes)
   ------------------------------------------------- */
static Stock gStocks[MAX_SYM];
static int gStockCount = 0;
static Lattice gLattice;
static RtMidiOut *gMidi = NULL;
static pthread_mutex_t gMutex = PTHREAD_MUTEX_INITIALIZER;

/* -------------------------------------------------
   Helper: fetch price via a dummy HTTP API (placeholder)
   ------------------------------------------------- */
static size_t curl_write(void *ptr, size_t size, size_t nmemb, void *stream) {
    size_t realsize = size * nmemb;
    strncat((char*)stream, (char*)ptr, realsize);
    return realsize;
}
static double fetch_price(const char *symbol) {
    // In a real program use a proper finance API.
    // Here we simulate with a pseudo‑random price.
    srand((unsigned)time(NULL) ^ (unsigned)symbol[0]);
    return 100.0 + (rand() % 5000) / 10.0; // 100.0 – 600.0
}

/* -------------------------------------------------
   Convert price to rule set (12‑step cellular automaton)
   ------------------------------------------------- */
static void price_to_rule(const Stock *s, int rule[CA_STEPS]) {
    // take first 12 digits of price*100 (ignore decimal point)
    char buf[32];
    snprintf(buf, sizeof(buf), "%09.0f", s->price * 100);
    for (int i = 0; i < CA_STEPS; ++i) {
        rule[i] = (buf[i] - '0') % 2; // binary rule (0/1)
    }
}

/* -------------------------------------------------
   Run 1‑D cellular automaton on a line of cells
   ------------------------------------------------- */
static void run_ca(const int *rule, int *line, int len) {
    int next[len];
    for (int i = 0; i < len; ++i) {
        int left  = line[(i - 1 + len) % len];
        int self  = line[i];
        int right = line[(i + 1) % len];
        int idx = (left << 2) | (self << 1) | right;
        next[i] = rule[idx % CA_STEPS]; // wrap rule length
    }
    memcpy(line, next, len * sizeof(int));
}

/* -------------------------------------------------
   Update lattice based on stocks
   ------------------------------------------------- */
static void update_lattice(void) {
    pthread_mutex_lock(&gMutex);
    // clear
    memset(&gLattice, 0, sizeof(gLattice));

    for (int s = 0; s < gStockCount; ++s) {
        int rule[CA_STEPS];
        price_to_rule(&gStocks[s], rule);

        // initialise a 1‑D line along X for this stock
        int line[LATTICE_SIZE];
        for (int i = 0; i < LATTICE_SIZE; ++i) line[i] = rand() % 2;

        // run CA CA_STEPS times, deposit result into lattice slice
        for (int step = 0; step < CA_STEPS; ++step) {
            run_ca(rule, line, LATTICE_SIZE);
            for (int x = 0; x < LATTICE_SIZE; ++x) {
                int y = (s + step) % LATTICE_SIZE;
                int z = (s * step) % LATTICE_SIZE;
                gLattice.cells[x][y][z] = line[x];
                // hue encodes volatility (price change)
                gLattice.hue[x][y][z] = (float)fabs(gStocks[s].price - fetch_price(gStocks[s].symbol)) / 100.0f;
            }
        }
    }
    pthread_mutex_unlock(&gMutex);
}

/* -------------------------------------------------
   OpenGL drawing of colored tetrahedra
   ------------------------------------------------- */
static void draw_tetra(float cx, float cy, float cz, float hue) {
    const float size = 0.4f;
    float r = hue, g = 1.0f - hue, b = 0.5f;
    glColor3f(r, g, b);
    glBegin(GL_TRIANGLES);
    // four faces
    glVertex3f(cx, cy, cz + size);
    glVertex3f(cx - size, cy - size, cz - size);
    glVertex3f(cx + size, cy - size, cz - size);

    glVertex3f(cx, cy, cz + size);
    glVertex3f(cx + size, cy - size, cz - size);
    glVertex3f(cx, cy + size, cz - size);

    glVertex3f(cx, cy, cz + size);
    glVertex3f(cx, cy + size, cz - size);
    glVertex3f(cx - size, cy - size, cz - size);

    glVertex3f(cx - size, cy - size, cz - size);
    glVertex3f(cx + size, cy - size, cz - size);
    glVertex3f(cx, cy + size, cz - size);
    glEnd();
}
static void display(void) {
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glLoadIdentity();
    glTranslatef(-4.0f, -4.0f, -20.0f);
    glRotatef(30, 1, 0, 0);
    glRotatef((float)glutGet(GLUT_ELAPSED_TIME) / 100.0f, 0, 1, 0);

    pthread_mutex_lock(&gMutex);
    for (int x = 0; x < LATTICE_SIZE; ++x)
        for (int y = 0; y < LATTICE_SIZE; ++y)
            for (int z = 0; z < LATTICE_SIZE; ++z)
                if (gLattice.cells[x][y][z])
                    draw_tetra(x, y, z, gLattice.hue[x][y][z]);
    pthread_mutex_unlock(&gMutex);

    glutSwapBuffers();
}
static void idle(void) {
    update_lattice();
    glutPostRedisplay();
}

/* -------------------------------------------------
   MIDI handling – each active tetrahedron sends a note
   ------------------------------------------------- */
static void send_midi_notes(void) {
    pthread_mutex_lock(&gMutex);
    std::vector<unsigned char> message(3);
    for (int x = 0; x < LATTICE_SIZE; ++x)
        for (int y = 0; y < LATTICE_SIZE; ++y)
            for (int z = 0; z < LATTICE_SIZE; ++z)
                if (gLattice.cells[x][y][z]) {
                    int note = 60 + (x + y + z) % 12; // map position to pitch
                    message[0] = 0x90;               // Note on, channel 0
                    message[1] = note;
                    message[2] = 100;                // velocity
                    gMidi->sendMessage(&message);
                }
    pthread_mutex_unlock(&gMutex);
}

/* -------------------------------------------------
   Thread that periodically updates stock data & MIDI
   ------------------------------------------------- */
static void *background_thread(void *arg) {
    while (1) {
        // update stock list (for demo we use a static set)
        const char *symbols[] = {"AAPL","MSFT","GOOG","AMZN","FB","JPM","V","NVDA"};
        gStockCount = sizeof(symbols)/sizeof(symbols[0]);
        for (int i=0;i<gStockCount;i++) {
            strncpy(gStocks[i].symbol, symbols[i], sizeof(gStocks[i].symbol)-1);
            gStocks[i].price = fetch_price(symbols[i]);
        }
        // send MIDI based on current lattice
        send_midi_notes();
        sleep(2);
    }
    return NULL;
}

/* -------------------------------------------------
   Main – initialise OpenGL, MIDI, launch threads
   ------------------------------------------------- */
int main(int argc, char **argv) {
    // initialise MIDI
    try {
        gMidi = new RtMidiOut();
        if (gMidi->getPortCount() == 0) {
            fprintf(stderr, "No MIDI output ports available.\n");
            delete gMidi;
            gMidi = NULL;
        } else {
            gMidi->openPort(0);
        }
    } catch (RtMidiError &error) {
        error.printMessage();
        return 1;
    }

    pthread_t th;
    pthread_create(&th, NULL, background_thread, NULL);

    // initialise OpenGL/GLUT
    glutInit(&argc, argv);
    glutInitDisplayMode(GLUT_DOUBLE | GLUT_RGB | GLUT_DEPTH);
    glutInitWindowSize(800, 600);
    glutCreateWindow("Stock‑CA 3D Lattice");
    glEnable(GL_DEPTH_TEST);
    glutDisplayFunc(display);
    glutIdleFunc(idle);
    glutMainLoop();

    // cleanup
    if (gMidi) delete gMidi;
    return 0;
}