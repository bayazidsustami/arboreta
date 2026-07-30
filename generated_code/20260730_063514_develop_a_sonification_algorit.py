import random
import time
import math
import sys
try:
    import pygame
    import numpy as np
except ImportError:
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "pygame", "numpy"])
    import pygame
    import numpy as np

# Audio Configuration
SAMPLE_RATE = 44100
BUFFER_SIZE = 1024
pygame.mixer.pre_init(SAMPLE_RATE, -16, 2, BUFFER_SIZE)
pygame.init()

# Simulation Parameters
RAM_SIZE = 64              # Number of memory blocks to map
PENTATONIC_SCALE = [261.63, 293.66, 329.63, 392.00, 440.00, 523.25, 587.33, 659.25]  # C Major Pentatonic

# Memory Pool State (0: Free, 1: Allocated, 2: Fragmented/Orphaned)
memory_pool = [0] * RAM_SIZE

def generate_sine_wave(freq, duration=0.1, amplitude=0.3):
    """Generates a stereo sine wave audio buffer for polyphonic pitch playback."""
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration), False)
    wave = amplitude * np.sin(2 * np.pi * freq * t)
    # Envelope to avoid clicks
    envelope = np.ones_like(wave)
    fade_len = int(len(wave) * 0.1)
    if fade_len > 0:
        envelope[:fade_len] = np.linspace(0, 1, fade_len)
        envelope[-fade_len:] = np.linspace(1, 0, fade_len)
    wave = wave * envelope
    stereo_wave = np.column_stack((wave, wave))
    return pygame.sndarray.make_sound((stereo_wave * 32767).astype(np.int16))

def generate_perc_hit(duration=0.15, noise_ratio=0.8):
    """Generates a percussive white-noise burst simulating Garbage Collection."""
    sample_count = int(SAMPLE_RATE * duration)
    noise = np.random.uniform(-1, 1, sample_count)
    env = np.exp(-np.linspace(0, 10, sample_count))  # Sharp exponential decay
    perc = noise * env * 0.5
    stereo_perc = np.column_stack((perc, perc))
    return pygame.sndarray.make_sound((stereo_perc * 32767).astype(np.int16))

def simulate_memory_churn():
    """Simulates dynamic memory allocation, fragmentation, and triggers GC."""
    gc_triggered = False
    
    # Random allocation/deallocation
    action = random.choice(["alloc", "free", "fragment", "gc_check"])
    
    if action == "alloc":
        size = random.randint(1, 4)
        for i in range(len(memory_pool) - size):
            if all(m == 0 for m in memory_pool[i:i+size]):
                for j in range(i, i+size):
                    memory_pool[j] = 1
                break
    elif action == "free":
        target = random.randint(0, len(memory_pool) - 1)
        if memory_pool[target] == 1:
            memory_pool[target] = 0
    elif action == "fragment":
        # Introduce isolated single-block gaps (fragmentation)
        idx = random.randint(0, len(memory_pool) - 1)
        memory_pool[idx] = 2

    # If fragmentation exceeds threshold, trigger Garbage Collection (GC)
    frag_count = memory_pool.count(2) + sum(
        1 for i in range(1, len(memory_pool)-1) 
        if memory_pool[i] == 0 and memory_pool[i-1] == 1 and memory_pool[i+1] == 1
    )
    
    if frag_count > 8 or random.random() < 0.05:
        # Perform Garbage Collection: compact memory and clear fragments
        for i in range(len(memory_pool)):
            if memory_pool[i] == 2:
                memory_pool[i] = 0
        memory_pool.sort(reverse=True)  # Compact occupied blocks
        gc_triggered = True
        
    return gc_triggered

def sonify_fragmentation_map(gc_hit):
    """Translates memory map state to continuous polyphonic harmony and GC percussion."""
    print("\n--- Live Memory Map Sonification ---")
    map_str = "".join(["█" if m == 1 else "░" if m == 0 else "▓" for m in memory_pool])
    print(f"Map: [{map_str}]")
    
    if gc_hit:
        print(">>> GARBAGE COLLECTION CYCLE (Percussion Hit) <<<")
        perc_sound = generate_perc_hit()
        perc_sound.play()
    
    # Calculate polyphonic voices based on fragmentation density across memory regions
    chunk_size = len(memory_pool) // len(PENTATONIC_SCALE)
    active_voices = []

    for i in range(len(PENTATONIC_SCALE)):
        chunk = memory_pool[i * chunk_size : (i + 1) * chunk_size]
        occupancy = sum(1 for block in chunk if block != 0) / float(chunk_size)
        
        # If chunk is active/fragmented, trigger a note pitch corresponding to the region
        if occupancy > 0.2:
            freq = PENTATONIC_SCALE[i]
            amp = min(0.4, occupancy * 0.3)
            tone = generate_sine_wave(freq, duration=0.2, amplitude=amp)
            tone.play()
            active_voices.append(f"{freq:.1f}Hz")

    print(f"Active Polyphonic Pitch Layer: {', '.join(active_voices) if active_voices else 'Silent'}")

def main():
    print("Starting Memory Fragmentation Sonifier...")
    print("Legend: [█ = Allocated | ▓ = Fragmented | ░ = Free]")
    print("Press Ctrl+C to terminate application.\n")
    
    try:
        while True:
            gc_hit = simulate_memory_churn()
            sonify_fragmentation_map(gc_hit)
            time.sleep(0.25)  # Rhythm tempo step (~240 BPM pulses)
    except KeyboardInterrupt:
        print("\nStopping Audio Engine and Exiting...")
        pygame.quit()

if __name__ == "__main__":
    main()