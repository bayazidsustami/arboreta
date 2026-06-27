import cv2
import numpy as np
from sklearn.cluster import KMeans
import pygame
import pygame.midi
from scipy.spatial import Voronoi
import sounddevice as sd
import threading
import time

# --- Init pygame and MIDI ---
pygame.init()
pygame.midi.init()
midi_out = pygame.midi.Output(pygame.midi.get_default_output_id())
# Simple sine synth parameters
SAMPLE_RATE = 44100
CHORD_DURATION = 0.2

def midi_to_freq(midi_note):
    return 440.0 * (2 ** ((midi_note - 69) / 12.0))

def synth_chord(notes):
    t = np.linspace(0, CHORD_DURATION, int(SAMPLE_RATE * CHORD_DURATION), False)
    wave = sum(np.sin(2 * np.pi * midi_to_freq(n) * t) for n in notes)
    wave = wave * (0.2 / len(notes))  # volume normalize
    sd.play(wave, SAMPLE_RATE, blocking=False)

# --- Global state for painting ---
paint_points = []          # (x, y, (r,g,b))
paint_lock = threading.Lock()

def add_paint_point(x, y, color):
    with paint_lock:
        paint_points.append((x, y, color))
        if len(paint_points) > 100:   # keep size manageable
            paint_points.pop(0)

# --- Main processing thread ---
def process():
    cap = cv2.VideoCapture(0)
    if not cap.isOpened():
        print("Webcam not found")
        return

    # Create a pygame window for visualization
    win_w, win_h = 640, 480
    screen = pygame.display.set_mode((win_w, win_h))
    pygame.display.set_caption("Live Voronoi & MIDI")
    clock = pygame.time.Clock()

    last_wave = np.zeros(512)  # placeholder for waveform amplitude

    while True:
        ret, frame = cap.read()
        if not ret:
            break

        # Resize for speed
        small = cv2.resize(frame, (160, 120))
        pixels = small.reshape(-1, 3)

        # KMeans for dominant palette (5 colors)
        k = 5
        kmeans = KMeans(n_clusters=k, random_state=0).fit(pixels)
        colors = np.clip(kmeans.cluster_centers_, 0, 255).astype(int)

        # Map colors to MIDI notes (C4=60 .. G5=79)
        notes = []
        for c in colors:
            hue = cv2.cvtColor(np.uint8([[c]]), cv2.COLOR_BGR2HSV)[0][0][0]  # 0-179
            note = 60 + int((hue / 179) * 19)  # 20-note range
            notes.append(note)

        # Play chord in separate thread to avoid blocking
        threading.Thread(target=synth_chord, args=(notes, ), daemon=True).start()

        # ---- Voronoi visualization ----
        # Points are palette colors positioned randomly, warped by last waveform
        pts = np.random.rand(k, 2) * np.array([win_w, win_h])
        # warp using waveform amplitude (simple scaling)
        amp = np.abs(last_wave).mean()
        pts *= (1 + 0.5 * amp)

        # Add painted points as extra sites
        with paint_lock:
            extra_pts = np.array([[p[0], p[1]] for p in paint_points])
            extra_cols = [p[2] for p in paint_points]
        if extra_pts.size:
            pts = np.vstack([pts, extra_pts])

        # Compute Voronoi
        vor = Voronoi(pts)

        # Draw cells
        screen.fill((0, 0, 0))
        for region_idx in vor.point_region:
            region = vor.regions[region_idx]
            if -1 in region or len(region) == 0:
                continue
            polygon = [vor.vertices[i] for i in region]
            pygame.draw.polygon(screen, (255, 255, 255), polygon, 1)

        # Color cells by nearest palette color
        for i, point in enumerate(vor.points):
            region = vor.regions[vor.point_region[i]]
            if -1 in region or len(region) == 0:
                continue
            polygon = [vor.vertices[j] for j in region]
            if i < k:
                col = tuple(int(c) for c in colors[i])
            else:
                col = extra_cols[i - k]
            pygame.draw.polygon(screen, col, polygon)

        # Capture hand painting (simple red object detection)
        hsv = cv2.cvtColor(frame, cv2.COLOR_BGR2HSV)
        mask = cv2.inRange(hsv, (0, 120, 120), (10, 255, 255))
        mask = cv2.dilate(mask, None, iterations=2)
        contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        if contours:
            c = max(contours, key=cv2.contourArea)
            if cv2.contourArea(c) > 500:
                x, y, w, h = cv2.boundingRect(c)
                cx, cy = x + w // 2, y + h // 2
                # Grab color under the centroid
                col = frame[cy, cx].tolist()
                add_paint_point(int(cx * win_w / frame.shape[1]), int(cy * win_h / frame.shape[0]), tuple(col))

        # Compute waveform for next warp (simple sum of sine waves)
        t = np.linspace(0, 0.02, 512, False)
        last_wave = sum(np.sin(2 * np.pi * midi_to_freq(n) * t) for n in notes)

        # Event handling
        for ev in pygame.event.get():
            if ev.type == pygame.QUIT:
                cap.release()
                pygame.quit()
                return
            elif ev.type == pygame.MOUSEBUTTONDOWN:
                mx, my = ev.pos
                col = (np.random.randint(255), np.random.randint(255), np.random.randint(255))
                add_paint_point(mx, my, col)

        pygame.display.flip()
        clock.tick(30)

if __name__ == "__main__":
    process()