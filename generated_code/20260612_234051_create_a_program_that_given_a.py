import sys, threading, time, math, random, collections
import numpy as np
import pyaudio

# ---------- Audio capture & FFT ----------
CHUNK = 1024
RATE = 44100
BANDS = 12  # number of frequency bands / colors

p = pyaudio.PyAudio()
stream = p.open(format=pyaudio.paInt16,
                channels=1,
                rate=RATE,
                input=True,
                frames_per_buffer=CHUNK)

def get_spectrum():
    data = np.frombuffer(stream.read(CHUNK, exception_on_overflow=False), dtype=np.int16)
    fft = np.abs(np.fft.rfft(data))[:BANDS]
    # simple smoothing
    get_spectrum.history = 0.8 * get_spectrum.history + 0.2 * fft
    return get_spectrum.history
get_spectrum.history = np.zeros(BANDS)

# ---------- Color mapping ----------
def band_to_color(band_idx, magnitude):
    hue = (band_idx / BANDS) * 360
    sat = 80 + 20 * (magnitude / 32768)
    light = 40 + 30 * (magnitude / 32768)
    return f"hsl({hue:.0f},{sat:.0f}%,{light:.0f}%)"

# ---------- SVG generator ----------
SVG_SIZE = 500
def make_svg(spectrum, angle):
    center = SVG_SIZE // 2
    radius = SVG_SIZE * 0.4
    paths = []
    for i, mag in enumerate(spectrum):
        theta = 2*math.pi*i/BANDS + angle
        r = radius * (0.5 + 0.5*mag/32768)
        x = center + r*math.cos(theta)
        y = center + r*math.sin(theta)
        col = band_to_color(i, mag)
        paths.append(f'<circle cx="{x:.2f}" cy="{y:.2f}" r="{5+5*mag/32768:.2f}" fill="{col}" />')
    # kaleidoscopic symmetry: mirror copy
    mirror = ''.join(paths[::-1])
    content = ''.join(paths) + mirror
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{SVG_SIZE}" height="{SVG_SIZE}" viewBox="0 0 {SVG_SIZE} {SVG_SIZE}">
<rect width="100%" height="100%" fill="black"/>
{content}
</svg>'''

def svg_thread():
    angle = 0.0
    while True:
        spec = get_spectrum()
        svg = make_svg(spec, angle)
        with open("kaleido.svg", "w") as f:
            f.write(svg)
        angle += 0.02
        time.sleep(0.05)

# ---------- Poetic stanza generator ----------
VOWELS = "aeiou"
CONSONANTS = "bcdfghjklmnpqrstvwxz"

def syllable_len():
    return random.choice([1,2])

def make_word():
    s = ''
    for _ in range(syllable_len()):
        s += random.choice(CONSONANTS) + random.choice(VOWELS)
    return s

def make_line():
    words = [make_word() for _ in range(random.randint(4,7))]
    return ' '.join(words).capitalize()

def poetic_thread():
    while True:
        # use spectrum to decide stanza length (1‑4 lines)
        lines = int(1 + (np.mean(get_spectrum())/32768)*3)
        stanza = '\n'.join(make_line() for _ in range(lines))
        print("\n--- Poem ---\n" + stanza + "\n")
        time.sleep(4)

# ---------- Main ----------
if __name__ == "__main__":
    threading.Thread(target=svg_thread, daemon=True).start()
    threading.Thread(target=poetic_thread, daemon=True).start()
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        stream.stop_stream()
        stream.close()
        p.terminate()
        sys.exit()