import math
import random
import time
import tkinter as tk

# --- ESOTERIC COMPILER: Legacy Metrics to Ecosystem IR ---
class LegacyMetricsCompiler:
    """Parses legacy codebase thread sync metrics and compiles them into ecosystem DNA."""
    def __init__(self, raw_metrics):
        self.raw_metrics = raw_metrics

    def compile(self):
        ecosystem_dna = []
        for module, data in self.raw_metrics.items():
            contention = data.get("lock_contention", 0.1)
            wait_time = data.get("wait_time", 10.0)
            
            # Compile into firefly traits: speed, erraticness, pulse rate, color
            firefly_count = int(data.get("loc", 100) / 15)
            for _ in range(firefly_count):
                dna = {
                    "module": module,
                    "speed": 0.8 + (contention * 3.5),
                    "erraticness": contention * 2.0,
                    "glow_speed": 0.04 + (wait_time / 150.0),
                    "color": self._get_bottleneck_color(contention)
                }
                ecosystem_dna.append(dna)
        return ecosystem_dna

    def _get_bottleneck_color(self, contention):
        if contention > 0.7:
            return "#ff3344"  # Critical bottleneck (Red)
        elif contention > 0.4:
            return "#ffaa00"  # Moderate warning (Amber)
        return "#22ee88"      # Healthy synchronization (Green)

# --- GENERATIVE ECOSYSTEM (Simulation) ---
class Firefly:
    def __init__(self, canvas, width, height, dna):
        self.canvas = canvas
        self.x = random.uniform(0, width)
        self.y = random.uniform(0, height)
        self.vx = random.uniform(-1, 1) * dna["speed"]
        self.vy = random.uniform(-1, 1) * dna["speed"]
        self.dna = dna
        self.glow_phase = random.uniform(0, math.pi * 2)
        self.radius = 3.5
        
        self.id = canvas.create_oval(
            self.x - self.radius, self.y - self.radius,
            self.x + self.radius, self.y + self.radius,
            fill=dna["color"], outline=""
        )

    def update(self, width, height):
        # Erratic movement maps to thread contention spikes
        self.vx += random.uniform(-self.dna["erraticness"], self.dna["erraticness"])
        self.vy += random.uniform(-self.dna["erraticness"], self.dna["erraticness"])
        
        # Friction dampening
        self.vx *= 0.94
        self.vy *= 0.94
        
        self.x += self.vx
        self.y += self.vy
        
        # Toroidal space wrapping
        if self.x < 0: self.x = width
        elif self.x > width: self.x = 0
        if self.y < 0: self.y = height
        elif self.y > height: self.y = 0
        
        # Flashing frequency maps to wait times
        self.glow_phase += self.dna["glow_speed"]
        
        self.canvas.coords(
            self.id,
            self.x - self.radius, self.y - self.radius,
            self.x + self.radius, self.y + self.radius
        )

class EcosystemApp:
    def __init__(self, root, ecosystem_dna):
        self.root = root
        self.root.title("Esoteric Compiler: Legacy Codebase Ecosystem")
        self.width, self.height = 900, 600
        
        self.canvas = tk.Canvas(root, width=self.width, height=self.height, bg="#0d0d12")
        self.canvas.pack(fill=tk.BOTH, expand=True)
        
        self.fireflies = [Firefly(self.canvas, self.width, self.height, dna) for dna in ecosystem_dna]
        
        # Dashboard overlay
        self.canvas.create_text(25, 25, anchor=tk.NW, text="Legacy Thread Synchronization Visualizer", fill="#ffffff", font=("Helvetica", 14, "bold"))
        self.canvas.create_text(25, 50, anchor=tk.NW, text="🟢 Healthy Sync   🟡 Moderate Contention   🔴 Critical Bottleneck", fill="#888899", font=("Helvetica", 10))
        
        self.animate()

    def animate(self):
        for ff in self.fireflies:
            ff.update(self.width, self.height)
        self.root.after(25, self.animate)

if __name__ == "__main__":
    # Simulated metrics compiled from a legacy codebase
    legacy_metrics = {
        "AuthService.cpp": {"loc": 520, "lock_contention": 0.88, "wait_time": 180.0},
        "TransactionManager.java": {"loc": 750, "lock_contention": 0.62, "wait_time": 95.0},
        "CacheDispatcher.py": {"loc": 300, "lock_contention": 0.15, "wait_time": 12.0},
        "PacketBuffer.rs": {"loc": 410, "lock_contention": 0.35, "wait_time": 30.0}
    }
    
    compiler = LegacyMetricsCompiler(legacy_metrics)
    ecosystem_dna = compiler.compile()
    
    root = tk.Tk()
    app = EcosystemApp(root, ecosystem_dna)
    root.mainloop()