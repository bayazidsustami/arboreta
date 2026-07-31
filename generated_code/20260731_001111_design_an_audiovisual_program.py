import sys
import os
import time
import math
import struct
import threading
import gc
import tracemalloc
import random
import subprocess

# --- Real-Time Memory & Heap Tracker ---
class MemoryTracker:
    def __init__(self, grid_size=32):
        self.grid_size = grid_size
        tracemalloc.start()
        
    def get_heap_map(self):
        snapshot = tracemalloc.take_snapshot()
        stats = snapshot.statistics('traceback')
        grid = [0] * (self.grid_size * self.grid_size)
        total_blocks = sum(stat.count for stat in stats) or 1
        
        for i, stat in enumerate(stats[:self.grid_size * self.grid_size]):
            idx = (hash(stat.traceback) + i) % len(grid)
            grid[idx] = min(9, int((stat.size / (stat.count or 1)) / 1024) + 1)
            
        frag_score = len(stats) / (total_blocks + 1)
        total_bytes = sum(stat.size for stat in stats)
        return grid, frag_score, total_bytes, total_blocks

# --- Audio Synthesizer (4-Part Polyphonic Fugue Engine) ---
class PolyphonicFugueSynth:
    def __init__(self, sample_rate=22050):
        self.sample_rate = sample_rate
        self.scale = [261.63, 293.66, 329.63, 349.23, 392.00, 440.00, 493.88, 523.25, 587.33, 659.25, 698.46, 783.99]
        self.running = True
        self.voices = [0.0, 0.0, 0.0, 0.0]
        self.phases = [0.0, 0.0, 0.0, 0.0]
        
    def set_voices(self, frag_score, total_bytes, total_blocks):
        # Voice 1: Soprano (Subject - derived from total bytes)
        v1_idx = int((total_bytes / 1024) % len(self.scale))
        # Voice 2: Alto (Countersubject - derived from block count)
        v2_idx = int((total_blocks % len(self.scale)))
        # Voice 3: Tenor (Counterpoint - derived from fragmentation)
        v3_idx = int((frag_score * 100) % len(self.scale))
        # Voice 4: Bass (Pedal Note - slow shifting root bass)
        v4_idx = (v1_idx - 7) % len(self.scale)

        self.voices[0] = self.scale[v1_idx]
        self.voices[1] = self.scale[v2_idx] / 2.0
        self.voices[2] = self.scale[v3_idx] / 1.5
        self.voices[3] = self.scale[v4_idx] / 4.0

    def generate_pcm_chunk(self, duration=0.1):
        num_samples = int(self.sample_rate * duration)
        pcm_data = bytearray()
        
        for _ in range(num_samples):
            sample = 0.0
            for i in range(4):
                freq = self.voices[i]
                if freq > 0:
                    self.phases[i] += (2.0 * math.pi * freq) / self.sample_rate
                    if self.phases[i] > 2.0 * math.pi:
                        self.phases[i] -= 2.0 * math.pi
                    # Waveform blending: Sine + Triangle for classical fugue timbre
                    sine_wave = math.sin(self.phases[i])
                    tri_wave = (2.0 / math.pi) * math.asin(math.sin(self.phases[i]))
                    sample += 0.25 * (0.6 * sine_wave + 0.4 * tri_wave)
            
            # Clip and convert to 16-bit PCM integer
            int_sample = max(-32768, min(32767, int(sample * 16384)))
            pcm_data.extend(struct.pack('<h', int_sample))
        return bytes(pcm_data)

# --- Audio Playback Engine ---
class AudioPlayer:
    def __init__(self, synth):
        self.synth = synth
        self.process = None
        self._start_audio_stream()

    def _start_audio_stream(self):
        # Try cross-platform audio pipe streams (aplay for Linux, afplay/sox for MacOS, or powershell on Windows)
        cmd = None
        if sys.platform.startswith('linux'):
            cmd = ['aplay', '-t', 'raw', '-r', str(self.synth.sample_rate), '-f', 'S16_LE', '-c', '1', '-q']
        elif sys.platform == 'darwin':
            cmd = ['sox', '-t', 'raw', '-r', str(self.synth.sample_rate), '-e', 'signed', '-b', '16', '-c', '1', '-', '-d']
        elif sys.platform == 'win32':
            # Soft fallback to silent or powershell raw output play
            cmd = ['powershell', '-c', '$arg=System.Console::OpenStandardInput(); $player=New-Object System.Media.SoundPlayer($arg);']

        try:
            if cmd:
                self.process = subprocess.Popen(cmd, stdin=subprocess.PIPE, stderr=subprocess.DEVNULL, stdout=subprocess.DEVNULL)
        except Exception:
            self.process = None

    def play_chunk(self, chunk):
        if self.process and self.process.stdin:
            try:
                self.process.stdin.write(chunk)
                self.process.stdin.flush()
            except Exception:
                pass

    def stop(self):
        if self.process:
            try:
                self.process.terminate()
            except Exception:
                pass

