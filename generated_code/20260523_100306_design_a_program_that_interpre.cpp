#include <bits/stdc++.h>
using namespace std;

/* ---------- Simple L‑System ---------- */
struct LSystem {
    string axiom;
    unordered_map<char,string> rules;
    string current;

    LSystem(string a) : axiom(move(a)), current(axiom) {}

    // one iteration
    void expand() {
        string nxt;
        nxt.reserve(current.size()*2);
        for(char c: current){
            auto it = rules.find(c);
            nxt += (it==rules.end()? string(1,c) : it->second);
        }
        current.swap(nxt);
    }

    // add/override a rule
    void setRule(char pred, const string& repl){ rules[pred]=repl; }
};

/* ---------- Turtle graphics to SVG ---------- */
struct Turtle {
    double x=0, y=0, angle=0;               // angle in degrees
    double step;                           // length of forward move
    vector<pair<double,double>> poly;      // vertices of current polyline
    string path;                           // SVG path data
    string stroke;                         // colour

    Turtle(double s, string col) : step(s), stroke(move(col)){
        poly.emplace_back(x,y);
    }

    void forward(){
        double rad = angle*M_PI/180.0;
        x += step*cos(rad);
        y += step*sin(rad);
        poly.emplace_back(x,y);
    }
    void turn(double deg){ angle+=deg; }

    // convert collected points to a single SVG path element
    void flushPath(){
        if(poly.size()<2) return;
        stringstream ss;
        ss<<"<path d=\"M "<<poly[0].first<<" "<<poly[0].second;
        for(size_t i=1;i<poly.size();++i)
            ss<<" L "<<poly[i].first<<" "<<poly[i].second;
        ss<<"\" stroke=\""<<stroke<<"\" fill=\"none\" stroke-width=\"1\"/>\n";
        path+=ss.str();
        poly.clear();
        poly.emplace_back(x,y);
    }
};

/* ---------- Helper: map frequency to colour (HSV→RGB) ---------- */
static string freqToHex(double f){
    // map audible range 20‑20000 Hz to hue 0‑360
    double hue = f<20?0: f>20000?360: (f-20.0)/(20000.0-20.0)*360.0;
    double c = 1.0, x = c*(1-abs(fmod(hue/60.0,2)-1)), m=0;
    double r=0,g=0,b=0;
    if(hue<60){ r=c; g=x; }
    else if(hue<120){ r=x; g=c; }
    else if(hue<180){ g=c; b=x; }
    else if(hue<240){ g=x; b=c; }
    else if(hue<300){ r=x; b=c; }
    else { r=c; b=x; }
    int R=int((r+m)*255), G=int((g+m)*255), B=int((b+m)*255);
    char buf[8];
    snprintf(buf,sizeof(buf),"#%02X%02X%02X",R,G,B);
    return string(buf);
}

/* ---------- Main program ---------- */
int main(){
    ios::sync_with_stdio(false);
    cin.tie(nullptr);

    // Initialise a tiny L‑system (a simple binary tree)
    LSystem sys("F");
    sys.setRule('F',"F[+F]F[-F]F");   // default rule, will be mutated

    const double step = 5.0;          // drawing step size
    int frame=0;

    double freq;
    while(cin>>freq){                 // read frequencies from stdin (one per line)
        // 1) adapt grammar: low frequencies add a branching rule, high frequencies change angle
        if(freq<300){                  // bass → more branching
            sys.setRule('F',"F[+F]F[-F]F");
        }else if(freq>2000){          // treble → tighten the pattern
            sys.setRule('F',"F[+F]F");
        }

        // 2) expand the L‑system one generation per frequency sample
        sys.expand();

        // 3) draw the result
        string colour = freqToHex(freq);
        Turtle t(step, colour);
        double angleStep = 25.0;       // base turning angle
        // modify angle slightly according to frequency noise
        angleStep += (freq - 1000.0)/4000.0*5.0;

        for(char c: sys.current){
            switch(c){
                case 'F': t.forward(); break;
                case '+': t.turn(angleStep); break;
                case '-': t.turn(-angleStep); break;
                case '[': {
                    t.flushPath();                // start new polyline
                    // push state
                    t.poly.push_back({t.x,t.y}); // dummy – we keep only position
                    // for simplicity we ignore stack; a full implementation would use a std::stack
                } break;
                case ']': {
                    t.flushPath();                // end current polyline
                    // pop state (ignored)
                } break;
                default: break;
            }
        }
        t.flushPath();

        // 4) emit an SVG frame
        stringstream svg;
        svg<<"<?xml version=\"1.0\" standalone=\"no\"?>\n"
           "<!DOCTYPE svg PUBLIC \"-//W3C//DTD SVG 1.1//EN\" "
           "\"http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd\">\n"
           "<svg xmlns=\"http://www.w3.org/2000/svg\" version=\"1.1\" "
           "width=\"800\" height=\"800\" viewBox=\"-400 -400 800 800\">\n"
           "<g transform=\"scale(1,-1)\">\n"   // Y‑up coordinate system
           <<t.path
           "</g>\n</svg>\n";

        string filename = "frame_" + to_string(frame++) + ".svg";
        ofstream out(filename);
        out<<svg.str();
        out.close();

        // optional: limit number of frames to keep runtime reasonable
        if(frame>200) break;
    }
    return 0;
}