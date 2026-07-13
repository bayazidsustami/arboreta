#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

#define WIDTH  800
#define HEIGHT 800
#define CELLS  100   // grid size (100x100)
#define FRAMES 200   // number of animation frames

// ---------- simple MIDI parsing (only Note On events) ----------
typedef struct {
    uint8_t *data;
    size_t   len;
    size_t   pos;
} MidiStream;

static uint32_t read_varlen(MidiStream *ms) {
    uint32_t v = 0;
    uint8_t  b;
    do {
        b = ms->data[ms->pos++];
        v = (v << 7) | (b & 0x7F);
    } while (b & 0x80);
    return v;
}

static uint8_t read_byte(MidiStream *ms) {
    return ms->pos < ms->len ? ms->data[ms->pos++] : 0;
}

// returns an array of note numbers (0‑127). Caller must free().
static uint8_t *extract_notes(const char *filename, size_t *out_cnt) {
    FILE *f = fopen(filename, "rb");
    if (!f) return NULL;

    fseek(f, 0, SEEK_END);
    long sz = ftell(f);
    fseek(f, 0, SEEK_SET);
    uint8_t *buf = malloc(sz);
    fread(buf, 1, sz, f);
    fclose(f);

    MidiStream ms = {buf, (size_t)sz, 0};

    // skip header chunk (14 bytes)
    if (ms.pos+14 > ms.len) { free(buf); return NULL; }
    ms.pos += 14;

    // locate first track chunk
    while (ms.pos+8 <= ms.len) {
        if (memcmp(&ms.data[ms.pos], "MTrk", 4) == 0) break;
        ms.pos++;
    }
    if (ms.pos+8 > ms.len) { free(buf); return NULL; }
    ms.pos += 4;                         // "MTrk"
    uint32_t trklen = (ms.data[ms.pos]<<24)|(ms.data[ms.pos+1]<<16)|(ms.data[ms.pos+2]<<8)|ms.data[ms.pos+3];
    ms.pos += 4;
    size_t trk_end = ms.pos + trklen;

    uint8_t running_status = 0;
    uint8_t *notes = malloc(1024);
    size_t  note_cnt = 0, note_cap = 1024;

    while (ms.pos < trk_end) {
        read_varlen(&ms);                     // delta time (ignore)
        uint8_t b = read_byte(&ms);
        if (b & 0x80) {                        // status byte
            running_status = b;
            b = read_byte(&ms);
        }
        uint8_t type = running_status & 0xF0;
        if (type == 0x90 && b != 0) {          // Note On with velocity >0
            uint8_t note = b;
            if (note_cnt == note_cap) {
                note_cap *= 2;
                notes = realloc(notes, note_cap);
            }
            notes[note_cnt++] = note;
        } else {
            // skip one data byte (most events have 2 bytes)
            read_byte(&ms);
        }
    }
    free(buf);
    *out_cnt = note_cnt;
    return notes;
}

// ---------- cellular automaton ----------
typedef struct {
    uint8_t cur[CELLS][CELLS];
    uint8_t nxt[CELLS][CELLS];
} Grid;

static void init_grid(Grid *g) {
    for (int y=0;y<CELLS;y++)
        for (int x=0;x<CELLS;x++)
            g->cur[y][x] = (rand() & 1);
}

static uint8_t rule_from_note(uint8_t n) {
    // map MIDI note (0‑127) to a 8‑bit rule (like Wolfram's elementary CA)
    return (n * 0x12) & 0xFF;
}

// simple 2‑D self‑modifying rule: sum of 8 neighbours + rule byte decides next state
static void step(Grid *g, uint8_t rule) {
    for (int y=0;y<CELLS;y++) {
        for (int x=0;x<CELLS;x++) {
            int sum = 0;
            for (int dy=-1;dy<=1;dy++) for (int dx=-1;dx<=1;dx++) {
                if (dx==0 && dy==0) continue;
                int nx = (x+dx+CELLS)%CELLS;
                int ny = (y+dy+CELLS)%CELLS;
                sum += g->cur[ny][nx];
            }
            // use rule byte as a lookup table (8 bits)
            uint8_t bit = (rule >> (sum%8)) & 1;
            g->nxt[y][x] = bit;
        }
    }
    // swap buffers
    memcpy(g->cur, g->nxt, sizeof(g->cur));
}

