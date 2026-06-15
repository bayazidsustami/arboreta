#include <bits/stdc++.h>
#include <chrono>
#include <thread>
#include <regex>
#include <iostream>
#include <fstream>
#include <sstream>
#include <random>

// Simple sentiment word lists
const std::unordered_set<std::string> POSITIVE = {"joy","happy","love","bright","good","wonderful","great","excellent","pleased"};
const std::unordered_set<std::string> NEGATIVE = {"sad","bad","hate","pain","dark","terrible","awful","sorrow","angry"};

// ANSI colour helpers
std::string colour(int r,int g,int b){ return "\033[38;2;" + std::to_string(r) + ";" + std::to_string(g) + ";" + std::to_string(b) + "m"; }
std::string bgColour(int r,int g,int b){ return "\033[48;2;" + std::to_string(r) + ";" + std::to_string(g) + ";" + std::to_string(b) + "m"; }
const std::string RESET = "\033[0m";

// Braille pattern generator (U+2800 + bits)
char32_t braille(int dots){ return 0x2800 + dots; }

// Convert UTF-32 codepoint to UTF-8 string
std::string u8(char32_t cp){
    std::string r;
    if(cp<=0x7F) r+=static_cast<char>(cp);
    else if(cp<=0x7FF){
        r+=static_cast<char>(0xC0|((cp>>6)&0x1F));
        r+=static_cast<char>(0x80|(cp&0x3F));
    }else if(cp<=0xFFFF){
        r+=static_cast<char>(0xE0|((cp>>12)&0x0F));
        r+=static_cast<char>(0x80|((cp>>6)&0x3F));
        r+=static_cast<char>(0x80|(cp&0x3F));
    }else{
        r+=static_cast<char>(0xF0|((cp>>18)&0x07));
        r+=static_cast<char>(0x80|((cp>>12)&0x3F));
        r+=static_cast<char>(0x80|((cp>>6)&0x3F));
        r+=static_cast<char>(0x80|(cp&0x3F));
    }
    return r;
}

// Very cheap “syntactic complexity”: longer sentences → higher complexity
int sentenceComplexity(const std::string& s){
    return std::min(255, static_cast<int>(s.size()));
}

// Sentiment score: +1 per positive word, -1 per negative word
int sentimentScore(const std::string& w){
    std::string lw=w; std::transform(lw.begin(),lw.end(),lw.begin(),::tolower);
    if(POSITIVE.count(lw)) return 1;
    if(NEGATIVE.count(lw)) return -1;
    return 0;
}

// Map sentiment to colour (red→green)
std::tuple<int,int,int> sentimentColour(int score){
    int r = std::max(0,255-100*score);
    int g = std::max(0,255+100*score);
    int b = 100;
    return {r,g,b};
}

// Render a word as a block of Braille cells whose pattern depends on score & complexity
std::string renderWord(const std::string& word,int score,int complexity){
    // Use score to pick a base dot pattern
    int base = (score+1)*4; // -4,-0,4
    // Complexity influences extra random dots
    std::mt19937 rng(std::hash<std::string>{}(word));
    std::uniform_int_distribution<int> dist(0,0xFF);
    int dots = base ^ (dist(rng) & (complexity>>4));
    char32_t cell = braille(dots&0xFF);
    auto [r,g,b]=sentimentColour(score);
    return colour(r,g,b)+u8(cell)+RESET;
}

// Simple audio placeholder: prints a line that would represent a note
void playAudioPlaceholder(const std::string& phoneme){
    // In a real implementation this would synthesize a tone.
    std::cout << "\033[2K\r" << colour(200,200,200) << "[audio:" << phoneme << "]" << RESET << std::flush;
}

// Main loop: reads file, split into sentences, animate
int main(int argc,char* argv[]){
    if(argc<2){
        std::cerr<<"Usage: "<<argv[0]<<" <textfile>\n";
        return 1;
    }
    std::ifstream in(argv[1]);
    if(!in){ std::cerr<<"Cannot open file.\n"; return 1; }

    std::stringstream buf; buf<<in.rdbuf();
    std::string text=buf.str();

    // Split into sentences (very naive)
    std::vector<std::string> sentences;
    std::regex rgx("([^.!?]*[.!?])");
    for(std::sregex_iterator i=text.begin(), e=text.end(), it(i, e, rgx); it!=e; ++it){
        sentences.push_back(it->str());
    }

    // Animation parameters
    const int FPS = 10;
    const int frameDelay = 1000/FPS;

    // Main animation loop
    for(int frame=0;;++frame){
        std::cout<<"\033[2J\033[H"; // clear screen, home cursor
        for(const auto& sent: sentences){
            int comp = sentenceComplexity(sent);
            std::istringstream ss(sent);
            std::string w;
            while(ss>>w){
                int sc = sentimentScore(w);
                std::cout<<renderWord(w,sc,comp)<<" ";
                // Simulate audio sync (phoneme approximated by first letter)
                if(frame%FPS==0) playAudioPlaceholder(std::string(1,std::tolower(w[0])));
            }
            std::cout<<"\n";
        }
        std::cout.flush();
        std::this_thread::sleep_for(std::chrono::milliseconds(frameDelay));
        // Exit on key press (non‑blocking simple check)
        if(std::cin.rdbuf()->in_avail()){
            break;
        }
    }
    std::cout<<RESET<<std::endl;
    return 0;
}