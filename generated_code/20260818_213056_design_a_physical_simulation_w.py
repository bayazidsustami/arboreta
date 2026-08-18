import sys
import math
import random
import numpy as np
import pygame
import pygame.sarray

# --- Audio Analysis Setup ---
SAMPLE_RATE = 22050
BUFFER_SIZE = 1024

class AudioAnalyzer:
    """Generates synthetic audio frequencies and amplitudes simulating real-time audio input."""
    def __init__(self):
        self.time = 0.0
        self.low_freq = 0.0
        self.mid_freq = 0.0
        self.high_freq = 0.0

    def update(self):
        self.time += 0.05
        # Simulate dynamic bass, mid, and treble audio signals using layered sine waves
        self.low_freq = (math.sin(self.time * 1.5) * 0.5 + 0.5) ** 2
        self.mid_freq = (math.sin(self.time * 3.2 + 1.0) * 0.5 + 0.5)
        self.high_freq = (math.sin(self.time * 7.8 + 2.0) * 0.5 + 0.5) * (math.cos(self.time * 0.5) * 0.5 + 0.5)

# --- Vector Portrait Path Generator ---
def create_portrait_paths(width, height):
    """Generates a structured set of vector paths representing a stylized line-art face."""
    cx, cy = width // 2, height // 2
    paths = []

    def circle_path(center_x, center_y, radius, num_points):
        return [[center_x + radius * math.cos(a), center_y + radius * math.sin(a)]
                for a in [2 * math.pi * i / num_points for i in range(num_points)]]

    # Outline / Head
    paths.append(circle_path(cx, cy - 20, 180, 60))
    # Eyes
    paths.append(circle_path(cx - 65, cy - 60, 30, 24))
    paths.append(circle_path(cx + 65, cy - 60, 30, 24))
    # Pupils
    paths.append(circle_path(cx - 65, cy - 60, 10, 12))
    paths.append(circle_path(cx + 65, cy - 60, 10, 12))
    # Nose
    paths.append([[cx, cy - 40], [cx - 20, cy + 20], [cx + 10, cy + 25]])
    # Mouth
    paths.append([[cx - 50, cy + 70], [cx - 20, cy + 90], [cx + 20, cy + 90], [cx + 50, cy + 70]])
    paths.append([[cx - 50, cy + 70], [cx, cy + 100], [cx + 50, cy + 70]])
    # Hair / Contour lines
    for i in range(-5, 6):
        hx = cx + i * 30
        paths.append([[hx, cy - 180], [hx + i * 5, cy - 250 - abs(i) * 10]])

    return paths

# --- Vector Particle System ---
class VectorParticle:
    """Represents a node on a vector line that untangles into fluid simulation particles."""
    def __init__(self, origin_x, origin_y):
        self.origin = np.array([origin_x, origin_y], dtype=float)
        self.pos = np.array([origin_x, origin_y], dtype=float)
        self.vel = np.array([0.0, 0.0], dtype=float)
        self.acc = np.array([0.0, 0.0], dtype=float)
        self.friction = 0.95

    def update_fluid_physics(self, grid_velocity, untangle_factor, audio_boost):
        # Anchor force keeping the point near its portrait origin
        anchor_force = (self.origin - self.pos) * (1.0 - untangle_factor) * 0.05
        
        # Fluid velocity interaction influenced by audio intensity
        fluid_force = grid_velocity * untangle_factor * (1.0 + audio_boost * 2.0)
        
        # Brownian motion / turbulence
        turbulence = np.random.randn(2) * untangle_factor * audio_boost * 1.5

        self.acc += anchor_force + fluid_force + turbulence
        self.vel = (self.vel + self.acc) * self.friction
        self.pos += self.vel
        self.acc *= 0.0

# --- Main Simulation ---
def main():
    pygame.init()
    width, height = 900, 900
    screen = pygame.display.set_mode((width, height))
    pygame.display.set_caption("Line-Art Untangling Fluid Mechanics Simulation")
    clock = pygame.time.Clock()

    audio = AudioAnalyzer()
    portrait_paths = create_portrait_paths(width, height)

    # Convert paths to trainable particles
    particle_paths = []
    for path in portrait_paths:
        p_line = [VectorParticle(pt[0], pt[1]) for pt in path]
        particle_paths.append(p_line)

    # Simulation parameters
    grid_size = 30
    cols, rows = width // grid_size, height // grid_size
    untangle_factor = 0.0  # 0 = rigid portrait, 1 = total fluid state
    time_step = 0.0

    running = True
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT or (event.type == pygame.KEYDOWN and event.key == pygame.K_ESCAPE):
                running = False

        audio.update()
        time_step += 0.03

        # Dynamic untangling driven by audio high & mid frequencies, gradually cycling
        target_untangle = (math.sin(time_step * 0.5) * 0.5 + 0.5) * audio.mid_freq
        untangle_factor += (target_untangle - untangle_factor) * 0.05

        # Generate a procedural fluid vector field (curl noise representation)
        velocity_grid = np.zeros((cols, rows, 2))
        for i in range(cols):
            for j in range(rows):
                angle = (math.cos(i * 0.15 + time_step) + math.sin(j * 0.15 + time_step)) * math.pi * 2
                magnitude = (audio.low_freq * 2.0 + 0.5)
                velocity_grid[i, j] = [math.cos(angle) * magnitude, math.sin(angle) * magnitude]

        # Dark fluid background fade effect
        fade_surface = pygame.Surface((width, height))
        fade_surface.set_alpha(40)
        fade_surface.fill((10, 12, 20))
        screen.blit(fade_surface, (0, 0))

        # Color palette influenced by audio state
        r_col = int(100 + 155 * audio.low_freq)
        g_col = int(150 + 105 * audio.mid_freq)
        b_col = int(200 + 55 * audio.high_freq)
        line_color = (r_col, g_col, b_col)

        # Update and draw vector paths
        for path in particle_paths:
            points = []
            for p in path:
                # Calculate grid coordinates for particle
                gx = int(np.clip(p.pos[0] // grid_size, 0, cols - 1))
                gy = int(np.clip(p.pos[1] // grid_size, 0, rows - 1))
                grid_vel = velocity_grid[gx, gy]

                p.update_fluid_physics(grid_vel, untangle_factor, audio.high_freq)
                points.append((int(p.pos[0]), int(p.pos[1])))

            # Draw vector lines if enough points exist
            if len(points) > 1:
                pygame.draw.lines(screen, line_color, False, points, 2)
                # Draw small glowing nodes at vector vertices
                if untangle_factor > 0.2:
                    for pt in points:
                        pygame.draw.circle(screen, (255, 255, 255), pt, int(1 + 3 * untangle_factor))

        pygame.display.flip()
        clock.tick(60)

    pygame.quit()
    sys.exit()

if __name__ == "__main__":
    main()