import numpy as np
import matplotlib.pyplot as plt
from matplotlib.animation import FuncAnimation
import time
import threading

# ==========================================
# ALIEN TOPOGRAPHY ENGINE (TYPING-DRIVEN)
# ==========================================
# Translates typing cadence (uplift) and backspace 
# frequency (hydraulic/thermal erosion) into a 
# living 3D alien mountain range.
# ==========================================

class AlienTerrainEngine:
    def __init__(self, size=120):
        self.size = size
        # Initialize base heightmap using multi-frequency trigonometric noise
        x = np.linspace(0, 4 * np.pi, size)
        y = np.linspace(0, 4 * np.pi, size)
        xx, yy = np.meshgrid(x, y)
        self.heightmap = np.sin(xx) * np.cos(yy) + 0.5 * np.sin(xx * 2) * np.cos(yy * 2)
        self.heightmap = (self.heightmap - self.heightmap.min()) / (self.heightmap.max() - self.heightmap.min()) * 4.0
        self.lock = threading.Lock()
        
    def uplift(self, intensity=0.25):
        """Simulates tectonic rise driven by rapid keystrokes/typing bursts."""
        with self.lock:
            cx = np.random.randint(15, self.size - 15)
            cy = np.random.randint(15, self.size - 15)
            sigma = np.random.uniform(4, 9)
            
            x = np.arange(self.size)
            y = np.arange(self.size)
            xx, yy = np.meshgrid(x, y)
            gaussian = np.exp(-((xx - cx)**2 + (yy - cy)**2) / (2 * sigma**2))
            self.heightmap += gaussian * intensity

    def erode(self, intensity=0.4):
        """Simulates rapid weathering and valley carving triggered by backspaces."""
        with self.lock:
            kernel = np.array([[0.05, 0.1,  0.05],
                               [0.1,  0.4,  0.1 ],
                               [0.05, 0.1,  0.05]])
            smoothed = np.zeros_like(self.heightmap)
            padded = np.pad(self.heightmap, 1, mode='edge')
            for i in range(3):
                for j in range(3):
                    smoothed += kernel[i, j] * padded[i:i+self.size, j:j+self.size]
            
            # Blend heightmap with smoothed matrix to flatten peaks and fill basins
            self.heightmap = (1 - intensity) * self.heightmap + intensity * smoothed
            self.heightmap -= 0.015 * intensity

    def weathering_step(self):
        """Continuous atmospheric wind erosion over time."""
        with self.lock:
            self.heightmap[:-1, :] = 0.992 * self.heightmap[:-1, :] + 0.008 * self.heightmap[1:, :]

# Initialize Engine
engine = AlienTerrainEngine(size=100)

# Setup Matplotlib 3D Visualization
fig = plt.figure(figsize=(11, 8))
ax = fig.add_subplot(111, projection='3d')
fig.patch.set_facecolor('#080c14')
ax.set_facecolor('#080c14')

x = np.arange(engine.size)
y = np.arange(engine.size)
X, Y = np.meshgrid(x, y)

def update(frame):
    ax.clear()
    engine.weathering_step()
    
    with engine.lock:
        Z = engine.heightmap.copy()
        
    ax.set_facecolor('#080c14')
    ax.xaxis.set_pane_color((0.02, 0.04, 0.08, 1.0))
    ax.yaxis.set_pane_color((0.02, 0.04, 0.08, 1.0))
    ax.zaxis.set_pane_color((0.02, 0.04, 0.08, 1.0))
    
    # Render alien mountain mesh with plasma colormap
    surf = ax.plot_surface(X, Y, Z, cmap='inferno', edgecolor='none', rstride=2, cstride=2, antialiased=True, alpha=0.95)
    
    ax.set_title("Xenomorphic Topography: Cadence Uplift & Backspace Erosion", color='#00ffcc', fontsize=13, weight='bold')
    ax.set_axis_off()
    return surf,

# Simulate typing cadence and correction streams for standalone demonstration
def live_simulation():
    while True:
        time.sleep(0.4)
        # Simulate typing burst -> Mountain uplift
        engine.uplift(intensity=np.random.uniform(0.15, 0.35))
        # Simulate backspace corrections -> Intense erosion phase
        if np.random.rand() < 0.5:
            engine.erode(intensity=np.random.uniform(0.4, 0.8))

sim_thread = threading.Thread(target=live_simulation, daemon=True)
sim_thread.start()

ani = FuncAnimation(fig, update, interval=80, cache_frame_data=False)
plt.show()