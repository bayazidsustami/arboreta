import sys
import os
import random
import math
import tkinter as tk

class SolarSystemCompiler:
    def __init__(self, canvas, width, height, code_bytes):
        self.canvas = canvas
        self.width = width
        self.height = height
        self.center_x = width // 2
        self.center_y = height // 2
        self.bytes = code_bytes
        
        # Virtual Machine / Compiler state
        self.ip = 0
        self.stack = []
        self.memory = {}
        self.max_stack = 12
        
        # Visual state
        self.planets = []
        self.supernova = None
        self.star_radius = 25
        self.angle_offset = 0.0
        
        self.compile_bytes_to_planets()

    def compile_bytes_to_planets(self):
        """Parse raw opcodes (bytes) into planetary orbital parameters."""
        i = 0
        orbit_idx = 1
        while i < len(self.bytes):
            opcode = self.bytes[i]
            # Opcodes drive orbital characteristics
            radius = 50 + orbit_idx * 35
            speed = (0.01 + (opcode % 50) / 2000.0) * (1 if opcode % 2 == 0 else -1)
            size = max(4, (opcode % 18))
            
            # Color derived from opcode byte ranges
            r = (opcode * 7) % 256
            g = (opcode * 13) % 256
            b = (opcode * 19) % 256
            color = f"#{r:02x}{g:02x}{b:02x}"
            
            self.planets.append({
                'id': i,
                'opcode': opcode,
                'orbit_radius': radius,
                'speed': speed,
                'angle': (opcode * 17) % 360,
                'size': size,
                'color': color,
                'rings': []  # Populated via memory allocation opcodes
            })
            orbit_idx += 1
            i += max(1, opcode % 8)

    def step(self):
        """Execute bytecode step: allocate memory (rings), push/pop stack, trigger supernova on overflow."""
        if self.supernova:
            return

        if self.ip >= len(self.bytes):
            self.ip = 0  # Loop execution stream

        opcode = self.bytes[self.ip]
        self.ip += 1

        # Opcode logic simulation:
        # High bits trigger stack push; low bits trigger memory allocation
        if opcode % 3 == 0:
            # Memory allocation -> creates planetary rings
            planet = self.planets[self.ip % len(self.planets)]
            if len(planet['rings']) < 5:
                ring_radius = planet['size'] + len(planet['rings']) * 4 + 3
                planet['rings'].append(ring_radius)
                self.memory[len(self.memory)] = opcode
        elif opcode % 3 == 1:
            # Stack push
            self.stack.append(opcode)
            if len(self.stack) > self.max_stack:
                # Stack overflow triggers a Supernova event
                self.supernova = {'radius': 10, 'max_radius': max(self.width, self.height), 'alpha': 255}
                self.stack.clear()
                self.memory.clear()
        else:
            # Stack pop
            if self.stack:
                self.stack.pop()

    def update_and_draw(self):
        """Render orbital dynamics and active cosmic events."""
        self.canvas.delete("all")
        
        # Draw central compiler sun
        self.canvas.create_oval(
            self.center_x - self.star_radius, self.center_y - self.star_radius,
            self.center_x + self.star_radius, self.center_y + self.star_radius,
            fill="#ffcc00", outline="#ff8800", width=2
        )

        # Draw planets and memory rings
        for planet in self.planets:
            planet['angle'] += planet['speed']
            px = self.center_x + planet['orbit_radius'] * math.cos(planet['angle'])
            py = self.center_y + planet['orbit_radius'] * math.sin(planet['angle'])

            # Orbit path
            r = planet['orbit_radius']
            self.canvas.create_oval(
                self.center_x - r, self.center_y - r,
                self.center_x + r, self.center_y + r,
                outline="#222244", width=1
            )

            # Memory Allocation Rings
            for ring_r in planet['rings']:
                self.canvas.create_oval(
                    px - ring_r, py - ring_r / 2,
                    px + ring_r, py + ring_r / 2,
                    outline="#88ccff", width=1
                )

            # Planet Body
            ps = planet['size']
            self.canvas.create_oval(
                px - ps, py - ps, px + ps, py + ps,
                fill=planet['color'], outline="#ffffff"
            )

        # Supernova Event Rendering
        if self.supernova:
            sr = self.supernova['radius']
            self.canvas.create_oval(
                self.center_x - sr, self.center_y - sr,
                self.center_x + sr, self.center_y + sr,
                fill="#ffffff", outline="#ff3300", width=4
            )
            self.supernova['radius'] += 25
            if self.supernova['radius'] > self.supernova['max_radius']:
                self.supernova = None  # Reset after supernova clears

        # Display Stack State / VM stats
        stack_str = f"Stack Depth: {len(self.stack)} / {self.max_stack} | Memory Blocks: {len(self.memory)}"
        self.canvas.create_text(10, 10, anchor="nw", text=stack_str, fill="#00ff00", font=("Courier", 10))


def main():
    # Read own binary byte stream (self-referential)
    file_path = os.path.abspath(__file__)
    try:
        with open(file_path, "rb") as f:
            code_bytes = f.read()
    except Exception:
        # Fallback if executed dynamically without physical file
        code_bytes = b"SelfReferentialCompilerBinaryStreamBytecodeGenerator"

    # Setup Visualizing Canvas
    root = tk.Tk()
    root.title("Self-Referential Compiler Solar System")
    width, height = 900, 900
    canvas = tk.Canvas(root, width=width, height=height, bg="#050510")
    canvas.pack(fill="both", expand=True)

    compiler = SolarSystemCompiler(canvas, width, height, code_bytes)

    def animate():
        compiler.step()
        compiler.update_and_draw()
        root.after(30, animate)

    animate()
    root.mainloop()

if __name__ == "__main__":
    main()