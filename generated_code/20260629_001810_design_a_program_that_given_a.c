#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>
#include <pthread.h>
#include <portaudio.h>
#include <fftw3.h>
#include <SDL2/SDL.h>

#define SAMPLE_RATE     44100
#define FRAMES_PER_BUFFER 1024
#define FFT_SIZE        1024
#define MAX_RULES       8
#define MAX_STRING      65536
#define WIN_W           800
#define WIN_H           600

/* ---------- Audio capture ---------- */
static float audio_buffer[FFT_SIZE];
static int audio_pos = 0;
static pthread_mutex_t audio_mutex = PTHREAD_MUTEX_INITIALIZER;

static int paCallback(const void *input, void *output,
                      unsigned long frameCount,
                      const PaStreamCallbackTimeInfo* timeInfo,
                      PaStreamCallbackFlags statusFlags,
                      void *userData)
{
    const float *in = (const float*)input;
    (void)output; (void)timeInfo; (void)statusFlags; (void)userData;
    pthread_mutex_lock(&audio_mutex);
    for (unsigned long i = 0; i < frameCount; ++i) {
        audio_buffer[audio_pos++] = in[i];
        if (audio_pos >= FFT_SIZE) audio_pos = 0;
    }
    pthread_mutex_unlock(&audio_mutex);
    return paContinue;
}

/* ---------- Simple L‑system ---------- */
typedef struct {
    char axiom[64];
    char rules[MAX_RULES][2][64]; // left -> right
    int ruleCount;
    double angle;   // in radians
    double step;
} LSystem;

static void initLSystem(LSystem *ls)
{
    strcpy(ls->axiom, "F");
    ls->ruleCount = 2;
    strcpy(ls->rules[0][0], "F");
    strcpy(ls->rules[0][1], "F[+F]F[-F]F");
    strcpy(ls->rules[1][0], "F");
    strcpy(ls->rules[1][1], "FF");
    ls->angle = M_PI/6.0;
    ls->step = 4.0;
}

/* Replace symbols according to current rule set */
static void generateString(const LSystem *ls, const char *src, char *dst, int depth)
{
    if (depth==0) { strcpy(dst, src); return; }
    char tmp[MAX_STRING];
    tmp[0]='\0';
    for (const char *p=src; *p && strlen(tmp)<MAX_STRING-1; ++p) {
        int replaced=0;
        for (int r=0;r<ls->ruleCount;++r){
            if (*p==ls->rules[r][0][0]) {
                strcat(tmp, ls->rules[r][1]);
                replaced=1;
                break;
            }
        }
        if (!replaced) {
            size_t len=strlen(tmp);
            tmp[len]=*p; tmp[len+1]='\0';
        }
    }
    generateString(ls, tmp, dst, depth-1);
}

/* ---------- Rendering ---------- */
static void renderLSystem(SDL_Renderer *ren, const LSystem *ls, const char *seq)
{
    double x = WIN_W/2, y = WIN_H;
    double dir = -M_PI/2; // up
    double stack[256][3];
    int sp = 0;

    SDL_SetRenderDrawColor(ren, 0,0,0,255);
    SDL_RenderClear(ren);
    SDL_SetRenderDrawColor(ren, 255,255,255,255);

    for (const char *p=seq; *p; ++p) {
        switch(*p){
            case 'F':{
                double nx = x + ls->step * cos(dir);
                double ny = y + ls->step * sin(dir);
                SDL_RenderDrawLineF(ren, (float)x,(float)y,(float)nx,(float)ny);
                x=nx; y=ny;
                break;}
            case '+':
                dir += ls->angle;
                break;
            case '-':
                dir -= ls->angle;
                break;
            case '[':
                if (sp<255){
                    stack[sp][0]=x; stack[sp][1]=y; stack[sp][2]=dir; sp++;
                }
                break;
            case ']':
                if (sp>0){
                    sp--; x=stack[sp][0]; y=stack[sp][1]; dir=stack[sp][2];
                }
                break;
        }
    }
    SDL_RenderPresent(ren);
}

