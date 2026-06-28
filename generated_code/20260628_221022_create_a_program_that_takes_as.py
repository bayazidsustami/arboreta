import sys, time, math, threading
import numpy as np
import pygame
from pygame import surfarray
from mido import MidiFile
from noise import pnoise2

# ---------- Music analysis ----------
def load_midi(path):
    mid = MidiFile(path)
    ticks_per_beat = mid.ticks_per_beat
    tempo = 500000  # default 120bpm
    # build time‑velocity curve (sum of velocities per beat)
    curve = {}
    cur_time = 0
    for msg in mid:
        cur_time += msg.time
        if msg.type == 'set_tempo':
            tempo = msg.tempo
        if msg.type == 'note_on' and msg.velocity > 0:
            sec = mido_tick_to_sec(cur_time, ticks_per_beat, tempo)
            beat = sec * 2  # 2 beats per second at 120bpm
            idx = int(beat * 4)  # 4 samples per beat
            curve[idx] = curve.get(idx, 0) + msg.velocity
    if not curve:
        curve[0] = 0
    max_idx = max(curve.keys())
    arr = np.zeros(max_idx + 1, dtype=np.float32)
    for i, v in curve.items():
        arr[i] = v
    # smooth
    arr = np.convolve(arr, np.ones(8)/8, mode='same')
    return arr

def mido_tick_to_sec(tick, ticks_per_beat, tempo):
    # tempo in microseconds per beat
    return (tick / ticks_per_beat) * (tempo / 1e6)

# ---------- Visualization ----------
class FractalWorld:
    def __init__(self, music_curve):
        pygame.init()
        self.size = (800, 600)
        self.screen = pygame.display.set_mode(self.size)
        self.clock = pygame.time.Clock()
        self.curve = music_curve
        self.cur_len = len(music_curve)
        self.t = 0.0
        self.offset = 0.0

    def run(self):
        running = True
        while running:
            dt = self.clock.tick(60) / 1000.0
            for e in pygame.event.get():
                if e.type == pygame.QUIT:
                    running = False
            self.t += dt
            idx = int(self.t * 2) % self.cur_len  # 2 samples per sec
            amp = self.curve[idx] / 127.0  # normalize velocity
            self.offset += dt * (0.1 + amp * 0.5)
            self.render(amp)
            pygame.display.flip()
        pygame.quit()

    def render(self, amp):
        w, h = self.size
        scale = 0.005 + amp * 0.02
        speed = 0.1 + amp * 0.4
        arr = np.zeros((h, w, 3), dtype=np.uint8)
        for y in range(h):
            ny = y / h
            for x in range(w):
                nx = x / w
                n = pnoise2((nx + self.offset) * scale,
                            (ny + self.offset) * scale,
                            octaves=4,
                            repeatx=1024,
                            repeaty=1024,
                            base=0)
                height = (n + 0.5) * 255
                col = self.colormap(height, amp)
                arr[y, x] = col
        surf = surfarray.make_surface(arr.swapaxes(0, 1))
        self.screen.blit(surf, (0, 0))

    def colormap(self, h, amp):
        # map height to hue, modulated by music amplitude
        hue = (h / 255.0 + amp) % 1.0
        sat = 0.6 + 0.4 * amp
        val = 0.3 + 0.7 * (h / 255.0)
        return hsv_to_rgb(hue, sat, val)

def hsv_to_rgb(h, s, v):
    i = int(h * 6)
    f = h * 6 - i
    p = int(255 * v * (1 - s))
    q = int(255 * v * (1 - f * s))
    t = int(255 * v * (1 - (1 - f) * s))
    v = int(255 * v)
    i = i % 6
    if i == 0:
        return (v, t, p)
    if i == 1:
        return (q, v, p)
    if i == 2:
        return (p, v, t)
    if i == 3:
        return (p, q, v)
    if i == 4:
        return (t, p, v)
    return (v, p, q)

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print('Usage: python', sys.argv[0], 'path_to_mid')
        sys.exit(1)
    music_curve = load_midi(sys.argv[1])
    world = FractalWorld(music_curve)
    world.run()