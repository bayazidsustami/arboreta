import math
import random
import struct
import sys
import threading
import time
import tkinter as tk
from dataclasses import dataclass, field
from typing import List

try:
    import numpy as np
    import sounddevice as sd
    HAS_AUDIO = True
except ImportError:
    HAS_AUDIO = False

# --- Gregorian Chant Musical Constants ---
# Dorian/Phrygian Modal Frequencies (A2 = 110Hz root for deep chant voice)
ROOT_FREQ = 110.0
# Just intonation intervals relative to root (Unison, Minor 2nd, Major 2nd, Minor 3rd, Perfect 4th, Perfect 5th, Minor 6th, Minor 7th, Octave)
SCALE_RATIOS = [1.0, 16/15, 9/8, 6/5, 4/3, 3/2, 8/5, 9/5, 2.0]
# Consonant intervals vs Dissonant intervals (mapped by latency)
CONSONANT_INDICES = [0, 4, 5, 8] # Root, P4, P5, Octave
DISSONANT_INDICES = [1, 2, 3, 6, 7] # 2nds, 3rds, 6ths, 7ths

SAMPLE_RATE = 44100

@dataclass
class Packet:
    timestamp: float
    latency_ms: float
    is_lost: bool
    size: int
    payload_type: int

@dataclass
class VoiceState:
    freq: float = 110.0
    target_freq: float = 110.0
    amplitude: float = 0.0
    target_amplitude: float = 0.0
    phase: float = 0.0
    vibrato_phase: float = 0.0
    vowel_formant: float = 500.0  # Formant filter center for vocal texture

