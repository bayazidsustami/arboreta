import os
import random
import math
import tkinter as tk
from tkinter import font as tkfont

# Since we want it self-contained without external dependencies like nltk/textblob,
# we use a lightweight built-in lexicon approach for sentiment analysis,
# and basic part-of-speech heuristic tagging via capitalization and common suffixes.

LEXICON = {
    "joy": 1.0, "happy": 1.0, "love": 1.5, "beautiful": 1.2, "creative": 1.0,
    "excellent": 1.3, "bright": 0.8, "peace": 1.0, "serene": 1.2, "vibrant": 1.1,
    "hate": -1.5, "sad": -1.0, "dark": -0.8, "gloom": -1.2, "chaos": -0.5,
    "angry": -1.2, "fear": -1.1, "death": -1.5, "grim": -1.0, "pain": -1.2
}

def analyze_sentiment(text):
    """Returns a score between -1.0 (negative) and 1.0 (positive)."""
    words = text.lower().split()
    score = 0.0
    count = 0
    for w in words:
        clean = "".join(c for c in w if c.isalnum())
        if clean in LEXICON:
            score += LEXICON[clean]
            count += 1
    return max(-1.0, min(1.0, score / count)) if count > 0 else 0.0

def guess_syntax(word):
    """Heuristic POS tagger: returns 'noun', 'verb', 'adj', or 'other'."""
    clean = "".join(c for c in word if c.isalnum()).lower()
    if not clean:
        return "other"
    if word[0].isupper() and len(word) > 1:
        return "noun"  # Proper noun heuristic
    if clean.endswith(("ing", "ed", "ate", "ify")):
        return "verb"
    if clean.endswith(("ful", "ous", "al", "ive", "ic", "less")):
        return "adj"
    if clean.endswith(("tion", "ment", "ness", "er", "or")):
        return "noun"
    return "other"

class Boid:
    def __init__(self, tx, ty, syntax_mode):
        self.tx = tx  # Target X (from font glyph path)
        self.ty = ty  # Target Y
        self.x = tx + random.uniform(-50, 50)
        self.y = ty + random.uniform(-50, 50)
        self.vx = random.uniform(-2, 2)
        self.vy = random.uniform(-2, 2)
        self.syntax = syntax_mode
        
        # Base flocking parameters
        self.max_speed = 4.0
        self.max_force = 0.2
        self.perception = 40.0
        
        # Dynamic adjustments based on Syntax
        if self.syntax == "noun":    # Strong structural attraction
            self.target_weight = 1.8
            self.cohesion_weight = 0.6
        elif self.syntax == "verb":  # Highly energetic and erratic
            self.max_speed = 6.0
            self.target_weight = 0.8
            self.separation_weight = 1.8
        elif self.syntax == "adj":   # Decorative, flowing paths
            self.perception = 60.0
            self.cohesion_weight = 1.5
            self.alignment_weight = 1.2
        else:                        # Standard default
            self.target_weight = 1.2
            self.separation_weight = 1.0

    def update(self, boids, sentiment):
        # Alter parameters dynamically via global sentiment
        # Positive sentiment = smoother, cohesive flow. Negative = chaotic, repelling.
        s_align = 1.0 + (sentiment * 0.5)
        s_cohere = 1.0 + (sentiment * 0.7)
        s_separate = 1.0 - (sentiment * 0.6)
        
        sep_x, sep_y = 0.0, 0.0
        ali_x, ali_y = 0.0, 0.0
        coh_x, coh_y = 0.0, 0.0
        total = 0

        for other in boids:
            if other is self:
                continue
            dx = other.x - self.x
            dy = other.y - self.y
            dist = math.hypot(dx, dy)
            if 0 < dist < self.perception:
                # Separation
                sep_x -= dx / dist
                sep_y -= dy / dist
                # Alignment
                ali_x += other.vx
                ali_y += other.vy
                # Cohesion
                coh_x += other.x
                coh_y += other.y
                total += 1

        ax, ay = 0.0, 0.0
        if total > 0:
            # Normalize behaviors
            sep_x /= total
            sep_y /= total
            ali_x /= total
            ali_y /= total
            coh_x = (coh_x / total) - self.x
            coh_y = (coh_y / total) - self.y
            
            # Apply sentiment adjustments and weights
            w_sep = getattr(self, 'separation_weight', 1.0) * s_separate
            w_ali = getattr(self, 'alignment_weight', 1.0) * s_align
            w_coh = getattr(self, 'cohesion_weight', 1.0) * s_cohere
            
            ax += sep_x * w_sep + ali_x * w_ali + coh_x * w_coh
            ay += sep_y * w_sep + ali_y * w_ali + coh_y * w_coh

        # Target Attraction (The typography constraint)
        tx_force = self.tx - self.x
        ty_force = self.ty - self.y
        w_tgt = getattr(self, 'target_weight', 1.2)
        ax += tx_force * w_tgt
        ay += ty_force * w_tgt

        # Truncate force
        f_mag = math.hypot(ax, ay)
        if f_mag > self.max_force:
            ax = (ax / f_mag) * self.max_force
            ay = (ay / f_mag) * self.max_force

        # Update physics
        self.vx += ax
        self.vy += ay
        v_mag = math.hypot(self.vx, self.vy)
        if v_mag > self.max_speed:
            self.vx = (self.vx / v_mag) * self.max_speed
            self.vy = (self.vy / v_mag) * self.max_speed

        self.x += self.vx
        self.y += self.vy

