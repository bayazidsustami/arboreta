import math
import random
import time
import os
import sys

# Define base star visual representations based on POS categories
POS_MARKERS = {
    'NOUN': ['★', '✦', '✶'],
    'VERB': ['⚡', '✵', '✷'],
    'ADJ':  ['✨', '✧', '☸'],
    'ADV':  ['·', '•', '◦'],
    'OTHER':['.', '°', '+']
}

# Lexicon for lightweight, rule-based sentiment detection
POSITIVE_WORDS = {
    'good', 'great', 'love', 'like', 'happy', 'bright', 'joy', 'light', 'hope',
    'peace', 'sun', 'star', 'beauty', 'shine', 'radiant', 'life', 'sweet', 'fly'
}
NEGATIVE_WORDS = {
    'bad', 'dark', 'gloom', 'hate', 'sad', 'pain', 'cold', 'fear', 'death',
    'void', 'loss', 'shadow', 'grim', 'storm', 'night', 'fall', 'ruin', 'decay'
}

# Simple heuristic POS tagger
def tag_pos(word):
    w = word.lower()
    if w.endswith('ing') or w.endswith('ed') or w in {'is', 'are', 'was', 'were', 'run', 'fly', 'glow'}:
        return 'VERB'
    elif w.endswith('ly'):
        return 'ADV'
    elif w.endswith('ful') or w.endswith('ous') or w.endswith('ive') or w.endswith('able'):
        return 'ADJ'
    elif len(w) > 3 and not w.endswith('s'):
        return 'NOUN'
    return 'OTHER'

# Simple heuristic sentiment calculator returning (-1.0 to 1.0)
def analyze_sentiment(word):
    w = word.lower()
    if w in POSITIVE_WORDS:
        return 0.8
    elif w in NEGATIVE_WORDS:
        return -0.8
    elif any(pos in w for pos in ['good', 'joy', 'light', 'sun', 'love']):
        return 0.5
    elif any(neg in w for neg in ['dark', 'grim', 'fear', 'cold', 'sad']):
        return -0.5
    return 0.0

class Star:
    def __init__(self, text, distance, angle):
        self.text = text
        self.pos = tag_pos(text)
        self.sentiment = analyze_sentiment(text)
        
        # Base visual symbol based on POS
        markers = POS_MARKERS.get(self.pos, POS_MARKERS['OTHER'])
        self.marker = markers[len(text) % len(markers)]
        
        # Orbital properties
        self.distance = distance
        self.angle = angle
        
        # Speed: Higher positive sentiment or longer words orbit faster/differently
        base_speed = 0.03 + (0.02 * (1.0 / max(distance, 1)))
        sentiment_factor = 1.0 + (self.sentiment * 0.5)
        self.orbital_speed = base_speed * sentiment_factor
        
        # Pulsing brightness/size parameters
        self.phase = random.uniform(0, math.pi * 2)

    def update(self):
        self.angle += self.orbital_speed
        self.phase += 0.1

    def get_symbol(self):
        # Pulse brightness based on sentiment and sine wave
        pulse = math.sin(self.phase)
        if self.sentiment > 0.3 and pulse > 0:
            return f"\033[1;33m{self.marker}\033[0m" # Bright Yellow/Gold
        elif self.sentiment < -0.3:
            return f"\033[1;35m{self.marker}\033[0m" # Magenta/Dark Purple
        elif self.pos == 'NOUN':
            return f"\033[1;36m{self.marker}\033[0m" # Cyan
        elif self.pos == 'VERB':
            return f"\033[1;31m{self.marker}\033[0m" # Red/Orange
        else:
            return f"\033[0;37m{self.marker}\033[0m" # Dim White

class ConstellationMap:
    def __init__(self, text_content, width=80, height=35):
        self.width = width
        self.height = height
        self.cx = width // 2
        self.cy = height // 2
        self.stars = []
        
        words = [w.strip(".,!?;:\"'()[]") for w in text_content.split() if w.strip()]
        
        # Distribute words in orbits around central black hole
        for i, word in enumerate(words):
            distance = 3 + (i % 12) * 2 + random.uniform(-0.5, 0.5)
            angle = (i * (137.5 * math.pi / 180)) # Golden ratio distribution
            self.stars.append(Star(word, distance, angle))

    def render_frame(self):
        # Create empty screen buffer
        buffer = [[' ' for _ in range(self.width)] for _ in range(self.height)]
        
        # Draw Central Semantic Black Hole
        bh_symbol = "\033[1;30;40m🕳 \033[0m"
        if 0 <= self.cy < self.height and 0 <= self.cx < self.width:
            buffer[self.cy][self.cx] = bh_symbol

        # Update and render stars
        for star in self.stars:
            star.update()
            
            # Apply aspect ratio adjustment for terminal characters (~2:1 tall-to-wide ratio)
            x = int(self.cx + star.distance * math.cos(star.angle) * 2.0)
            y = int(self.cy + star.distance * math.sin(star.angle))
            
            if 0 <= y < self.height and 0 <= x < self.width:
                # Render label occasionally or just the star marker
                if int(star.phase) % 6 < 2 and x + len(star.text) < self.width:
                    # Render star with word label
                    for idx, char in enumerate(star.text):
                        if 0 <= x + idx < self.width:
                            buffer[y][x + idx] = f"\033[36m{char}\033[0m"
                else:
                    buffer[y][x] = star.get_symbol()
                    
        # Construct frame string
        output = ["\033[H"] # Move cursor to top left
        for row in buffer:
            output.append("".join(row))
        return "\n".join(output)

def main():
    # Provide sample input text if no file path supplied or file missing
    sample_text = """
    In the vast dark void of space, bright radiant stars shine with eternal hope and love.
    Shadows fall and cold fear creeps through the quiet night, yet beauty glows gracefully.
    Galaxies collide, releasing cosmic power, driving the endless dance of life and decay.
    """
    
    content = sample_text
    if len(sys.argv) > 1 and os.path.exists(sys.argv[1]):
        with open(sys.argv[1], 'r', encoding='utf-8') as f:
            content = f.read()

    # Clear terminal window
    os.system('cls' if os.name == 'nt' else 'clear')
    
    cmap = ConstellationMap(content)
    
    try:
        while True:
            print(cmap.render_frame())
            time.sleep(0.08)
    except KeyboardInterrupt:
        os.system('cls' if os.name == 'nt' else 'clear')
        print("Constellation map collapsed into the black hole.")

if __name__ == "__main__":
    main()