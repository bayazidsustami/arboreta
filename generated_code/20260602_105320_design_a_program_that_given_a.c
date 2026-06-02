#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <pthread.h>
#include <opencv2/opencv.hpp>
#include <SDL2/SDL.h>
#include <portaudio.h>

/* Simple L‑system structure */
typedef struct {
    char axiom[128];
    char current[4096];
    struct {
        char predecessor;
        char successor[128];
    } rules[16];
    int rule_count;
    int iterations;
} LSystem;

/* Global shared data */
static Uint32 *pixel_buf = NULL;
static int tex_w = 640, tex_h = 480;
static SDL_Texture *texture = NULL;
static SDL_Renderer *renderer = NULL;
static pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;

/* Dummy audio analysis – in real code this would use FFT */
static float g_tempo = 120.0f;   /* BPM */
static float g_amplitude = 0.5f;/* 0..1 */

/* --------------------------------------------------------------- */
/* PortAudio callback: just compute RMS amplitude as a placeholder   */
static int pa_callback(const void *input, void *output,
                       unsigned long frameCount,
                       const PaStreamCallbackTimeInfo* timeInfo,
                       PaStreamCallbackFlags statusFlags,
                       void *userData)
{
    const float *in = (const float*)input;
    double sum = 0.0;
    for (unsigned long i=0;i<frameCount;i++) {
        sum += in[i]*in[i];
    }
    g_amplitude = (float)sqrt(sum/frameCount);
    /* Simulate tempo change by mapping amplitude to BPM */
    g_tempo = 60.0f + 180.0f * g_amplitude;
    (void)output; (void)timeInfo; (void)statusFlags; (void)userData;
    return paContinue;
}

/* --------------------------------------------------------------- */
/* Initialise audio capture */
static void init_audio()
{
    Pa_Initialize();
    PaStream *stream;
    PaStreamParameters iparams = {0};
    iparams.device = Pa_GetDefaultInputDevice();
    iparams.channelCount = 1;
    iparams.sampleFormat = paFloat32;
    iparams.suggestedLatency = Pa_GetDeviceInfo(iparams.device)->defaultLowInputLatency;
    Pa_OpenStream(&stream, &iparams, NULL, 44100, 256, paClipOff, pa_callback, NULL);
    Pa_StartStream(stream);
}

/* --------------------------------------------------------------- */
/* Compute dominant palette using k‑means (k=3) */
static void dominant_palette(const cv::Mat &frame, cv::Scalar palette[3])
{
    cv::Mat samples = frame.reshape(1, frame.total());
    samples.convertTo(samples, CV_32F);
    cv::Mat labels, centers;
    cv::kmeans(samples, 3, labels,
               cv::TermCriteria(cv::TermCriteria::EPS+cv::TermCriteria::MAX_ITER,10,1.0),
               3, cv::KMEANS_PP_CENTERS, centers);
    for (int i=0;i<3;i++) {
        palette[i] = cv::Scalar(centers.at<float>(i,0),
                                centers.at<float>(i,1),
                                centers.at<float>(i,2));
    }
}

/* --------------------------------------------------------------- */
/* Update L‑system rules based on tempo & amplitude */
static void update_rules(LSystem *ls)
{
    /* Very simple mapping: higher tempo -> longer strings */
    int len = (int)(2 + (g_tempo-60)/60); /* 2..5 */
    char succ[128];
    for (int i=0;i<len;i++) succ[i]='F';
    succ[len]=0;
    ls->rule_count = 1;
    ls->rules[0].predecessor = 'F';
    strcpy(ls->rules[0].successor, succ);
}

/* --------------------------------------------------------------- */
/* Perform L‑system iteration */
static void lsystem_iterate(LSystem *ls)
{
    char next[4096]={0};
    int p=0;
    for (int i=0; i<strlen(ls->current) && p<4095; ++i) {
        char c = ls->current[i];
        int replaced=0;
        for (int r=0;r<ls->rule_count;r++) {
            if (c==ls->rules[r].predecessor) {
                strcpy(&next[p], ls->rules[r].successor);
                p+=strlen(ls->rules[r].successor);
                replaced=1;
                break;
            }
        }
        if (!replaced) next[p++]=c;
    }
    strcpy(ls->current, next);
}