// ---------- SVG generation ----------
static void svg_header(FILE *out) {
    fprintf(out,
        "<?xml version=\"1.0\" standalone=\"no\"?>\n"
        "<!DOCTYPE svg PUBLIC \"-//W3C//DTD SVG 1.1//EN\" "
        "\"http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd\">\n"
        "<svg width=\"%d\" height=\"%d\" viewBox=\"0 0 %d %d\" "
        "xmlns=\"http://www.w3.org/2000/svg\" version=\"1.1\">\n",
        WIDTH, HEIGHT, WIDTH, HEIGHT);
    // background
    fprintf(out, "<rect width=\"100%%\" height=\"100%%\" fill=\"black\" />\n");
}

static void svg_footer(FILE *out) {
    fprintf(out, "</svg>\n");
}

// map note to hue (0‑360)
static double hue_from_note(uint8_t n) {
    return (n % 12) * 30.0; // 12 notes => 30° steps
}

// convert hue to rgb (simple)
static void hsv_to_rgb(double h, double s, double v, int *r, int *g, int *b) {
    double c = v * s;
    double x = c * (1 - fabs(fmod(h/60.0,2)-1));
    double m = v - c;
    double rp=0,gp=0,bp=0;
    if (h<60){rp=c;gp=x;}
    else if (h<120){rp=x;gp=c;}
    else if (h<180){gp=c;bp=x;}
    else if (h<240){gp=x;bp=c;}
    else if (h<300){rp=c;bp=x;}
    else {rp=x;bp=c;}
    *r = (int)((rp+m)*255);
    *g = (int)((gp+m)*255);
    *b = (int)((bp+m)*255);
}

// write one frame as a <g> element with animation attributes
static void svg_frame(FILE *out, Grid *g, uint8_t note, int frame) {
    double hue = hue_from_note(note);
    int r,gc,b;
    hsv_to_rgb(hue,0.7,0.9,&r,&gc,&b);
    char color[32];
    snprintf(color,sizeof(color),"rgb(%d,%d,%d)",r,gc,b);

    double cell_w = (double)WIDTH / CELLS;
    double cell_h = (double)HEIGHT / CELLS;

    fprintf(out,
        "<g id=\"f%d\" visibility=\"hidden\">\n", frame);
    for (int y=0;y<CELLS;y++) {
        for (int x=0;x<CELLS;x++) {
            if (g->cur[y][x]) {
                double cx = x * cell_w;
                double cy = y * cell_h;
                fprintf(out,
                    "<rect x=\"%g\" y=\"%g\" width=\"%g\" height=\"%g\" fill=\"%s\" />\n",
                    cx, cy, cell_w, cell_h, color);
            }
        }
    }
    fprintf(out, "</g>\n");
}

// create animation that cycles through frame groups
static void svg_animation(FILE *out, int total_frames) {
    fprintf(out,
        "<animate attributeName=\"visibility\" values=\"");
    for (int i=0;i<total_frames;i++) {
        for (int j=0;j<total_frames;j++) {
            fprintf(out, "hidden;");
        }
        fprintf(out, "visible;");
    }
    // final hide
    fprintf(out, "hidden\" dur=\"%gs\" repeatCount=\"indefinite\" />\n",
        (total_frames*0.05));
}

// ---------- main ----------
int main(int argc, char *argv[]) {
    if (argc!=2) {
        fprintf(stderr,"Usage: %s music.mid\n",argv[0]);
        return 1;
    }
    size_t note_cnt;
    uint8_t *notes = extract_notes(argv[1],&note_cnt);
    if (!notes||note_cnt==0) {
        fprintf(stderr,"Failed to read notes.\n");
        return 1;
    }

    Grid g;
    init_grid(&g);

    FILE *out = fopen("output.svg","w");
    if (!out) { perror("fopen"); return 1; }

    svg_header(out);

    // Create frames
    for (int f=0; f<FRAMES; f++) {
        uint8_t note = notes[f % note_cnt];
        uint8_t rule = rule_from_note(note);
        step(&g, rule);
        svg_frame(out, &g, note, f);
    }

    // Simple visibility animation (show each frame for 0.05s)
    fprintf(out,
        "<script type=\"text/ecmascript\"><![CDATA[\n"
        "var frames=%d;var cur=0;function show(){\n"
        "for(var i=0;i<frames;i++)document.getElementById('f'+i).setAttribute('visibility','hidden');\n"
        "document.getElementById('f'+cur).setAttribute('visibility','visible');\n"
        "cur=(cur+1)%frames;setTimeout(show,50);\n}\n"
        "window.onload=show;\n"
        "]]></script>\n", FRAMES);

    svg_footer(out);
    fclose(out);
    free(notes);
    return 0;
}