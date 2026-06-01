import cv2
import numpy as np
import sounddevice as sd
import pygame
import threading
import time
from scipy.fft import rfft, rfftfreq
from scipy.ndimage import sobel

# ---------- Audio synthesis ----------
SAMPLE_RATE = 44100
TONE_COUNT = 24                     # our micro‑tonal scale
BASE_FREQ = 55.0                    # low A1
# generate 24‑tone equal‑tempered microtonal frequencies (ratio = 2^(1/24))
scale_freqs = BASE_FREQ * (2 ** (np.arange(TONE_COUNT) / 24.0))

# synth parameters (will be updated per frame)
current_notes = []
note_amplitudes = []
note_phases = np.zeros(TONE_COUNT)

def audio_callback(outdata, frames, time_info, status):
    """Callback feeding the sounddevice output stream."""
    t = (np.arange(frames) + audio_callback.pos) / SAMPLE_RATE
    audio_callback.pos += frames
    signal = np.zeros(frames)
    # simple additive synthesis of active notes
    for i, amp in enumerate(note_amplitudes):
        if amp > 0:
            freq = scale_freqs[i]
            phase = note_phases[i]
            signal += amp * np.sin(2*np.pi*freq*t + phase)
            note_phases[i] = (phase + 2*np.pi*freq*frames/SAMPLE_RATE) % (2*np.pi)
    outdata[:] = signal.reshape(-1, 1)
audio_callback.pos = 0

stream = sd.OutputStream(channels=1, callback=audio_callback,
                         samplerate=SAMPLE_RATE, blocksize=1024)
stream.start()

# ---------- Visualisation ----------
WIDTH, HEIGHT = 960, 540
pygame.init()
screen = pygame.display.set_mode((WIDTH, HEIGHT))
clock = pygame.time.Clock()

# simple bird sprite
BIRD_COLOR = (255, 210, 120)
BIRD_SIZE = 6

class Bird:
    def __init__(self, pos):
        self.pos = np.array(pos, dtype=float)
        self.vel = np.random.randn(2) * 0.5
    def update(self, tension):
        # tension (0‑1) influences speed and direction randomness
        self.vel += (np.random.randn(2) * 0.2) * tension
        speed = np.linalg.norm(self.vel)
        if speed > 5:
            self.vel = self.vel / speed * 5
        self.pos += self.vel
        # wrap around edges
        self.pos[0] %= WIDTH
        self.pos[1] %= HEIGHT
    def draw(self, surf):
        pygame.draw.circle(surf, BIRD_COLOR,
                           self.pos.astype(int), BIRD_SIZE)

birds = [Bird((np.random.rand(2) * [WIDTH, HEIGHT])) for _ in range(50)]

# ---------- Main processing ----------
def map_freq_to_scale(freq):
    """Closest microtonal index for a given frequency."""
    if freq <= 0: return 0
    ratios = scale_freqs / freq
    idx = np.argmin(np.abs(ratios - 1))
    return idx

def compute_edge_density(gray):
    """Edge density via Sobel magnitude."""
    gx = sobel(gray, axis=1)
    gy = sobel(gray, axis=0)
    mag = np.hypot(gx, gy)
    return np.mean(mag) / 255.0

def compute_motion(prev, curr):
    """Simple frame‑difference motion magnitude."""
    diff = cv2.absdiff(prev, curr)
    return np.mean(diff) / 255.0

cap = cv2.VideoCapture(0)
if not cap.isOpened():
    raise RuntimeError("Cannot open webcam")

ret, prev_frame = cap.read()
prev_gray = cv2.cvtColor(prev_frame, cv2.COLOR_BGR2GRAY)

while True:
    # ----- event handling -----
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            cap.release()
            stream.stop()
            pygame.quit()
            quit()

    ret, frame = cap.read()
    if not ret:
        continue
    # resize for speed
    frame = cv2.resize(frame, (WIDTH, HEIGHT))
    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)

    # ----- audio analysis -----
    # take a slice of the luminance channel as a 1‑D signal
    signal = gray.mean(axis=0).astype(np.float32)
    # remove DC
    signal -= signal.mean()
    # FFT
    yf = np.abs(rfft(signal))
    xf = rfftfreq(signal.size, d=1.0/30.0)   # assume ~30 fps temporal sampling
    dominant_idx = np.argmax(yf[1:]) + 1
    dominant_freq = xf[dominant_idx]

    # map dominant frequency → scale tonic
    tonic_idx = map_freq_to_scale(dominant_freq)
    # build a simple chord: tonic + a third + a fifth (wrapping)
    chord_idxs = [(tonic_idx + i) % TONE_COUNT for i in (0, 8, 16)]
    # motion controls which notes are active
    motion = compute_motion(prev_gray, gray)
    # edge density controls overall amplitude envelope
    edge_den = compute_edge_density(gray)

    note_amplitudes = np.zeros(TONE_COUNT)
    for i in chord_idxs:
        note_amplitudes[i] = 0.3 + 0.7 * motion          # louder with motion
    note_amplitudes *= edge_den                           # timbre reacts to edges

    # ----- visual mapping -----
    tension = motion * edge_den               # harmonic tension proxy
    screen.fill((10, 10, 30))
    for bird in birds:
        bird.update(tension)
        bird.draw(screen)

    # overlay semi‑transparent video for reference
    frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
    frame_surf = pygame.surfarray.make_surface(frame_rgb.swapaxes(0,1))
    frame_surf.set_alpha(80)
    screen.blit(frame_surf, (0,0))

    pygame.display.flip()
    clock.tick(30)

    # store for next iteration
    prev_gray = gray.copy()