/* --------------------------------------------------------------- */
/* Render L‑system to pixel buffer (turtle graphics) */
static void render_lsystem(const LSystem *ls, const cv::Scalar palette[3])
{
    /* Clear buffer */
    memset(pixel_buf, 0, tex_w*tex_h*sizeof(Uint32));

    /* Simple turtle: start centre, heading right */
    float x = tex_w/2, y = tex_h/2;
    float angle = 0;
    float step = 4.0f;
    Uint32 col = SDL_MapRGB(SDL_AllocFormat(SDL_PIXELFORMAT_ARGB8888),
                            (Uint8)palette[0][2],
                            (Uint8)palette[0][1],
                            (Uint8)palette[0][0]);

    for (size_t i=0;i<strlen(ls->current);i++) {
        char c = ls->current[i];
        if (c=='F') {
            float nx = x + step*cosf(angle);
            float ny = y + step*sinf(angle);
            /* Bresenham line */
            int ix = (int)x, iy = (int)y, jx = (int)nx, jy = (int)ny;
            int dx = abs(jx-ix), sx = ix<jx?1:-1;
            int dy = -abs(jy-iy), sy = iy<jy?1:-1;
            int err = dx+dy, e2;
            while (1) {
                if (ix>=0 && ix<tex_w && iy>=0 && iy<tex_h)
                    pixel_buf[iy*tex_w+ix]=col;
                if (ix==jx && iy==jy) break;
                e2=2*err;
                if (e2>=dy){ err+=dy; ix+=sx; }
                if (e2<=dx){ err+=dx; iy+=sy; }
            }
            x=nx; y=ny;
        } else if (c=='+') {
            angle += M_PI/6; /* turn 30° */
        } else if (c=='-') {
            angle -= M_PI/6;
        }
    }
}

/* --------------------------------------------------------------- */
static void *render_thread(void *arg)
{
    LSystem *ls = (LSystem*)arg;
    cv::VideoCapture cap(0);
    if (!cap.isOpened()) { fprintf(stderr,"Camera error\n"); return NULL; }

    while (1) {
        cv::Mat frame;
        cap>>frame;
        if (frame.empty()) continue;
        cv::resize(frame, frame, cv::Size(tex_w, tex_h));

        cv::Scalar palette[3];
        dominant_palette(frame, palette);

        pthread_mutex_lock(&lock);
        update_rules(ls);
        lsystem_iterate(ls);
        render_lsystem(ls, palette);
        pthread_mutex_unlock(&lock);

        SDL_UpdateTexture(texture, NULL, pixel_buf, tex_w*sizeof(Uint32));
        SDL_RenderClear(renderer);
        SDL_RenderCopy(renderer, texture, NULL, NULL);
        SDL_RenderPresent(renderer);
        SDL_Delay(30);
    }
    return NULL;
}

/* --------------------------------------------------------------- */
int main(int argc, char *argv[])
{
    (void)argc; (void)argv;
    if (SDL_Init(SDL_INIT_VIDEO)!=0) { fprintf(stderr,"SDL init err: %s\n",SDL_GetError()); return -1; }

    SDL_Window *win = SDL_CreateWindow("AV Poem",SDL_WINDOWPOS_CENTERED,SDL_WINDOWPOS_CENTERED,
                                       tex_w, tex_h, 0);
    renderer = SDL_CreateRenderer(win, -1, SDL_RENDERER_ACCELERATED);
    texture = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_ARGB8888,
                                SDL_TEXTUREACCESS_STREAMING, tex_w, tex_h);
    pixel_buf = (Uint32*)malloc(tex_w*tex_h*sizeof(Uint32));

    LSystem ls = {0};
    strcpy(ls.axiom, "F");
    strcpy(ls.current, ls.axiom);
    ls.iterations = 0;
    ls.rule_count = 0;

    init_audio();

    pthread_t thr;
    pthread_create(&thr, NULL, render_thread, &ls);

    /* Simple event loop */
    SDL_Event ev;
    int quit=0;
    while (!quit) {
        while (SDL_PollEvent(&ev)) {
            if (ev.type==SDL_QUIT) quit=1;
        }
        SDL_Delay(10);
    }

    /* Cleanup */
    SDL_DestroyTexture(texture);
    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(win);
    SDL_Quit();
    free(pixel_buf);
    Pa_Terminate();
    return 0;
}