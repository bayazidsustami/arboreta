import sys
import math
import random
import time
import psutil
import pygame
import numpy as np

# Initialize Pygame
pygame.init()
WIDTH, HEIGHT = 1000, 700
screen = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("Memory Metamorphosis: Watercolor Canvas")

# Canvas Surfaces (Base texture + watercolor paint layer)
canvas_surface = pygame.Surface((WIDTH, HEIGHT))
paint_surface = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)

# Background Textured Canvas Setup
canvas_surface.fill((245, 242, 235))  # Off-white paper background
for _ in range(5000):
    x, y = random.randint(0, WIDTH - 1), random.randint(0, HEIGHT - 1)
    shade = random.randint(230, 240)
    canvas_surface.set_at((x, y), (shade, shade - 5, shade - 10))

# Colors (Watercolor Palette & Decay)
WATER_COLORS = [
    (70, 130, 180, 12),   # Steel Blue
    (100, 149, 237, 12),  # Cornflower Blue
    (72, 209, 204, 12),   # Medium Turquoise
    (147, 112, 219, 12),  # Medium Purple
]
MILDEW_COLORS = [
    (40, 55, 30, 18),     # Dark Mold Green
    (70, 65, 35, 18),     # Rot Yellow-Brown
    (25, 35, 25, 22),     # Spore Black
]
FRACTURE_COLOR = (20, 15, 15, 220)

# State Tracking Variables
mildew_clusters = []
fractures = []
simulated_leaks = []  # User-triggered artificial memory bloat
clock = pygame.time.Clock()

def add_mildew_spore(x, y):
    """Spawns a new mildew spore that grows organically over time."""
    mildew_clusters.append({
        'x': x,
        'y': y,
        'radius': random.uniform(3, 8),
        'max_radius': random.uniform(25, 60),
        'color': random.choice(MILDEW_COLORS)
    })

def trigger_seismic_fracture():
    """Generates a catastrophic seismic fracture across the canvas."""
    start_x = random.randint(0, WIDTH)
    start_y = 0 if random.random() < 0.5 else HEIGHT
    angle = math.atan2(HEIGHT / 2 - start_y, WIDTH / 2 - start_x) + random.uniform(-0.5, 0.5)
    
    curr_x, curr_y = start_x, start_y
    segments = []
    
    while 0 <= curr_x <= WIDTH and 0 <= curr_y <= HEIGHT:
        length = random.uniform(15, 40)
        angle += random.uniform(-0.4, 0.4)
        next_x = curr_x + math.cos(angle) * length
        next_y = curr_y + math.sin(angle) * length
        segments.append(((curr_x, curr_y), (next_x, next_y), random.uniform(1.5, 4.5)))
        curr_x, curr_y = next_x, next_y
        
    fractures.append(segments)

def paint_organic_wash(x, y, radius, color):
    """Renders layered transparent polygonal shapes to mimic watercolor diffusion."""
    points = []
    num_pts = random.randint(8, 14)
    for i in range(num_pts):
        a = (i / num_pts) * 2 * math.pi
        r = radius * random.uniform(0.7, 1.3)
        points.append((x + math.cos(a) * r, y + math.sin(a) * r))
    pygame.draw.polygon(paint_surface, color, points)

# --- Main Program Loop ---
running = True
last_mem_pct = psutil.virtual_memory().percent

while running:
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
        elif event.type == pygame.KEYDOWN:
            if event.key == pygame.K_m:  # Simulate Memory Leak
                simulated_leaks.append(bytearray(25 * 1024 * 1024))  # Allocate 25MB
            elif event.key == pygame.K_s:  # Simulate Stack Overflow / Fracture
                trigger_seismic_fracture()

    # Query System Memory Metrics
    mem_info = psutil.virtual_memory()
    mem_pct = mem_info.percent
    mem_diff = mem_pct - last_mem_pct

    # 1. Normal Memory Usage Flow -> Abstract Watercolor Strokes
    flow_speed = mem_pct / 100.0
    for _ in range(int(3 * flow_speed) + 1):
        wx = random.gauss(WIDTH / 2, WIDTH / 3)
        wy = random.gauss(HEIGHT / 2, HEIGHT / 3)
        paint_organic_wash(wx, wy, random.uniform(15, 50), random.choice(WATER_COLORS))

    # 2. Memory Leak Detection -> Spreading Mildew
    if mem_diff > 0.1 or len(simulated_leaks) > 0:
        # Spawn spores proportionally to memory growth
        num_spores = int(max(1, mem_diff * 3)) + len(simulated_leaks)
        for _ in range(num_spores):
            add_mildew_spore(random.randint(0, WIDTH), random.randint(0, HEIGHT))

    # Update & Render Mildew Spores
    for spot in mildew_clusters:
        if spot['radius'] < spot['max_radius']:
            spot['radius'] += random.uniform(0.05, 0.2)
            # Irregular growth rendering
            ang = random.uniform(0, 2 * math.pi)
            dist = random.uniform(0, spot['radius'])
            px = spot['x'] + math.cos(ang) * dist
            py = spot['y'] + math.sin(ang) * dist
            pygame.draw.circle(paint_surface, spot['color'], (int(px), int(py)), int(random.uniform(2, 6)))

    # 3. Stack Overflow / High Pressure -> Seismic Fractures Rendering
    if mem_pct > 90.0 and random.random() < 0.05:
        trigger_seismic_fracture()

    # Draw Fractures onto Canvas Surface
    for fracture in fractures:
        for p1, p2, width in fracture:
            pygame.draw.line(canvas_surface, FRACTURE_COLOR, p1, p2, int(width))

    # Blit Background & Fluid Watercolor Layer to Display
    screen.blit(canvas_surface, (0, 0))
    screen.blit(paint_surface, (0, 0))

    # Render HUD / UI Instructions
    font = pygame.font.SysFont("Georgia", 16)
    status_text = f"RAM: {mem_pct}% | Spores: {len(mildew_clusters)} | Leaks Bloat: {len(simulated_leaks)*25}MB"
    hud = font.render(status_text, True, (40, 40, 40))
    help_text = font.render("[M] Inject Memory Leak  |  [S] Trigger Stack Fracture", True, (80, 80, 80))
    screen.blit(hud, (15, 15))
    screen.blit(help_text, (15, 38))

    pygame.display.flip()
    last_mem_pct = mem_pct
    clock.tick(30)

pygame.quit()
sys.exit()