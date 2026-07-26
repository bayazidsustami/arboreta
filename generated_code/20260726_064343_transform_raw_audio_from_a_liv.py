import sys
import time
import math
import threading
import numpy as np
import pygame
import psutil

try:
    import sounddevice as sd
    HAS_AUDIO = True
except ImportError:
    HAS_AUDIO = False

# Configuration & Constants
GRID_SIZE = 180
SCALE = 4
WINDOW_SIZE = GRID_SIZE * SCALE

# Audio Telemetry Global Variables
audio_energy = 0.0
audio_pitch = 0.5
lock = threading.Lock()

def audio_callback(indata, frames, time_info, status):
    """Processes live ambient audio stream to compute amplitude energy and dominant pitch."""
    global audio_energy, audio_pitch
    if indata.size == 0:
        return
    mono = indata[:, 0]
    rms = float(np.sqrt(np.mean(mono**2)))
    
    # Compute FFT for frequency analysis
    fft_vals = np.abs(np.fft.rfft(mono))
    peak_idx = int(np.argmax(fft_vals)) if len(fft_vals) > 0 else 0
    pitch_norm = float(peak_idx / max(len(fft_vals), 1))
    
    with lock:
        audio_energy = audio_energy * 0.7 + rms * 0.3
        audio_pitch = audio_pitch * 0.8 + pitch_norm * 0.2

def init_audio():
    """Initializes sounddevice stream with robust fallback handling."""
    if not HAS_AUDIO:
        return None
    try:
        stream = sd.InputStream(channels=1, samplerate=44100, blocksize=2048, callback=audio_callback)
        stream.start()
        return stream
    except Exception:
        return None

def get_cpu_temperature():
    """Harvests thermal hardware telemetry; gracefully falls back to CPU load proxy if unreadable."""
    try:
        temps = psutil.sensors_temperatures()
        if temps:
            for sensor, entries in temps.items():
                for entry in entries:
                    if entry.current and entry.current > 0:
                        return float(entry.current)
    except Exception:
        pass
    # Fallback temperature curve calculated from CPU activity
    return 35.0 + (psutil.cpu_percent(interval=None) * 0.45)

def build_watercolor_palette(temp_celsius):
    """Dynamically generates a wet-on-wet watercolor RGB palette derived from core device temperature."""
    # Normalize temperature between typical operational range (30°C to 80°C)
    t = float(np.clip((temp_celsius - 30.0) / 50.0, 0.0, 1.0))
    
    # Cool thermal baseline (indigo / emerald) transitioning to hot thermal baseline (crimson / amber)
    c_low = np.array([15 + 180 * t, 30 + 40 * (1 - t), 80 - 40 * t])
    c_mid = np.array([40 + 200 * t, 120 - 80 * t, 160 - 100 * t])
    c_high = np.array([220, 180 * (1 - t) + 40, 40 + 180 * t])
    
    return c_low, c_mid, c_high

def laplacian(grid):
    """Calculates discrete 2D isotropic Laplacian convolution for fluidic diffusion."""
    return (
        np.roll(grid, 1, axis=0) + np.roll(grid, -1, axis=0) +
        np.roll(grid, 1, axis=1) + np.roll(grid, -1, axis=1) +
        0.5 * (
            np.roll(np.roll(grid, 1, axis=0), 1, axis=1) +
            np.roll(np.roll(grid, 1, axis=0), -1, axis=1) +
            np.roll(np.roll(grid, -1, axis=0), 1, axis=1) +
            np.roll(np.roll(grid, -1, axis=0), -1, axis=1)
        ) - 6.0 * grid
    )