class GenerativeTypographyPoster:
    def __init__(self, root, text_content):
        self.root = root
        self.root.title("Generative Typography Poster")
        self.width, self.height = 1000, 750
        
        # Poster Styling based on Sentiment
        self.sentiment = analyze_sentiment(text_content)
        self.bg_color = "#111115" if self.sentiment < 0 else "#faf9f6"
        self.canvas = tk.Canvas(root, width=self.width, height=self.height, bg=self.bg_color, highlightthickness=0)
        self.canvas.pack()

        self.words = text_content.split()
        self.boids = []
        self.setup_typography()
        self.animate()

    def setup_typography(self):
        """Extracts coordinate masks from text layout and initialises boids inside them."""
        # Setup clean offscreen canvas rendering via standard Tkinter Font mechanics
        f_size = 64 if len(self.words) > 10 else 96
        font_style = tkfont.Font(family="Helvetica", size=f_size, weight="bold")
        
        # Layout tracking variables
        margin_x, margin_y = 80, 150
        curr_x, curr_y = margin_x, margin_y
        line_height = f_size * 1.4

        for word in self.words:
            syntax = guess_syntax(word)
            w_width = font_style.measure(word + " ")
            
            if curr_x + w_width > self.width - margin_x:
                curr_x = margin_x
                curr_y += line_height
                if curr_y > self.height - margin_y:
                    break # Break if we overflow the canvas grid boundaries

            # Generate font backbone geometry by creating temporary text objects to sample geometry
            t_id = self.canvas.create_text(curr_x, curr_y, text=word, font=font_style, anchor="nw")
            bbox = self.canvas.bbox(t_id)
            self.canvas.delete(t_id)
            
            if bbox:
                bx1, by1, bx2, by2 = bbox
                # Subsample points inside the bounding box of the text to discover letter forms
                samples = 0
                max_samples_per_word = 120
                attempts = 0
                
                while samples < max_samples_per_word and attempts < max_samples_per_word * 5:
                    attempts += 1
                    rx = random.uniform(bx1, bx2)
                    ry = random.uniform(by1, by2)
                    
                    # Fine-grained overlap check using canvas find_overlapping
                    test_id = self.canvas.create_text(curr_x, curr_y, text=word, font=font_style, anchor="nw", fill="#000000")
                    overlapping = self.canvas.find_overlapping(rx, ry, rx+1, ry+1)
                    self.canvas.delete(test_id)
                    
                    if overlapping:
                        self.boids.append(Boid(rx, ry, syntax))
                        samples += 1
            
            curr_x += w_width

    def get_color_palette(self, syntax):
        """Maps syntax styles and global sentiment to generative color palettes."""
        if self.sentiment >= 0: # Positive aesthetic (Light background)
            if syntax == "noun": return "#2E4057" # Deep blue slate
            if syntax == "verb": return "#F4D35E" # Energetic warm yellow
            if syntax == "adj":  return "#EE964B" # Saturated saffron
            return "#1D3557"
        else: # Negative/Chaos aesthetic (Dark background)
            if syntax == "noun": return "#4A4E69" # Ash muted purple
            if syntax == "verb": return "#E63946" # Crimson fire
            if syntax == "adj":  return "#9A8C98" # Ghostly silver grey
            return "#F1FAEE"

    def animate(self):
        # Semi-transparent background fade simulation to create artistic trail paths
        fade_color = "#111115" if self.sentiment < 0 else "#faf9f6"
        # Since Tkinter canvas doesn't easily support alpha transparency shapes natively without complex images, 
        # we dynamically handle trail effects via rendering small points and drawing connections or explicit clearing
        self.canvas.delete("trail_particle")

        # Update and render agent networks
        for boid in self.boids:
            boid.update(self.boids, self.sentiment)
            color = self.get_color_palette(boid.syntax)
            
            # Draw autonomous kinetic agent
            r = 2.5 if boid.syntax == "verb" else 1.8
            self.canvas.create_oval(
                boid.x - r, boid.y - r, boid.x + r, boid.y + r,
                fill=color, outline="", tags="trail_particle"
            )
            
            # Occasionally trace structural ties back to typography layout anchor origins
            if random.random() < 0.04:
                self.canvas.create_line(
                    boid.x, boid.y, boid.tx, boid.ty,
                    fill=color, stipple="gray25", tags="trail_particle"
                )

        self.root.after(30, self.animate)

if __name__ == "__main__":
    # Sample input text block rich with varied sentiments and structural syntax
    sample_text = (
        "Creative expressions paint beautiful designs into serene worlds. "
        "Yet chaos brings dark fear, angry pain, and violent unexpected death."
    )
    
    # Save text locally to fulfill the file reader constraint workflow pipeline
    file_path = "input_poster_text.txt"
    with open(file_path, "w", encoding="utf-8") as f:
        f.write(sample_text)

    # Read the translated asset file
    with open(file_path, "r", encoding="utf-8") as f:
        active_content = f.read()

    # Launch generation application interface
    main_window = tk.Tk()
    poster_app = GenerativeTypographyPoster(main_window, active_content)
    
    # Cleanup dummy file on shutdown
    def on_closing():
        if os.path.exists(file_path):
            os.remove(file_path)
        main_window.destroy()
        
    main_window.protocol("WM_DELETE_WINDOW", on_closing)
    main_window.mainloop()