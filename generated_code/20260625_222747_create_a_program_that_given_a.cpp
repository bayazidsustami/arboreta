#include <opencv2/opencv.hpp>
#include <SDL2/SDL.h>
#include <SDL2/SDL_audio.h>
#include <iostream>
#include <fstream>
#include <vector>
#include <cmath>
#include <chrono>
#include <thread>

// ------------ Poem (self‑modifying) ------------
// A canvas of hue, a chorus of tone,
// Pixels dance, the world is known.
//-------------------------------------------------

// Map hue (0‑360) to a note frequency (A4=440Hz, chromatic)
double hueToFreq(double h) {
    static const double base = 440.0; // A4
    static const std::vector<double> semitone = {
        1.0, std::pow(2.0,1.0/12), std::pow(2.0,2.0/12), std::pow(2.0,3.0/12),
        std::pow(2.0,4.0/12), std::pow(2.0,5.0/12), std::pow(2.0,6.0/12),
        std::pow(2.0,7.0/12), std::pow(2.0,8.0/12), std::pow(2.0,9.0/12),
        std::pow(2.0,10.0/12),std::pow(2.0,11.0/12)
    };
    int index = static_cast<int>(h/30.0) % 12;
    int oct = static_cast<int>(h/360.0);
    return base * semitone[index] * std::pow(2.0, oct);
}

// Audio callback – generates a sine wave for current frequency
struct AudioState {
    double freq = 440.0;
    double phase = 0.0;
    double sampleRate = 48000.0;
} audioState;

void audioCallback(void* /*userdata*/, Uint8* stream, int len) {
    double* out = reinterpret_cast<double*>(stream);
    int samples = len / sizeof(double);
    double inc = 2.0*M_PI*audioState.freq/audioState.sampleRate;
    for(int i=0;i<samples;++i){
        out[i] = 0.2 * std::sin(audioState.phase);
        audioState.phase += inc;
        if(audioState.phase>2.0*M_PI) audioState.phase-=2.0*M_PI;
    }
}

// Write a simple poem reflecting the current palette
void rewritePoem(const std::vector<cv::Vec3b>& colors) {
    const char* src = __FILE__;
    std::ifstream in(src);
    std::string line, content;
    while(std::getline(in,line)){
        if(line.find("//------------ Poem")!=std::string::npos){
            // skip old poem lines
            while(std::getline(in,line) && line.find("//-------------------------------------------------")==std::string::npos);
            content += "//------------ Poem (self‑modifying)\n";
            std::string verse = "// ";
            for(size_t i=0;i<colors.size();++i){
                char buf[64];
                std::snprintf(buf, sizeof(buf), "#%02X%02X%02X ", colors[i][2], colors[i][1], colors[i][0]);
                verse += buf;
            }
            content += verse + "\n";
            content += "//-------------------------------------------------\n";
            continue;
        }
        content += line + "\n";
    }
    std::ofstream out(src);
    out << content;
}

// --------------------------------------------------

int main(int argc,char**argv){
    // Init webcam
    cv::VideoCapture cap(0);
    if(!cap.isOpened()){
        std::cerr<<"Cannot open camera\n";
        return -1;
    }

    // Init SDL (audio+video)
    if(SDL_Init(SDL_INIT_VIDEO|SDL_INIT_AUDIO)<0){
        std::cerr<<"SDL init failed: "<<SDL_GetError()<<"\n";
        return -1;
    }

    SDL_Window* win = SDL_CreateWindow("Synesthetic Poem",
        SDL_WINDOWPOS_CENTERED,SDL_WINDOWPOS_CENTERED,800,600,SDL_WINDOW_OPENGL);
    SDL_Renderer* ren = SDL_CreateRenderer(win,-1,SDL_RENDERER_ACCELERATED);

    SDL_AudioSpec want{}, have{};
    want.freq = 48000;
    want.format = AUDIO_F64SYS;
    want.channels = 1;
    want.samples = 1024;
    want.callback = audioCallback;
    if(SDL_OpenAudio(&want,&have)<0){
        std::cerr<<"Audio open: "<<SDL_GetError()<<"\n";
        return -1;
    }
    SDL_PauseAudio(0);

    auto lastPoem = std::chrono::steady_clock::now();

    while(true){
        cv::Mat frame;
        cap>>frame;
        if(frame.empty()) break;
        cv::Mat small;
        cv::resize(frame,small,cv::Size(64,64));

        // K‑means to get dominant colors
        cv::Mat reshaped = small.reshape(1, small.total());
        reshaped.convertTo(reshaped, CV_32F);
        cv::Mat labels, centers;
        cv::kmeans(reshaped, 4, labels,
            cv::TermCriteria(cv::TermCriteria::EPS+cv::TermCriteria::MAX_ITER,10,1.0),
            3, cv::KMEANS_PP_CENTERS, centers);
        std::vector<cv::Vec3b> palette;
        for(int i=0;i<centers.rows;i++){
            cv::Vec3f c = centers.at<cv::Vec3f>(i);
            palette.emplace_back(cv::Vec3b(c[0],c[1],c[2]));
        }

        // Update audio frequency from first palette hue
        cv::Mat hsv;
        cv::cvtColor(palette[0], hsv, cv::COLOR_BGR2HSV);
        double hue = hsv.at<cv::Vec3b>(0)[0] * 2.0; // OpenCV hue 0‑180
        audioState.freq = hueToFreq(hue);

        // Render abstract morphing shapes
        SDL_SetRenderDrawColor(ren,0,0,0,255);
        SDL_RenderClear(ren);
        for(size_t i=0;i<palette.size();++i){
            Uint8 r=palette[i][2], g=palette[i][1], b=palette[i][0];
            SDL_SetRenderDrawColor(ren,r,g,b,200);
            SDL_Rect rect{
                static_cast<int>(200+200*std::sin(SDL_GetTicks()/1000.0+i)),
                static_cast<int>(150+150*std::cos(SDL_GetTicks()/1000.0+i)),
                100,100};
            SDL_RenderFillRect(ren,&rect);
        }
        SDL_RenderPresent(ren);

        // Every few seconds rewrite poem in source
        if(std::chrono::steady_clock::now()-lastPoem>std::chrono::seconds(5)){
            rewritePoem(palette);
            lastPoem=std::chrono::steady_clock::now();
        }

        // Event handling
        SDL_Event e;
        while(SDL_PollEvent(&e)){
            if(e.type==SDL_QUIT) goto end;
        }
    }
end:
    SDL_CloseAudio();
    SDL_DestroyRenderer(ren);
    SDL_DestroyWindow(win);
    SDL_Quit();
    return 0;
}