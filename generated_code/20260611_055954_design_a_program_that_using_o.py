import sys, os, struct, math, wave, random, time
from datetime import datetime

# ------------------------------------------------------------
# Helper: generate a simple sine wave note (44.1kHz, 16‑bit)
# ------------------------------------------------------------
def note_wave(freq, duration=0.2, rate=44100):
    n_samples = int(rate * duration)
    amp = 32767 // 4
    data = bytearray()
    for i in range(n_samples):
        t = i / rate
        sample = int(amp * math.sin(2 * math.pi * freq * t))
        data += struct.pack('<h', sample)
    return data

# ------------------------------------------------------------
# Map a hue (0‑360) to a pentatonic note (C D E G A)
# ------------------------------------------------------------
PENTATONIC = [261.63, 293.66, 329.63, 392.00, 440.00]  # C4,E4,G4,A4,B4
def hue_to_note(hue):
    idx = int((hue % 360) / 72) % len(PENTATONIC)
    return PENTATONIC[idx]

# ------------------------------------------------------------
# Mock frame generator – yields a pseudo‑random "dominant hue"
# ------------------------------------------------------------
def fake_frames(num=30):
    for _ in range(num):
        # simulate a dominant hue extracted from a webcam frame
        hue = random.random() * 360
        yield hue
        time.sleep(0.05)  # pretend real‑time capture

# ------------------------------------------------------------
# Generate audio track from frame hues
# ------------------------------------------------------------
def create_audio(hues, filename='output.wav'):
    with wave.open(filename, 'wb') as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)      # 16‑bit
        wf.setframerate(44100)
        for hue in hues:
            freq = hue_to_note(hue)
            wf.writeframes(note_wave(freq))
    print(f'Audio written to {filename}')

# ------------------------------------------------------------
# Very naive GIF writer (binary, no external libs)
# Writes a sequence of grayscale frames as a GIF89a animation.
# ------------------------------------------------------------
def gif_header(width, height, n_frames):
    header = b'GIF89a'
    lsd = struct.pack('<HHBBB', width, height, 0b10000101, 0, 0)  # GCT flag, 2‑bit size
    palette = bytes([i for i in range(256) for _ in (0, 0)])[:768]  # black‑white palette
    return header + lsd + palette

def gif_image_block(frame_idx, width, height, data):
    # Image descriptor
    img_desc = b',' + struct.pack('<4H2B', 0, 0, width, height, 0, 0)
    # LZW minimum code size
    lzw_min = b'\x08'
    # Uncompressed image data as sub‑blocks (simple, not compressed)
    sub_block = bytes([len(data)]) + data
    terminator = b'\x00'
    return img_desc + lzw_min + sub_block + terminator

def create_gif(hues, filename='output.gif', width=64, height=64):
    frames = []
    for hue in hues:
        # create a simple radial gradient based on hue
        shade = int((hue / 360) * 255)
        frame = bytes([shade] * (width * height))
        frames.append(frame)

    with open(filename, 'wb') as f:
        f.write(gif_header(width, height, len(frames)))
        for i, frm in enumerate(frames):
            f.write(gif_image_block(i, width, height, frm))
        # GIF trailer
        f.write(b'\x3B')
    print(f'Animated GIF written to {filename}')

# ------------------------------------------------------------
# Main orchestration
# ------------------------------------------------------------
def main():
    num_frames = 30
    hues = list(fake_frames(num_frames))
    create_audio(hues, 'melody.wav')
    create_gif(hues, 'kaleido.gif')

if __name__ == '__main__':
    main()