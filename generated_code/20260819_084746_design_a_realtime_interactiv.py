import sys
import time
import math
import random
import shutil
import struct
import pyaudio
import numpy as np

# Audio capture & FFT configuration
CHUNK = 1024
FORMAT = pyaudio.paInt16
CHANNELS = 1
RATE = 44100

# ANSI Color Definitions for Dynamic Weather & Forest Palette
RESET = "\033[0m"
GREEN = "\033[32m"
BRIGHT_GREEN = "\033[92m"
YELLOW = "\033[33m"
CYAN = "\033[36m"
BRIGHT_CYAN = "\033[96m"
BLUE = "\033[34m"
MAGENTA = "\033[35m"
WHITE = "\033[97m"
DARK_GRAY = "\033[90m"

# Species definitions mapped to spectral harmonic bands (Bass, Mid, Treble)
PLANT_SPECIES = {
    'bass': [
        {"trunk": " || ", "leaf": "#####", "type": "Oak", "color": GREEN},
        {"trunk": " || ", "leaf": "@@@@@", "type": "Redwood", "color": MAGENTA},
        {"trunk": "[||]", "leaf": "&&&&&", "type": "Baobab", "color": YELLOW}
    ],
    'mid': [
        {"trunk": "  |  ", "leaf": " /\\\\ ", "type": "Pine", "color": BRIGHT_GREEN},
        {"trunk": "  |  ", "leaf": " ()() ", "type": "Birch", "color": WHITE},
        {"trunk": "  |  ", "leaf": " {}{} ", "type": "Willow", "color": CYAN}
    ],
    'treble': [
        {"trunk": "  .  ", "leaf": "  *  ", "type": "Fern", "color": BRIGHT_CYAN},
        {"trunk": "  |  ", "leaf": "  ~  ", "type": "Reed", "color": GREEN},
        {"trunk": "  i  ", "leaf": "  o  ", "type": "Sprout", "color": YELLOW}
    ]
}

def analyze_spectrum(data):
    """Processes audio frame with FFT to compute volume, bass, mid, and treble energies."""
    audio_data = np.frombuffer(data, dtype=np.int16).astype(np.float32)
    # Root-Mean-Square volume calculation
    rms = np.sqrt(np.mean(audio_data ** 2)) if len(audio_data) > 0 else 0
    
    # Fast Fourier Transform for frequency spectrum analysis
    fft_data = np.abs(np.fft.rfft(audio_data))
    freqs = np.fft.rfftfreq(len(audio_data), 1.0 / RATE)
    
    # Frequency energy bands
    bass = np.mean(fft_data[(freqs >= 20) & (freqs < 300)]) if len(fft_data) else 0
    mid = np.mean(fft_data[(freqs >= 300) & (freqs < 2000)]) if len(fft_data) else 0
    treble = np.mean(fft_data[(freqs >= 2000) & (freqs < 8000)]) if len(fft_data) else 0
    
    total = bass + mid + treble + 1e-6
    return rms, bass / total, mid / total, treble / total

