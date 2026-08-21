import math
import os
import sys
import time
import shutil
import select
from collections import Counter

# Optional dependencies for audio capture: sounddevice + numpy
try:
    import sounddevice as sd
    import numpy as np
    AUDIO_AVAILABLE = True
except ImportError:
    AUDIO_AVAILABLE = False

# Fallback fake audio stream generator if audio packages are missing
def fake_audio_level():
    t = time.time()
    # Combine sine waves to simulate rhythmic sound variation
    return (math.sin(t * 3.0) * 0.4 + math.sin(t * 7.5) * 0.3 + 0.3) ** 2

class AudioAnalyzer:
    def __init__(self, sample_rate=44100, block_size=1024):
        self.level = 0.1
        self.available = AUDIO_AVAILABLE
        if self.available:
            try:
                self.stream = sd.InputStream(
                    channels=1,
                    samplerate=sample_rate,
                    blocksize=block_size,
                    callback=self._audio_callback
                )
                self.stream.start()
            except Exception:
                self.available = False

    def _audio_callback(self, indata, frames, time_info, status):
        # Calculate RMS volume level normalized roughly to [0, 1]
        rms = np.sqrt(np.mean(indata**2))
        self.level = float(np.clip(rms * 10.0, 0.0, 1.0))

    def get_level(self):
        if self.available:
            return self.level
        return fake_audio_level()

def prepare_char_palette(filename):
    """Parses text file frequencies and creates a structured character palette."""
    default_palette = list(" .:-=+*#%@")
    if not filename or not os.path.exists(filename):
        return default_palette

    try:
        with open(filename, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
        counts = Counter([c for c in content if not c.isspace()])
        if not counts:
            return default_palette
        # Sort characters from least frequent to most frequent
        sorted_chars = [pair[0] for pair in counts.most_common()]
        sorted_chars.reverse()
        return sorted_chars
    except Exception:
        return default_palette

def render_kaleidoscope(width, height, angle_offset, zoom, audio_boost, palette):
    """Renders a symmetric rotational ASCII mandala pattern."""
    center_x, center_y = width / 2.0, height / 2.0
    aspect_correction = 0.5  # Adjust for non-square terminal characters
    num_folds = 8
    fold_angle = (2 * math.pi) / num_folds
    palette_len = len(palette)
    
    buffer = []
    
    for y in range(height):
        row = []
        dy = (y - center_y) * aspect_correction
        for x in range(width):
            dx = x - center_x
            
            # Convert to polar coordinates
            r = math.hypot(dx, dy)
            theta = math.atan2(dy, dx) + angle_offset
            
            # Apply kaleidoscope rotational symmetry folding
            theta = theta % fold_angle
            if theta > fold_angle / 2.0:
                theta = fold_angle - theta
                
            # Polar projection warp mapped to dynamic geometric pattern
            fx = r * math.cos(theta) * (0.05 / zoom)
            fy = r * math.sin(theta) * (0.05 / zoom)
            
            # Interference pattern driven by audio amplitude
            value = math.sin(fx + audio_boost * 3.0) * math.cos(fy + audio_boost * 3.0) + \
                    math.cos(math.hypot(fx, fy) * 2.0 - angle_offset * 2.0)
            
            # Map normalized value to character palette index
            norm_val = (value + 2.0) / 4.0  # Normalize to [0, 1]
            norm_val = max(0.0, min(1.0, norm_val * (0.5 + audio_boost * 0.8)))
            
            idx = int(norm_val * (palette_len - 1))
            row.append(palette[idx])
        buffer.append("".join(row))
        
    return "\033[H" + "\n".join(buffer)

def main():
    target_file = sys.argv[1] if len(sys.argv) > 1 else __file__
    palette = prepare_char_palette(target_file)
    audio = AudioAnalyzer()

    # Hide cursor and clear terminal screen
    sys.stdout.write("\033[?25l\033[2J")
    sys.stdout.flush()

    angle = 0.0
    try:
        while True:
            # Dynamically fetch current terminal size
            term_size = shutil.get_terminal_size((80, 24))
            w, h = term_size.columns, term_size.lines - 1
            
            audio_level = audio.get_level()
            
            # Rotation speed and scale expand reactively with audio volume
            angle += 0.03 + (audio_level * 0.08)
            zoom = 1.0 + (audio_level * 0.5)
            
            frame = render_kaleidoscope(w, h, angle, zoom, audio_level, palette)
            sys.stdout.write(frame)
            sys.stdout.flush()
            
            time.sleep(0.03)
            
    except KeyboardInterrupt:
        pass
    finally:
        # Restore terminal cursor state
        sys.stdout.write("\033[?25h\033[2J\033[H")
        sys.stdout.flush()

if __name__ == "__main__":
    main()