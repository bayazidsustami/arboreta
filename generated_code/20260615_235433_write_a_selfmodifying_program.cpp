#include <bits/stdc++.h>
using namespace std;

//=== BEGIN PAYLOAD =========================================================
// This block will be shuffled on each run but stays inside a comment so the
// program stays syntactically correct. Anything can be placed here.
//==========================================================================
//ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789
//==========================================================================
//=== END PAYLOAD ===========================================================

int main(int argc, char* argv[]) {
    // 1. read own source
    const string filename = argv[0];
    ifstream in(filename);
    if (!in) return 1;
    string src((istreambuf_iterator<char>(in)), istreambuf_iterator<char>());
    in.close();

    // 2. locate payload region
    const string startTag = "//=== BEGIN PAYLOAD";
    const string endTag   = "//=== END PAYLOAD";
    size_t start = src.find(startTag);
    size_t end   = src.find(endTag, start);
    if (start==string::npos||end==string::npos) return 1;
    // move to end of line after startTag
    start = src.find('\n', start);
    end   = src.rfind('\n', end);
    if (start==string::npos||end==string::npos) return 1;
    string payload = src.substr(start+1, end-start-1);

    // 3. treat payload as 2‑D grid (width = line length of first line)
    vector<string> rows;
    string line;
    stringstream ss(payload);
    size_t maxw = 0;
    while (getline(ss, line)) {
        rows.push_back(line);
        maxw = max(maxw, line.size());
    }
    size_t h = rows.size(), w = maxw;

    // 4. generate height map and simple ANSI terrain
    const string shades = " .:-=+*#%@";
    for (size_t y=0;y<h;y++) {
        for (size_t x=0;x<w;x++) {
            char c = (x<rows[y].size()) ? rows[y][x] : ' ';
            int hval = (unsigned char)c;
            int idx = (hval * (shades.size()-1)) / 255;
            cout << "\x1b[38;5;" << 16+idx << "m" << shades[idx];
        }
        cout << "\x1b[0m\n";
    }

    // 5. shuffle payload according to height sorting (stable)
    struct Cell { size_t y,x; unsigned char h; char ch; };
    vector<Cell> cells;
    for (size_t y=0;y<h;y++)
        for (size_t x=0;x<rows[y].size();x++)
            cells.push_back({y,x,(unsigned char)rows[y][x], rows[y][x]});
    stable_sort(cells.begin(), cells.end(),
        [](const Cell&a,const Cell&b){ return a.h<b.h; });
    // write back sorted chars in same scan order
    size_t idx=0;
    for (size_t y=0;y<h;y++)
        for (size_t x=0;x<rows[y].size();x++)
            rows[y][x]=cells[idx++].ch;

    // rebuild payload string
    string newPayload;
    for (auto &r:rows) {
        newPayload+=r;
        newPayload+='\n';
    }

    // 6. replace old payload in source
    src.replace(start+1, end-start-1, newPayload);

    // 7. write back to file
    ofstream out(filename);
    out<<src;
    return 0;
}