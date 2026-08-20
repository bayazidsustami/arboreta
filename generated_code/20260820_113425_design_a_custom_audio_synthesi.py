import wave
import struct
import math
import random
from PIL import Image

def generate_ambient_soundscape(image_path, output_wav_path, duration_per_pixel=0.05, sample_rate=44100):
    # Load and resize image to keep the output audio duration manageable
    img = Image.open(image_path).convert('RGB')
    img = img.resize((32, 32))  # 1024 pixel-notes total
    pixels = list(img.getdata())
    
    total_samples = int(sample_rate * duration_per_pixel)
    num_channels = 2  # Stereo output for panning
    
    # State variables for continuous smooth audio synthesis (low-pass filter state)
    lowpass_l = 0.0
    lowpass_r = 0.0
    
    with wave.open(output_wav_path, 'w') as wav_file:
        wav_file.setnchannels(num_channels)
        wav_file.setsampwidth(2)  # 16-bit audio
        wav_file.setframerate(sample_rate)
        
        phase = 0.0
        
        for r, g, b in pixels:
            # Map Red channel -> Frequency (Pentatonic scale range ~100Hz to 1200Hz)
            base_freq = 100.0 + (r / 255.0) * 1100.0
            
            # Map Green channel -> Filter Resonance / Alpha (0.01 = heavy filtering, 0.95 = sharp/bright)
            filter_alpha = 0.02 + (g / 255.0) * 0.90
            
            # Map Blue channel -> Stereo Panning (0.0 = full left, 1.0 = full right)
            pan = b / 255.0
            pan_l = math.cos(pan * math.pi / 2.0)
            pan_r = math.sin(pan * math.pi / 2.0)
            
            for t in range(total_samples):
                # Harmonic synthesizer with subtle amplitude modulation for ambient feel
                phase += 2.0 * math.pi * base_freq / sample_rate
                
                # Combine fundamental wave with warm soft-clipped harmonics
                raw_signal = (
                    0.6 * math.sin(phase) + 
                    0.3 * math.sin(2.0 * phase) + 
                    0.1 * (random.random() * 2.0 - 1.0)  # Gentle organic noise texturing
                )
                
                # Apply simple single-pole IIR low-pass filter (Resonance control via Green channel)
                lowpass_l += filter_alpha * (raw_signal * pan_l - lowpass_l)
                lowpass_r += filter_alpha * (raw_signal * pan_r - lowpass_r)
                
                # Envelope shaping to avoid clicking between pixel transitions
                env = math.sin(math.pi * (t / total_samples))
                
                out_l = int(max(-32767, min(32767, lowpass_l * env * 16384)))
                out_r = int(max(-32767, min(32767, lowpass_r * env * 16384)))
                
                # Write stereo 16-bit PCM frame
                wav_file.writeframes(struct.pack('<hh', out_l, out_r))

# Create a sample synthetic image if run directly
if __name__ == "__main__":
    img = Image.new('RGB', (100, 100))
    for x in range(100):
        for y in range(100):
            img.putpixel((x, y), (x * 2, y * 2, (x + y) % 256))
    img.save("input_sample.png")
    
    generate_ambient_soundscape("input_sample.png", "ambient_soundscape.wav")