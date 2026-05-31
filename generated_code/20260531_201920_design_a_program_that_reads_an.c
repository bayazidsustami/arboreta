#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>
#include <SDL2/SDL.h>

#define WINDOW_W 800
#define WINDOW_H 600
#define MAX_WORDS 1024
#define MAX_BUBBLES 256
#define PI 3.14159265358979323846

/* Simple sentiment dictionary (word -> score [-1,1]) */
typedef struct { const char *word; float score; } SentEntry;
SentEntry sentiment_dict[] = {
    {"love",  0.9f}, {"joy",   0.8f}, {"happy",0.7f},
    {"peace", 0.6f}, {"bright",0.5f}, {"hope", 0.5f},
    {"sad",  -0.7f}, {"pain", -0.8f}, {"dark", -0.6f},
    {"death",-0.9f}, {"cry",  -0.5f}, {"fear", -0.4f},
    {NULL,0}
};

/* Approximate syllable count: count vowel groups */
int syllables(const char *word){
    int cnt=0; int in_vowel=0;
    for(;*word;word++){
        char c=tolower(*word);
        int isv = (c=='a'||c=='e'||c=='i'||c=='o'||c=='u'||c=='y');
        if(isv && !in_vowel){cnt++; in_vowel=1;}
        else if(!isv) in_vowel=0;
    }
    if(cnt==0) cnt=1;
    return cnt;
}

/* Get sentiment score, default 0 */
float sentiment(const char *w){
    for(int i=0;sentiment_dict[i].word;i++)
        if(strcmp(w, sentiment_dict[i].word)==0)
            return sentiment_dict[i].score;
    return 0.0f;
}

/* Map sentiment [-1,1] to hue [0,360] */
float hue_from_sentiment(float s){ return (s+1.0f)*180.0f; }

/* Convert HSV to RGB (0..255) */
void hsv2rgb(float h,float s,float v, Uint8 *r, Uint8 *g, Uint8 *b){
    float c=v*s;
    float x=c*(1-fabsf(fmodf(h/60.0f,2)-1));
    float m=v-c;
    float rp=0,gp=0,bp=0;
    if(h<60){rp=c; gp=x;}
    else if(h<120){rp=x; gp=c;}
    else if(h<180){gp=c; bp=x;}
    else if(h<240){gp=x; bp=c;}
    else if(h<300){rp=c; bp=x;}
    else {rp=x; bp=c;}
    *r=(Uint8)((rp+m)*255);
    *g=(Uint8)((gp+m)*255);
    *b=(Uint8)((bp+m)*255);
}

/* Musical note frequency from MIDI note number */
float note_freq(int midi){ return 440.0f * powf(2.0f,(midi-69)/12.0f); }

/* Bubble structure */
typedef struct{
    float x,y,dx,dy;
    Uint8 r,g,b;
    int midi;           // note to play
    Uint32 last_play;   // time of last note
    char text[64];
} Bubble;

/* Generate a sine wave for a given frequency */
void audio_callback(void *userdata, Uint8 *stream, int len){
    static double phase=0;
    Bubble *bubbles = (Bubble*)userdata;
    float *buf = (float*)stream;
    int samples = len / sizeof(float);
    Uint32 now = SDL_GetTicks();
    for(int i=0;i<samples;i++){
        float sample=0.0f;
        for(int j=0;j<MAX_BUBBLES;j++){
            if(bubbles[j].last_play && now-bubbles[j].last_play<200){
                float freq = note_freq(bubbles[j].midi);
                sample += 0.3f * sinf(2*PI*freq*phase);
            }
        }
        buf[i]=sample;
        phase += 1.0/(48000.0);
    }
}

