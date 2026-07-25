import sys
import time
import math
import random
import threading
import numpy as np
import pygame

# Attempt audio input via sounddevice
try:
    import sounddevice as sd
    HAS_AUDIO = True
except ImportError:
    HAS_AUDIO = False

# Configuration & Constants
WIDTH, HEIGHT = 800, 600
PIGMENT_COUNT = 6000
DAMPING = 0.96
PALETTE = [
    (15, 32, 67),    # Deep Indigo
    (53, 162, 159),  # Vibrant Teal
    (214, 90, 49),   # Coral Rust
    (239, 195, 108), # Ochre Gold
    (140, 70, 130),  # Magenta Haze
    (240, 235, 225)  # Soft Paper White
]

class SystemInterruptMonitor(threading.Thread):
    """Monitors system interrupt frequency changes to drive physical fluid dynamics."""
    def __init__(self):
        super().__init__(daemon=True)
        self.interrupt_rate = 1.0
        self.last_count = self._get_interrupt_count()
        self.last_time = time.time()

    def _get_interrupt_count(self):
        try:
            with open('/proc/interrupts', 'r') as f:
                lines = f.readlines()
            total = 0
            for line in lines[1:]:
                parts = line.strip().split()
                for p in parts[1:]:
                    if p.isdigit():
                        total += int(p)
                    else:
                        break
            return total
        except Exception:
            return None

    def run(self):
        while True:
            time.sleep(0.1)
            curr_count = self._get_interrupt_count()
            curr_time = time.time()
            dt = curr_time - self.last_time
            if curr_count is not None and self.last_count is not None and dt > 0:
                rate = (curr_count - self.last_count) / dt
                # Normalize rate dynamically around nominal values
                self.interrupt_rate = np.clip(rate / 5000.0, 0.2, 5.0)
                self.last_count = curr_count
            else:
                # Fallback synthetic oscillation if /proc/interrupts isn't accessible
                self.interrupt_rate = 1.0 + 0.5 * math.sin(curr_time * 2.5)
            self.last_time = curr_time

class MicrophoneAudioMonitor:
    """Captures ambient microphone harmonics to modulate surface tension."""
    def __init__(self):
        self.surface_tension = 1.0
        self.harmonic_frequency = 1.0
        if HAS_AUDIO:
            try:
                self.stream = sd.InputStream(
                    channels=1, samplerate=22050, blocksize=1024, callback=self._audio_callback
                )
                self.stream.start()
            except Exception:
                pass

    def _audio_callback(self, indata, frames, time_info, status):
        signal = indata[:, 0]
        fft_vals = np.abs(np.fft.rfft(signal))
        freqs = np.fft.rfftfreq(len(signal), 1.0 / 22050)
        
        # Calculate volume level (RMS) and dominant harmonic peak
        rms = np.sqrt(np.mean(signal**2))
        peak_idx = np.argmax(fft_vals[1:]) + 1 if len(fft_vals) > 1 else 0
        
        # Audio RMS scales surface tension elasticity
        self.surface_tension = 0.5 + np.clip(rms * 15.0, 0.0, 4.0)
        self.harmonic_frequency = freqs[peak_idx] if peak_idx < len(freqs) else 440.0

    def update_fallback(self, frame_count):
        """Synthetic fallback if mic stream is unavailable."""
        if not HAS_AUDIO or not hasattr(self, 'stream'):
            self.surface_tension = 1.0 + 0.6 * math.sin(frame_count * 0.05)
            self.harmonic_frequency = 220.0 + 110.0 * math.cos(frame_count * 0.03)

def create_paper_texture(width, height):
    """Generates a textured watercolor paper substrate."""
    surface = pygame.Surface((width, height))
    base_color = np.array([245, 242, 235], dtype=np.float32)
    noise = np.random.normal(0, 4, (height, width, 3))
    paper_data = np.clip(base_color + noise, 0, 255).astype(np.uint8)
    pygame.surfarray.blit_array(surface, np.transpose(paper_data, (1, 0, 2)))
    return surface

