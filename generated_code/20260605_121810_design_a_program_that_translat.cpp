#include <opencv2/opencv.hpp>
#include <fstream>
#include <vector>
#include <string>
#include <sstream>
#include <iomanip>
#include <chrono>
#include <numeric>

// ------------------------------------------------------------
// Simple GIF encoder (public domain) – single‑header implementation
// Source: https://github.com/charlietangora/gif-h
// ------------------------------------------------------------
#define GIF_MAX_BUFFER_SIZE 512*512*4
struct GifWriter {
    FILE* f;
    uint8_t* palette;
    bool firstFrame;
    int width, height;
    int repeat;
};
static bool GifBegin(GifWriter* writer, const char* filename, int width, int height, int delay, int repeat = -1) {
    writer->f = fopen(filename, "wb");
    if (!writer->f) return false;
    writer->width = width;
    writer->height = height;
    writer->repeat = repeat;
    writer->firstFrame = true;
    static const unsigned char header[] = "GIF89a";
    fwrite(header, 1, 6, writer->f);
    // Logical Screen Descriptor
    uint8_t lsd[7];
    lsd[0] = width & 0xFF; lsd[1] = (width >> 8) & 0xFF;
    lsd[2] = height & 0xFF; lsd[3] = (height >> 8) & 0xFF;
    lsd[4] = 0x80 | 0x70 | 0x07; // GCT flag, color resolution, size of GCT
    lsd[5] = 0; // Background color index
    lsd[6] = 0; // Pixel aspect ratio
    fwrite(lsd, 1, 7, writer->f);
    // Global Color Table (placeholder, will be overwritten later)
    uint8_t gct[3*256] = {0};
    fwrite(gct, 1, sizeof(gct), writer->f);
    // Application Extension for looping
    if (repeat >= 0) {
        uint8_t appExt[19] = {0x21,0xFF,0x0B,'N','E','T','S','C','A','P','E','2','.','0','0','1',0x03,0x01,0,0,0};
        appExt[16] = repeat & 0xFF;
        appExt[17] = (repeat >> 8) & 0xFF;
        fwrite(appExt, 1, 19, writer->f);
    }
    return true;
}
static void writeWord(FILE* f, uint16_t w) {
    fputc(w & 0xFF, f);
    fputc((w >> 8) & 0xFF, f);
}
static void GifWriteFrame(GifWriter* writer, const uint8_t* img, int delay) {
    // Simple 256‑color quantization (median cut omitted for brevity)
    static uint8_t localPal[3*256];
    // Build palette from image (very naive: take first 256 colors)
    memset(localPal,0,sizeof(localPal));
    std::map<uint32_t,int> colMap;
    int idx=0;
    for(int i=0;i<writer->width*writer->height && idx<256;i++) {
        uint32_t c = ((uint32_t)img[i*3+2]<<16)|((uint32_t)img[i*3+1]<<8)|(uint32_t)img[i*3];
        if(colMap.find(c)==colMap.end()){
            colMap[c]=idx;
            localPal[idx*3+0]=(c>>16)&0xFF;
            localPal[idx*3+1]=(c>>8)&0xFF;
            localPal[idx*3+2]=c&0xFF;
            ++idx;
        }
    }
    // Graphic Control Extension
    uint8_t gce[8] = {0x21,0xF9,4,0,0,0,0,0};
    gce[4] = (delay/10)&0xFF;
    gce[5] = (delay/10)>>8;
    fwrite(gce,1,8,writer->f);
    // Image Descriptor
    uint8_t id[10] = {0x2C,0,0,0,0,0,0,0,0,0};
    id[5]=writer->width &0xFF; id[6]=(writer->width>>8)&0xFF;
    id[7]=writer->height &0xFF; id[8]=(writer->height>>8)&0xFF;
    id[9]=0x80|0x07; // local color table flag + size
    fwrite(id,1,10,writer->f);
    // Write local color table
    fwrite(localPal,1,3*256,writer->f);
    // Image Data (LZW minimum code size = 8, no compression)
    fputc(8, writer->f);
    // Sub-blocks
    int dataSize = writer->width*writer->height;
    fputc(dataSize & 0xFF, writer->f);
    fwrite(img,1,dataSize,writer->f);
    fputc(0, writer->f); // block terminator
}
static void GifEnd(GifWriter* writer) {
    fputc(0x3B, writer->f); // Trailer
    fclose(writer->f);
}

