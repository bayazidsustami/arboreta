#include <bits/stdc++.h>
using namespace std;

// Simple 1‑D cellular automaton (elementary CA) with periodic boundary.
// Uses Rule 30 by default, but any 8‑bit rule can be supplied as a command line argument.

int main(int argc, char* argv[]) {
    // ----- configuration -----
    const int cells = 79;          // width of the universe
    const int steps = 40;          // number of generations to display
    const unsigned char rule = (argc > 1) ? static_cast<unsigned char>(stoi(argv[1])) : 30;
    // -------------------------

    // initialise first generation: single live cell in the centre
    vector<unsigned char> cur(cells, 0), nxt(cells, 0);
    cur[cells / 2] = 1;

    // pre‑compute rule table: index = (left<<2)|(center<<1)|right
    bool table[8];
    for (int i = 0; i < 8; ++i) table[i] = (rule >> i) & 1;

    for (int t = 0; t < steps; ++t) {
        // display current generation
        for (int i = 0; i < cells; ++i) cout << (cur[i] ? '#' : ' ');
        cout << '\n';

        // compute next generation with periodic wrap‑around
        for (int i = 0; i < cells; ++i) {
            int left   = cur[(i - 1 + cells) % cells];
            int center = cur[i];
            int right  = cur[(i + 1) % cells];
            int idx = (left << 2) | (center << 1) | right;
            nxt[i] = table[idx];
        }
        cur.swap(nxt);
    }
    return 0;
}