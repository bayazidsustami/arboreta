# Generative Typography Engine: Text File to 3D Printable Mesh (OBJ/STL)
# Translates prose into a 3D plaque where typography geometry (height, density, surface texture)
# is procedurally driven by semantic sentiment and syllable cadence.

import math
import sys
import os
import re

# Simple built-in 5x7 bitmap font for ASCII printable characters
FONT_5X7 = {
    'A': ["01110","10001","10001","11111","10001","10001","10001"],
    'B': ["11110","10001","10001","11110","10001","10001","11110"],
    'C': ["01111","10000","10000","10000","10000","10000","01111"],
    'D': ["11110","10001","10001","10001","10001","10001","11110"],
    'E': ["11111","10000","10000","11110","10000","10000","11111"],
    'F': ["11111","10000","10000","11110","10000","10000","10000"],
    'G': ["01111","10000","10000","10011","10001","10001","01110"],
    'H': ["10001","10001","10001","11111","10001","10001","10001"],
    'I': ["01110","00100","00100","00100","00100","00100","01110"],
    'J': ["00011","00001","00001","00001","00001","10001","01110"],
    'K': ["10001","10010","10100","11000","10100","10010","10001"],
    'L': ["10000","10000","10000","10000","10000","10000","11111"],
    'M': ["10001","11011","10101","10001","10001","10001","10001"],
    'N': ["10001","11001","10101","10011","10001","10001","10001"],
    'O': ["01110","10001","10001","10001","10001","10001","01110"],
    'P': ["11110","10001","10001","11110","10000","10000","10000"],
    'Q': ["01110","10001","10001","10001","10101","10010","01101"],
    'R': ["11110","10001","10001","11110","10100","10010","10001"],
    'S': ["01111","10000","10000","01110","00001","00001","11110"],
    'T': ["11111","00100","00100","00100","00100","00100","00100"],
    'U': ["10001","10001","10001","10001","10001","10001","01110"],
    'V': ["10001","10001","10001","10001","10001","01010","00100"],
    'W': ["10001","10001","10001","10001","10101","11011","10001"],
    'X': ["10001","10001","01010","00100","01010","10001","10001"],
    'Y': ["10001","10001","01010","00100","00100","00100","00100"],
    'Z': ["11111","00001","00010","00100","01000","10000","11111"],
    ' ': ["00000","00000","00000","00000","00000","00000","00000"],
    '.': ["00000","00000","00000","00000","00000","01100","01100"],
    ',': ["00000","00000","00000","00000","00110","00100","01000"],
    '!': ["00100","00100","00100","00100","00100","00000","00100"],
    '?': ["01110","10001","00010","00100","00100","00000","00100"],
}

# Lexicon for sentiment calculation
POSITIVE_LEXICON = {
    'good', 'great', 'happy', 'joy', 'bright', 'love', 'light', 'calm', 'peace', 'soar',
    'elevation', 'hope', 'life', 'sweet', 'warm', 'soft', 'beautiful', 'gentle', 'shine',
    'wonder', 'radiant', 'divine', 'pure', 'clarity', 'triumph', 'bless', 'harmony'
}
NEGATIVE_LEXICON = {
    'bad', 'dark', 'heavy', 'sad', 'gloom', 'fall', 'decay', 'death', 'bitter', 'pain',
    'sharp', 'fear', 'cold', 'grim', 'shadow', 'storm', 'grief', 'rage', 'ruin', 'dread',
    'broken', 'haunt', 'despair', 'night', 'void', 'loss', 'harsh', 'sorrow', 'agony'
}

def analyze_sentiment(text):
    """Calculates sentiment scores (-1.0 to +1.0) for each word in text."""
    words = re.findall(r'\b\w+\b', text.lower())
    scores = []
    for w in words:
        val = 0.0
        if w in POSITIVE_LEXICON:
            val = 1.0
        elif w in NEGATIVE_LEXICON:
            val = -1.0
        scores.append(val)
    if not scores:
        return [0.0]
    # Smooth sentiment using moving average
    smoothed = []
    window = 3
    for i in range(len(scores)):
        start = max(0, i - window)
        end = min(len(scores), i + window + 1)
        smoothed.append(sum(scores[start:end]) / (end - start))
    return smoothed

def count_syllables(word):
    """Estimates syllable count of a word using vowel sequence heuristics."""
    word = word.lower()
    if len(word) <= 3:
        return 1
    word = re.sub(r'(?:[^laeiouy]es|ed|[^laeiouy]e)$', '', word)
    word = re.sub(r'^y', '', word)
    syllables = len(re.findall(r'[aeiouy]{1,2}', word))
    return max(1, syllables)

def procedural_noise(x, y, phase, frequency=0.5):
    """Trigonometric multi-frequency noise generator for surface texturing."""
    n1 = math.sin(x * frequency + phase) * math.cos(y * frequency + phase)
    n2 = math.sin((x + y) * frequency * 2.1 + phase * 1.3) * 0.5
    n3 = math.cos(math.sqrt(x*x + y*y) * frequency * 1.5 - phase) * 0.25
    return n1 + n2 + n3

