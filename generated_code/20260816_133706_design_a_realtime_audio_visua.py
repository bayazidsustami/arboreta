import sys
import time
import math
import numpy as np
import pyaudio

from VisPy.glsl import OpenGL
import vispy.app
from vispy import scene
from vispy.scene import visual_names

# Audio Configuration
CHUNK = 1024
FORMAT = pyaudio.paInt16
CHANNELS = 1
RATE = 44100

# Simulation Grid Configuration
GRID_SIZE = 128

class AudioAnalyzer:
    def __init__(self):
        self.p = pyaudio.PyAudio()
        self.stream = None
        self.volume = 0.0
        self.pitch = 0.0
        self.timbre = 0.0
        
    def start(self):
        try:
            self.stream = self.p.open(
                format=FORMAT,
                channels=CHANNELS,
                rate=RATE,
                input=True,
                frames_per_buffer=CHUNK
            )
        except Exception as e:
            print(f"Audio stream failed to open: {e}")
            self.stream = None

    def update(self):
        if self.stream is None:
            # Fallback synth for testing without microphone
            t = time.time()
            self.volume = (math.sin(t * 2) + 1) * 0.5
            self.pitch = (math.cos(t * 0.5) + 1) * 0.5
            self.timbre = (math.sin(t * 1.5) + 1) * 0.5
            return

        try:
            data = self.stream.read(CHUNK, exception_on_overflow=False)
            audio_data = np.frombuffer(data, dtype=np.int16).astype(np.float32)
            
            # Volume (RMS)
            rms = np.sqrt(np.mean(audio_data ** 2))
            self.volume = float(np.clip(rms / 3000.0, 0.0, 1.0))
            
            # FFT for Pitch and Timbre
            fft_data = np.abs(np.fft.rfft(audio_data))
            freqs = np.fft.rfftfreq(CHUNK, 1.0 / RATE)
            
            if np.sum(fft_data) > 0:
                # Pitch: Dominant Frequency normalized
                dominant_idx = np.argmax(fft_data)
                self.pitch = float(np.clip(freqs[dominant_idx] / 2000.0, 0.0, 1.0))
                
                # Timbre: Spectral Centroid / Spread
                spectral_centroid = np.sum(freqs * fft_data) / np.sum(fft_data)
                self.timbre = float(np.clip(spectral_centroid / 4000.0, 0.0, 1.0))
            else:
                self.pitch = 0.0
                self.timbre = 0.0

        except Exception:
            pass

    def close(self):
        if self.stream:
            self.stream.stop_stream()
            self.stream.close()
        self.p.terminate()

class LichenVisualizer:
    def __init__(self):
        # VisPy Canvas & Viewport
        self.canvas = scene.SceneCanvas(keys='interactive', show=True, title='Digital Lichen Colony')
        self.view = self.canvas.central_widget.add_view()
        self.view.camera = scene.cameras.ArcballCamera(fov=45, distance=200)
        
        # Grid initialization
        self.size = GRID_SIZE
        self.colony = np.zeros((self.size, self.size), dtype=np.float32)
        
        # Audio input module
        self.audio = AudioAnalyzer()
        self.audio.start()
        
        # Create 3D Mesh Surface
        x = np.linspace(-50, 50, self.size)
        y = np.linspace(-50, 50, self.size)
        self.X, self.Y = np.meshgrid(x, y)
        self.Z = np.zeros((self.size, self.size), dtype=np.float32)
        
        # Create initial mesh visual
        vertices, faces = self._generate_mesh(self.Z)
        colors = self._compute_colors(self.colony)
        
        self.mesh = scene.visuals.Mesh(vertices=vertices, faces=faces, vertex_colors=colors, shading='smooth')
        self.view.add(self.mesh)
        
        # Animation Loop
        self.timer = vispy.app.Timer(interval=0.033, connect=self.on_timer, start=True)

    def _generate_mesh(self, z_data):
        # Create vertices and faces for a regular 2D heightfield mesh
        vertices = np.zeros((self.size * self.size, 3), dtype=np.float32)
        vertices[:, 0] = self.X.flatten()
        vertices[:, 1] = self.Y.flatten()
        vertices[:, 2] = z_data.flatten()
        
        faces = []
        for i in range(self.size - 1):
            for j in range(self.size - 1):
                idx = i * self.size + j
                faces.append([idx, idx + 1, idx + self.size])
                faces.append([idx + 1, idx + self.size + 1, idx + self.size])
                
        return vertices, np.array(faces, dtype=np.uint32)

    def _compute_colors(self, growth):
        # Compute dynamic lichen surface colors (bioluminescent green/cyan/gold)
        colors = np.zeros((self.size * self.size, 4), dtype=np.float32)
        g = growth.flatten()
        
        colors[:, 0] = g * 0.2  # Red
        colors[:, 1] = g * 0.8  # Green
        colors[:, 2] = np.sin(g * np.pi) * 0.5  # Blue/Cyan
        colors[:, 3] = np.clip(g * 2.0, 0.2, 1.0)  # Alpha
        return colors

    def update_simulation(self):
        self.audio.update()
        vol = self.audio.volume
        pitch = self.audio.pitch
        timbre = self.audio.timbre
        
        # 1. Pitch controls Spore Germination
        if vol > 0.05 and np.random.rand() < (pitch * 0.3 + 0.05):
            gx = np.random.randint(5, self.size - 5)
            gy = np.random.randint(5, self.size - 5)
            self.colony[gx, gy] = 1.0
            
        # 2. Timbre dictates Fractal Edges (Reaction-Diffusion Modifier)
        # Shift diffusion neighborhood weights mathematically based on timbre
        k = 0.05 + timbre * 0.15
        
        # Simple Laplacians for cellular growth
        laplacian = (
            np.roll(self.colony, 1, axis=0) + np.roll(self.colony, -1, axis=0) +
            np.roll(self.colony, 1, axis=1) + np.roll(self.colony, -1, axis=1) -
            4 * self.colony
        )
        
        # 3. Volume controls Growth Speed
        growth_rate = 0.05 + vol * 0.5
        self.colony += growth_rate * (laplacian * k + self.colony * (1.0 - self.colony) * 0.1)
        self.colony = np.clip(self.colony, 0.0, 1.0)
        
        # Map colony growth to 3D mesh displacement
        self.Z = self.colony * 15.0

    def on_timer(self, event):
        self.update_simulation()
        
        # Update mesh positions and visual properties
        vertices, _ = self._generate_mesh(self.Z)
        colors = self._compute_colors(self.colony)
        
        self.mesh.set_data(vertices=vertices, faces=self.mesh.faces, vertex_colors=colors)
        self.canvas.update()

if __name__ == '__main__':
    viz = LichenVisualizer()
    vispy.app.run()