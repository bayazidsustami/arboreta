#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>

/*--------------------------------------------------------------
 * Simple self‑contained Mandelbrot GIF generator.
 *   - No external libs, only stdio/stdlib.
 *   - Audio/sentiment, note mapping and self‑modifying fractal are
 *     stubbed with deterministic pseudo‑random data to keep the
 *     program self‑contained.
 *   - The program reads stdin (expects raw ASCII words) and
 *     produces an animated GIF to stdout.
 *--------------------------------------------------------------*/

#define WIDTH  320
#define HEIGHT 240
#define FRAMES 60          /* length of animation */
#define MAX_ITER 256
#define PALETTE_SIZE 256

/* GIF constants */
static const unsigned char gif_header[] = "GIF89a";
static const unsigned char gif_trailer = ';';
static const unsigned char gif_graphic_control_ext[] = {
    0x21,0xF9,0x04,0x00,0x00,0x00,0x00,0x00
};

/* Global state */
unsigned char palette[PALETTE_SIZE*3];
unsigned char *framebuf;

/* Very naive pseudo‑sentiment analyzer: counts happy words */
int sentiment_score(const char *word) {
    static const char *happy[] = {"joy","happy","love","yay","great","awesome",NULL};
    for (int i=0; happy[i]; ++i)
        if (strstr(word, happy[i])) return 1;
    return -1;
}

/* Map sentiment to palette offset (0..255) */
int palette_offset_from_sentiment(int score) {
    static int hue = 0;
    hue = (hue + (score>0?5:-5) + 256) % 256;
    return hue;
}

/* Fill palette with a smooth hue gradient */
void build_palette(int offset) {
    for (int i=0;i<PALETTE_SIZE;i++) {
        int v = (i + offset) & 255;
        palette[i*3+0] = (unsigned char)((sin(v*0.024)+1)*127.5);   /* R */
        palette[i*3+1] = (unsigned char)((sin(v*0.024+2)+1)*127.5);/* G */
        palette[i*3+2] = (unsigned char)((sin(v*0.024+4)+1)*127.5);/* B */
    }
}

/* Render one Mandelbrot frame with a time‑varying zoom/center */
void render_frame(double cx, double cy, double zoom) {
    for (int y=0; y<HEIGHT; ++y) {
        for (int x=0; x<WIDTH; ++x) {
            double zx = (x - WIDTH/2.0) * (4.0/WIDTH) / zoom + cx;
            double zy = (y - HEIGHT/2.0) * (4.0/WIDTH) / zoom + cy;
            int i;
            for (i=0; i<MAX_ITER; ++i) {
                double zzx = zx*zx - zy*zy + cx;
                double zzy = 2.0*zx*zy + cy;
                zx = zzx; zy = zzy;
                if (zx*zx + zy*zy > 4.0) break;
            }
            framebuf[y*WIDTH + x] = (unsigned char)i;
        }
    }
}

/* Write a single GIF frame (image descriptor + LZW min code size + data) */
void write_gif_frame(FILE *out) {
    unsigned char img_desc[10] = {
        0x2C,                     /* image separator */
        0,0,0,0,                  /* left, top */
        WIDTH & 0xFF, WIDTH>>8,
        HEIGHT & 0xFF, HEIGHT>>8,
        0x80 | 0x00 | 0x07        /* LCT flag + interlace 0 + LCT size 7 */
    };
    fwrite(img_desc,1,sizeof(img_desc),out);
    fwrite(palette,1,PALETTE_SIZE*3,out);
    fputc(8, out);               /* LZW Minimum Code Size */
    /* Very naive "no compression": output each pixel as a sub‑block */
    size_t pos = 0, total = WIDTH*HEIGHT;
    while (pos < total) {
        unsigned char block = (total - pos > 255) ? 255 : (unsigned char)(total - pos);
        fputc(block, out);
        fwrite(framebuf+pos,1,block,out);
        pos += block;
    }
    fputc(0, out);               /* block terminator */
}

/* Main driver */
int main(void) {
    /* Allocate frame buffer */
    framebuf = malloc(WIDTH * HEIGHT);
    if (!framebuf) return 1;

    /* Initialize GIF header */
    fwrite(gif_header,1,6,stdout);
    /* Logical Screen Descriptor */
    unsigned char lsd[7] = {
        WIDTH & 0xFF, WIDTH>>8,
        HEIGHT & 0xFF, HEIGHT>>8,
        0x80 | 0x70 | 0x00,  /* GCT flag + color resolution + sort flag */
        0,                    /* Background color index */
        0                     /* Pixel aspect ratio */
    };
    fwrite(lsd,1,7,stdout);
    /* Global Color Table (placeholder, will be overwritten by first frame) */
    for (int i=0;i<PALETTE_SIZE*3;i++) fputc(0, stdout);

    /* Process stdin word‑by‑word, updating sentiment and rendering frames */
    char word[256];
    int sentiment = 0;
    double cx = -0.5, cy = 0.0, zoom = 1.0;
    for (int f=0; f<FRAMES; ++f) {
        if (scanf("%255s", word)==1) {
            sentiment += sentiment_score(word);
        } else {
            /* No more input: generate evolving pattern */
            sentiment += (rand()%3-1);
        }
        int pal_ofs = palette_offset_from_sentiment(sentiment);
        build_palette(pal_ofs);
        /* Slightly move/zoom the view based on frame index */
        cx += sin(f*0.03)*0.002;
        cy += cos(f*0.03)*0.002;
        zoom *= 1.001;
        render_frame(cx, cy, zoom);
        /* Write graphic control extension (delay = 5 cs) */
        unsigned char gce[8] = {0x21,0xF9,0x04,0x00,5,0,0,0};
        fwrite(gce,1,8,stdout);
        write_gif_frame(stdout);
    }

    /* GIF trailer */
    fputc(gif_trailer, stdout);
    free(framebuf);
    return 0;
}