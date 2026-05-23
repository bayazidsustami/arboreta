#include <SDL2/SDL.h>
#include <iostream>
#include <fstream>
#include <vector>
#include <string>
#include <cmath>
#include <map>

//--------------------------------------------------
// Simple helper: read chord root numbers (0‑11) from a txt file
//--------------------------------------------------
std::vector<int> loadChordRoots(const std::string& path)
{
    std::vector<int> roots;
    std::ifstream in(path);
    if (!in) { std::cerr<<"Cannot open "<<path<<"\n"; return roots; }
    std::string token;
    while (in>>token) {
        // token may be like C, D#, F etc.
        static const std::map<std::string,int> name2pc = {
            {"C",0},{"C#",1},{"Db",1},{"D",2},{"D#",3},{"Eb",3},
            {"E",4},{"F",5},{"F#",6},{"Gb",6},{"G",7},{"G#",8},
            {"Ab",8},{"A",9},{"A#",10},{"Bb",10},{"B",11}
        };
        auto it = name2pc.find(token);
        if (it!=name2pc.end()) roots.push_back(it->second);
    }
    return roots;
}

//--------------------------------------------------
// Map a chord root (0‑11) to a Wolfram elementary CA rule (0‑255)
//--------------------------------------------------
int ruleFromRoot(int pc) {
    // simple deterministic mapping: rotate bits of pc
    int base = 30; // rule 30 as a default aesthetic
    return (base ^ (pc << 2)) & 0xFF;
}

//--------------------------------------------------
// Generate 1‑D cellular automaton rows
//--------------------------------------------------
std::vector<std::vector<uint8_t>> generateCA(const std::vector<int>& rules,
                                            int steps, int width)
{
    std::vector<std::vector<uint8_t>> rows;
    rows.reserve(steps);
    std::vector<uint8_t> cur(width,0), nxt(width,0);
    cur[width/2]=1; // seed
    for (int s=0; s<steps; ++s) {
        rows.push_back(cur);
        int rule = rules[s % rules.size()];
        for (int i=0;i<width;++i){
            int left = cur[(i-1+width)%width];
            int centre = cur[i];
            int right = cur[(i+1)%width];
            int idx = (left<<2)|(centre<<1)|right;
            nxt[i] = (rule >> idx) & 1;
        }
        cur.swap(nxt);
    }
    return rows;
}

//--------------------------------------------------
// Convert CA cell state to hue based on distance from tonal centre
//--------------------------------------------------
Uint32 hueToRGB(float hue,float sat,float val, SDL_PixelFormat* fmt)
{
    // HSV to RGB conversion (hue in [0,360))
    float c = val * sat;
    float x = c * (1 - fabsf(fmodf(hue/60.0f,2)-1));
    float m = val - c;
    float r=0,g=0,b=0;
    if (hue<60){r=c;g=x;}
    else if (hue<120){r=x;g=c;}
    else if (hue<180){g=c;b=x;}
    else if (hue<240){g=x;b=c;}
    else if (hue<300){r=x;b=c;}
    else {r=c;b=x;}
    Uint8 R = Uint8((r+m)*255);
    Uint8 G = Uint8((g+m)*255);
    Uint8 B = Uint8((b+m)*255);
    return SDL_MapRGB(fmt,R,G,B);
}

//--------------------------------------------------
// Main
//--------------------------------------------------
int main(int argc, char*argv[])
{
    if (argc<2){
        std::cerr<<"Usage: "<<argv[0]<<" chords.txt\n";
        return 1;
    }
    // 1. Load chord roots (tonal centre assumed C = 0)
    auto roots = loadChordRoots(argv[1]);
    if (roots.empty()){
        std::cerr<<"No chords loaded.\n";
        return 1;
    }

    // 2. Build rule list
    std::vector<int> rules;
    for (int pc:roots) rules.push_back(ruleFromRoot(pc));

    // 3. Determine steps proportional to tempo (mocked as 4 * number of chords)
    int steps = 4 * static_cast<int>(roots.size());
    const int width = 256;

    // 4. Generate automaton
    auto ca = generateCA(rules,steps,width);

    // 5. Initialise SDL
    if (SDL_Init(SDL_INIT_VIDEO)!=0){
        std::cerr<<"SDL error: "<<SDL_GetError()<<"\n";
        return 1;
    }
    const int cellSize = 3;
    SDL_Window* win = SDL_CreateWindow("Music CA Tapestry",
                    SDL_WINDOWPOS_CENTERED,SDL_WINDOWPOS_CENTERED,
                    width*cellSize, steps*cellSize,
                    SDL_WINDOW_SHOWN);
    SDL_Renderer* ren = SDL_CreateRenderer(win,-1,SDL_RENDERER_ACCELERATED);
    SDL_Texture* tex = SDL_CreateTexture(ren,
                    SDL_PIXELFORMAT_RGB24,
                    SDL_TEXTUREACCESS_STREAMING,
                    width, steps);
    // 6. Fill texture with colour‑coded cells
    void* pixels; int pitch;
    SDL_LockTexture(tex,&SDL_Rect{0,0,width,steps},&pixels,&pitch);
    Uint8* dst = static_cast<Uint8*>(pixels);
    for (int y=0;y<steps;++y){
        for (int x=0;x<width;++x){
            uint8_t state = ca[y][x];
            // distance from tonal centre (C=0) = min(|pc-0|,12-|pc-0|)
            int pc = roots[y%roots.size()];
            int dist = std::min(pc,12-pc);
            float hue = (float)dist/6.0f*360.0f; // map distance to hue circle
            Uint32 col = hueToRGB(hue,0.8f, state?1.0f:0.1f, SDL_AllocFormat(SDL_PIXELFORMAT_RGB24));
            Uint8 r,g,b;
            SDL_GetRGB(col,SDL_AllocFormat(SDL_PIXELFORMAT_RGB24),&r,&g,&b);
            int offset = y*pitch + x*3;
            dst[offset+0]=r;
            dst[offset+1]=g;
            dst[offset+2]=b;
        }
    }
    SDL_UnlockTexture(tex);

    // 7. Main loop – simple animated scrolling
    bool quit=false; SDL_Event e;
    int offsetY=0;
    while(!quit){
        while(SDL_PollEvent(&e)){
            if(e.type==SDL_QUIT) quit=true;
        }
        SDL_RenderClear(ren);
        SDL_Rect src{0, offsetY, width, steps - offsetY};
        SDL_Rect dstR{0,0,width*cellSize, (steps - offsetY)*cellSize};
        SDL_RenderCopy(ren,tex,&src,&dstR);
        // wrap around
        if(offsetY>0){
            SDL_Rect src2{0,0,width,offsetY};
            SDL_Rect dstR2{0,(steps-offsetY)*cellSize,width*cellSize,offsetY*cellSize};
            SDL_RenderCopy(ren,tex,&src2,&dstR2);
        }
        SDL_RenderPresent(ren);
        SDL_Delay(30);
        offsetY = (offsetY+1) % steps;
    }

    SDL_DestroyTexture(tex);
    SDL_DestroyRenderer(ren);
    SDL_DestroyWindow(win);
    SDL_Quit();
    return 0;
}