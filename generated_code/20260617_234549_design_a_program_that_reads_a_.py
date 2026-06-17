import cv2
import numpy as np
from sklearn.cluster import KMeans
import sounddevice as sd
import pygame
from scipy.spatial import Voronoi
import time

# ---------- Settings ----------
CAM_IDX = 0               # webcam index
PALETTE_SIZE = 5          # number of dominant colors
SAMPLE_RATE = 44100       # audio sample rate
NOTE_DURATION = 0.2       # seconds per frame sound
BASE_FREQ = 261.63        # middle C (C4)
SCALE_STEPS = [0, 2, 4, 5, 7, 9, 11, 12]  # major scale intervals
WIN_SIZE = (640, 480)     # display window size
# --------------------------------

def dominant_palette(frame, k=PALETTE_SIZE):
    """Return k dominant colors from the frame (RGB)."""
    img = cv2.resize(frame, (160, 120))        # speed‑up
    img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    pixels = img.reshape(-1, 3)
    kmeans = KMeans(n_clusters=k, n_init=1, random_state=0).fit(pixels)
    palette = np.rint(kmeans.cluster_centers_).astype(int)
    return palette

def palette_to_frequencies(palette):
    """Map palette hues to a major scale anchored at BASE_FREQ."""
    # Convert to HSV, sort by hue
    hsv = cv2.cvtColor(palette[np.newaxis, :, :], cv2.COLOR_RGB2HSV)[0]
    order = np.argsort(hsv[:, 0])
    freqs = []
    for i, idx in enumerate(order):
        step = SCALE_STEPS[i % len(SCALE_STEPS)]
        freq = BASE_FREQ * (2 ** (step / 12.0))
        freqs.append(freq)
    return np.array(freqs)

def synthesize(freqs, duration=NOTE_DURATION, sr=SAMPLE_RATE):
    """Create a short chord from given frequencies."""
    t = np.linspace(0, duration, int(sr * duration), False)
    wave = np.zeros_like(t)
    for f in freqs:
        wave += np.sin(2 * np.pi * f * t) * 0.2   # moderate amplitude
    # simple envelope
    env = np.linspace(1, 0, wave.size)
    wave *= env
    return wave.astype(np.float32)

def voronoi_image(points, colors, size):
    """Render voronoi cells coloured by palette."""
    vor = Voronoi(points)
    img = np.zeros((size[1], size[0], 3), dtype=np.uint8)
    # draw each region
    for i, region_idx in enumerate(vor.point_region):
        region = vor.regions[region_idx]
        if -1 in region or len(region) == 0:
            continue
        polygon = [vor.vertices[v] for v in region]
        poly = np.array(polygon, dtype=np.int32)
        cv2.fillPoly(img, [poly], colors[i % len(colors)].tolist())
    return img

def main():
    pygame.init()
    screen = pygame.display.set_mode(WIN_SIZE)
    pygame.display.set_caption("Live Audio‑Visual Voronoi")
    cap = cv2.VideoCapture(CAM_IDX)

    # initialise random seed points for Voronoi
    points = np.random.rand(PALETTE_SIZE, 2) * np.array(WIN_SIZE)

    while True:
        ret, frame = cap.read()
        if not ret:
            break

        # ------- colour analysis -------
        palette = dominant_palette(frame)
        freqs = palette_to_frequencies(palette)

        # ------- sound synthesis -------
        chord = synthesize(freqs)
        sd.play(chord, SAMPLE_RATE, blocking=False)

        # ------- Voronoi dynamics -------
        # move points with audio RMS (simple visual rhythm)
        rms = np.sqrt(np.mean(chord**2))
        displacement = (np.random.rand(PALETTE_SIZE, 2) - 0.5) * rms * 500
        points = (points + displacement) % np.array(WIN_SIZE)

        # render voronoi diagram
        vor_img = voronoi_image(points, palette, WIN_SIZE)
        surf = pygame.surfarray.make_surface(cv2.cvtColor(vor_img, cv2.COLOR_RGB2BGR))

        # ------- display -------
        screen.blit(surf, (0, 0))
        pygame.display.flip()

        # event handling
        for ev in pygame.event.get():
            if ev.type == pygame.QUIT:
                cap.release()
                pygame.quit()
                sd.stop()
                return

        # limit to ~30 FPS
        time.sleep(0.03)

if __name__ == "__main__":
    main()