import math
import random
import tkinter as tk

class CoralReefEngine:
    def __init__(self, root):
        self.root = root
        self.root.title("Procedural Memory Reef: Coral vs. Crown of Thorns")
        
        # Setup underwater canvas
        self.canvas = tk.Canvas(root, width=900, height=600, bg="#001a33")
        self.canvas.pack(fill=tk.BOTH, expand=True)

        self.corals = []
        self.starfish = []
        
        # Simulation metrics representing live system state
        self.allocated_memory = 40.0  # MB
        self.leaked_memory = 0.0      # MB
        
        # Draw ocean floor
        self.canvas.create_rectangle(0, 540, 900, 600, fill="#00334d", outline="")
        
        # Start visualization loop
        self.animate()

    def spawn_coral(self, x, y):
        # Blooms a colorful coral polyp representing healthy memory structures
        petals = random.randint(6, 14)
        radius = random.randint(12, 32)
        color = random.choice(["#ff6b81", "#ff4757", "#ffa502", "#2ed573", "#1e90ff", "#ff7979", "#badc58"])
        items = []
        for i in range(petals):
            angle = (i / petals) * 2 * math.pi
            px = x + math.cos(angle) * (radius * 0.6)
            py = y + math.sin(angle) * (radius * 0.6)
            item = self.canvas.create_oval(px-4, py-4, px+4, py+4, fill=color, outline="")
            items.append(item)
        center = self.canvas.create_oval(x-radius/3, y-radius/3, x+radius/3, y+radius/3, fill=color, outline="")
        self.corals.append({"center": center, "items": items})

    def spawn_starfish(self, x, y):
        # Spawns an invading Crown of Thorns starfish representing memory leaks
        points = []
        for i in range(12):
            angle = (i / 12) * 2 * math.pi
            r = 18 if i % 2 == 0 else 9
            px = x + math.cos(angle) * r
            py = y + math.sin(angle) * r
            points.append((px, py))
        flat_points = [coord for pt in points for coord in pt]
        item = self.canvas.create_polygon(flat_points, fill="#8B0000", outline="#FF4500", width=2)
        self.starfish.append({"item": item, "x": x, "y": y})

    def update(self):
        # Simulate dynamic allocation fluxes
        self.allocated_memory += random.uniform(-0.8, 1.2)
        self.allocated_memory = max(10.0, min(self.allocated_memory, 250.0))

        # Introduce memory leak increments over time
        if random.random() < 0.2:
            self.leaked_memory += random.uniform(0.5, 2.5)
        
        # Periodic partial garbage collection cleanup
        if random.random() < 0.04 and self.leaked_memory > 5:
            self.leaked_memory = max(0.0, self.leaked_memory - 4.0)

        # Scale coral population with allocated memory footprint
        desired_corals = int(self.allocated_memory / 6)
        while len(self.corals) < desired_corals:
            self.spawn_coral(random.randint(60, 840), random.randint(460, 530))

        # Scale starfish population with leaked memory footprint
        desired_starfish = int(self.leaked_memory / 4)
        while len(self.starfish) < desired_starfish:
            self.spawn_starfish(random.randint(60, 840), random.randint(80, 400))

        # Creep starfish downward toward the reef ecosystem
        for sf in self.starfish:
            if sf["y"] < 520:
                drift_x = random.choice([-1, 0, 1])
                sf["y"] += 1
                self.canvas.move(sf["item"], drift_x, 1)

        # Render real-time telemetry overlay
        self.canvas.delete("telemetry")
        status_str = f"Live Memory Allocated: {self.allocated_memory:.1f} MB  |  Memory Leak (Crown of Thorns): {self.leaked_memory:.1f} MB"
        self.canvas.create_text(15, 15, anchor=tk.NW, text=status_str, fill="#ffffff", font=("Courier", 11, "bold"), tag="telemetry")

        # Frame rate throttle
        self.root.after(80, self.update)

    def animate(self):
        self.update()

if __name__ == "__main__":
    root = tk.Tk()
    app = CoralReefEngine(root)
    root.mainloop()