# --- Visual ASCII Kaleidoscope Engine ---
class ASCIIKaleidoscope:
    def __init__(self, size=25):
        self.size = size
        self.palette = [" ", ".", ":", "*", "o", "S", "#", "@", "8", "&"]
        self.colors = [31, 32, 33, 34, 35, 36, 91, 92, 93, 94, 95, 96]

    def render(self, grid, frag_score, frame_num):
        center = self.size / 2.0
        lines = []
        color_code = self.colors[int(frame_num + frag_score * 10) % len(self.colors)]
        
        # Clear terminal screen
        lines.append("\033[H\033[2J")
        lines.append(f"\033[1;{color_code}m=== MEMORY FUGUE KALEIDOSCOPE ===\033[0m")
        lines.append(f"Fragmentation: {frag_score:.4f} | Voice Polyphony: 4 Parts\n")

        grid_dim = int(math.sqrt(len(grid)))
        
        for y in range(self.size):
            row = []
            for x in range(self.size):
                # Normalize polar coordinates
                dx = x - center
                dy = y - center
                r = math.sqrt(dx * dx + dy * dy)
                theta = math.atan2(dy, dx)

                # Apply 8-fold rotational symmetry for Kaleidoscope effect
                sym_theta = abs(math.fmod(theta + math.pi / 4 + frame_num * 0.05, math.pi / 2) - math.pi / 4)
                kx = int(center + r * math.cos(sym_theta))
                ky = int(center + r * math.sin(sym_theta))

                # Map transformed coordinate to heap grid memory block intensity
                gx = abs(kx) % grid_dim
                gy = abs(ky) % grid_dim
                val = grid[gy * grid_dim + gx]
                
                char = self.palette[val % len(self.palette)]
                row.append(char)
            lines.append(f"\033[38;5;{16 + (val * 25 + frame_num * 2) % 200}m" + "".join(row) + "\033[0m")

        lines.append("\n[Press Ctrl+C to Exit]")
        sys.stdout.write("\n".join(lines))
        sys.stdout.flush()

# --- Main Memory Audio-Visual Loop ---
def main():
    tracker = MemoryTracker(grid_size=32)
    synth = PolyphonicFugueSynth()
    player = AudioPlayer(synth)
    kaleidoscope = ASCIIKaleidoscope(size=27)

    frame = 0
    # Dynamic memory allocator simulator to continuously alter heap structure
    dynamic_allocations = []

    try:
        while True:
            # Dynamically modify system heap memory to cause evolving music & visuals
            if random.random() > 0.3:
                dynamic_allocations.append(bytearray(random.randint(1000, 50000)))
            if len(dynamic_allocations) > 40 or random.random() < 0.2:
                if dynamic_allocations:
                    dynamic_allocations.pop(random.randint(0, len(dynamic_allocations) - 1))
            gc.collect()

            # Retrieve memory tracking statistics
            grid, frag_score, total_bytes, total_blocks = tracker.get_heap_map()

            # Update synthesiser voices (Fugue subject, countersubject, tenor, bass)
            synth.set_voices(frag_score, total_bytes, total_blocks)

            # Generate and stream synthesized audio
            chunk = synth.generate_pcm_chunk(duration=0.08)
            player.play_chunk(chunk)

            # Render Visual ASCII Kaleidoscope
            kaleidoscope.render(grid, frag_score, frame)

            frame += 1
            time.sleep(0.05)

    except KeyboardInterrupt:
        player.stop()
        sys.stdout.write("\033[0m\nAudio-Visual Memory Fugue Terminated.\n")

if __name__ == "__main__":
    main()