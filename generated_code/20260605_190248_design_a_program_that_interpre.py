import numpy as np
import sounddevice as sd
import svgwrite
import time
import threading
import math

# ---------- Audio analysis ----------
FS = 44100            # sampling rate
CHUNK = 1024          # samples per frame
BANDS = [(20, 200), (200, 800), (800, 3000), (3000, 8000)]  # low‑mid‑high bands

class AudioState:
    def __init__(self):
        self.lock = threading.Lock()
        self.amps = np.zeros(len(BANDS))
        self.centroid = 0.0
        self.beat = False

audio = AudioState()

def audio_callback(indata, frames, time_info, status):
    data = np.mean(indata, axis=1)               # mono
    fft = np.abs(np.fft.rfftfreq(len(data), 1/FS))
    spectrum = np.abs(np.fft.rfft(data))
    # band amplitudes
    amps = []
    for lo, hi in BANDS:
        idx = np.where((fft >= lo) & (fft < hi))[0]
        amps.append(spectrum[idx].mean() if idx.size else 0)
    # spectral centroid as timbre proxy
    centroid = (fft * spectrum).sum() / (spectrum.sum() + 1e-9)
    # simple beat detection (energy spike)
    energy = np.linalg.norm(data)
    beat = energy > 0.3  # crude threshold
    with audio.lock:
        audio.amps = np.array(amps)
        audio.centroid = centroid
        audio.beat = beat

stream = sd.InputStream(callback=audio_callback, channels=1, samplerate=FS, blocksize=CHUNK)
stream.start()

# ---------- L‑system ----------
axiom = "A"
rules = {
    "A": ["AB", "AC", "AD", "AE"],
    "B": ["BF", "BG", "BH", "BI"],
    "C": ["CJ", "CK", "CL", "CM"],
    "D": ["DN", "DO", "DP", "DQ"],
    "E": ["ER", "ES", "ET", "EU"]
}
# mapping band index -> rule choice offset
def next_string(s):
    with audio.lock:
        band_idx = np.argmax(audio.amps)          # dominant band selects symbol to expand
        offset = np.argmax(audio.amps) % 4        # which production to pick
    out = []
    for ch in s:
        if ch in rules:
            prod = rules[ch][offset]
            out.append(prod)
        else:
            out.append(ch)
    return "".join(out)

# ---------- SVG mandala ----------
def draw_mandala(path_str, depth, line_w, hue):
    dwg = svgwrite.Drawing("mandala.svg", size=("600px","600px"))
    cx, cy = 300, 300
    radius = 200
    def turtle(pos, angle, idx, max_idx):
        if idx == max_idx:
            return
        # interpret symbols: A‑E branches, other chars ignored
        for sym in path_str:
            if sym in "ABCDE":
                x = pos[0] + radius * math.cos(math.radians(angle))
                y = pos[1] + radius * math.sin(math.radians(angle))
                dwg.add(dwg.line(pos, (x, y),
                                 stroke=svgwrite.rgb((hue+idx*30)%256, 100, 200, '%'),
                                 stroke_width=line_w))
                turtle((x, y), angle+72, idx+1, max_idx)
                angle -= 72
    turtle((cx, cy), 0, 0, depth)
    dwg.save()

# ---------- Main loop ----------
def main():
    current = axiom
    while True:
        with audio.lock:
            beat = audio.beat
            amp = audio.amps.mean()
            centroid = audio.centroid
        if beat:
            current = next_string(current)
        # map audio features to visual params
        depth = 2 + int(min(amp*20, 6))            # recursion depth 2‑8
        line_w = 0.5 + (centroid % 1000) / 2000    # line thickness 0.5‑1
        hue = int((amp * 500) % 256)              # color hue
        draw_mandala(current, depth, line_w, hue)
        time.sleep(0.1)                           # sync speed loosely to beat

if __name__ == "__main__":
    try:
        main()
    finally:
        stream.stop()
        stream.close()