// ------------------------------------------------------------
// Helper functions for poetic mapping
// ------------------------------------------------------------
std::string pickSyllable(int hue, int brightness) {
    static const std::vector<std::string> vowels = {"a","e","i","o","u","ae","ai","ou","ia","oo"};
    static const std::vector<std::string> consonants = {"b","c","d","f","g","h","j","k","l","m","n","p","r","s","t","v","w","z"};
    int v = hue % vowels.size();
    int c = brightness % consonants.size();
    return consonants[c] + vowels[v];
}
std::string generateLine(const cv::Mat& diff, const cv::Mat& frame) {
    // Compute average hue and brightness
    cv::Mat hsv;
    cv::cvtColor(frame, hsv, cv::COLOR_BGR2HSV);
    cv::Scalar avgHSV = cv::mean(hsv);
    int hue = static_cast<int>(avgHSV[0]);          // 0‑179
    int brightness = static_cast<int>(avgHSV[2]);   // 0‑255

    // Motion magnitude influences line length
    double motion = cv::mean(diff)[0];
    int syllables = std::max(1, std::min(12, static_cast<int>(motion/4)));

    std::ostringstream line;
    for (int i = 0; i < syllables; ++i)
        line << pickSyllable(hue, brightness);
    // Randomly insert a space to simulate meter
    if (syllables > 4) line.insert(line.str().size()/2, " ");
    return line.str();
}

// ------------------------------------------------------------
int main() {
    cv::VideoCapture cap(0);
    if (!cap.isOpened()) return -1;

    int w = static_cast<int>(cap.get(cv::CAP_PROP_FRAME_WIDTH));
    int h = static_cast<int>(cap.get(cv::CAP_PROP_FRAME_HEIGHT));

    GifWriter gif;
    GifBegin(&gif, "fractal_poem.gif", w, h, 100, 0); // 10 fps, loop forever

    cv::Mat prev, frame, diff;
    std::vector<std::string> poemLines;
    const int totalFrames = 200; // duration ~20 s

    for (int i = 0; i < totalFrames; ++i) {
        cap >> frame;
        if (frame.empty()) break;
        cv::GaussianBlur(frame, frame, cv::Size(5,5), 0);

        if (!prev.empty()) {
            cv::absdiff(frame, prev, diff);
            cv::cvtColor(diff, diff, cv::COLOR_BGR2GRAY);
        } else {
            diff = cv::Mat::zeros(h, w, CV_8U);
        }

        // Generate poetic line from current visual state
        std::string line = generateLine(diff, frame);
        poemLines.push_back(line);

        // Render text onto frame (self‑organizing: each line at varying y)
        int y = 30 + (i%10)*30;
        cv::putText(frame, line, cv::Point(10, y),
                    cv::FONT_HERSHEY_SIMPLEX, 0.7,
                    cv::Scalar(255,255,255), 2, cv::LINE_AA);

        // Convert to 24‑bit BGR for GIF writer
        std::vector<uint8_t> imgData(w*h*3);
        std::memcpy(imgData.data(), frame.data, imgData.size());
        GifWriteFrame(&gif, imgData.data(), 100);

        prev = frame.clone();
    }
    GifEnd(&gif);

    // Export markdown lyric file
    std::ofstream md("fractal_poem.md");
    md << "# Fractal Poem (generated from webcam)\n\n";
    for (size_t i = 0; i < poemLines.size(); ++i) {
        md << poemLines[i] << "  \n"; // markdown line break
        if ((i+1)%4==0) md << "\n";   // stanza break
    }
    md.close();

    return 0;
}