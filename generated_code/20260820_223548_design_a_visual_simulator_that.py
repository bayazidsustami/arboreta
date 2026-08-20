import sys
import math
import random
import time
import psutil
import pygame
import numpy as np

# System & Ecosystem Setup
pygame.init()
try:
    pygame.mixer.init(frequency=44100, size=-16, channels=2, buffer=512)
    AUDIO_ENABLED = True
except Exception:
    AUDIO_ENABLED = False

WIDTH, HEIGHT = 1280, 720
screen = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("Memory Ecosystem: Thread Species Simulator")
clock = pygame.time.Clock()

# Audio Generation Helpers
AUDIO_TICKS = 0
def generate_tone(frequency, duration=0.05, volume=0.3):
    if not AUDIO_ENABLED or frequency <= 0:
        return None
    sample_rate = 44100
    n_samples = int(sample_rate * duration)
    t = np.linspace(0, duration, n_samples, False)
    sine = np.sin(2 * np.pi * frequency * t)
    # Apply fade out envelope to prevent clicking
    envelope = np.exp(-3 * t / duration)
    waveform = (sine * envelope * volume * 32767).astype(np.int16)
    stereo = np.column_stack((waveform, waveform))
    return pygame.sndarray.make_sound(stereo)

# Ecosystem Species Representation
class Species:
    def __init__(self, thread_id, x, y):
        self.thread_id = thread_id
        self.x = x
        self.y = y
        self.vx = random.uniform(-1.5, 1.5)
        self.vy = random.uniform(-1.5, 1.5)
        self.energy = random.uniform(50, 100)
        self.radius = random.uniform(4, 8)
        # Unique color based on thread identity
        random.seed(thread_id)
        self.color = (random.randint(100, 255), random.randint(100, 255), random.randint(150, 255))
        random.seed()

    def update(self, memory_pressure):
        # Memory pressure increases aggression and movement speed
        speed_mult = 1.0 + (memory_pressure / 50.0)
        self.x += self.vx * speed_mult
        self.y += self.vy * speed_mult

        # Boundary bounce
        if self.x < 10 or self.x > WIDTH - 10:
            self.vx *= -1
        if self.y < 10 or self.y > HEIGHT - 10:
            self.vy *= -1

        # Energy decay based on stress
        self.energy -= 0.1 * speed_mult
        self.radius = max(2, min(20, self.energy / 10.0))

    def draw(self, surface):
        alpha_color = self.color
        pygame.draw.circle(surface, alpha_color, (int(self.x), int(self.y)), int(self.radius))
        # Draw energy aura
        pygame.draw.circle(surface, self.color, (int(self.x), int(self.y)), int(self.radius + 3), 1)

