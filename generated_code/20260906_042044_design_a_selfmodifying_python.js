const fs = require('fs');
const http = require('http');

/**
 * Self-Modifying Python Stack Fractal & Microtonal Audio Visualizer Generator
 * Generates and runs a Python script that continuously tracks its call stack,
 * grows a dynamic ASCII fractal based on execution depth, translates heap address
 * dynamics into multi-phonic microtonal synth frequencies, and dynamically rewrites its source code.
 */

const pythonScriptContent = `
import sys
import os
import math
import time
import random
import gc
import wave
import struct
import threading
import subprocess

# Self-modification count tracker
REWRITE_COUNT = 0

def generate_microtonal_audio(heap_addresses, filename="synth.wav"):
    """Translates heap memory addresses into a multi-phonic microtonal composition."""
    sample_rate = 22050
    duration = 0.4
    num_samples = int(sample_rate * duration)
    
    # Base frequency scale (Microtonal 19-TET tuning)
    base_freq = 110.0
    scale_steps = 19
    
    # Extract frequencies from heap address dynamics
    frequencies = []
    for addr in heap_addresses[:4]:  # Polyphony up to 4 voices
        step = (addr // 64) % scale_steps
        octave = (addr // 1024) % 3
        freq = base_freq * (2 ** (octave + step / scale_steps))
        frequencies.append(freq)
    
    if not frequencies:
        frequencies = [220.0]

    audio_data = []
    for i in range(num_samples):
        t = i / sample_rate
        sample_val = 0
        for f in frequencies:
            # Multi-phonic microtonal additive synthesis with decay envelope
            envelope = math.exp(-3.0 * (t / duration))
            sample_val += 0.25 * math.sin(2 * math.pi * f * t) * envelope
        
        # Clamp & scale to 16-bit PCM integer
        sample_val = max(-1.0, min(1.0, sample_val))
        int_val = int(sample_val * 32767)
        audio_data.append(struct.pack('<h', int_val))
        
    with wave.open(filename, 'wb') as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(sample_rate)
        wav_file.writeframes(b''.join(audio_data))

def play_audio_async():
    """Attempts asynchronous playback across cross-platform audio tools."""
    for cmd in [["aplay", "-q", "synth.wav"], ["afplay", "synth.wav"], ["powershell", "-c", "(New-Object Media.SoundPlayer 'synth.wav').PlaySync()"]]:
        try:
            subprocess.Popen(cmd, stderr=subprocess.DEVNULL, stdout=subprocess.DEVNULL)
            break
        except Exception:
            continue

def render_ascii_fractal(depth, max_depth, heap_seed):
    """Renders a reactive ASCII fractal tree based on stack depth and memory dynamics."""
    width = 60
    height = 16
    grid = [[' ' for _ in range(width)] for _ in range(height)]
    
    def draw_branch(x, y, length, angle, current_depth):
        if current_depth <= 0 or length < 1:
            return
        
        x2 = x + length * math.cos(angle)
        y2 = y - length * math.sin(angle)
        
        # Bresenham-like line rendering for ASCII canvas
        steps = int(max(abs(x2 - x), abs(y2 - y))) + 1
        for i in range(steps):
            px = int(x + (x2 - x) * i / max(1, steps))
            py = int(y + (y2 - y) * i / max(1, steps))
            if 0 <= px < width and 0 <= py < height:
                chars = "#*/\\~+-."
                grid[py][px] = chars[(current_depth + heap_seed) % len(chars)]
                
        # Branch out symmetrically with angle modulation from heap state
        spread = 0.4 + (heap_seed % 10) * 0.03
        draw_branch(x2, y2, length * 0.7, angle - spread, current_depth - 1)
        draw_branch(x2, y2, length * 0.7, angle + spread, current_depth - 1)

    draw_branch(width // 2, height - 1, height * 0.45, math.pi / 2, min(depth, 6))

    sys.stdout.write("\\033[H\\033[J")  # Clear terminal screen
    print(f"=== CALL STACK ASCII FRACTAL | DEPTH: {depth} | MUTATION: {REWRITE_COUNT} ===")
    for row in grid:
        print("".join(row))
    print("=" * 60)

def mutate_self():
    """Modifies its own source code on-the-fly by altering constants and mutating structure."""
    global REWRITE_COUNT
    script_path = __file__
    try:
        with open(script_path, 'r') as f:
            code = f.read()
        
        REWRITE_COUNT += 1
        # Rewrite mutation tracker constant
        new_code = code.replace(f"REWRITE_COUNT = {REWRITE_COUNT - 1}", f"REWRITE_COUNT = {REWRITE_COUNT}")
        
        with open(script_path, 'w') as f:
            f.write(new_code)
    except Exception:
        pass

def dynamic_stack_recurse(depth, target_depth):
    """Recursive call stack generator driving execution mechanics."""
    frame = sys._getframe()
    stack_depth = 0
    curr = frame
    while curr:
        stack_depth += 1
        curr = curr.f_back
        
    # Gather dynamic heap state
    objects = gc.get_objects()
    heap_addrs = [id(obj) for obj in objects[::max(1, len(objects)//8)]]
    heap_seed = sum(heap_addrs) % 97

    # Render graphics and synthesize audio
    render_ascii_fractal(stack_depth, target_depth, heap_seed)
    generate_microtonal_audio(heap_addrs)
    play_audio_async()
    time.sleep(0.15)

    mutate_self()

    if depth < target_depth:
        dynamic_stack_recurse(depth + 1, target_depth)

def main():
    target_depth = random.randint(5, 10)
    dynamic_stack_recurse(1, target_depth)

if __name__ == '__main__':
    main()
`;

// Write the dynamic Python script to disk
const pythonFileName = 'self_modifying_fractal.py';
fs.writeFileSync(pythonFileName, pythonScriptContent);

console.log(`Generated self-modifying Python engine: ${pythonFileName}`);
console.log('Executing Python engine...\n');

// Execute generated script directly using Python child process
const { spawn } = require('child_process');
const pyProcess = spawn('python3', [pythonFileName], { stdio: 'inherit' });

pyProcess.on('error', () => {
    // Fallback to 'python' command if 'python3' is not explicitly aliased
    spawn('python', [pythonFileName], { stdio: 'inherit' });
});