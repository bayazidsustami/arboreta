#include <opencv2/opencv.hpp>
#include <SFML/Graphics.hpp>
#include <SFML/Audio.hpp>
#include <random>
#include <string>
#include <vector>
#include <cmath>
#include <chrono>

// ---------- Simple sentiment mock ----------
enum class Emotion { Happy, Sad, Angry, Calm };
Emotion getRandomEmotion()
{
    static std::mt19937 rng(std::random_device{}());
    static std::uniform_int_distribution<int> dist(0, 3);
    return static_cast<Emotion>(dist(rng));
}

// ---------- L‑system ----------
struct Rule { char predecessor; std::string successor; };
class LSystem
{
public:
    LSystem(const std::string& axiom, const std::vector<Rule>& rules)
        : current(axiom), prodRules(rules) {}

    void iterate()
    {
        std::string next;
        for (char ch : current)
        {
            bool replaced = false;
            for (const auto& r : prodRules)
                if (r.predecessor == ch) { next += r.successor; replaced = true; break; }
            if (!replaced) next += ch;
        }
        current = std::move(next);
    }
    const std::string& get() const { return current; }

private:
    std::string current;
    std::vector<Rule> prodRules;
};

// ---------- Fractal drawing ----------
void drawFractal(sf::RenderWindow& win, const std::string& seq, float angleDeg, float step)
{
    sf::Vector2f pos(win.getSize().x/2.f, win.getSize().y);
    float angle = -90.f; // start upward
    std::vector<sf::Vector2f> stackPos;
    std::vector<float>      stackAng;

    sf::VertexArray lines(sf::LinesStrip);
    lines.append(sf::Vertex(pos, sf::Color::White));

    for (char c : seq)
    {
        switch (c)
        {
            case 'F':
            {
                sf::Vector2f dir(std::cos(angle * 3.14159265f/180.f),
                                 std::sin(angle * 3.14159265f/180.f));
                pos += dir * step;
                lines.append(sf::Vertex(pos, sf::Color::White));
                break;
            }
            case '+': angle += angleDeg; break;
            case '-': angle -= angleDeg; break;
            case '[':
                stackPos.push_back(pos);
                stackAng.push_back(angle);
                break;
            case ']':
                if (!stackPos.empty())
                {
                    pos = stackPos.back(); stackPos.pop_back();
                    angle = stackAng.back(); stackAng.pop_back();
                    lines.append(sf::Vertex(pos, sf::Color::White));
                }
                break;
        }
    }
    win.draw(lines);
}

// ---------- Audio generation ----------
class ToneStream : public sf::SoundStream
{
public:
    void start(float freq, float volume)
    {
        phase = 0.f;
        this->freq = freq;
        this->vol = volume;
        setPitch(1.f);
        setVolume(volume);
        initialize(1, 44100);
        play();
    }

    void setFrequency(float f) { freq = f; }

protected:
    virtual bool onGetData(Chunk& data) override
    {
        const std::size_t sampleCount = 4410; // 0.1s buffer
        samples.resize(sampleCount);
        const float twoPi = 6.283185307179586f;
        for (std::size_t i = 0; i < sampleCount; ++i)
        {
            samples[i] = static_cast<sf::Int16>(std::sin(phase) * 30000);
            phase += twoPi * freq / 44100.f;
            if (phase > twoPi) phase -= twoPi;
        }
        data.samples = samples.data();
        data.sampleCount = sampleCount;
        return true;
    }

    virtual void onSeek(sf::Time) override {}

private:
    std::vector<sf::Int16> samples;
    float freq = 440.f;
    float vol = 100.f;
    float phase = 0.f;
};

// ---------- Mapping ----------
LSystem createLSystem(Emotion e)
{
    // Simple deterministic rules per emotion
    if (e == Emotion::Happy)
        return LSystem("F", { {'F',"F[+F]F[-F]F"} });
    if (e == Emotion::Sad)
        return LSystem("F", { {'F',"F[--F]F[++F]F"} });
    if (e == Emotion::Angry)
        return LSystem("F", { {'F',"F[+F]F[+F]F"} });
    // Calm
    return LSystem("F", { {'F',"F[--F]F"} });
}
float emotionTempo(Emotion e)
{
    switch (e)
    {
        case Emotion::Happy: return 120.f;
        case Emotion::Sad:   return 60.f;
        case Emotion::Angry: return 150.f;
        default:             return 80.f;
    }
}

// ---------- Main ----------
int main()
{
    // OpenCV webcam
    cv::VideoCapture cam(0);
    if (!cam.isOpened()) return -1;

    // SFML window for graphics
    sf::RenderWindow win(sf::VideoMode(800,600), "Emotion Fractal Show");
    win.setFramerateLimit(30);

    // Audio
    ToneStream tone;
    tone.setVolume(50.f);

    // State
    Emotion curEmo = Emotion::Calm;
    LSystem lsys = createLSystem(curEmo);
    int iterCount = 0;
    auto lastSwap = std::chrono::steady_clock::now();

    while (win.isOpen())
    {
        // ----- camera frame (unused, just to keep feed live) -----
        cv::Mat frame;
        cam >> frame;
        if (frame.empty()) break;

        // ----- event handling -----
        sf::Event ev;
        while (win.pollEvent(ev))
            if (ev.type == sf::Event::Closed) win.close();

        // ----- emotion change every 2 seconds -----
        auto now = std::chrono::steady_clock::now();
        if (std::chrono::duration_cast<std::chrono::seconds>(now-lastSwap).count() > 2)
        {
            curEmo = getRandomEmotion();
            lsys = createLSystem(curEmo);
            iterCount = 0;
            tone.start(440.f, 50.f);
            lastSwap = now;
        }

        // ----- L‑system iteration and draw -----
        if (iterCount < 5) { lsys.iterate(); ++iterCount; }

        win.clear(sf::Color::Black);
        drawFractal(win, lsys.get(), 25.f, 5.f);
        win.display();

        // ----- Audio tempo based on emotion -----
        float baseFreq = 220.f;
        float tempo = emotionTempo(curEmo);
        float freq = baseFreq * (tempo/60.f); // simple mapping
        tone.setFrequency(freq);
    }

    tone.stop();
    return 0;
}