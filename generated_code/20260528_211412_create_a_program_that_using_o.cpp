#include <iostream>
#include <thread>
#include <chrono>
#include <vector>
#include <string>
#include <opencv2/opencv.hpp>

// Helper: generate a line with combining diacritics that wobble based on a value
std::string decorate(const std::string& base, double intensity) {
    static const std::vector<std::string> diacritics = {
        "\u0300", "\u0301", "\u0302", "\u0303", "\u0304",
        "\u0305", "\u0306", "\u0307", "\u0308", "\u0309",
        "\u030A", "\u030B", "\u030C", "\u030D", "\u030E",
        "\u030F", "\u0310", "\u0311", "\u0312", "\u0313"
    };
    std::string out;
    for (char ch : base) {
        out += ch;
        // pick a diacritic based on intensity and position
        int idx = static_cast<int>((std::sin(intensity) + 1.0) * 5.0) % diacritics.size();
        out += diacritics[idx];
        intensity += 0.3;
    }
    return out;
}

// Simple poem stored as stanzas
const std::vector<std::string> poem = {
    "the moon sighs", 
    "soft shadows dance", 
    "night whispers low", 
    "stars blink awake"
};

// Map facial expression (smile ratio) to a morph factor
double expressionFactor(const cv::Mat& frame) {
    static cv::CascadeClassifier face_cascade;
    static cv::CascadeClassifier smile_cascade;
    static bool loaded = false;
    if (!loaded) {
        face_cascade.load(cv::samples::findFile("haarcascade_frontalface_default.xml"));
        smile_cascade.load(cv::samples::findFile("haarcascade_smile.xml"));
        loaded = true;
    }

    std::vector<cv::Rect> faces;
    face_cascade.detectMultiScale(frame, faces, 1.1, 3);
    if (faces.empty()) return 0.0;

    cv::Mat faceROI = frame(faces[0]);
    std::vector<cv::Rect> smiles;
    smile_cascade.detectMultiScale(faceROI, smiles, 1.7, 20);
    // ratio of smiling width to face width as a simple metric
    double ratio = 0.0;
    if (!smiles.empty()) {
        ratio = static_cast<double>(smiles[0].width) / faces[0].width;
    }
    return ratio; // 0..~0.5
}

int main() {
    // Open default webcam
    cv::VideoCapture cap(0);
    if (!cap.isOpened()) {
        std::cerr << "Cannot open webcam.\n";
        return 1;
    }

    // Hide cursor for nicer animation
    std::cout << "\x1b[?25l";

    while (true) {
        cv::Mat frame;
        cap >> frame;
        if (frame.empty()) break;
        cv::cvtColor(frame, frame, cv::COLOR_BGR2GRAY);
        double factor = expressionFactor(frame); // 0 = neutral, >0 = smile

        // Clear screen
        std::cout << "\x1b[2J\x1b[H";

        // Render each stanza with distortion based on factor and time
        double t = std::chrono::duration<double>(std::chrono::steady_clock::now().time_since_epoch()).count();
        for (size_t i = 0; i < poem.size(); ++i) {
            double intensity = t * (0.5 + factor) + i;
            std::string line = decorate(poem[i], intensity);
            std::cout << line << "\n\n";
        }

        // Small delay to keep ~15 FPS
        std::this_thread::sleep_for(std::chrono::milliseconds(66));

        // Exit on key press
        if (cv::waitKey(1) == 27) break; // ESC
    }

    // Restore cursor
    std::cout << "\x1b[?25h";
    return 0;
}