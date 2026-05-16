import numpy as npimport sounddevice as sd
import pygame
import math
import threading

# Audio parameters
SAMPLE_RATE = 44100
BLOCKSIZE = 1024

# Pygame init
pygame.init()
WIDTH, HEIGHT = 800, 600
screen = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("Audio Ecosystem")
clock = pygame.time.Clock()

# Creature class
class Creature:
    def __init__(self, x, y, vx, vy, radius, hue):
        self.x = float(x)
        self.y = float(y)
        self.vx = float(vx)
        self.vy = float(vy)
        self.radius = float(radius)
        self.hue = hue  # 0-360

    def update(self, freq_norm, amp_norm):
        # Frequency influences direction
        angle = (self.hue / 360.0) * 2 * math.pi
        speed_factor = amp_norm
        self.vx += math.cos(angle) * speed_factor * 0.5
        self.vy += math.sin(angle) * speed_factor * 0.5
        # damping
        self.vx *= 0.95
        self.vy *= 0.95
        self.x += self.vx
        self.y += self.vy
        # wrap around
        if self.x < 0 or self.x > WIDTH:
            self.x = WIDTH if self.x < 0 else 0
        if self.y < 0 or self.y > HEIGHT:
            self.y = HEIGHT if self.y < 0 else 0

    def draw(self):
        # Map hue to RGB
        r = int(math.sin((self.hue + 0) * math.pi / 180) * 127 + 127)
        g = int(math.sin((self.hue + 120) * math.pi / 180) * 127 + 127)
        b = int(math.sin((self.hue + 240) * math.pi / 180) * 127 + 127)
        color = (r, g, b)
        pygame.draw.circle(screen, color, (int(self.x), int(self.y)), int(self.radius))

# Global creatures list and lock
creatures = []
creature_lock = threading.Lock()

# Global variables for audio callback
freq_norm = 0.0
amp_norm = 0.0

def audio_callback(indata, frames, time_info, status):
    """Process audio block, compute spectrum, and spawn creatures."""
    global freq_norm, amp_norm
    # Mono conversion
    audio = indata[:, 0] if indata.ndim > 1 else indata
    # FFT
    fft_vals = np.fft.rfft(audio)
    freqs = np.fft.rfftfreq(len(audio), 1.0 / SAMPLE_RATE)
    mags = np.abs(fft_vals)
    # Dominant frequency (ignore DC)
    idx = np.argmax(mags[1:]) + 1
    dominant_freq = freqs[idx]
    # Normalize frequency to [0, 1] (0-10kHz)
    freq_norm = min(dominant_freq / 10000.0, 1.0)
    # RMS amplitude
    rms = np.sqrt(np.mean(audio**2))
    # Normalize amplitude (assuming max ~0.1)
    amp_norm = min(rms / 0.1, 1.0)

    # Spawn new creatures when amplitude is high enough
    if amp_norm > 0.2:
        hue = (dominant_freq / 10000.0) * 360  # map freq to hue
        x = np.random.uniform(WIDTH * 0.2, WIDTH * 0.8)
        y = np.random.uniform(HEIGHT * 0.2, HEIGHT * 0.8)
        vx = np.random.uniform(-2, 2)
        vy = np.random.uniform(-2, 2)
        radius = np.random.uniform(5, 15)
        with creature_lock:
            creatures.append(Creature(x, y, vx, vy, radius, hue))

def main():
    running = True
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False

        # Update creatures
        with creature_lock:
            for cr in creatures:
                cr.update(freq_norm, amp_norm)
            # Remove tiny creatures
            creatures = [cr for cr in creatures if cr.radius > 1]

        # Draw
        screen.fill((0, 0, 0))
        with creature_lock:
            for cr in creatures:
                cr.draw()
        pygame.display.flip()
        clock.tick(60)

    # Cleanup
    sd.stop()
    pygame.quit()

# Start audio stream (non-blocking)
stream = sd.InputStream(samplerate=SAMPLE_RATE,
                        blocksize=BLOCKSIZE,
                        channels=1,
                        dtype='float32',
                        callback=audio_callback)
stream.start()

# Run the main loop
main()