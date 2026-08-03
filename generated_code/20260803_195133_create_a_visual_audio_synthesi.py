# System Topology Fractal Reef & Bioluminescent Microtonal Synthesizer
import os
import sys
import time
import math
import random
import threading
import numpy as np

try:
    import pygame
    from pygame.locals import *
    from OpenGL.GL import *
    from OpenGL.GLU import *
except ImportError:
    print("Dependencies missing! Please install: pip install pygame PyOpenGL numpy")
    sys.exit(1)

# Initialize Audio System
SAMPLE_RATE = 44100
pygame.mixer.pre_init(SAMPLE_RATE, -16, 2, 512)
pygame.init()

# Audio Synthesizer producing microtonal harmonics on file events
class MicrotonalSynth:
    def play_microtonal_bloom(self, base_freq=220.0, divisions=19, degree=0):
        # 19-TET (19 Equal Temperament) microtonal scale computation
        freq = base_freq * (2.0 ** (degree / divisions))
        duration = 1.2
        t = np.linspace(0, duration, int(SAMPLE_RATE * duration), False)
        
        # Bioluminescent organic envelope with harmonic shimmer
        envelope = np.exp(-3.5 * t) * np.sin(np.pi * t / duration)
        wave = 0.5 * np.sin(2 * np.pi * freq * t)
        wave += 0.25 * np.sin(2 * np.pi * freq * 1.498 * t)  # Microtonal fifth
        wave += 0.15 * np.sin(2 * np.pi * freq * 2.31 * t)   # Upper shimmer harmonic
        
        audio = (wave * envelope * 32767).astype(np.int16)
        stereo_audio = np.column_stack((audio, audio))
        
        sound = pygame.sndarray.make_sound(stereo_audio)
        sound.set_volume(0.5)
        sound.play()

synth = MicrotonalSynth()

# Represents a filesystem entity in 3D fractal space
class ReefNode:
    def __init__(self, path, depth=0, angle=0.0):
        self.path = path
        self.is_dir = os.path.isdir(path)
        self.depth = depth
        self.angle = angle
        self.children = []
        self.bloom_intensity = 0.0
        self.microtone_degree = random.randint(0, 37)  # Microtonal degree in 19-TET
        self.last_mtime = os.path.getmtime(path) if os.path.exists(path) else 0
        
        # Geometry dimensions based on topology depth
        self.branch_length = max(0.4, 2.5 / (depth + 1))
        self.radius = max(0.04, 0.35 / (depth + 1))

    def update_and_check(self):
        # Poll for real-time filesystem modifications
        try:
            mtime = os.path.getmtime(self.path)
            if mtime > self.last_mtime:
                self.last_mtime = mtime
                self.trigger_bloom()
        except OSError:
            pass

        # Decay bioluminescent glow over time
        if self.bloom_intensity > 0:
            self.bloom_intensity = max(0.0, self.bloom_intensity - 0.02)

        for child in self.children:
            child.update_and_check()

    def trigger_bloom(self):
        self.bloom_intensity = 1.0
        synth.play_microtonal_bloom(base_freq=110.0 * (1 + (self.depth % 3)), degree=self.microtone_degree)

# Recursively maps folder structures into a fractal reef graph
def build_reef(root_path, max_depth=3, current_depth=0):
    node = ReefNode(root_path, depth=current_depth)
    if current_depth >= max_depth or not node.is_dir:
        return node

    try:
        entries = sorted(os.listdir(root_path))[:6]  # Branch factor limit for rendering performance
        num_entries = len(entries)
        for i, entry in enumerate(entries):
            child_path = os.path.join(root_path, entry)
            angle = (2 * math.pi / max(1, num_entries)) * i
            child_node = build_reef(child_path, max_depth, current_depth + 1)
            child_node.angle = angle
            node.children.append(child_node)
    except PermissionError:
        pass

    return node

# 3D Primitive Rendering
def draw_cylinder(radius, height, slices=8):
    quad = gluNewQuadric()
    gluCylinder(quad, radius, radius * 0.7, height, slices, 1)

def draw_reef_node(node):
    glPushMatrix()
    
    # Calculate bioluminescent emission color
    r = 0.1 + 0.85 * node.bloom_intensity
    g = 0.3 + 0.5 * (1.0 - node.depth / 4.0) + 0.6 * node.bloom_intensity
    b = 0.8 + 0.2 * node.bloom_intensity
    
    glMaterialfv(GL_FRONT, GL_AMBIENT_AND_DIFFUSE, [r, g, b, 1.0])
    glMaterialfv(GL_FRONT, GL_EMISSION, [r * node.bloom_intensity, g * node.bloom_intensity, b * node.bloom_intensity, 1.0])

    # Transform coral branch along fractal path
    glRotatef(math.degrees(node.angle), 0, 1, 0)
    glRotatef(25 + node.depth * 6, 1, 0, 0)
    draw_cylinder(node.radius, node.branch_length)

    # Translate to branch tip
    glTranslatef(0, 0, node.branch_length)
    
    # Render bioluminescent coral polyp node
    quad = gluNewQuadric()
    glow_size = node.radius * (1.4 + node.bloom_intensity * 1.5)
    gluSphere(quad, glow_size, 8, 8)

    # Recursively render child branches
    for child in node.children:
        draw_reef_node(child)

    glPopMatrix()

def main():
    target_dir = os.path.abspath(".")
    print(f"Mapping filesystem reef topology at: {target_dir}")
    reef_root = build_reef(target_dir, max_depth=3)

    # Pygame & OpenGL Display Initialization
    display = (1024, 768)
    pygame.display.set_mode(display, DOUBLEBUF | OPENGL)
    pygame.display.set_caption("Filesystem 3D Fractal Reef - Microtonal Synth")

    glEnable(GL_DEPTH_TEST)
    glEnable(GL_LIGHTING)
    glEnable(GL_LIGHT0)
    glEnable(GL_COLOR_MATERIAL)

    glLightfv(GL_LIGHT0, GL_POSITION, (5.0, 10.0, 5.0, 1.0))
    glLightfv(GL_LIGHT0, GL_DIFFUSE, (0.8, 0.9, 1.0, 1.0))

    gluPerspective(45, (display[0] / display[1]), 0.1, 100.0)
    glTranslatef(0.0, -1.8, -9.0)

    # Helper to simulate file events on idle systems
    last_ambient_bloom = time.time()
    def trigger_random_leaf(node):
        if not node.children or random.random() < 0.35:
            node.trigger_bloom()
        else:
            trigger_random_leaf(random.choice(node.children))

    rotation = 0.0
    clock = pygame.time.Clock()
    running = True

    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT or (event.type == KEYDOWN and event.key == K_ESCAPE):
                running = False
            elif event.type == MOUSEBUTTONDOWN:
                trigger_random_leaf(reef_root)

        # Check for genuine file modifications in real time
        reef_root.update_and_check()

        # Ambient pulse generator every 3 seconds if files remain static
        if time.time() - last_ambient_bloom > 3.0:
            trigger_random_leaf(reef_root)
            last_ambient_bloom = time.time()

        # Scene Rendering Loop
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
        glPushMatrix()
        
        # Orbit camera around fractal reef
        glRotatef(rotation, 0, 1, 0)
        rotation += 0.35
        
        draw_reef_node(reef_root)
        
        glPopMatrix()
        pygame.display.flip()
        clock.tick(60)

    pygame.quit()

if __name__ == "__main__":
    main()