class NetworkChantSimulator:
    def __init__(self):
        self.running = True
        self.packets: List[Packet] = []
        self.lock = threading.Lock()
        
        # 4 Voices for Polyphonic Gregorian Organum (Bass, Tenor, Alto, Soprano)
        self.voices = [VoiceState(freq=ROOT_FREQ * (2**i)) for i in range(4)]
        
        # Musical / Network metrics
        self.current_latency = 20.0
        self.packet_loss_active = False
        self.pause_decay = 1.0  # For smooth dramatic pauses on packet loss
        
        # Audio stream setup
        self.audio_stream = None
        if HAS_AUDIO:
            try:
                self.audio_stream = sd.OutputStream(
                    samplerate=SAMPLE_RATE,
                    channels=1,
                    callback=self._audio_callback,
                    blocksize=1024
                )
            except Exception:
                HAS_AUDIO = False

    def simulate_network_traffic(self):
        """Simulates live network traffic packet stream with varying latency and burst loss."""
        while self.running:
            time.sleep(random.uniform(0.05, 0.2))
            
            # Simulate occasional network latency spikes and packet loss bursts
            burst = random.random()
            if burst < 0.05:  # Packet loss event
                is_lost = True
                latency = random.uniform(300, 800)
            elif burst < 0.25:  # High latency jitter
                is_lost = False
                latency = random.uniform(150, 400)
            else:  # Normal low latency network traffic
                is_lost = False
                latency = random.uniform(10, 50)

            pkt = Packet(
                timestamp=time.time(),
                latency_ms=latency,
                is_lost=is_lost,
                size=random.randint(64, 1500),
                payload_type=random.randint(0, 3)
            )

            with self.lock:
                self.packets.append(pkt)
                if len(self.packets) > 50:
                    self.packets.pop(0)

                self.current_latency = latency
                
                # Update Chant Harmony based on Network Latency & Packet Loss
                if is_lost:
                    self.packet_loss_active = True
                else:
                    self.packet_loss_active = False
                    self._update_chords(latency, pkt.payload_type)

    def _update_chords(self, latency: float, voice_lead: int):
        """Generates Gregorian Organum harmony where latency dictates dissonance."""
        # Normalize latency (0ms to 300ms+) into dissonance index
        dissonance_factor = min(1.0, max(0.0, (latency - 20) / 250.0))
        
        # Pick pitch intervals based on dissonance degree
        for i, voice in enumerate(self.voices):
            octave_mult = 2 ** (i // 2)
            if random.random() > dissonance_factor:
                idx = random.choice(CONSONANT_INDICES)
            else:
                idx = random.choice(DISSONANT_INDICES)
            
            interval_ratio = SCALE_RATIOS[idx]
            voice.target_freq = ROOT_FREQ * octave_mult * interval_ratio
            voice.target_amplitude = random.uniform(0.15, 0.3)
            # Modulate vocal formant based on packet size/type for 'vowel' shifts (A/E/O/U)
            voice.vowel_formant = 300.0 + (voice_lead * 250.0) + (dissonance_factor * 800.0)

    def _audio_callback(self, outdata, frames, time_info, status):
        """Generates real-time audio synthesis of organum voices with vocal formants."""
        t = np.arange(frames) / SAMPLE_RATE
        output = np.zeros(frames)

        with self.lock:
            # Handle dramatic musical pauses on packet loss
            if self.packet_loss_active:
                self.pause_decay = max(0.0, self.pause_decay - 0.05)
            else:
                self.pause_decay = min(1.0, self.pause_decay + 0.02)

            decay = self.pause_decay

            for voice in self.voices:
                # Smooth pitch transitions (portamento chant style)
                voice.freq += (voice.target_freq - voice.freq) * 0.05
                voice.amplitude += (voice.target_amplitude - voice.amplitude) * 0.05
                
                # Fundamental tone + organum overtone series for rich choir timbre
                phase_inc = 2 * math.pi * voice.freq / SAMPLE_RATE
                phases = voice.phase + phase_inc * np.arange(frames)
                voice.phase = (voice.phase + phase_inc * frames) % (2 * math.pi)

                # Add gentle vibrato
                vibrato = 1.0 + 0.005 * np.sin(2 * math.pi * 5.0 * (voice.vibrato_phase + t))
                voice.vibrato_phase = (voice.vibrato_phase + 5.0 * frames / SAMPLE_RATE) % 1.0

                # Synth vocal waveform: Fundamental + Warm 2nd & 3rd Harmonics
                signal = (
                    0.6 * np.sin(phases * vibrato) +
                    0.3 * np.sin(2 * phases * vibrato) +
                    0.1 * np.sin(3 * phases * vibrato)
                )

                # Resonant filter simulation for Gregorian vowel resonance
                formant_w = 2 * math.pi * voice.vowel_formant / SAMPLE_RATE
                filter_env = np.exp(-0.001 * np.abs(np.sin(phases)))
                
                output += signal * voice.amplitude * filter_env * decay

        outdata[:] = (output * 0.2).reshape(-1, 1)

class VisualizerGUI:
    def __init__(self, simulator: NetworkChantSimulator):
        self.sim = simulator
        self.root = tk.Tk()
        self.root.title("Gregorian Chant Network Packet Simulator")
        self.root.geometry("800x500")
        self.root.configure(bg="#110e19")

        self.canvas = tk.Canvas(self.root, bg="#110e19", highlightthickness=0)
        self.canvas.pack(fill=tk.BOTH, expand=True)

        self.root.protocol("WM_DELETE_WINDOW", self.on_close)
        self.animate()

    def animate(self):
        """Draws live multi-voiced manuscript waves, network latency, and pause flashes."""
        self.canvas.delete("all")
        w = self.canvas.winfo_width()
        h = self.canvas.winfo_height()

        if w <= 1 or h <= 1:
            self.root.after(40, self.animate)
            return

        with self.sim.lock:
            packets = list(self.sim.packets)
            latency = self.sim.current_latency
            is_pause = self.sim.packet_loss_active
            voices = [VoiceState(v.freq, v.target_freq, v.amplitude, v.target_amplitude) for v in self.sim.voices]

        # Draw Background Score Staves
        staff_spacing = 12
        for line in range(4):
            y = h // 2 - 30 + (line * staff_spacing)
            self.canvas.create_line(50, y, w - 50, y, fill="#2a233c", width=1)

        # Draw Packet Loss Dramatic Pause Visual Effect
        if is_pause:
            self.canvas.create_rectangle(0, 0, w, h, fill="#3a0913", outline="")
            self.canvas.create_text(
                w // 2, h // 2, 
                text="PAUSE - PACKET LOSS DETECTED", 
                fill="#ff4d4d", font=("Georgia", 18, "bold")
            )
        else:
            # Draw Polyphonic Chant Voice Waveforms
            colors = ["#ffd700", "#c0c0c0", "#cd7f32", "#8a2be2"]
            for idx, voice in enumerate(voices):
                points = []
                freq = voice.freq
                amp = voice.amplitude * 60
                y_center = h // 2 - 40 + (idx * 25)
                
                for x in range(50, w - 50, 5):
                    y = y_center + math.sin((x * 0.02) + (time.time() * freq * 0.05)) * amp
                    points.extend([x, y])
                
                if len(points) >= 4:
                    self.canvas.create_line(points, fill=colors[idx % len(colors)], width=2, smooth=True)

            # Draw Network Traffic Data Points along score
            for i, pkt in enumerate(packets):
                x = 50 + i * ((w - 100) / max(1, len(packets)))
                y_offset = (pkt.latency_ms / 500.0) * 80
                y = h - 100 - y_offset
                color = "#ff3366" if pkt.is_lost else "#00ffcc"
                radius = max(3, min(12, pkt.size // 150))
                self.canvas.create_oval(x - radius, y - radius, x + radius, y + radius, fill=color, outline="")

        # Metric Labels
        dissonance_pct = min(100, int((latency / 300) * 100))
        status_text = f"Latency: {latency:.1f} ms | Harmonic Dissonance: {dissonance_pct}% | Voices: 4 Organum"
        self.canvas.create_text(60, 30, text="GREGORIAN NETWORK CANTICLES", fill="#e6d7ff", font=("Georgia", 14, "bold"), anchor="w")
        self.canvas.create_text(60, 55, text=status_text, fill="#a390c4", font=("Georgia", 10), anchor="w")

        if not HAS_AUDIO:
            self.canvas.create_text(w // 2, 30, text="[Audio Output Disabled: Install numpy & sounddevice for sound]", fill="#ff8800", font=("Georgia", 9))

        self.root.after(40, self.animate)

    def on_close(self):
        self.sim.running = False
        if self.sim.audio_stream:
            self.sim.audio_stream.stop()
            self.sim.audio_stream.close()
        self.root.destroy()

def main():
    sim = NetworkChantSimulator()
    
    # Start Network Traffic Thread
    net_thread = threading.Thread(target=sim.simulate_network_traffic, daemon=True)
    net_thread.start()

    # Start Real-time Audio Stream if dependencies available
    if HAS_AUDIO and sim.audio_stream:
        try:
            sim.audio_stream.start()
        except Exception as e:
            print(f"Audio playback error: {e}")

    # Launch Visual Interface
    gui = VisualizerGUI(sim)
    gui.root.mainloop()

if __name__ == "__main__":
    main()