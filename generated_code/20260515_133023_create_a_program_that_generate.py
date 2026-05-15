import tkinter as tk
import random

# A digital meditation on impermanence.
# This cellular automaton translates a haiku's structure into a visual decay.

def morning(canvas, haiku_data):
    """Initializes the visual seeds based on syllable counts."""
    cells = []
    x_offset = 50
    y_offset = 100
    
    for line_idx, syllables in enumerate(haiku_data):
        # Map syllable count to a cluster of cells
        for s in range(syllables):
            # Each cell: [x, y, lifespan, color_val]
            color_val = 150 + (line_idx * 40)
            cell = [x_offset + (s * 40), y_offset + (line_idx * 60), 255, color_val]
            cells.append(cell)
    return cells

def whisper(cells):
    """Updates the cellular automaton: cells drift and fade."""
    for cell in cells:
        # Subtle random drift (impermanence of position)
        cell[0] += random.uniform(-1, 1)
        cell[1] += random.uniform(-1, 1)
        # Gradual decay of lifespan (impermanence of existence)
        cell[2] -= 1.5 
        # Color shifts as they die
        cell[3] = max(0, cell[3] - 0.2)

def silence(canvas, cells):
    """Renders the current state of the automaton to the screen."""
    canvas.delete("all")
    for cell in cells:
        if cell[2] > 0:
            # Map lifespan to radius and alpha-like visual weight
            radius = cell[2] / 50
            color = f'#{int(cell[3]):02x}{int(cell[2]/2):02x}{int(cell[2]):02x}'
            canvas.create_oval(
                cell[0] - radius, cell[1] - radius, 
                cell[0] + radius, cell[1] + radius, 
                fill=color, outline=""
            )

def run_poem():
    # Haiku structure: 5, 7, 5 syllables
    haiku_structure = [5, 7, 5]
    
    root = tk.Tk()
    root.title("Digital Haiku: Impermanence")
    root.configure(bg="black")
    
    canvas = tk.Canvas(root, width=600, height=400, bg="black", highlightthickness=0)
    canvas.pack()

    # Initialize state
    state = morning(canvas, haiku_structure)

    def animate():
        whisper(state)
        silence(canvas, state)
        # Stop when the last cell fades to silence
        if any(c[2] > 0 for c in state):
            root.after(30, animate)

    animate()
    root.mainloop()

if __name__ == "__main__":
    run_poem()