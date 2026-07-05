import sys, os, math, struct, itertools, threading, time
from collections import deque, Counter

#--- 3D visualization using vpython (pip install vpython) -----------------
try:
    from vpython import canvas, sphere, vector, color, rate, keysdown, scene
except ImportError:
    print("Please install vpython: pip install vpython")
    sys.exit(1)

#--- Simple audio synthesis using simpleaudio (pip install simpleaudio) -----
try:
    import numpy as np, simpleaudio as sa
except ImportError:
    print("Please install numpy and simpleaudio")
    sys.exit(1)

#--- Parameters ------------------------------------------------------------
WINDOW = 256            # bytes for local entropy
SAMPLE_RATE = 44100     # audio
BASE_FREQ = 220.0       # base pitch
MAX_POINTS = 2000       # max spheres displayed

#--- Global state -----------------------------------------------------------
points = deque()
audio_queue = deque()
running = True

#--- Entropy calculation ----------------------------------------------------
def entropy(buf):
    if not buf:
        return 0.0
    freq = Counter(buf)
    probs = [c/len(buf) for c in freq.values()]
    return -sum(p*math.log2(p) for p in probs)

#--- Audio thread -----------------------------------------------------------
def audio_worker():
    while running:
        if audio_queue:
            freq, dur = audio_queue.popleft()
            t = np.linspace(0, dur, int(SAMPLE_RATE*dur), False)
            wave = np.sin(freq*t*2*math.pi) * 0.3
            audio = (wave * 32767).astype(np.int16)
            sa.play_buffer(audio, 1, 2, SAMPLE_RATE)
        else:
            time.sleep(0.01)

threading.Thread(target=audio_worker, daemon=True).start()

#--- Main visualization loop ------------------------------------------------
def main(filepath):
    global running
    if not os.path.isfile(filepath):
        print("File not found:", filepath)
        return

    # read whole file as bytes
    data = open(filepath, "rb").read()
    n = len(data)

    # set up canvas
    scene.title = "Byte‑Entropy Fractal Explorer"
    scene.width = 800
    scene.height = 600
    scene.autoscale = False
    scene.range = 5

    # sliding window for entropy
    win = deque(maxlen=WINDOW)
    for i in range(min(WINDOW, n)):
        win.append(data[i])

    idx = WINDOW
    while running:
        rate(60)

        # compute entropy of current window
        e = entropy(win)
        # map entropy -> radius, color hue, rotation speed
        radius = 0.05 + 0.2*e
        hue = (e % 1.0)
        col = vector(math.sin(hue*2*math.pi), math.cos(hue*2*math.pi), math.sin(hue*math.pi))

        # position based on byte value and index
        b = data[idx % n]
        angle = (b/255.0)*2*math.pi
        r = 2 + (b/255.0)*3
        pos = vector(r*math.cos(angle), (idx%100)/10.0-5, r*math.sin(angle))

        # create sphere
        s = sphere(pos=pos, radius=radius, color=col, make_trail=False)
        points.append(s)
        if len(points) > MAX_POINTS:
            old = points.popleft()
            old.visible = False
            del old

        # audio: map entropy spikes to pitch changes
        freq = BASE_FREQ * (2**(e*4))  # 4 octaves range
        dur = 0.03
        audio_queue.append((freq, dur))

        # advance window
        win.append(data[idx % n])
        idx += 1
        if idx - WINDOW > n:
            idx = WINDOW

        # handle exit
        if 'esc' in keysdown():
            running = False

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python script.py <textfile>")
    else:
        main(sys.argv[1])