/* Main program */
int main(int argc, char *argv[]){
    if(argc<2){fprintf(stderr,"Usage: %s poem.txt\n",argv[0]);return 1;}
    FILE *f=fopen(argv[1],"r");
    if(!f){perror("open");return 1;}
    char line[256];
    Bubble bubbles[MAX_BUBBLES];
    int bubble_cnt=0;
    srand((unsigned)time(NULL));
    while(fgets(line,sizeof(line),f) && bubble_cnt<MAX_BUBBLES){
        char *tok=strtok(line," \t\r\n.,;:!?'\"-");
        while(tok && bubble_cnt<MAX_BUBBLES){
            char word[64];
            strncpy(word,tok,63); word[63]=0;
            for(char *p=word;*p;p++) *p=tolower(*p);
            float s=sentiment(word);
            int syl=syllables(word);
            float hue=hue_from_sentiment(s);
            Uint8 r,g,b;
            hsv2rgb(hue,0.8f,0.9f,&r,&g,&b);
            Bubble *b=&bubbles[bubble_cnt++];
            b->x = rand()%WINDOW_W;
            b->y = rand()%WINDOW_H;
            b->dx = ((rand()%200)-100)/100.0f;
            b->dy = ((rand()%200)-100)/100.0f;
            b->r=r; b->g=g; b->b=b;
            b->midi = 60 + (syl%12); // middle C + syllable offset
            b->last_play=SDL_GetTicks();
            snprintf(b->text,63,"%s",word);
            tok=strtok(NULL," \t\r\n.,;:!?'\"-");
        }
    }
    fclose(f);

    if(SDL_Init(SDL_INIT_VIDEO|SDL_INIT_AUDIO)<0){
        fprintf(stderr,"SDL init: %s\n",SDL_GetError());return 1;
    }

    SDL_Window *win=SDL_CreateWindow("Poem Bubbles",
        SDL_WINDOWPOS_CENTERED,SDL_WINDOWPOS_CENTERED,
        WINDOW_W,WINDOW_W,0);
    SDL_Renderer *ren=SDL_CreateRenderer(win,-1,SDL_RENDERER_ACCELERATED);
    SDL_AudioSpec spec={0};
    spec.freq=48000; spec.format=AUDIO_F32SYS; spec.channels=1;
    spec.samples=1024; spec.callback=audio_callback; spec.userdata=bubbles;
    if(SDL_OpenAudio(&spec,NULL)<0){
        fprintf(stderr,"Audio: %s\n",SDL_GetError());
    }else SDL_PauseAudio(0);

    int quit=0; SDL_Event e;
    Uint32 last=SDL_GetTicks();
    while(!quit){
        while(SDL_PollEvent(&e)){
            if(e.type==SDL_QUIT) quit=1;
        }
        Uint32 now=SDL_GetTicks();
        float dt=(now-last)/1000.0f;
        last=now;
        /* update positions */
        for(int i=0;i<bubble_cnt;i++){
            Bubble *b=&bubbles[i];
            b->x+=b->dx*dt*50;
            b->y+=b->dy*dt*50;
            if(b->x<0||b->x>WINDOW_W) b->dx*=-1;
            if(b->y<0||b->y>WINDOW_H) b->dy*=-1;
        }

        SDL_SetRenderDrawColor(ren,0,0,0,255);
        SDL_RenderClear(ren);
        for(int i=0;i<bubble_cnt;i++){
            Bubble *b=&bubbles[i];
            SDL_SetRenderDrawColor(ren,b->r,b->g,b->b,200);
            for(int rad=20;rad>0;rad--) /* simple pulse */
                SDL_RenderDrawCircle(ren,(int)b->x,(int)b->y,rad);
            /* draw word (simple: not actually rendered, placeholder) */
        }
        SDL_RenderPresent(ren);
        SDL_Delay(16);
    }

    SDL_CloseAudio();
    SDL_DestroyRenderer(ren);
    SDL_DestroyWindow(win);
    SDL_Quit();
    return 0;
}

/* Helper to draw circles (SDL2 has no primitive) */
int SDL_RenderDrawCircle(SDL_Renderer *renderer, int32_t centreX, int32_t centreY, int32_t radius){
    const int32_t diameter = (radius * 2);
    int32_t x = (radius - 1);
    int32_t y = 0;
    int32_t tx = 1;
    int32_t ty = 1;
    int32_t error = (tx - diameter);
    while (x >= y){
        // 8-way symmetry
        SDL_RenderDrawPoint(renderer, centreX + x, centreY - y);
        SDL_RenderDrawPoint(renderer, centreX + x, centreY + y);
        SDL_RenderDrawPoint(renderer, centreX - x, centreY - y);
        SDL_RenderDrawPoint(renderer, centreX - x, centreY + y);
        SDL_RenderDrawPoint(renderer, centreX + y, centreY - x);
        SDL_RenderDrawPoint(renderer, centreX + y, centreY + x);
        SDL_RenderDrawPoint(renderer, centreX - y, centreY - x);
        SDL_RenderDrawPoint(renderer, centreX - y, centreY + x);
        if (error <= 0){
            ++y;
            error += ty;
            ty += 2;
        }
        if (error > 0){
            --x;
            tx += 2;
            error += (tx - diameter);
        }
    }
    return 0;
}