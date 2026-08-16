import os
import sys
import time
import math
import wave
import struct
import tempfile
import subprocess
import numpy as np

# Self-Modifying Visual-Acoustic Quine Engine
# 1. Reads its own source code.
# 2. Renders the code visually as a 2D PPM image array.
# 3. Sonifies the visual structure into an audio wave (RGB -> Frequencies/Amplitudes).
# 4. Captures ambient audio via system recording utility or generates harmonic room noise.
# 5. Analyzes the ambient audio spectrum to mutate its own code inline.

def get_self_source():
    """Reads the current file's source code."""
    try:
        with open(__file__, 'r') as f:
            return f.read()
    except Exception:
        return "print('Hello, Self-Modifying Sonified World!')"

def render_code_to_ppm_image(source_text, width=64, height=64):
    """Renders text characters into a 2D RGB color matrix (PPM format)."""
    pixels = np.zeros((height, width, 3), dtype=np.uint8)
    chars = [ord(c) for c in source_text]
    total_chars = len(chars)
    
    idx = 0
    for y in range(height):
        for x in range(width):
            if idx < total_chars:
                char_val = chars[idx]
                # Map ASCII character byte to vibrant RGB color space
                r = (char_val * 7) % 256
                g = (char_val * 13) % 256
                b = (char_val * 17) % 256
                pixels[y, x] = [r, g, b]
                idx += 1
            else:
                # Background padding
                pixels[y, x] = [10, 15, 25]
    return pixels

def render_image_to_soundwave(pixels, output_wav="quine_sound.wav", duration_sec=1.5, sample_rate=22050):
    """Converts 2D visual structure into audio frequencies (Additive Synthesis)."""
    height, width, _ = pixels.shape
    total_samples = int(sample_rate * duration_sec)
    t = np.linspace(0, duration_sec, total_samples, endpoint=False)
    audio_buffer = np.zeros(total_samples, dtype=np.float32)

    # Scan rows of image to build audio spectrum
    row_frequencies = np.linspace(150, 2400, height)
    for y in range(height):
        row_intensity = np.mean(pixels[y, :, :]) / 255.0
        if row_intensity > 0.05:
            freq = row_frequencies[y]
            # Synthesize wave with row brightness as amplitude
            audio_buffer += row_intensity * 0.02 * np.sin(2 * np.pi * freq * t)

    # Normalize audio signal
    max_val = np.max(np.abs(audio_buffer))
    if max_val > 0:
        audio_buffer = audio_buffer / max_val * 0.7

    # Save to standard WAV file format
    packed_data = bytearray()
    for s in audio_buffer:
        packed_data.extend(struct.pack('<h', int(s * 32767)))

    with wave.open(output_wav, 'w') as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        wf.writeframes(packed_data)

def capture_ambient_audio_spectrum(duration_sec=0.5, sample_rate=22050):
    """Listens to room acoustics via microphone tool or simulates ambient spectrum."""
    num_samples = int(sample_rate * duration_sec)
    audio_data = None
    
    # Attempt cross-platform recording using native CLI commands
    temp_rec = os.path.join(tempfile.gettempdir(), "ambient_rec.wav")
    rec_cmd = None
    if sys.platform.startswith('linux'):
        rec_cmd = f"arecord -d 1 -r {sample_rate} -f S16_LE -c 1 {temp_rec}"
    elif sys.platform == 'darwin':
        rec_cmd = f"sox -d -r {sample_rate} -c 1 {temp_rec} trim 0 {duration_sec}"

    if rec_cmd:
        try:
            subprocess.run(rec_cmd, shell=True, stderr=subprocess.DEVNULL, stdout=subprocess.DEVNULL, timeout=1.5)
            if os.path.exists(temp_rec):
                with wave.open(temp_rec, 'rb') as wf:
                    frames = wf.readframes(num_samples)
                    audio_data = np.frombuffer(frames, dtype=np.int16).astype(np.float32)
                os.remove(temp_rec)
        except Exception:
            audio_data = None

    # Fallback to room ambient synthetic noise if mic device isn't accessible directly
    if audio_data is None or len(audio_data) == 0:
        t = np.linspace(0, duration_sec, num_samples)
        # Simulates ambient noise room resonance around 440Hz + ambient drift
        audio_data = np.random.normal(0, 0.1, num_samples) + 0.3 * np.sin(2 * np.pi * 440 * t)

    # Calculate real-time Fast Fourier Transform (FFT) spectrum
    fft_spectrum = np.abs(np.fft.rfft(audio_data))
    return fft_spectrum

def mutate_source(source_text, spectrum):
    """Mutates code text based on ambient audio frequency peaks."""
    peak_freq_bin = int(np.argmax(spectrum))
    energy = float(np.mean(spectrum))
    
    # Acoustic-driven mutations
    mutation_tag = f"# [Acoustic State Resonance Peak: Bin {peak_freq_bin} | Energy: {energy:.2f}]"
    
    lines = source_text.split('\n')
    if lines and lines[-1].startswith("# [Acoustic State Resonance"):
        lines[-1] = mutation_tag
    else:
        lines.append(mutation_tag)
        
    return '\n'.join(lines)

def main():
    print("[1/4] Reading source code...")
    source_code = get_self_source()

    print("[2/4] Rendering source code into PPM visual matrix...")
    img_pixels = render_code_to_ppm_image(source_code)
    print(f"      Visual Dimensions: {img_pixels.shape[1]}x{img_pixels.shape[0]} RGB")

    print("[3/4] Converting visual structure to audio waveform...")
    wav_out = "quine_acoustics.wav"
    render_image_to_soundwave(img_pixels, output_wav=wav_out)
    print(f"      Rendered sonified code to: {wav_out}")

    print("[4/4] Listening to room ambient acoustics & mutating source...")
    spectrum = capture_ambient_audio_spectrum()
    mutated_code = mutate_source(source_code, spectrum)

    # Self-modification step: re-write self source file
    try:
        with open(__file__, 'w') as f:
            f.write(mutated_code)
        print("      Self-modification complete. Updated script text with acoustic spectrum state.")
    except Exception as e:
        print(f"      Self-modification skipped: {e}")

if __name__ == "__main__":
    main()