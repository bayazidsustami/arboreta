#include <opencv2/opencv.hpp>
#include <iostream>
#include <vector>
#include <random>
#include <fstream>
#include <sstream>
#include <cmath>

// Simple wav writer (single‑channel 16‑bit)
struct WavWriter{
    std::vector<short> data;
    void push(float sample){
        if(sample>1.f) sample=1.f;
        if(sample<-1.f) sample=-1.f;
        data.push_back(static_cast<short>(sample*32767));
    }
    void write(const std::string& fn){
        std::ofstream f(fn, std::ios::binary);
        int32_t subchunk2Size = data.size()*sizeof(short);
        int32_t chunkSize = 36 + subchunk2Size;
        f.write("RIFF",4);
        f.write(reinterpret_cast<char*>(&chunkSize),4);
        f.write("WAVE",4);
        f.write("fmt ",4);
        int32_t subchunk1Size=16;
        f.write(reinterpret_cast<char*>(&subchunk1Size),4);
        int16_t audioFormat=1, numChannels=1, bitsPerSample=16;
        f.write(reinterpret_cast<char*>(&audioFormat),2);
        f.write(reinterpret_cast<char*>(&numChannels),2);
        int32_t sampleRate=44100;
        f.write(reinterpret_cast<char*>(&sampleRate),4);
        int32_t byteRate=sampleRate* numChannels * bitsPerSample/8;
        f.write(reinterpret_cast<char*>(&byteRate),4);
        int16_t blockAlign=numChannels*bitsPerSample/8;
        f.write(reinterpret_cast<char*>(&blockAlign),2);
        f.write(reinterpret_cast<char*>(&bitsPerSample),2);
        f.write("data",4);
        f.write(reinterpret_cast<char*>(&subchunk2Size),4);
        f.write(reinterpret_cast<char*>(data.data()), subchunk2Size);
    }
};

// map a hue (0‑360) to a microtonal note frequency (C = 261.63 Hz)
float hueToFreq(float h){
    // 12‑tone equal temperament + 3 extra micro‑steps per semitone
    const float base=261.63f;
    float step = std::pow(2.f, 1.f/12.f/3.f); // 3 micro‑steps
    int idx = static_cast<int>(h/30.f); // 12 hues around circle
    return base*std::pow(step, idx);
}

// generate a short tone for given frequency
void addTone(WavWriter& wav, float freq, float dur){
    const int SR=44100;
    int N = static_cast<int>(dur*SR);
    for(int i=0;i<N;i++){
        float t=i/(float)SR;
        float env = std::pow(1.f- t/dur,2); // simple decay
        wav.push( std::sin(2*M_PI*freq*t) * env );
    }
}

// extract dominant colors using k‑means (k=4)
std::vector<cv::Vec3b> dominantColors(const cv::Mat& img){
    cv::Mat samples(img.rows*img.cols,3,CV_32F);
    for(int y=0;y<img.rows;y++)
        for(int x=0;x<img.cols;x++)
            for(int z=0;z<3;z++)
                samples.at<float>(y*img.cols+x,z)=img.at<cv::Vec3b>(y,x)[z];
    cv::Mat labels, centers;
    cv::kmeans(samples,4,labels,
               cv::TermCriteria(cv::TermCriteria::EPS+cv::TermCriteria::COUNT,10,1.0),
               3, cv::KMEANS_PP_CENTERS, centers);
    std::vector<cv::Vec3b> cols;
    for(int i=0;i<4;i++){
        cv::Vec3b c;
        for(int z=0;z<3;z++) c[z]=static_cast<uchar>(centers.at<float>(i,z));
        cols.push_back(c);
    }
    return cols;
}

// generate a minimal HTML5 file embedding the audio and a canvas mandala
void writeHTML(const std::string& wavFile){
    std::ifstream wav(wavFile, std::ios::binary);
    std::ostringstream ss;
    ss << wav.rdbuf();
    std::string wavB64;
    static const char* codetab="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    const std::string& in=ss.str();
    for(size_t i=0;i<in.size();i+=3){
        int b= (static_cast<unsigned char>(in[i])<<16);
        if(i+1<in.size()) b|=static_cast<unsigned char>(in[i+1])<<8;
        if(i+2<in.size()) b|=static_cast<unsigned char>(in[i+2]);
        wavB64+=codetab[(b>>18)&63];
        wavB64+=codetab[(b>>12)&63];
        wavB64+= (i+1<in.size())?codetab[(b>>6)&63]:'=';
        wavB64+= (i+2<in.size())?codetab[b&63]:'=';
    }
    std::ofstream html("art.html");
    html<<"<!DOCTYPE html><html><head><meta charset='utf-8'><title>Audio‑Visual Symphonia</title></head><body style='margin:0;background:#000;'>"
        "<canvas id='c'></canvas>"
        "<audio id='a' src='data:audio/wav;base64,"<<wavB64<<"' autoplay loop></audio>"
        "<script>"
        "const canvas=document.getElementById('c');"
        "const ctx=canvas.getContext('2d');"
        "function resize(){canvas.width=window.innerWidth;canvas.height=window.innerHeight;}"
        "window.onresize=resize;resize();"
        "let t=0;"
        "function draw(){"
        "ctx.clearRect(0,0,canvas.width,canvas.height);"
        "const cx=canvas.width/2, cy=canvas.height/2;"
        "for(let i=0;i<8;i++){"
        "let r= (i+1)*50 + 30*Math.sin(t*0.5+i);"
        "ctx.beginPath();"
        "ctx.arc(cx,cy,r,0,Math.PI*2);"
        "ctx.strokeStyle='hsl('+((t*20+i*45)%360)+',80%,60%)';"
        "ctx.lineWidth=2+Math.sin(t+i);"
        "ctx.stroke();"
        "}"
        "t+=0.02; requestAnimationFrame(draw);}"
        "draw();"
        "</script></body></html>";
}

// main loop: capture, analyse, synthesize, output HTML
int main(){
    cv::VideoCapture cap(0);
    if(!cap.isOpened()){
        std::cerr<<"Cannot open webcam\n";
        return -1;
    }
    WavWriter wav;
    for(int frame=0; frame<120; ++frame){ // ~4 seconds @30fps
        cv::Mat img; cap>>img;
        if(img.empty()) break;
        cv::resize(img,img,cv::Size(160,120)); // speed
        auto cols=dominantColors(img);
        for(const auto& c:cols){
            cv::Mat hsv; cv::cvtColor(cv::Mat(1,1,CV_8UC3,c),hsv,cv::COLOR_BGR2HSV);
            float hue=hsv.at<cv::Vec3b>(0,0)[0]*2; // 0‑360
            float freq=hueToFreq(hue);
            addTone(wav,freq,0.03f);
        }
    }
    wav.write("sound.wav");
    writeHTML("sound.wav");
    std::cout<<"Generated art.html + sound.wav\n";
    return 0;
}