# Main Simulation Loop
def main():
    running = True
    organisms = []
    particles = []
    
    # Track garbage collection (sudden drops in memory usage)
    prev_mem_used = psutil.virtual_memory().used
    extinction_event = 0
    extinction_color = [255, 0, 0]

    # Pre-generate ambient audio tones
    tones = [generate_tone(220 * (1.5 ** i), 0.08, 0.15) for i in range(5)]

    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT or (event.type == pygame.KEYDOWN and event.key == pygame.K_ESCAPE):
                running = False

        # System Metrics Sampling
        mem_info = psutil.virtual_memory()
        mem_percent = mem_info.percent
        current_mem_used = mem_info.used
        mem_diff = current_mem_used - prev_mem_used

        # Active System Threads as Competitors
        active_threads = []
        try:
            for proc in psutil.process_iter(['pid', 'num_threads']):
                try:
                    active_threads.extend([proc.info['pid'] + i for i in range(min(5, proc.info['num_threads'] or 1))])
                    if len(active_threads) > 150:
                        break
                except (psutil.NoSuchProcess, psutil.AccessDenied):
                    continue
        except Exception:
             active_threads = list(range(50))

        # Synchronize Ecosystem Species with System Threads
        existing_ids = {org.thread_id for org in organisms}
        target_ids = set(active_threads[:120])

        # Birth new organisms for new threads
        for tid in target_ids - existing_ids:
            organisms.append(Species(tid, random.randint(50, WIDTH - 50), random.randint(50, HEIGHT - 50)))

        # Natural Death/Removal
        organisms = [org for org in organisms if org.thread_id in target_ids and org.energy > 0]

        # Garbage Collection Detection: Significant memory release drop
        if mem_diff < -15 * 1024 * 1024:  # Drop greater than 15 MB
            extinction_event = 30  # Flash duration in frames
            # Mass Extinction Event: Purge weak organisms
            purge_count = len(organisms) // 2
            for _ in range(purge_count):
                if organisms:
                    dead = organisms.pop(random.randint(0, len(organisms) - 1))
                    # Spawn shockwave particles
                    for _ in range(8):
                        particles.append({
                            'x': dead.x, 'y': dead.y,
                            'vx': random.uniform(-4, 4), 'vy': random.uniform(-4, 4),
                            'life': 20, 'color': (255, 100, 50)
                        })
            if AUDIO_ENABLED and tones[0]:
                tones[0].play()

        prev_mem_used = current_mem_used

        # Ecosystem Mechanics: Competition for space
        for i, org1 in enumerate(organisms):
            org1.update(mem_percent)
            for org2 in organisms[i + 1:]:
                dx = org2.x - org1.x
                dy = org2.y - org1.y
                dist = math.hypot(dx, dy)
                if dist < (org1.radius + org2.radius):
                    # Species competition: transfers energy from smaller to larger
                    if org1.radius >= org2.radius:
                        org1.energy += 0.5
                        org2.energy -= 0.8
                    else:
                        org2.energy += 0.5
                        org1.energy -= 0.8

        # Audio-Reactive Tone Triggering based on population state
        if AUDIO_ENABLED and random.random() < (mem_percent / 100.0) * 0.3:
            tone_idx = min(len(tones) - 1, int((len(organisms) / 120.0) * len(tones)))
            if tones[tone_idx]:
                tones[tone_idx].play()

        # Rendering
        # Background reflects memory pressure (Dark blue/black to deep purple/red)
        bg_r = int(min(255, (mem_percent / 100.0) * 80))
        bg_g = int(max(0, 20 - (mem_percent / 100.0) * 20))
        bg_b = int(max(10, 40 - (mem_percent / 100.0) * 20))

        if extinction_event > 0:
            screen.fill((120, 20, 20))  # Mass Extinction Flash
            extinction_event -= 1
        else:
            screen.fill((bg_r, bg_g, bg_b))

        # Render Energy Web (Inter-species connections)
        for i, org1 in enumerate(organisms):
            for org2 in organisms[i + 1:]:
                dist = math.hypot(org2.x - org1.x, org2.y - org1.y)
                if dist < 80:
                    alpha = int(255 * (1 - dist / 80))
                    pygame.draw.line(screen, (alpha // 3, alpha // 2, alpha), (org1.x, org1.y), (org2.x, org2.y), 1)

        # Render Species
        for org in organisms:
            org.draw(screen)

        # Update & Render Particles (GC debris)
        for p in particles[:]:
            p['x'] += p['vx']
            p['y'] += p['vy']
            p['life'] -= 1
            pygame.draw.circle(screen, p['color'], (int(p['x']), int(p['y'])), max(1, p['life'] // 4))
            if p['life'] <= 0:
                particles.remove(p)

        # Dashboard Overlay
        font = pygame.font.SysFont("monospace", 16)
        stats = [
            f"SYSTEM MEMORY LOAD: {mem_percent:.1f}%",
            f"LIVING THREAD SPECIES: {len(organisms)}",
            f"GC SEASON STATUS: {'EXTINCTION EVENT!' if extinction_event > 0 else 'STABLE'}"
        ]
        for idx, text in enumerate(stats):
            lbl = font.render(text, True, (200, 255, 200) if extinction_event == 0 else (255, 200, 200))
            screen.blit(lbl, (20, 20 + idx * 22))

        pygame.display.flip()
        clock.tick(60)

    pygame.quit()

if __name__ == "__main__":
    main()