def main():
    pygame.init()
    screen = pygame.display.set_mode((WIDTH, HEIGHT))
    pygame.display.set_caption("Evolving Fluid Watercolor Canvas")
    clock = pygame.time.Clock()

    # Hardware & Physical Drivers
    sys_mon = SystemInterruptMonitor()
    sys_mon.start()
    mic_mon = MicrophoneAudioMonitor()

    # Substrate setup
    paper_bg = create_paper_texture(WIDTH, HEIGHT)
    canvas = paper_bg.copy()

    # Particle Initialization (Pigment Field)
    pos = np.random.rand(PIGMENT_COUNT, 2) * [WIDTH, HEIGHT]
    vel = (np.random.rand(PIGMENT_COUNT, 2) - 0.5) * 2.0
    
    # Assign watercolor palette colors and radii
    colors = np.array([random.choice(PALETTE) for _ in range(PIGMENT_COUNT)], dtype=np.float32)
    radii = np.random.uniform(2.5, 6.0, size=PIGMENT_COUNT)

    frame = 0
    running = True

    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT or (event.type == pygame.KEYDOWN and event.key == pygame.K_ESCAPE):
                running = False
            elif event.type == pygame.MOUSEBUTTONDOWN:
                # Inject turbulent splash at mouse coordinates
                mx, my = pygame.mouse.get_pos()
                dist = np.linalg.norm(pos - [mx, my], axis=1)
                mask = dist < 120
                angles = np.random.uniform(0, 2 * math.pi, np.sum(mask))
                speeds = np.random.uniform(4.0, 12.0, np.sum(mask))
                vel[mask] += np.column_stack((np.cos(angles) * speeds, np.sin(angles) * speeds))

        # Update drivers
        mic_mon.update_fallback(frame)
        interrupt_speed = sys_mon.interrupt_rate
        tension = mic_mon.surface_tension
        harmonic = mic_mon.harmonic_frequency

        # Build Perlin-like curl flow field influenced by interrupt dynamics
        scale = 0.005
        angles = (np.sin(pos[:, 0] * scale + frame * 0.01) + 
                  np.cos(pos[:, 1] * scale + frame * 0.015)) * math.pi * 2
        
        flow = np.column_stack((np.cos(angles), np.sin(angles))) * (1.5 * interrupt_speed)

        # Ambient Harmonic Surface Tension Force (Central Cohesive Attraction/Repulsion)
        center = np.array([WIDTH / 2.0, HEIGHT / 2.0])
        delta_center = center - pos
        dist_center = np.linalg.norm(delta_center, axis=1, keepdims=True) + 1e-5
        harmonic_mod = math.sin(harmonic * 0.01)
        tension_force = (delta_center / dist_center) * (tension * harmonic_mod * 0.15)

        # Physics Integration
        vel += (flow + tension_force)
        vel *= DAMPING
        pos += vel

        # Boundary Wraparound with Edge Diffusion
        pos[:, 0] %= WIDTH
        pos[:, 1] %= HEIGHT

        # Render Watercolor Bleed Overlay
        # Slowly blend canvas back to paper to simulate pigment diffusion/drying
        canvas.blit(paper_bg, (0, 0), special_flags=pygame.BLEND_MULT)

        # Draw Pigment Fluid Particles using additive alpha-like blending
        particle_surf = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
        
        # Batch draw particles for fluid performance
        for i in range(0, PIGMENT_COUNT, 4):  # Sub-sample per frame for speed & softness
            x, y = int(pos[i, 0]), int(pos[i, 1])
            r = int(radii[i] * (0.8 + 0.4 * math.sin(frame * 0.05 + i)))
            c = colors[i]
            # Soft pigment wash effect using semi-transparent circles
            alpha = int(35 + 20 * math.sin(i + frame * 0.1))
            pygame.draw.circle(particle_surf, (*c, alpha), (x, y), r)

        canvas.blit(particle_surf, (0, 0))
        screen.blit(canvas, (0, 0))

        pygame.display.flip()
        clock.tick(60)
        frame += 1

    pygame.quit()
    sys.exit()

if __name__ == '__main__':
    main()