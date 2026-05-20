#include <iostream>
#include <vector>
#include <complex>
#include <cmath>
#include <chrono>
#include <thread>
#include <random>
#include <sstream>

// ---------- Simple FFT (Cooley‑Tukey, radix‑2) ----------
using Complex = std::complex<double>;

void fft(std::vector<Complex>& a) {
    const size_t n = a.size();
    if (n <= 1) return;
    // bit reversal permutation
    size_t j = 0;
    for (size_t i = 1; i < n; ++i) {
        size_t bit = n >> 1;
        while (j & bit) { j ^= bit; bit >>= 1; }
        j ^= bit;
        if (i < j) std::swap(a[i], a[j]);
    }
    // Danielson‑Lanczos
    for (size_t len = 2; len <= n; len <<= 1) {
        double ang = -2 * M_PI / len;
        Complex wlen(cos(ang), sin(ang));
        for (size_t i = 0; i < n; i += len) {
            Complex w(1);
            for (size_t k = 0; k < len / 2; ++k) {
                Complex u = a[i + k];
                Complex v = a[i + k + len / 2] * w;
                a[i + k] = u + v;
                a[i + k + len / 2] = u - v;
                w *= wlen;
            }
        }
    }
}

// ---------- L‑system handling ----------
struct LSystem {
    std::string axiom;
    std::vector<std::pair<char, std::string>> rules;
    int iterations;

    // produce the string after n iterations
    std::string generate() const {
        std::string cur = axiom;
        for (int it = 0; it < iterations; ++it) {
            std::string nxt;
            for (char c : cur) {
                bool replaced = false;
                for (auto& r : rules) {
                    if (r.first == c) { nxt += r.second; replaced = true; break; }
                }
                if (!replaced) nxt += c;
            }
            cur.swap(nxt);
        }
        return cur;
    }
};

// ---------- SVG rendering ----------
struct SVG {
    std::ostringstream out;
    int width, height;
    SVG(int w, int h) : width(w), height(h) {
        out << "<?xml version=\"1.0\" standalone=\"no\"?>\n";
        out << "<svg xmlns=\"http://www.w3.org/2000/svg\" ";
        out << "width=\"" << w << "\" height=\"" << h << "\">\n";
    }
    void line(double x1,double y1,double x2,double y2,std::string color,double width) {
        out << "<line x1=\"" << x1 << "\" y1=\"" << y1
            << "\" x2=\"" << x2 << "\" y2=\"" << y2
            << "\" stroke=\"" << color << "\" stroke-width=\"" << width << "\"/>\n";
    }
    void finish() { out << "</svg>\n"; }
    std::string str() const { return out.str(); }
};

// ---------- Core processing ----------
int main() {
    const int SAMPLE_RATE = 44100;
    const int FFT_SIZE = 1024;            // power of two
    const int BANDS = 8;                  // map to 8 L‑system rules
    const int WIDTH = 800, HEIGHT = 600;

    // Dummy audio source: white noise (replace with real audio capture)
    std::mt19937 rng(std::random_device{}());
    std::uniform_real_distribution<double> dist(-1.0, 1.0);

    // Prepare L‑system rules (one per band)
    std::vector<std::string> ruleTemplates = {
        "F[+F]F[-F]F", "F[+F]F", "F[-F]F", "F[+F]F[-F]F",
        "F[+F]F", "F[-F]F", "F[+F]F[-F]F", "F"
    };
    LSystem lsys;
    lsys.axiom = "F";
    lsys.iterations = 4;
    for (int i = 0; i < BANDS; ++i)
        lsys.rules.push_back({ static_cast<char>('A' + i), ruleTemplates[i] });

    // Main loop – in a real program you'd run until user quits
    for (int frame = 0; frame < 200; ++frame) {
        // 1. Acquire audio chunk
        std::vector<Complex> buffer(FFT_SIZE);
        for (int i = 0; i < FFT_SIZE; ++i) buffer[i] = Complex(dist(rng), 0.0);

        // 2. FFT → magnitude spectrum
        fft(buffer);
        std::vector<double> mag(FFT_SIZE / 2);
        for (size_t i = 0; i < mag.size(); ++i)
            mag[i] = std::abs(buffer[i]);

        // 3. Split spectrum into bands and compute average amplitude per band
        std::vector<double> bandAmp(BANDS, 0.0);
        size_t binsPerBand = mag.size() / BANDS;
        for (int b = 0; b < BANDS; ++b) {
            double sum = 0.0;
            for (size_t i = b * binsPerBand; i < (b + 1) * binsPerBand; ++i)
                sum += mag[i];
            bandAmp[b] = sum / binsPerBand;
        }

        // 4. Map bands to L‑system rules (replace placeholder letters)
        std::string grammar = lsys.axiom;
        for (int b = 0; b < BANDS; ++b) {
            char placeholder = static_cast<char>('A' + b);
            std::string repl = ruleTemplates[b];
            // optionally modulate rule length by amplitude (simple trick)
            int repeat = 1 + static_cast<int>(bandAmp[b] * 5);
            std::string modRule;
            for (int r = 0; r < repeat; ++r) modRule += repl;
            // replace all occurrences
            size_t pos = 0;
            while ((pos = grammar.find(placeholder, pos)) != std::string::npos) {
                grammar.replace(pos, 1, modRule);
                pos += modRule.size();
            }
        }

        // 5. Generate final L‑system string
        LSystem dynamic;
        dynamic.axiom = grammar;
        dynamic.rules = {};               // no further productions
        dynamic.iterations = 0;
        std::string finalString = dynamic.generate();

        // 6. Render to SVG using turtle graphics
        SVG svg(WIDTH, HEIGHT);
        double x = WIDTH / 2.0, y = HEIGHT;
        double angle = -90.0;             // start pointing up
        double step = 8.0;
        std::vector<std::pair<double,double>> stack;
        std::vector<double> angleStack;

        for (char c : finalString) {
            if (c == 'F') {
                double rad = angle * M_PI / 180.0;
                double nx = x + step * cos(rad);
                double ny = y + step * sin(rad);
                // colour pulse based on nearest band amplitude
                int bandIdx = std::clamp(static_cast<int>((angle+180)/45), 0, BANDS-1);
                double amp = bandAmp[bandIdx];
                int hue = static_cast<int>(std::fmod(amp * 3600, 360));
                char color[32];
                snprintf(color, sizeof(color), "hsl(%d,80%%,50%%)", hue);
                svg.line(x, y, nx, ny, color, 1.5);
                x = nx; y = ny;
            } else if (c == '+') {
                angle += 25.0;
            } else if (c == '-') {
                angle -= 25.0;
            } else if (c == '[') {
                stack.emplace_back(x, y);
                angleStack.push_back(angle);
            } else if (c == ']') {
                if (!stack.empty()) {
                    std::tie(x, y) = stack.back(); stack.pop_back();
                    angle = angleStack.back(); angleStack.pop_back();
                }
            }
        }
        svg.finish();

        // 7. Output SVG frame (could be streamed to a file or displayed)
        std::cout << "Frame " << frame << ":\n";
        std::cout << svg.str() << "\n";

        // simple frame rate control
        std::this_thread::sleep_for(std::chrono::milliseconds(30));
    }

    return 0;
}