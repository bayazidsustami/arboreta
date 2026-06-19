#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>
#include <time.h>
#include <portaudio.h>
#include <kissfft/kiss_fft.h>

/* Simple L‑system symbols */
#define AXIOM "F"
#define MAX_RULES 8
#define MAX_ITER 5
#define BUF_SIZE 1024

/* Data structures */
typedef struct {
    char predecessor;
    char successor[16];
} Rule;

typedef struct {
    Rule rules[MAX_RULES];
    int count;
} Grammar;

/* Global state */
static Grammar g;
static float g_palette[3] = {1.0f, 1.0f, 1.0f};

/* ---------- Audio capture ---------- */
#define SAMPLE_RATE 44100
#define FRAMES_PER_BUFFER 512
#define CHANNELS 1

typedef struct {
    kiss_fft_cfg fft_cfg;
    kiss_fft_cpx in[BUF_SIZE];
    kiss_fft_cpx out[BUF_SIZE];
    float buffer[BUF_SIZE];
    int idx;
} AudioProc;

static int audioCallback(const void *input, void *output,
                         unsigned long frameCount,
                         const PaStreamCallbackTimeInfo* timeInfo,
                         PaStreamCallbackFlags statusFlags,
                         void *userData)
{
    AudioProc *ap = (AudioProc*)userData;
    const float *in = (const float*)input;
    for (unsigned i = 0; i < frameCount; ++i) {
        if (ap->idx < BUF_SIZE) {
            ap->buffer[ap->idx++] = in[i];
        }
    }
    return paContinue;
}

/* ---------- FFT & feature extraction ---------- */
static void analyse(AudioProc *ap, float *outFreq, float *outTempo)
{
    if (ap->idx < BUF_SIZE) return;
    for (int i = 0; i < BUF_SIZE; ++i) {
        ap->in[i].r = ap->buffer[i];
        ap->in[i].i = 0.0f;
    }
    kiss_fft(ap->fft_cfg, ap->in, ap->out);
    /* magnitude spectrum */
    float sum = 0.0f;
    for (int i = 0; i < BUF_SIZE/2; ++i) {
        float mag = sqrtf(ap->out[i].r*ap->out[i].r + ap->out[i].i*ap->out[i].i);
        sum += mag;
    }
    *outFreq = sum / (BUF_SIZE/2);
    /* Very crude tempo estimate: energy peaks */
    *outTempo = fmodf(*outFreq * 0.1f, 1.0f);
    ap->idx = 0;
}

/* ---------- L‑system handling ---------- */
static void initGrammar(void)
{
    g.count = 0;
    /* Base rule, will be modulated */
    g.rules[g.count++] = (Rule){'F', "F[+F]F[-F]F"};
}

/* Modulate rule length based on a harmonic interval (simple mapping) */
static void modulateGrammar(float freq)
{
    int factor = (int)(freq/100.0f) % 3 + 2;   /* 2..4 */
    char succ[16];
    snprintf(succ, sizeof(succ), "F[+%dF]F[-%dF]F", factor, factor);
    g.rules[0].successor[0] = '\0';
    strncat(g.rules[0].successor, succ, sizeof(g.rules[0].successor)-1);
}

/* Apply L‑system for n iterations */
static void expand(const char *src, char *dst, int iter)
{
    if (iter==0) { strcpy(dst, src); return; }
    char tmp[1024] = "";
    for (const char *p=src; *p; ++p) {
        int replaced = 0;
        for (int r=0; r<g.count; ++r) {
            if (*p == g.rules[r].predecessor) {
                strncat(tmp, g.rules[r].successor, sizeof(tmp)-strlen(tmp)-1);
                replaced = 1; break;
            }
        }
        if (!replaced) {
            strncat(tmp, (char[]){*p,0}, sizeof(tmp)-strlen(tmp)-1);
        }
    }
    expand(tmp, dst, iter-1);
}

/* ---------- SVG rendering ---------- */
static void renderSVG(const char *lsys, float tempo)
{
    printf("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"800\" height=\"800\" viewBox=\"-400 -400 800 800\">\n");
    /* colour palette driven by tempo */
    float r = 0.5f + 0.5f*sin(2*M_PI*tempo);
    float gcol = 0.5f + 0.5f*sin(2*M_PI*tempo+2.0);
    float b = 0.5f + 0.5f*sin(2*M_PI*tempo+4.0);
    printf("<style>.stroke{stroke:rgb(%d,%d,%d);stroke-width:1;fill:none;}</style>\n",
           (int)(r*255),(int)(gcol*255),(int)(b*255));
    printf("<path class=\"stroke\" d=\"");
    double x=0, y=0, angle=0;
    double step = 5.0;
    for (const char *p=lsys; *p; ++p) {
        switch(*p) {
            case 'F':
                x += step*cos(angle);
                y += step*sin(angle);
                printf("L%g %g ", x, y);
                break;
            case '+':
                angle += M_PI/6; break;
            case '-':
                angle -= M_PI/6; break;
            case '[':
                printf("M%g %g ", x, y);
                break;
            case ']':
                printf("M%g %g ", x, y);
                break;
        }
    }
    printf("\"/>\n</svg>\n");
}

/* ---------- Main loop ---------- */
int main(void)
{
    PaError err = Pa_Initialize();
    if (err != paNoError) return 1;
    PaStream *stream;
    AudioProc ap;
    ap.fft_cfg = kiss_fft_alloc(BUF_SIZE,0,NULL,NULL);
    ap.idx = 0;
    err = Pa_OpenDefaultStream(&stream,
                               CHANNELS,0,
                               paFloat32,
                               SAMPLE_RATE,
                               FRAMES_PER_BUFFER,
                               audioCallback,
                               &ap);
    if (err != paNoError) return 1;
    Pa_StartStream(stream);

    initGrammar();

    char lsys[1024];
    for (int frame=0; frame<200; ++frame) {
        float freq=0, tempo=0;
        analyse(&ap,&freq,&tempo);
        if (freq>0) modulateGrammar(freq);
        expand(AXIOM, lsys, MAX_ITER);
        renderSVG(lsys, tempo);
        Pa_Sleep(30);
    }

    Pa_StopStream(stream);
    Pa_CloseStream(stream);
    Pa_Terminate();
    free(ap.fft_cfg);
    return 0;
}