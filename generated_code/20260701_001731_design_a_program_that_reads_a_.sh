#!/usr/bin/env bash
# audio_swarm.sh - Real‑time audio reactive L‑system particle swarm visualizer
# Dependencies: ffmpeg, python3 with numpy, scipy, pygame
# Usage: ./audio_swarm.sh [audio_source]
#   audio_source can be a device (e.g. "default") or a URL/filename.

set -e

SRC="${1:-default}"       # default audio device
TMP_WAV=$(mktemp --suffix=.wav)

# Capture raw audio (stereo, 44.1k, 16‑bit) from source using ffmpeg
ffmpeg -hide_banner -loglevel error -y -nostdin -i "$SRC" \
       -ar 44100 -ac 2 -f wav "$TMP_WAV" &
FFPID=$!

# Cleanup on exit
cleanup() {
    kill "$FFPID" 2>/dev/null || true
    rm -f "$TMP_WAV"
}
trap cleanup EXIT

# ------------------- Embedded Python visualizer -------------------
python3 - <<'PY'
import sys, os, struct, threading, collections, math, random, time
import numpy as np
import pygame
from scipy.fft import rfft, rfftfreq

# Audio pipe
WAV = open(os.environ.get('TMP_WAV'), 'rb')
# Skip WAV header (44 bytes)
WAV.read(44)

# Parameters
CHUNK = 2048            # samples per analysis frame
RATE = 44100
WIDTH, HEIGHT = 800, 600
MAX_PARTICLES = 300

# L‑system definition
axiom = "A"
rules = {"A":"AB", "B":"A"}
angle = 0.0

# Particle class
class Particle:
    def __init__(self):
        self.pos = np.array([WIDTH/2, HEIGHT/2], dtype=float)
        self.vel = np.random.randn(2)
        self.col = (255,255,255)
    def update(self, attract):
        dir_vec = attract - self.pos
        self.vel += 0.01*dir_vec/ (np.linalg.norm(dir_vec)+1e-6)
        self.vel *= 0.95
        self.pos += self.vel
        # wrap
        self.pos %= [WIDTH, HEIGHT]

# Global state
particles = [Particle() for _ in range(MAX_PARTICLES)]
lstring = axiom
last_time = time.time()

def audio_thread():
    global lstring, angle
    while True:
        data = WAV.read(CHUNK*2*2)   # 2 channels, 2 bytes per sample
        if len(data) < CHUNK*2*2:
            break
        # Convert to mono float32
        samples = np.frombuffer(data, dtype=np.int16).astype(np.float32)
        samples = samples[::2]                     # take one channel
        samples = samples / 32768.0
        # Spectral centroid
        mag = np.abs(rfft(samples))
        freqs = rfftfreq(len(samples), d=1./RATE)
        if mag.sum() == 0:
            centroid = 0
        else:
            centroid = (freqs * mag).sum() / mag.sum()
        # Map centroid to L‑system mutation
        if centroid > 3000:
            rules["A"] = "ABAB"
        elif centroid > 1000:
            rules["A"] = "AB"
        else:
            rules["A"] = "A"
        # Change angle slowly
        angle = (centroid / 8000.0) * 2 * math.pi
        # Evolve string every 0.5s
        if time.time() - audio_thread.last_update > 0.5:
            lstring = "".join(rules.get(ch,ch) for ch in lstring)
            lstring = lstring[-100:]  # keep size manageable
            audio_thread.last_update = time.time()
audio_thread.last_update = time.time()

threading.Thread(target=audio_thread, daemon=True).start()

# Pygame visual loop
pygame.init()
screen = pygame.display.set_mode((WIDTH, HEIGHT))
clock = pygame.time.Clock()

def draw_lsystem():
    # Interpret the L‑system as attractor points
    pos = np.array([WIDTH/2, HEIGHT/2], dtype=float)
    heading = np.array([0, -1], dtype=float)
    points = []
    step = 5
    for cmd in lstring:
        if cmd == "A":
            pos += heading*step
            points.append(pos.copy())
        elif cmd == "B":
            heading = np.array([heading[0]*math.cos(angle)-heading[1]*math.sin(angle),
                                heading[0]*math.sin(angle)+heading[1]*math.cos(angle)])
    return points

while True:
    for ev in pygame.event.get():
        if ev.type == pygame.QUIT:
            pygame.quit(); sys.exit()
    screen.fill((0,0,0))
    attractors = draw_lsystem()
    # Update particles towards nearest attractor
    for p in particles:
        if attractors:
            target = min(attractors, key=lambda a: np.linalg.norm(a-p.pos))
            p.update(np.array(target))
        else:
            p.update(np.array([WIDTH/2, HEIGHT/2]))
        pygame.draw.circle(screen, p.col, p.pos.astype(int), 2)
    pygame.display.flip()
    clock.tick(60)
PY
# End of script