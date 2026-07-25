import sys
import socket
import threading
import random
import time
import math
import struct
import wave
import os

# --- Ecosystem & Genetics ---
# DNA contains parameters for ASCII flora visual structure and audio synthesis frequency
class Organism:
    def __init__(self, dna=None):
        if dna:
            self.dna = dna
        else:
            self.dna = {
                'chars': random.sample(['*', '~', '@', '&', '#', '%', '^', '+', 'o', '|', '/'], 4),
                'height': random.randint(3, 7),
                'symmetry': random.choice([True, False]),
                'base_freq': random.randint(150, 600),
                'harmonics': [random.uniform(0.5, 2.0) for _ in range(3)]
            }
        self.age = 0

    def mutate(self, exception_type):
        """Mutates DNA based on the hash of the exception type string."""
        seed_val = sum(ord(c) for c in str(exception_type))
        random.seed(seed_val + int(time.time()))
        
        # Shift ASCII characters
        chars_pool = ['*', '~', '@', '&', '#', '%', '^', '+', 'o', '|', '/', 'S', 'X', 'V', 'Y']
        self.dna['chars'] = random.sample(chars_pool, 4)
        self.dna['height'] = max(2, min(10, self.dna['height'] + random.choice([-1, 1])))
        self.dna['base_freq'] = max(100, min(1200, self.dna['base_freq'] + random.randint(-50, 50)))
        random.seed() # Reset RNG

    def cross_pollinate(self, foreign_dna):
        """Combines local DNA with foreign DNA received via network socket."""
        new_dna = {}
        new_dna['chars'] = [random.choice([c1, c2]) for c1, c2 in zip(self.dna['chars'], foreign_dna['chars'])]
        new_dna['height'] = (self.dna['height'] + foreign_dna['height']) // 2
        new_dna['symmetry'] = self.dna['symmetry'] if random.random() > 0.5 else foreign_dna['symmetry']
        new_dna['base_freq'] = (self.dna['base_freq'] + foreign_dna['base_freq']) // 2
        new_dna['harmonics'] = [(h1 + h2) / 2 for h1, h2 in zip(self.dna['harmonics'], foreign_dna['harmonics'])]
        return Organism(new_dna)

    def render(self):
        """Generates visual ASCII flora representation."""
        lines = []
        c = self.dna['chars']
        h = self.dna['height']
        
        # Canopy
        for i in range(h):
            width = (i + 1) if not self.dna['symmetry'] else (i * 2 + 1)
            pattern = "".join(random.choice(c[:2]) for _ in range(width))
            padding = " " * (h - i)
            lines.append(padding + pattern)
            
        # Stem
        stem_char = c[2]
        stem_padding = " " * h
        lines.append(stem_padding + stem_char)
        lines.append(stem_padding + c[3])
        return "\n".join(lines)

# --- Global Ecosystem State ---
garden = [Organism()]
garden_lock = threading.Lock()
PORT = 42424

# --- Generative Ambient Soundscape Engine ---
def generate_audio_tone(organism, duration=1.5, sample_rate=22050):
    """Generates a soft, additive synthesis ambient audio buffer."""
    num_samples = int(sample_rate * duration)
    audio_data = bytearray()
    
    base_freq = organism.dna['base_freq']
    harmonics = organism.dna['harmonics']
    
    for i in range(num_samples):
        t = float(i) / sample_rate
        # Amplitude envelope (smooth fade-in and fade-out)
        env = math.sin(math.pi * (i / num_samples))
        
        # Fundamental + Harmonics
        signal = math.sin(2 * math.pi * base_freq * t)
        for idx, h in enumerate(harmonics):
            signal += (0.5 / (idx + 1)) * math.sin(2 * math.pi * (base_freq * h) * t)
        
        # Scale & Normalize to 8-bit PCM
        val = int(127 + 40 * env * signal)
        val = max(0, min(255, val))
        audio_data.append(val)
        
    return audio_data

def play_ambient_soundscape():
    """Continuously synthesizes and plays audio streams for flora in the garden."""
    while True:
        time.sleep(2)
        with garden_lock:
            if not garden:
                continue
            flora = random.choice(garden)
        
        audio_bytes = generate_audio_tone(flora)
        # Attempt to stream to platform-specific audio sink or stdout
        try:
            if os.name == 'posix': # macOS / Linux pipe to aplay or afplay if available
                dev = '/dev/dsp'
                if os.path.exists(dev):
                    with open(dev, 'wb') as f:
                        f.write(audio_bytes)
        except Exception:
            pass # Silent fallback if audio hardware direct write is restricted

# --- Network Cross-Pollination (Sockets) ---
def network_listener():
    """Listens for foreign spore DNA broadcast over local sockets."""
    server = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    try:
        server.bind(('0.0.0.0', PORT))
    except Exception:
        return

    while True:
        try:
            data, _ = server.recvfrom(1024)
            foreign_dna = eval(data.decode('utf-8')) # Deserializes basic dict
            with garden_lock:
                parent = random.choice(garden)
                child = parent.cross_pollinate(foreign_dna)
                garden.append(child)
                if len(garden) > 5:
                    garden.pop(0)
                print("\n[Ecosystem] Foreign pollen received via network! Hybrid flora sprouted:")
                print(child.render())
        except Exception:
            pass

def broadcast_spore(organism):
    """Broadcasting local DNA to local subnets for peer cross-pollination."""
    client = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    client.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
    try:
        payload = str(organism.dna).encode('utf-8')
        client.sendto(payload, ('<broadcast>', PORT))
    except Exception:
        pass
    finally:
        client.close()

# --- Exception Handler Hook ---
def exception_ecosystem_feeder(exc_type, exc_value, traceback):
    """Intercepts unhandled exceptions, feeding flora and mutating visual/audio DNA."""
    print(f"\n[Unhandled Exception Detected: {exc_type.__name__}]")
    print("Feeding system error energy into ASCII Ecosystem...")
    
    with garden_lock:
        target_flora = random.choice(garden)
        target_flora.mutate(exc_type.__name__)
        print("\n=== MUTATED FLORA BLOOM ===")
        print(target_flora.render())
        print("===========================\n")
        
        # Broadcast mutated spore to network
        threading.Thread(target=broadcast_spore, args=(target_flora,), daemon=True).start()

# --- System Setup & Interactive Simulation ---
sys.excepthook = exception_ecosystem_feeder

# Start Background Threads
threading.Thread(target=network_listener, daemon=True).start()
threading.Thread(target=play_ambient_soundscape, daemon=True).start()

if __name__ == '__main__':
    print("ASCII Flora Ecosystem Initialized.")
    print("Listening for unhandled system exceptions and network pollen...")
    print("Simulating organism lifecycle (Press Ctrl+C to exit)...")
    
    # Display initial flora
    print(garden[0].render())
    
    # Simulate active environment triggering intentional exception to showcase functionality
    time.sleep(2)
    print("\nSimulating unhandled ZeroDivisionError to feed ecosystem...")
    1 / 0