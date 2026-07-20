import math
import struct
import wave
import urllib.request
import json
import gc

# --- 1. Real-Time Atmospheric Pressure Fetcher ---
def get_pressure():
    """Fetch real-time surface atmospheric pressure (hPa) via Open-Meteo API."""
    try:
        url = "[https://api.open-meteo.com/v1/forecast?latitude=40.7128&longitude=-74.0060&current=surface_pressure](https://api.open-meteo.com/v1/forecast?latitude=40.7128&longitude=-74.0060&current=surface_pressure)"
        req = urllib.request.urlopen(url, timeout=3)
        data = json.loads(req.read().decode())
        pressure = data['current']['surface_pressure']
        print(f"Live Atmospheric Pressure: {pressure} hPa")
        return float(pressure)
    except Exception:
        print("Network offline. Falling back to standard pressure baseline: 1013.25 hPa")
        return 1013.25

# --- 2. Acoustic Memory Leak Engine ---
class AcousticDecayFrame:
    """Object structure that intentional leaks memory to simulate lingering reverberation."""
    def __init__(self, samples, decay_rate):
        self.samples = samples
        self.decay_rate = decay_rate
        # Circular reference prevents automatic garbage collection cleanup
        self.self_reference = self 

# Heap pool holding uncollected acoustic leak objects
ACOUSTIC_LEAK_POOL = []

def leak_acoustic_frame(samples, decay_rate=0.65):
    """Intentionally retain audio buffers in heap memory to simulate physical room resonance."""
    frame = AcousticDecayFrame(samples, decay_rate)
    ACOUSTIC_LEAK_POOL.append(frame)

def synthesize_echo_reflections(current_samples):
    """Retrieve and mix lingering memory-leaked frames into current audio generation."""
    mixed = list(current_samples)
    for frame in ACOUSTIC_LEAK_POOL[-10:]:  # Accumulate recent memory leaks
        frame.decay_rate *= 0.88  # Damping factor
        for i in range(min(len(mixed), len(frame.samples))):
            mixed[i] += frame.samples[i] * frame.decay_rate
    return mixed

# --- 3. Generative Algorithmic Synthesizer ---
def pressure_to_pentatonic(pressure):
    """Translate pressure into a pentatonic scale dynamic."""
    base_freq = 110.0 + (pressure % 120) * 2.5
    ratios = [1.0, 1.125, 1.25, 1.5, 1.667, 2.0, 2.25]
    return [base_freq * r for r in ratios]

def render_score(pressure, duration=12, sample_rate=44100):
    """Synthesize algorithmic musical score parameterized by pressure data."""
    scale = pressure_to_pentatonic(pressure)
    total_samples = duration * sample_rate
    master_buffer = [0.0] * total_samples
    
    bpm = int(50 + (pressure - 950) * 0.75)
    step_duration = int(sample_rate * (60.0 / bpm) / 2)
    steps = total_samples // step_duration

    for step in range(steps):
        start = step * step_duration
        freq = scale[(step * 3 + int(pressure)) % len(scale)]
        
        note_samples = []
        for t_idx in range(step_duration):
            t = t_idx / sample_rate
            envelope = math.exp(-3.5 * (t_idx / step_duration))
            # Harmonic synthesis formula
            signal = math.sin(2 * math.pi * freq * t) + 0.4 * math.sin(4 * math.pi * freq * t)
            note_samples.append(signal * envelope * 0.3)

        # Trigger acoustic memory leak
        leak_acoustic_frame(note_samples, decay_rate=0.7)
        
        # Render echoes using accumulated leaked heap objects
        echoed_note = synthesize_echo_reflections(note_samples)

        # Mix into master audio stream
        for i, val in enumerate(echoed_note):
            if start + i < total_samples:
                master_buffer[start + i] += val

    # Peak normalization
    peak = max(max(abs(x) for x in master_buffer), 1e-5)
    return [int((x / peak) * 32767) for x in master_buffer], sample_rate

# --- 4. Main Execution ---
def main():
    pressure = get_pressure()
    print("Generating pressure-driven score with memory-leak acoustic decay...")
    
    pcm_data, sample_rate = render_score(pressure, duration=12)
    
    filename = "atmospheric_score.wav"
    with wave.open(filename, 'w') as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(sample_rate)
        wav.writeframes(struct.pack(f'<{len(pcm_data)}h', *pcm_data))

    print(f"Audio file saved as '{filename}'.")
    print(f"Active memory-leaked acoustic frames in heap pool: {len(ACOUSTIC_LEAK_POOL)}")
    
    # Demonstrate garbage collector retention due to intentional circular leaks
    gc.collect()
    print(f"Post-GC heap leak count (retained circular frames): {len(ACOUSTIC_LEAK_POOL)}")

if __name__ == "__main__":
    main()