def generate_forest_canvas(width, height, rms, b_ratio, m_ratio, t_ratio, frame_count):
    """Generates ASCII frame of evolving forest, branching structure, and dynamic weather."""
    canvas = [[" " for _ in range(width)] for _ in range(height)]
    
    # Determine dominant plant species derived from harmonic ratios
    if b_ratio >= m_ratio and b_ratio >= t_ratio:
        species_set = PLANT_SPECIES['bass']
    elif m_ratio >= b_ratio and m_ratio >= t_ratio:
        species_set = PLANT_SPECIES['mid']
    else:
        species_set = PLANT_SPECIES['treble']
    
    # Plant growth dynamics driven by volume/decibels
    num_trees = min(width // 8, max(3, int((rms / 500) * (width // 10))))
    spacing = width // (num_trees + 1)
    
    # Render forest trees
    for i in range(num_trees):
        col = spacing * (i + 1) + int(math.sin(frame_count * 0.1 + i) * 2)
        if 2 <= col < width - 3:
            species = species_set[i % len(species_set)]
            tree_height = min(height - 4, max(3, int(4 + (rms / 800) * 8)))
            
            # Draw trunk
            for h in range(tree_height):
                r = height - 2 - h
                if 0 <= r < height:
                    for char_idx, ch in enumerate(species["trunk"]):
                        if 0 <= col + char_idx < width:
                            canvas[r][col + char_idx] = species["color"] + ch + RESET
                            
            # Render branching foliage influenced by pitch harmonics
            foliage_top = height - 2 - tree_height
            if foliage_top >= 0:
                leaf_str = species["leaf"]
                for char_idx, ch in enumerate(leaf_str):
                    if 0 <= col - 1 + char_idx < width:
                        canvas[foliage_top][col - 1 + char_idx] = species["color"] + ch + RESET

    # Dynamic weather systems (Rain, Wind, Lightning) based on loudness
    wind_shift = int(math.sin(frame_count * 0.2) * 3) if rms > 1500 else 0
    rain_density = int(min(width * height * 0.05, (rms / 2000) * (width * height * 0.03)))
    
    for _ in range(rain_density):
        rx = random.randint(0, width - 1)
        ry = random.randint(0, height - 3)
        drop_char = "/" if wind_shift > 0 else ("\\" if wind_shift < 0 else "|")
        canvas[ry][rx] = BLUE + drop_char + RESET

    # High-intensity volume triggers lightning/storm effects
    if rms > 3000 and random.random() < 0.3:
        lx = random.randint(0, width - 1)
        for ly in range(min(height - 2, 6)):
            canvas[ly][lx] = WHITE + "⚡" + RESET

    # Draw Ground/Soil layer
    ground_y = height - 1
    for x in range(width):
        canvas[ground_y][x] = GREEN + ("~" if (x + frame_count) % 4 < 2 else "^") + RESET
        
    return "\n".join("".join(row) for row in canvas)

def main():
    p = pyaudio.PyAudio()
    try:
        stream = p.open(format=FORMAT,
                        channels=CHANNELS,
                        rate=RATE,
                        input=True,
                        frames_per_buffer=CHUNK)
    except Exception as e:
        print(f"Error initializing microphone stream: {e}")
        sys.exit(1)

    print("\033[2J")  # Clear screen
    frame_count = 0

    try:
        while True:
            try:
                data = stream.read(CHUNK, exception_on_overflow=False)
            except IOError:
                continue

            rms, b_ratio, m_ratio, t_ratio = analyze_spectrum(data)
            width, height = shutil.get_terminal_size((80, 24))
            
            # Generate evolved forest ASCII canopy
            forest_frame = generate_forest_canvas(width, height - 2, rms, b_ratio, m_ratio, t_ratio, frame_count)
            
            # System status bar
            status = f"{DARK_GRAY}[Loudness: {int(rms):4d} dB] [Bass: {b_ratio*100:2.0f}% | Mid: {m_ratio*100:2.0f}% | Treble: {t_ratio*100:2.0f}%]{RESET}"
            
            # Output frame to terminal with cursor reset
            sys.stdout.write("\033[H")
            sys.stdout.write(forest_frame + "\n" + status)
            sys.stdout.flush()
            
            frame_count += 1
            time.sleep(0.03)

    except KeyboardInterrupt:
        pass
    finally:
        stream.stop_stream()
        stream.close()
        p.terminate()
        print("\033[2J\033[HForest visualizer closed successfully.")

if __name__ == "__main__":
    main()

For a detailed walkthrough on setting up live signal processing and audio spectrum visualization scripts in Python, check out [Real Time Audio Spectrum Analyzer Tutorial](https://www.youtube.com/watch?v=HfAlSg9rLFc). This video explains how audio captured from a microphone is decomposed in real-time using FFT to extract fundamental frequencies and harmonics.
http://googleusercontent.com/youtube_content/1