import dis
import inspect
import math
import sys
import tkinter as tk

# Self-contained generative script that inspects its own Python bytecode,
# converts machine instructions into a musical score, and renders the score
# alongside a rhythmically morphing fractal landscape in real time.

class BytecodeMusicFractalApp:
    def __init__(self, root):
        self.root = root
        self.root.title("Bytecode Music & Dynamic Fractal Landscape")
        self.width, self.height = 900, 700
        
        self.canvas = tk.Canvas(root, width=self.width, height=self.height, bg="#0a0a12")
        self.canvas.pack(fill=tk.BOTH, expand=True)
        
        # 1. Parse own bytecode machine instructions into musical notes
        self.score = self._extract_music_from_bytecode()
        self.playhead = 0
        self.angle_offset = 0.0
        
        # Start visualization animation loop
        self.animate()

    def _extract_music_from_bytecode(self):
        """Inspects own frame's bytecode instructions and maps opcodes to musical notes."""
        frame = inspect.currentframe()
        instructions = list(dis.get_instructions(frame.f_code))
        
        notes = []
        note_names = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']
        
        for instr in instructions:
            # Map opcode integer value to MIDI note pitch (36 to 84)
            midi_pitch = 36 + (instr.opcode % 48)
            octave = (midi_pitch // 12) - 1
            name = note_names[midi_pitch % 12] + str(octave)
            duration = 1 + (instr.arg or 1) % 4
            freq = 440.0 * (2.0 ** ((midi_pitch - 69) / 12.0))
            
            notes.append({
                'opcode_name': instr.opname,
                'midi': midi_pitch,
                'name': name,
                'freq': freq,
                'duration': duration,
                'staff_pos': (midi_pitch - 60)  # relative position on treble staff
            })
        return notes

    def draw_sheet_music(self):
        """Renders musical staves and notes derived from bytecode opcodes."""
        self.canvas.create_rectangle(20, 20, self.width - 20, 220, fill="#121220", outline="#2a2a40", width=2)
        self.canvas.create_text(40, 35, text="BYTECODE MUSICAL SCORE", fill="#8888ff", font=("Helvetica", 11, "bold"), anchor="w")
        
        # Draw 5 staff lines
        staff_y_center = 120
        line_spacing = 14
        for i in range(-2, 3):
            y = staff_y_center + i * line_spacing
            self.canvas.create_line(50, y, self.width - 50, y, fill="#444466", width=1)
            
        # Draw Treble Clef symbol
        self.canvas.create_text(70, staff_y_center, text="𝄞", fill="#aaaaaa", font=("Trebuchet MS", 42))
        
        # Draw musical notes along the score
        start_x = 120
        note_spacing = 35
        visible_count = int((self.width - 170) / note_spacing)
        
        for idx in range(min(visible_count, len(self.score))):
            note_idx = (self.playhead + idx) % len(self.score)
            note = self.score[note_idx]
            
            x = start_x + idx * note_spacing
            y = staff_y_center - (note['staff_pos'] * (line_spacing / 2))
            
            color = "#00ffff" if idx == 0 else "#aaaaee"
            radius = 6 if idx == 0 else 5
            
            # Note stem and head
            stem_dir = -1 if note['staff_pos'] >= 0 else 1
            self.canvas.create_line(x + radius, y, x + radius, y + (stem_dir * 25), fill=color, width=2)
            self.canvas.create_oval(x - radius, y - radius, x + radius, y + radius, fill=color, outline=color)
            
            # Draw Opcode label below staff
            if idx % 2 == 0:
                self.canvas.create_text(x, staff_y_center + 55, text=note['opcode_name'], fill="#666688", font=("Consolas", 7), angle=45, anchor="e")

    def draw_fractal_landscape(self, note):
        """Generates dynamic wireframe fractal terrain driven by the active opcode frequency."""
        center_y = 480
        pitch_factor = note['midi'] / 60.0
        
        cols = 40
        rows = 15
        
        points = []
        for r in range(rows):
            row_points = []
            z = r / rows
            perspective = 0.5 + 0.5 * z
            
            for c in range(cols + 1):
                x_norm = (c - cols / 2) / (cols / 2)
                
                # Multi-frequency harmonic wave modulated by pitch factor
                wave1 = math.sin(x_norm * 4.0 * pitch_factor + self.angle_offset + z * 3.0)
                wave2 = 0.5 * math.cos(x_norm * 9.0 - self.angle_offset * 1.5 + z * 5.0)
                wave3 = 0.25 * math.sin(x_norm * 18.0 + self.angle_offset * 2.0)
                
                height = (wave1 + wave2 + wave3) * 60.0 * (1.0 - z * 0.4)
                
                px = (self.width / 2) + (x_norm * 420.0 * perspective)
                py = center_y + (z * 160.0) - (height * perspective)
                
                row_points.append((px, py))
            points.append(row_points)
            
        # Draw dynamic landscape mesh
        for r in range(rows):
            for c in range(cols):
                p1 = points[r][c]
                p2 = points[r][c + 1]
                
                intensity = int(120 + 135 * (1.0 - r / rows))
                color = f"#{int(intensity*0.3):02x}{int(intensity*0.8):02x}{intensity:02x}"
                
                self.canvas.create_line(p1[0], p1[1], p2[0], p2[1], fill=color, width=1)
                if r < rows - 1:
                    p_below = points[r + 1][c]
                    self.canvas.create_line(p1[0], p1[1], p_below[0], p_below[1], fill=color, width=1)

    def animate(self):
        """Animation cycle refreshing rendering frame and advancing musical playhead."""
        self.canvas.delete("all")
        
        current_note = self.score[self.playhead]
        
        self.draw_sheet_music()
        self.draw_fractal_landscape(current_note)
        
        status_text = f"Instruction Opcode: {current_note['opcode_name']} | Note: {current_note['name']} ({current_note['freq']:.1f} Hz)"
        self.canvas.create_text(self.width / 2, self.height - 25, text=status_text, fill="#00ffcc", font=("Consolas", 11, "bold"))
        
        self.angle_offset += 0.05
        if int(self.angle_offset * 10) % 8 == 0:
            self.playhead = (self.playhead + 1) % len(self.score)
            
        self.root.after(40, self.animate)

if __name__ == "__main__":
    root = tk.Tk()
    app = BytecodeMusicFractalApp(root)
    root.mainloop()