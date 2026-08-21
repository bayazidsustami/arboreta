import math
import re
import sys

# Standard phonetic vowel patterns (used to approximate phonetic cadence and syllable flow)
VOWEL_PATTERN = re.compile(r'[aeiouy]+', re.IGNORECASE)

# Lexicon for lightweight sentiment analysis
POSITIVE_WORDS = {'good', 'great', 'bright', 'happy', 'joy', 'love', 'light', 'beautiful', 'calm', 'soft', 'hope', 'peace', 'glow', 'bloom', 'life'}
NEGATIVE_WORDS = {'bad', 'dark', 'gloom', 'sad', 'hate', 'cold', 'sharp', 'pain', 'fear', 'decay', 'death', 'storm', 'rough', 'harsh'}

# Extended 24-bit ANSI color formatting for terminal display
def ansi_rgb(r, g, b, text):
    return f"\033[38;2;{r};{g};{b}m{text}\033[0m"

class AsciiCanvas:
    """A virtual 2D canvas that accumulates drawn characters and RGB colors."""
    def __init__(self, width, height):
        self.width = width
        self.height = height
        self.grid = [[' ' for _ in range(width)] for _ in range(height)]
        self.color_grid = [[(0, 0, 0) for _ in range(width)] for _ in range(height)]

    def draw(self, x, y, char, r, g, b):
        ix, iy = int(round(x)), int(round(y))
        if 0 <= ix < self.width and 0 <= iy < self.height:
            self.grid[iy][ix] = char
            self.color_grid[iy][ix] = (int(r), int(g), int(b))

    def render(self):
        lines = []
        for y in range(self.height):
            line = []
            for x in range(self.width):
                char = self.grid[y][x]
                if char != ' ':
                    r, g, b = self.color_grid[y][x]
                    line.append(ansi_rgb(r, g, b, char))
                else:
                    line.append(' ')
            lines.append("".join(line))
        return "\n".join(lines)

def analyze_sentence(sentence):
    """Calculates phonetic cadence (syllable density/rhythm) and sentiment score (-1.0 to +1.0)."""
    words = re.findall(r'\b\w+\b', sentence.lower())
    if not words:
        return 1.0, 0.0

    # Phonetic Cadence: average syllables per word + cadence variations
    syllables = [max(1, len(VOWEL_PATTERN.findall(w))) for w in words]
    cadence = sum(syllables) / len(syllables)

    # Sentiment Score
    pos = sum(1 for w in words if w in POSITIVE_WORDS)
    neg = sum(1 for w in words if w in NEGATIVE_WORDS)
    total = pos + neg
    sentiment = (pos - neg) / total if total > 0 else 0.0

    return cadence, sentiment

def get_sentiment_color(sentiment, depth_ratio):
    """Generates RGB gradient shifting from warm/green positive tones to cold/red negative tones."""
    # Base color interpolation based on sentiment
    if sentiment >= 0:
        # Positive: Lush green to golden light
        r = int(30 + 180 * sentiment * depth_ratio)
        g = int(180 + 75 * (1 - depth_ratio))
        b = int(50 + 100 * (1 - sentiment))
    else:
        # Negative/Melancholic: Crimson red to deep purple
        s_abs = abs(sentiment)
        r = int(180 + 75 * s_abs)
        g = int(40 * (1 - s_abs))
        b = int(100 + 120 * depth_ratio)

    return max(0, min(255, r)), max(0, min(255, g)), max(0, min(255, b))

def parse_and_grow(canvas, sentence_data, x, y, angle, length, depth, max_depth):
    """Recursively draws the fractal tree branching according to cadence and sentiment."""
    if depth > max_depth or length < 1.0:
        return

    cadence, sentiment = sentence_data[depth % len(sentence_data)]

    # Draw current branch step by step
    rad = math.radians(angle)
    dx = math.sin(rad)
    dy = -math.cos(rad)  # Upward growth

    r, g, b = get_sentiment_color(sentiment, depth / max_depth)
    
    # Choose branch character based on direction
    char = '|' if abs(dx) < 0.3 else ('/' if dx > 0 else '\\')
    if depth == max_depth:
        char = '*'  # Leaf node character

    curr_x, curr_y = x, y
    for step in range(int(round(length))):
        canvas.draw(curr_x, curr_y, char, r, g, b)
        curr_x += dx
        curr_y += dy

    # Phonetic Cadence governs branching angle and split count
    base_spread = 15 + (cadence * 12)  # Higher cadence = wider branching
    spread_modifier = sentiment * 10    # Positive sentiment expands angle

    left_angle = angle - (base_spread + spread_modifier)
    right_angle = angle + (base_spread - spread_modifier)
    next_length = length * 0.72

    # Recursive fractal call for child branches/leaves
    parse_and_grow(canvas, sentence_data, curr_x, curr_y, left_angle, next_length, depth + 1, max_depth)
    parse_and_grow(canvas, sentence_data, curr_x, curr_y, right_angle, next_length, depth + 1, max_depth)

def compile_document_to_tree(text_doc, canvas_width=100, canvas_height=42):
    """Main esoteric parser pipeline."""
    # Split document into sentences
    sentences = [s.strip() for s in re.split(r'[.!?]+', text_doc) if s.strip()]
    if not sentences:
        sentences = ["A quiet bright hope blooms in the light."]

    # Analyze each sentence for phonetic cadence and sentiment
    sentence_data = [analyze_sentence(s) for s in sentences]

    canvas = AsciiCanvas(canvas_width, canvas_height)
    start_x = canvas_width // 2
    start_y = canvas_height - 2
    
    # Fractal growth depth bounded by document complexity
    max_depth = min(7, max(4, len(sentences) + 2))
    initial_length = 8.5

    # Grow the ASCII fractal tree
    parse_and_grow(canvas, sentence_data, start_x, start_y, angle=0, length=initial_length, depth=0, max_depth=max_depth)
    
    return canvas.render()

if __name__ == "__main__":
    sample_document = """
    A bright light blooms soft peace and hope into the calm day.
    Yet a dark cold storm brings fear and sharp pain.
    Life returns with brilliant joy and gentle grace.
    """
    
    if len(sys.argv) > 1:
        with open(sys.argv[1], 'r') as f:
            sample_document = f.read()

    print(compile_document_to_tree(sample_document))