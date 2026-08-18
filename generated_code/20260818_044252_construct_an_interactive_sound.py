import ast
import os
import random
import math
import wave
import struct
import tempfile
import winsound  # Standard library on Windows for simple audio playback

def analyze_ast(file_path):
    """
    Parses a Python file into an AST to extract metrics:
    - cyclomatic_complexity: number of control flow constructs
    - allocation_weight: frequency of object creations/allocations
    - node_count: total syntax nodes
    """
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            code = f.read()
        tree = ast.parse(code)
    except Exception:
        return {"complexity": 1, "allocations": 1, "nodes": 10}

    complexity = 1
    allocations = 0
    node_count = 0

    for node in ast.walk(tree):
        node_count += 1
        # Control flow increases complexity (modulates scale and rhythm)
        if isinstance(node, (ast.If, ast.For, ast.While, ast.With, ast.Try, ast.ExceptHandler)):
            complexity += 1
        # Object instantiation / collection literals simulate memory allocation
        elif isinstance(node, (ast.Call, ast.List, ast.Dict, ast.Set, ast.ListComp, ast.DictComp)):
            allocations += 1

    return {
        "complexity": complexity,
        "allocations": allocations,
        "nodes": node_count
    }

def generate_tone(freq, duration, sample_rate=22050, amplitude=0.3):
    """Generates a sine wave with a smooth fade-in and fade-out envelope."""
    num_samples = int(sample_rate * duration)
    samples = []
    for i in range(num_samples):
        t = float(i) / sample_rate
        # Basic envelope to smooth out clicking sounds
        envelope = math.sin(math.pi * i / num_samples)
        sample = amplitude * envelope * math.sin(2 * math.pi * freq * t)
        samples.append(sample)
    return samples

def synthesize_polyphonic_ambient(metrics, duration=6.0, sample_rate=22050):
    """
    Uses code metrics to construct a polyphonic ambient soundscape.
    - Scale selection & harmony derived from cyclomatic complexity.
    - Chord density & texture derived from memory allocations.
    """
    # Pentatonic base frequencies (Hz) across 3 octaves
    base_pentatonic = [130.81, 146.83, 164.81, 196.00, 220.00,  # C3 - A3
                       261.63, 293.66, 329.63, 392.00, 440.00,  # C4 - A4
                       523.25, 587.33, 659.25, 783.99, 880.00]  # C5 - A5

    complexity = metrics["complexity"]
    allocations = metrics["allocations"]
    
    # Map complexity to base pitch shift
    root_idx = complexity % 5
    scale = base_pentatonic[root_idx:]

    total_samples = int(sample_rate * duration)
    mixed_buffer = [0.0] * total_samples

    # Create polyphonic layers based on allocation density
    num_voices = min(max(2, allocations // 3), 6)
    
    for v in range(num_voices):
        voice_freq = scale[(v * 2 + complexity) % len(scale)]
        # Add subtle detune for ambient warmth
        voice_freq *= (1.0 + (random.random() - 0.5) * 0.015)
        
        # Layer pulse parameters
        note_duration = random.uniform(2.0, duration)
        start_time = random.uniform(0, max(0.1, duration - note_duration))
        start_sample = int(start_time * sample_rate)
        
        voice_samples = generate_tone(voice_freq, note_duration, sample_rate, amplitude=0.15)
        
        for i, s in enumerate(voice_samples):
            if start_sample + i < total_samples:
                mixed_buffer[start_sample + i] += s

    # Normalize audio buffer to avoid clipping
    max_val = max(abs(s) for s in mixed_buffer) if mixed_buffer else 1.0
    if max_val > 1.0:
        mixed_buffer = [s / max_val for s in mixed_buffer]

    return mixed_buffer, sample_rate

def play_audio(samples, sample_rate):
    """Converts raw float samples to 16-bit PCM WAV and plays it natively."""
    temp_wav = os.path.join(tempfile.gettempdir(), "ast_soundscape.wav")
    
    with wave.open(temp_wav, "w") as wave_file:
        wave_file.setnchannels(1)
        wave_file.setsampwidth(2)
        wave_file.setframerate(sample_rate)
        
        # Pack float samples into signed 16-bit integers
        packed_data = bytearray()
        for sample in samples:
            val = int(sample * 32767)
            val = max(-32768, min(32767, val))
            packed_data.extend(struct.pack("<h", val))
            
        wave_file.writeframes(packed_data)

    print("Playing generated ambient soundscape...")
    winsound.PlaySound(temp_wav, winsound.SND_FILENAME)

def run_soundscape_generator():
    """Interactively prompts for a file/directory to parse and generate audio."""
    path = input("Enter path to a Python file or directory to parse [default: current dir]: ").strip()
    if not path:
        path = "."

    targets = []
    if os.path.isfile(path) and path.endswith(".py"):
        targets.append(path)
    elif os.path.isdir(path):
        for root, _, files in os.walk(path):
            for f in files:
                if f.endswith(".py"):
                    targets.append(os.path.join(root, f))

    if not targets:
        print("No Python files found.")
        return

    print(f"Parsing AST for {len(targets)} Python file(s)...")
    aggregated_metrics = {"complexity": 0, "allocations": 0, "nodes": 0}
    
    for file_path in targets:
        m = analyze_ast(file_path)
        aggregated_metrics["complexity"] += m["complexity"]
        aggregated_metrics["allocations"] += m["allocations"]
        aggregated_metrics["nodes"] += m["nodes"]

    print("\n--- Codebase AST Metrics ---")
    print(f"Total Cyclomatic Complexity : {aggregated_metrics['complexity']}")
    print(f"Memory Allocations/Calls    : {aggregated_metrics['allocations']}")
    print(f"Total AST Nodes             : {aggregated_metrics['nodes']}")
    print("----------------------------\n")

    print("Generating polyphonic ambient audio from AST profile...")
    audio_buffer, rate = synthesize_polyphonic_ambient(aggregated_metrics, duration=7.0)
    play_audio(audio_buffer, rate)

if __name__ == "__main__":
    run_soundscape_generator()