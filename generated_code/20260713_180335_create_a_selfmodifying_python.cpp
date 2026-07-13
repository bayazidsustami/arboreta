#include <bits/stdc++.h>
#include <fstream>
#include <cstdlib>
using namespace std;

// This C++ program generates a self‑modifying Python script that:
// 1. Captures webcam frames with OpenCV.
// 2. Finds the dominant colour palette (k‑means, k=3).
// 3. Picks a short haiku from a mood‑based list.
// 4. Writes back a modified copy of itself, tweaking the mood mapping.
//
// Compile with: g++ -std=c++17 -O2 generate_selfmod.cpp -o generate_selfmod
// Run: ./generate_selfmod   (it creates "selfmod_poet.py" and executes it)

int main() {
    // Python source template with placeholders for mood mapping.
    const string pyTemplate = R"PYTHON(
import cv2, sys, numpy as np, random, json, os

# ---- Configurable mood mapping (will be rewritten) ----
# mood_map maps a colour hue bucket (0-5) to a list of haiku strings.
mood_map = %MOOD_MAP%

def dominant_hues(frame, k=3):
    img = cv2.cvtColor(frame, cv2.COLOR_BGR2HSV)
    pixels = img.reshape(-1, 3)
    # Simple k‑means using OpenCV
    criteria = (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 10, 1.0)
    _, labels, centers = cv2.kmeans(pixels.astype(np.float32), k, None, criteria, 5, cv2.KMEANS_PP_CENTERS)
    hues = centers[:,0]  # hue channel
    # Quantize hue to 6 buckets (0‑5)
    buckets = np.floor(hues / 30).astype(int) % 6
    # Return most common bucket
    uniq, cnts = np.unique(buckets, return_counts=True)
    return int(uniq[np.argmax(cnts)])

def pick_haiku(mood):
    candidates = mood_map.get(str(mood), ["Silent night\\nNo colour sings\\nStillness remains."])
    return random.choice(candidates)

def evolve_mood_map(prev_mood, new_mood):
    # Slightly shift one haiku from prev_mood to new_mood
    src = mood_map.get(str(prev_mood), [])
    dst = mood_map.get(str(new_mood), [])
    if src:
        line = src.pop()
        dst.append(line)
    mood_map[str(prev_mood)] = src
    mood_map[str(new_mood)] = dst
    # Write back modified source
    with open(__file__, 'r') as f: src_code = f.read()
    new_map = json.dumps(mood_map, ensure_ascii=False, indent=4)
    new_code = src_code.replace('%MOOD_MAP%', new_map)
    with open(__file__, 'w') as f: f.write(new_code)

def main():
    cap = cv2.VideoCapture(0)
    if not cap.isOpened():
        print("Cannot open webcam")
        sys.exit(1)
    prev_mood = None
    try:
        while True:
            ret, frame = cap.read()
            if not ret: break
            mood = dominant_hues(frame)
            haiku = pick_haiku(mood)
            print("\\n--- Haiku (mood %d) ---\\n%s\\n" % (mood, haiku))
            if prev_mood is not None:
                evolve_mood_map(prev_mood, mood)
            prev_mood = mood
            # Show frame (optional)
            cv2.imshow('Webcam', frame)
            if cv2.waitKey(1) & 0xFF == ord('q'): break
    finally:
        cap.release()
        cv2.destroyAllWindows()

if __name__ == '__main__':
    main()
)PYTHON)";

    // Initial mood map: 6 hue buckets, each with two simple haikus.
    unordered_map<string, vector<string>> moodMap = {
        {"0", {"Red sunrise\\nFlames kiss the sky\\nMorning awakens.", "Crimson tide\\nWaves whisper softly\\nShores blush."}},
        {"1", {"Orange glow\\nLeaves rustle warm\\nAutumn sighs.", "Mango dusk\\nSun melts slow\\nHorizon sighs."}},
        {"2", {"Yellow bloom\\nSunflowers sway\\nJoyful chorus.", "Gold sunrise\\nFields alight\\nDreams awaken."}},
        {"3", {"Green forest\\nLeaves murmur low\\nLife breaths.", "Emerald mist\\nMorning dew\\nHope glistens."}},
        {"4", {"Blue ocean\\nDepths sing calm\\nStars reflect.", "Cerulean night\\nMoon glides soft\\nSilence hums."}},
        {"5", {"Violet twilight\\nDreams unfold\\nNight embraces.", "Purple haze\\nStars twirl slow\\nNight whispers."}}
    };

    // Convert moodMap to JSON string.
    string jsonMap = "{\n";
    for (auto it = moodMap.begin(); it != moodMap.end(); ++it) {
        jsonMap += "    \"" + it->first + "\": [\n";
        for (size_t i = 0; i < it->second.size(); ++i) {
            jsonMap += "        \"" + it->second[i] + "\"";
            if (i + 1 < it->second.size()) jsonMap += ",";
            jsonMap += "\n";
        }
        jsonMap += "    ]";
        if (next(it) != moodMap.end()) jsonMap += ",";
        jsonMap += "\n";
    }
    jsonMap += "}";

    // Replace placeholder with actual JSON.
    string pyCode = pyTemplate;
    size_t pos = pyCode.find("%MOOD_MAP%");
    if (pos != string::npos) pyCode.replace(pos, 9, jsonMap);

    // Write to file.
    const string filename = "selfmod_poet.py";
    ofstream out(filename);
    out << pyCode;
    out.close();

    // Inform user and launch the script (requires python with opencv-python installed).
    cout << "Generated " << filename << ". Running it now...\n";
    // Use system call; assume python3 is available.
    system(("python3 " + filename).c_str());

    return 0;
}