def main():
    pygame.init()
    screen = pygame.display.set_mode((WINDOW_SIZE, WINDOW_SIZE))
    pygame.display.set_caption("Live Audio & Thermal Telemetry Watercolor Automaton")
    clock = pygame.time.Clock()
    
    audio_stream = init_audio()
    
    # Continuous Reaction-Diffusion Automaton Buffers (Gray-Scott model)
    A = np.ones((GRID_SIZE, GRID_SIZE), dtype=np.float32)
    B = np.zeros((GRID_SIZE, GRID_SIZE), dtype=np.float32)
    
    # Seed central dynamic reaction node
    r = 10
    cx, cy = GRID_SIZE // 2, GRID_SIZE // 2
    B[cx-r:cx+r, cy-r:cy+r] = 0.25
    
    # Render Canvas Buffer
    canvas = np.zeros((GRID_SIZE, GRID_SIZE, 3), dtype=np.float32)
    
    running = True
    frame_count = 0
    
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT or (event.type == pygame.KEYDOWN and event.key == pygame.K_ESCAPE):
                running = False

        # Read Telemetry Inputs
        with lock:
            curr_energy = audio_energy
            curr_pitch = audio_pitch
        
        # Synthetic noise if audio is unavailable
        if not HAS_AUDIO or audio_stream is None:
            curr_energy = 0.05 + 0.05 * math.sin(frame_count * 0.1)
            curr_pitch = 0.5 + 0.3 * math.cos(frame_count * 0.03)

        temp = get_cpu_temperature()
        c_low, c_mid, c_high = build_watercolor_palette(temp)

        # Inject dynamic ambient audio into cellular state (Ink drops onto wet paper)
        if curr_energy > 0.02 or frame_count % 15 == 0:
            angle = curr_pitch * 2.0 * math.pi + frame_count * 0.05
            dist = (0.2 + 0.3 * curr_pitch) * (GRID_SIZE // 2)
            px = int(GRID_SIZE // 2 + math.cos(angle) * dist) % GRID_SIZE
            py = int(GRID_SIZE // 2 + math.sin(angle) * dist) % GRID_SIZE
            
            radius = int(2 + curr_energy * 25)
            y, x = np.ogrid[-radius:radius+1, -radius:radius+1]
            mask = x*x + y*y <= radius*radius
            
            x_min, x_max = max(0, px-radius), min(GRID_SIZE, px+radius+1)
            y_min, y_max = max(0, py-radius), min(GRID_SIZE, py+radius+1)
            
            sub_mask = mask[(y_min-(py-radius)):(y_max-(py-radius)), 
                            (x_min-(px-radius)):(x_max-(px-radius))]
            B[x_min:x_max, y_min:y_max][sub_mask] += float(np.clip(curr_energy * 2.0, 0.2, 0.9))

        # Cellular Automaton Physics (Gray-Scott Reaction-Diffusion Simulation)
        Da, Db = 0.16, 0.08
        F = 0.035 + curr_energy * 0.02
        K = 0.060 + curr_pitch * 0.005
        
        lapA = laplacian(A)
        lapB = laplacian(B)
        
        abb = A * B * B
        A += (Da * lapA - abb + F * (1.0 - A))
        B += (Db * lapB + abb - (F + K) * B)
        
        A = np.clip(A, 0.0, 1.0)
        B = np.clip(B, 0.0, 1.0)

        # Render Continuous Automaton State as Watercolor Blending Dynamics
        # Map concentration matrix into multi-layered color space
        norm_B = np.nan_to_num(B[:, :, np.newaxis])
        target_color = np.where(
            norm_B < 0.3,
            c_low + (c_mid - c_low) * (norm_B / 0.3),
            c_mid + (c_high - c_mid) * (np.clip((norm_B - 0.3) / 0.7, 0, 1))
        )

        # Wet-paper pigment bleeding effect using temporal low-pass feedback blur
        canvas = canvas * 0.82 + target_color * 0.18
        render_frame = np.clip(canvas, 0, 255).astype(np.uint8)

        # Scale array up to window display surface
        surface = pygame.surfarray.make_surface(render_frame)
        scaled_surface = pygame.transform.smoothscale(surface, (WINDOW_SIZE, WINDOW_SIZE))
        
        screen.blit(scaled_surface, (0, 0))
        pygame.display.flip()
        
        frame_count += 1
        clock.tick(60)

    if audio_stream:
        audio_stream.stop()
        audio_stream.close()
    pygame.quit()
    sys.exit()

if __name__ == "__main__":
    main()