class MeshBuilder:
    """Manages 3D vertices and triangular faces for OBJ export."""
    def __init__(self):
        self.vertices = []
        self.faces = []

    def add_cube(self, x0, y0, z0, x1, y1, z1, top_texture_fn=None):
        """Adds an extruded rectangular block with optional surface noise displacement on top."""
        v_idx = len(self.vertices) + 1
        
        # Subdivided top surface for rich texture
        sub_x, sub_y = 2, 2
        top_verts = []
        for sy in range(sub_y + 1):
            for sx in range(sub_x + 1):
                px = x0 + (x1 - x0) * (sx / sub_x)
                py = y0 + (y1 - y0) * (sy / sub_y)
                pz = z1
                if top_texture_fn:
                    pz += top_texture_fn(px, py)
                top_verts.append((px, py, pz))

        # Bottom vertices (4 corners)
        bot_verts = [
            (x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0)
        ]

        for v in bot_verts:
            self.vertices.append(v)
        for v in top_verts:
            self.vertices.append(v)

        # Bottom face
        self.faces.append((v_idx, v_idx + 2, v_idx + 1))
        self.faces.append((v_idx, v_idx + 3, v_idx + 2))

        # Top surface triangles
        top_start = v_idx + 4
        for sy in range(sub_y):
            for sx in range(sub_x):
                i0 = top_start + sy * (sub_x + 1) + sx
                i1 = i0 + 1
                i2 = i0 + (sub_x + 1)
                i3 = i2 + 1
                self.faces.append((i0, i1, i3))
                self.faces.append((i0, i3, i2))

        # Side walls
        bl0, bl1, bl2, bl3 = v_idx, v_idx + 1, v_idx + 2, v_idx + 3
        tl0 = top_start
        tl1 = top_start + sub_x
        tl2 = top_start + (sub_y + 1) * (sub_x + 1) - 1
        tl3 = top_start + sub_y * (sub_x + 1)

        # South, East, North, West sides
        sides = [(bl0, bl1, tl1, tl0), (bl1, bl2, tl2, tl1), (bl2, bl3, tl3, tl2), (bl3, bl0, tl0, tl3)]
        for a, b, c, d in sides:
            self.faces.append((a, b, c))
            self.faces.append((a, c, d))

    def save_obj(self, filename):
        """Exports the generated geometry as an ASCII Wavefront OBJ file."""
        with open(filename, 'w') as f:
            f.write("# Generative Typography 3D Mesh\n")
            for v in self.vertices:
                f.write(f"v {v[0]:.4f} {v[1]:.4f} {v[2]:.4f}\n")
            for face in self.faces:
                f.write(f"f {' '.join(str(i) for i in face)}\n")

def generate_3d_typography(text, output_file="typography_mesh.obj", max_line_width=30):
    """Converts prose text into a 3D generative sculptural mesh plaque."""
    words = text.split()
    sentiments = analyze_sentiment(text)
    
    mesh = MeshBuilder()
    
    # Layout state
    cursor_x = 0.0
    cursor_y = 0.0
    char_spacing = 6.0
    line_spacing = 10.0
    pixel_size = 0.8
    
    # Base slab dimensions calculation
    max_cols = max_line_width * char_spacing
    
    word_idx = 0
    current_line_length = 0
    
    # Generate letter geometries
    for word in words:
        # Wrap line if necessary
        if current_line_length + len(word) > max_line_width:
            cursor_x = 0.0
            cursor_y -= line_spacing
            current_line_length = 0

        sentiment = sentiments[min(word_idx, len(sentiments) - 1)]
        syllables = count_syllables(word)
        cadence = syllables / float(max(1, len(word)))

        # Procedural mapping:
        # Height: Sentiment mapped to vertical relief extrusion (+1 positive = tall/elevated, -1 negative = low/sunken)
        base_height = 2.0 + (sentiment + 1.0) * 2.5 
        # Texture roughness and frequency modulated by cadence
        texture_amplitude = 0.2 + (1.0 - sentiment) * 0.3
        texture_freq = 0.4 + cadence * 0.8

        for char in word:
            glyph = FONT_5X7.get(char.upper(), FONT_5X7['?'])
            
            for r_idx, row in enumerate(glyph):
                for c_idx, bit in enumerate(row):
                    if bit == '1':
                        px0 = cursor_x + c_idx * pixel_size
                        py0 = cursor_y - r_idx * pixel_size
                        px1 = px0 + pixel_size
                        py1 = py0 - pixel_size
                        
                        # Apply texture closure using local procedural noise
                        def tex_fn(x, y, sa=texture_amplitude, sf=texture_freq, s_val=sentiment):
                            return procedural_noise(x, y, s_val * 3.1415, sf) * sa

                        mesh.add_cube(
                            px0, py1, 1.0, 
                            px1, py0, 1.0 + base_height, 
                            top_texture_fn=tex_fn
                        )

            cursor_x += char_spacing
            current_line_length += 1

        # Space between words
        cursor_x += char_spacing * 0.5
        current_line_length += 0.5
        word_idx += 1

    # Generate supporting substrate base slab for printability
    min_x = -2.0
    max_x = max_line_width * char_spacing + 2.0
    min_y = cursor_y - 8.0
    max_y = 2.0
    mesh.add_cube(min_x, min_y, 0.0, max_x, max_y, 1.0)

    mesh.save_obj(output_file)
    print(f"3D Typography mesh successfully saved to: {output_file}")

if __name__ == "__main__":
    sample_prose = (
        "In the quiet radiance of dawn, hope rises bright and calm. "
        "Yet bitter shadows fall through the dark heavy void of decay, "
        "weaving triumph and sorrow into pure timeless harmony."
    )
    
    input_text = sample_prose
    if len(sys.argv) > 1 and os.path.exists(sys.argv[1]):
        with open(sys.argv[1], 'r', encoding='utf-8') as f:
            input_text = f.read()

    output_path = "generative_prose.obj"
    generate_3d_typography(input_text, output_file=output_path)