/* ---------- Audio analysis ---------- */
static double dominantFreq()
{
    static double in[FFT_SIZE];
    static fftw_complex out[FFT_SIZE/2+1];
    static fftw_plan plan = NULL;
    if (!plan) plan = fftw_plan_dft_r2c_1d(FFT_SIZE,in,out,FFTW_MEASURE);
    pthread_mutex_lock(&audio_mutex);
    int start = (audio_pos + FFT_SIZE - FRAMES_PER_BUFFER) % FFT_SIZE;
    for (int i=0;i<FFT_SIZE;i++){
        in[i]=audio_buffer[(start+i)%FFT_SIZE];
    }
    pthread_mutex_unlock(&audio_mutex);
    fftw_execute(plan);
    double maxmag=0; int idx=0;
    for (int i=1;i<FFT_SIZE/2;i++){
        double mag = sqrt(out[i][0]*out[i][0]+out[i][1]*out[i][1]);
        if (mag>maxmag){ maxmag=mag; idx=i; }
    }
    return (double)idx * SAMPLE_RATE / FFT_SIZE;
}

/* ---------- Main program ---------- */
int main(int argc, char *argv[])
{
    (void)argc;(void)argv;
    if (Pa_Initialize()!=paNoError){
        fprintf(stderr,"PortAudio init failed\n");
        return 1;
    }
    PaStream *stream;
    PaStreamParameters inParam;
    inParam.device = Pa_GetDefaultInputDevice();
    if (inParam.device==paNoDevice){fprintf(stderr,"No input device\n");return 1;}
    const PaDeviceInfo *info = Pa_GetDeviceInfo(inParam.device);
    inParam.channelCount = 1;
    inParam.sampleFormat = paFloat32;
    inParam.suggestedLatency = info->defaultLowInputLatency;
    inParam.hostApiSpecificStreamInfo = NULL;
    if (Pa_OpenStream(&stream,&inParam,NULL,SAMPLE_RATE,FRAMES_PER_BUFFER,
                      paClipOff,paCallback,NULL)!=paNoError){
        fprintf(stderr,"Failed to open stream\n");
        return 1;
    }
    Pa_StartStream(stream);

    if (SDL_Init(SDL_INIT_VIDEO)!=0){
        fprintf(stderr,"SDL init error: %s\n",SDL_GetError());
        return 1;
    }
    SDL_Window *win = SDL_CreateWindow("Audio‑driven L‑system",
                                       SDL_WINDOWPOS_CENTERED,
                                       SDL_WINDOWPOS_CENTERED,
                                       WIN_W,WIN_H,0);
    SDL_Renderer *ren = SDL_CreateRenderer(win,-1,SDL_RENDERER_ACCELERATED);
    LSystem ls;
    initLSystem(&ls);
    char generated[MAX_STRING];
    int depth = 4;

    int quit=0;
    while(!quit){
        SDL_Event e;
        while(SDL_PollEvent(&e)){
            if(e.type==SDL_QUIT) quit=1;
            if(e.type==SDL_KEYDOWN && e.key.keysym.sym==SDLK_ESCAPE) quit=1;
        }
        double freq = dominantFreq();
        // Map frequency (20‑20000Hz) to rule variation and angle
        double norm = (freq-20.0)/(20000.0-20.0);
        if (norm<0) norm=0; if (norm>1) norm=1;
        // modify rule 0 right side length
        int len = 4 + (int)(norm*12);
        char rule[64]="F[+F]F[-F]F";
        rule[2]='F'; // ensure first char
        // expand rule by inserting extra 'F's according to len
        char newRule[64]="F[+";
        int pos=3;
        for(int i=0;i<len;i++) newRule[pos++]='F';
        newRule[pos++]='F'; newRule[pos++]=']';
        newRule[pos++]='F'; newRule[pos++]='['; newRule[pos++]='-';
        for(int i=0;i<len;i++) newRule[pos++]='F';
        newRule[pos++]='F'; newRule[pos++]=']';
        newRule[pos++]='F'; newRule[pos]='\0';
        strncpy(ls.rules[0][1], newRule, 63);
        // angle variation
        ls.angle = M_PI/6.0 + norm * M_PI/12.0;
        // generate string
        generateString(&ls, ls.axiom, generated, depth);
        // render
        renderLSystem(ren, &ls, generated);
        SDL_Delay(16); // ~60 FPS
    }

    SDL_DestroyRenderer(ren);
    SDL_DestroyWindow(win);
    SDL_Quit();
    Pa_StopStream(stream);
    Pa_CloseStream(stream);
    Pa_Terminate();
    return 0;
}