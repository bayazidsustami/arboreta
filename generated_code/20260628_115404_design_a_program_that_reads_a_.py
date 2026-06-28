import cv2, numpy as np, sounddevice as sd, pygame, threading, time, math, sys

# ---------- Audio synthesis thread ----------
class WindSynth:
    def __init__(self, sample_rate=44100):
        self.fs = sample_rate
        self.phase = 0.0
        self.freq = 0.1   # start near silence
        self.lock = threading.Lock()
        self.stream = sd.OutputStream(channels=1, callback=self.audio_callback,
                                      samplerate=self.fs, blocksize=1024)
        self.stream.start()

    def set_freq(self, f):
        with self.lock:
            self.freq = max(0.0, min(f, 2000.0))   # clamp

    def audio_callback(self, outdata, frames, time_info, status):
        t = (np.arange(frames) + self.phase) / self.fs
        with self.lock:
            f = self.freq
        # simple sine + a bit of noise for wind texture
        tone = np.sin(2*np.pi*f*t) * (0.3 + 0.7*np.random.rand(frames))
        outdata[:] = tone.reshape(-1,1)
        self.phase = (self.phase + frames) % self.fs

# ---------- Visual fractal (recursive tree) ----------
def draw_tree(surface, x, y, angle, length, depth, sway):
    if depth == 0 or length < 2:
        return
    # sway adds wind influence
    angle_rad = math.radians(angle + sway)
    x2 = x + int(math.cos(angle_rad) * length)
    y2 = y - int(math.sin(angle_rad) * length)
    color = (34, 139, 34) if depth > 2 else (50, 205, 50)
    pygame.draw.line(surface, color, (x, y), (x2, y2), max(1, depth))
    # two branches
    draw_tree(surface, x2, y2, angle - 20, length * 0.7, depth-1, sway)
    draw_tree(surface, x2, y2, angle + 20, length * 0.7, depth-1, sway)

# ---------- Main processing ----------
def main():
    cap = cv2.VideoCapture(0)
    if not cap.isOpened():
        print("Cannot open webcam")
        sys.exit(1)

    ret, prev = cap.read()
    prev_gray = cv2.cvtColor(prev, cv2.COLOR_BGR2GRAY)

    synth = WindSynth()

    pygame.init()
    width, height = 640, 480
    screen = pygame.display.set_mode((width, height))
    clock = pygame.time.Clock()

    sway_angle = 0.0

    while True:
        ret, frame = cap.read()
        if not ret:
            break
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)

        # Dense optical flow (Farneback)
        flow = cv2.calcOpticalFlowFarneback(prev_gray, gray,
                                            None, 0.5, 3, 15, 3, 5, 1.2, 0)
        mag, _ = cv2.cartToPolar(flow[...,0], flow[...,1])
        avg_mag = np.mean(mag)

        # Map flow magnitude to audio frequency (0‑2000 Hz) and sway amplitude
        freq = np.interp(avg_mag, [0, 5], [50, 1500])
        synth.set_freq(freq)
        sway_angle = np.interp(avg_mag, [0, 5], [0, 30])  # max 30° sway

        prev_gray = gray

        # ---------- Render fractal forest ----------
        screen.fill((0, 0, 0))
        # draw several trees with slight x‑offset
        for i in range(5):
            base_x = int(width/6 * (i+1))
            base_y = height - 10
            draw_tree(screen, base_x, base_y, -90, 80, 6, sway_angle * (np.random.rand()*0.5+0.75))

        pygame.display.flip()
        clock.tick(30)

        # Handle quit events
        for ev in pygame.event.get():
            if ev.type == pygame.QUIT:
                cap.release()
                synth.stream.stop()
                pygame.quit()
                sys.exit()

if __name__ == "__main__":
    main()