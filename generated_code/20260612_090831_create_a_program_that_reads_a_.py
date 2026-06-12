import cv2
import numpy as np
from sklearn.cluster import KMeans
import pygame
import math
import time

# ---------- Settings ----------
NUM_COLORS = 5               # how many palette swatches
WINDOW_SIZE = (800, 800)     # mandala window
FPS = 30                     # render fps
BASE_FREQ = 220.0            # base note (A3)
SCALE = [0, 2, 4, 5, 7, 9, 11, 12]  # major scale intervals
# --------------------------------

# initialise webcam
cap = cv2.VideoCapture(0)
if not cap.isOpened():
    raise RuntimeError("Cannot open webcam")

# initialise pygame for audio + graphics
pygame.init()
screen = pygame.display.set_mode(WINDOW_SIZE)
clock = pygame.time.Clock()
pygame.mixer.pre_init(44100, -16, 2, 512)
pygame.mixer.init()
# simple sine wave generator
def sine_wave(freq, dur=0.5, volume=0.3):
    sample_rate = 44100
    n = int(sample_rate * dur)
    t = np.linspace(0, dur, n, False)
    wave = np.sin(2 * np.pi * freq * t) * volume
    wave = np.int16(wave * 32767)
    sound = pygame.sndarray.make_sound(wave)
    return sound

# map each palette colour to a frequency in the scale
def colour_to_freq(col):
    # map hue to scale degree
    hsv = cv2.cvtColor(np.uint8([[col]]), cv2.COLOR_BGR2HSV)[0][0]
    hue = hsv[0] / 180.0            # 0‑1
    degree = int(hue * len(SCALE)) % len(SCALE)
    octave = 4 + int(hue * 2)       # 4‑5
    freq = BASE_FREQ * (2 ** (octave - 3)) * (2 ** (SCALE[degree] / 12.0))
    return freq

# mandala petal drawing based on sound params
def draw_petal(angle, radius, width, color):
    points = []
    for a in np.linspace(angle - width/2, angle + width/2, 10):
        r = radius * (0.5 + 0.5*np.sin(3*a))  # fractal wiggle
        x = WINDOW_SIZE[0]//2 + r*math.cos(a)
        y = WINDOW_SIZE[1]//2 + r*math.sin(a)
        points.append((x, y))
    pygame.draw.polygon(screen, color, points)

# main loop
last_palette = None
last_sounds = []
while True:
    ret, frame = cap.read()
    if not ret:
        break

    # resize for faster processing
    small = cv2.resize(frame, (160, 120))
    pixels = small.reshape(-1, 3)

    # dominant colours
    kmeans = KMeans(n_clusters=NUM_COLORS, random_state=0, n_init='auto')
    kmeans.fit(pixels)
    palette = np.uint8(kmeans.cluster_centers_)

    # movement detection (simple frame diff)
    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
    if 'prev_gray' in locals():
        diff = cv2.absdiff(gray, prev_gray)
        motion = np.mean(diff) / 255.0
    else:
        motion = 0.0
    prev_gray = gray

    # ambient light level
    brightness = np.mean(gray) / 255.0

    # map colours → frequencies and play
    freqs = [colour_to_freq(col) for col in palette]
    # stop old sounds
    for s in last_sounds:
        s.stop()
    # start new ones, volume modulated by brightness & motion
    vol = 0.2 + 0.5*brightness
    last_sounds = [sine_wave(f, dur=0.4, volume=vol) for f in freqs]
    for s in last_sounds:
        s.play(-1)   # loop short note

    # ---------- Render mandala ----------
    screen.fill((0, 0, 0))
    centre = (WINDOW_SIZE[0]//2, WINDOW_SIZE[1]//2)
    max_r = min(WINDOW_SIZE)//2 * (0.5 + 0.5*motion)   # radius grows with movement
    for i, col in enumerate(palette):
        angle = (2*math.pi/NUM_COLORS) * i + time.time()*0.2
        width = math.radians(30 + 10*motion)
        radius = max_r * (i+1) / NUM_COLORS
        draw_petal(angle, radius, width, tuple(int(c) for c in col))
    pygame.display.flip()

    # handle quit
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            cap.release()
            pygame.quit()
            exit()

    clock.tick(FPS)