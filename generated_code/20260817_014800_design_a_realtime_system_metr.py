import math
import random
import time
import threading
import psutil
import mido
import moderngl
import pygame

# Initialize pygame and set up audio synth engine
pygame.init()
pygame.mixer.init(frequency=44100, size=-16, channels=2, buffer=512)

# Open virtual/default MIDI output port using mido
try:
    midi_out = mido.open_output('System Metrics Synth', virtual=True)
except (AttributeError, NotImplementedError):
    midi_out = mido.open_output()

# System Metrics Monitor & Process Tree Procedural Midi Composer
class MetricsScoreEngine:
    def __init__(self):
        self.cpu = 0.0
        self.mem = 0.0
        self.running = True
        self.scale = [60, 62, 63, 65, 67, 68, 70, 72, 74, 75, 77, 79, 80, 82, 84] # C Minor Pentatonic / Harmonic Extended
        self.active_notes = {}

    def update_metrics(self):
        while self.running:
            self.cpu = psutil.cpu_percent(interval=0.1)
            self.mem = psutil.virtual_memory().percent
            self.procedural_midi_step()
            time.sleep(0.15)

    def generate_tone(self, freq, duration=0.2, volume=0.3):
        # Generate audio buffer for audio-reactive shader driving
        sr = 44100
        n_samples = int(sr * duration)
        buf = bytearray()
        for i in range(n_samples):
            t = float(i) / sr
            # Complex wave blend (Sine + Saw)
            val = 0.6 * math.sin(2 * math.pi * freq * t) + 0.4 * (2 * (t * freq - math.floor(0.5 + t * freq)))
            sample = int(val * volume * 32767)
            buf.extend(sample.to_bytes(2, byteorder='little', signed=True))
            buf.extend(sample.to_bytes(2, byteorder='little', signed=True))
        sound = pygame.mixer.Sound(buffer=bytes(buf))
        sound.play()

    def procedural_midi_step(self):
        # Map active process tree depth and CPU usage to live MIDI score
        processes = sorted(psutil.process_iter(['pid', 'cpu_percent']), key=lambda p: p.info['cpu_percent'] or 0, reverse=True)[:8]
        
        # Shut down old notes
        for note in list(self.active_notes.keys()):
            midi_out.send(mido.Message('note_off', note=note, velocity=0))
            del self.active_notes[note]

        # Trigger new procedural notes based on process tree signatures
        for idx, proc in enumerate(processes):
            proc_cpu = proc.info['cpu_percent'] or 0.0
            if proc_cpu > 0.5 or idx == 0:
                note_idx = (proc.info['pid'] + int(self.cpu * 10)) % len(self.scale)
                pitch = self.scale[note_idx]
                velocity = min(127, int(30 + proc_cpu * 2.5 + self.mem * 0.5))
                
                midi_out.send(mido.Message('note_on', note=pitch, velocity=velocity, channel=0))
                self.active_notes[pitch] = velocity
                
                # Render synth audio burst locally for real-time sound-reactive shader feed
                freq = 440.0 * (2.0 ** ((pitch - 69) / 12.0))
                self.generate_tone(freq, duration=0.18, volume=min(1.0, velocity / 127.0 * 0.4))

# Set up ModernGL Window and Shaders
pygame.display.set_mode((1280, 720), pygame.OPENGL | pygame.DOUBLEBUF)
pygame.display.set_caption("GLSL Audio-Reactive Fractal - Real-Time System Metrics")
ctx = moderngl.create_context()

VERT_SHADER = """
#version 330
in vec2 in_vert;
out vec2 uv;
void main() {
    uv = in_vert;
    gl_Position = vec4(in_vert, 0.0, 1.0);
}
"""

FRAG_SHADER = """
#version 330
uniform vec2 iResolution;
uniform float iTime;
uniform float u_cpu;
uniform float u_mem;
uniform float u_audio;
out vec4 fragColor;

// GLSL Evolving Audio-Reactive Mandelbox/Julia Fractal Hybrid
vec2 complexSquare(vec2 c) {
    return vec2(c.x * c.x - c.y * c.y, 2.0 * c.x * c.y);
}

void main() {
    vec2 st = (gl_FragCoord.xy - 0.5 * iResolution.xy) / iResolution.y;
    
    // Morph fractal parameters dynamically with CPU, Memory, and Audio pulses
    float zoom = 1.2 + sin(iTime * 0.5 + u_cpu * 0.05) * 0.4;
    vec2 c = vec2(-0.7 + sin(iTime * 0.2) * 0.1, 0.27015 + cos(iTime * 0.3) * 0.1);
    c += vec2(u_cpu * 0.002, u_mem * 0.002);
    
    vec2 z = st * zoom;
    float iter = 0.0;
    float max_iter = 64.0 + u_cpu * 0.6;
    
    float trap = 1e10;
    
    for (float i = 0.0; i < 128.0; i++) {
        if (i >= max_iter) break;
        
        // Audio reactive displacement
        z = complexSquare(z) + c + vec2(sin(z.y * 3.0 + iTime + u_audio) * 0.05, cos(z.x * 3.0 + u_audio) * 0.05);
        
        // Orbit trap for rich volumetric rendering
        trap = min(trap, length(z - vec2(sin(iTime), cos(iTime))));
        
        if (dot(z, z) > 4.0) {
            iter = i;
            break;
        }
    }
    
    // Procedural color mapping driven by memory and CPU load
    float t = iter / max_iter;
    vec3 col1 = vec3(0.1, 0.5, 0.9) * (1.0 + u_cpu * 0.02);
    vec3 col2 = vec3(0.9, 0.2, 0.4) * (1.0 + u_mem * 0.02);
    vec3 baseCol = mix(col1, col2, sin(t * 10.0 + iTime) * 0.5 + 0.5);
    
    // Add audio-reactive pulse glow
    baseCol += vec3(0.2, 0.8, 0.5) * (1.0 / (trap + 0.1)) * u_audio * 0.3;
    
    fragColor = vec4(baseCol * (1.0 - t), 1.0);
}
"""

prog = ctx.program(vertex_shader=VERT_SHADER, fragment_shader=FRAG_SHADER)
vbo = ctx.buffer(data=bytes([
    -1, -1,  1, -1, -1,  1,
    -1,  1,  1, -1,  1,  1,
], 'f4'))
vao = ctx.simple_vertex_array(prog, vbo, 'in_vert')

# Metrics & Midi Engine Async Thread Execution
engine = MetricsScoreEngine()
metrics_thread = threading.Thread(target=engine.update_metrics, daemon=True)
metrics_thread.start()

clock = pygame.time.Clock()
start_time = time.time()

# Real-time event and rendering loop
running = True
while running:
    for event in pygame.event.get():
        if event.type == pygame.QUIT or (event.type == pygame.KEYDOWN and event.key == pygame.K_ESCAPE):
            running = False

    t = time.time() - start_time
    audio_pulse = sum(engine.active_notes.values()) / (len(engine.active_notes) * 127.0 if engine.active_notes else 1.0)

    # Pass live telemetry to GLSL Shader
    prog['iResolution'].value = (1280.0, 720.0)
    prog['iTime'].value = t
    prog['u_cpu'].value = engine.cpu
    prog['u_mem'].value = engine.mem
    prog['u_audio'].value = audio_pulse

    ctx.clear(0.0, 0.0, 0.0)
    vao.render(moderngl.TRIANGLES)
    pygame.display.flip()
    clock.tick(60)

engine.running = False
pygame.quit()