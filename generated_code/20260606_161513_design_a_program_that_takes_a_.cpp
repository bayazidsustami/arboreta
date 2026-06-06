#include <opencv2/opencv.hpp>
#include <iostream>
#include <random>
#include <chrono>
#include <thread>
#include <atomic>

// Simple placeholder for sentiment extraction from audio.
// In a real implementation you would analyse the microphone input,
// transcribe lyrics and run a sentiment model.
// Here we just cycle through a few moods based on time.
enum Sentiment { HAPPY, SAD, ANGRY, CALM };
Sentiment currentSentiment()
{
    using namespace std::chrono;
    static auto start = steady_clock::now();
    auto secs = duration_cast<seconds>(steady_clock::now() - start).count();
    switch ((secs/10)%4) {
        case 0: return HAPPY;
        case 1: return SAD;
        case 2: return ANGRY;
        default:return CALM;
    }
}

// Choose a colour palette based on sentiment.
cv::Vec3b paletteColor(Sentiment s, float value)
{
    // value in [0,1] determines intensity.
    uchar v = static_cast<uchar>(value*255);
    switch(s){
        case HAPPY: return cv::Vec3b(v, 255, 255);           // bright cyan
        case SAD:   return cv::Vec3b(255, v, v);             // reddish
        case ANGRY: return cv::Vec3b(0, 0, v);               // intense blue
        case CALM:  return cv::Vec3b(v, v, 255);             // soft magenta
    }
    return cv::Vec3b(v,v,v);
}

// Apply a simple cellular automaton (totalistic rule 30) on a grayscale image.
void cellularStep(const cv::Mat& src, cv::Mat& dst)
{
    CV_Assert(src.type() == CV_8UC1);
    dst.create(src.size(), src.type());
    const int rows = src.rows, cols = src.cols;

    for(int y=0; y<rows; ++y){
        const uchar* prev = src.ptr<uchar>( (y-1+rows)%rows );
        const uchar* cur  = src.ptr<uchar>( y );
        const uchar* next = src.ptr<uchar>( (y+1)%rows );
        uchar* out = dst.ptr<uchar>( y );
        for(int x=0; x<cols; ++x){
            int sum = 0;
            // 8‑neighbourhood
            sum += prev[(x-1+cols)%cols];
            sum += prev[x];
            sum += prev[(x+1)%cols];
            sum += cur[(x-1+cols)%cols];
            sum += cur[(x+1)%cols];
            sum += next[(x-1+cols)%cols];
            sum += next[x];
            sum += next[(x+1)%cols];

            // Rule 30: new cell = parity of sum & 1 (just for demo)
            out[x] = (sum & 1) ? 255 : 0;
        }
    }
}

// Main processing loop.
int main()
{
    cv::VideoCapture cap(0);
    if(!cap.isOpened()){
        std::cerr<<"Cannot open webcam\n";
        return -1;
    }

    cv::Mat frame, gray, caPrev, caNext, coloured;
    std::mt19937 rng(std::random_device{}());

    // Initialise CA with random noise.
    cap >> frame;
    cv::cvtColor(frame, gray, cv::COLOR_BGR2GRAY);
    caPrev = gray.clone();
    cv::randu(caPrev, 0, 256);

    while(true){
        cap >> frame;
        if(frame.empty()) break;
        cv::cvtColor(frame, gray, cv::COLOR_BGR2GRAY);

        // Mix current video luminance into CA to keep it dynamic.
        cv::addWeighted(caPrev, 0.7, gray, 0.3, 0, caPrev);

        // One CA step.
        cellularStep(caPrev, caNext);
        caPrev = caNext.clone();

        // Colour according to sentiment.
        Sentiment s = currentSentiment();
        coloured.create(frame.size(), CV_8UC3);
        for(int y=0; y<coloured.rows; ++y){
            const uchar* caRow = caPrev.ptr<uchar>(y);
            cv::Vec3b* outRow = coloured.ptr<cv::Vec3b>(y);
            for(int x=0; x<coloured.cols; ++x){
                float norm = caRow[x]/255.f;
                outRow[x] = paletteColor(s, norm);
            }
        }

        // Kaleidoscopic mirroring.
        cv::Mat half = coloured(cv::Rect(0,0,coloured.cols/2,coloured.rows));
        cv::flip(half, half, 1); // horizontal mirror
        cv::imshow("Kaleido CA", coloured);

        if(cv::waitKey(1)==27) break; // ESC to quit
    }
    return 0;
}