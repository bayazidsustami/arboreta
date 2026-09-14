import sys
import time
import math
import struct
import threading
import collections
import numpy as np
import pygame
from pygame.locals import DOUBLEBUF, OPENGL
from OpenGL.GL import *
from OpenGL.GL.shaders import compileProgram, compileShader

# ==============================================================================
# 1. Real-time Audio Analysis & System Call Simulation
# ==============================================================================

class SystemCallMonitor(threading.Thread):
    """Simulates or intercepts system call traces and generates an audio stream."""
    def __init__(self, buffer_size=1024, sample_rate=44100):
        super().__init__()
        self.daemon = True
        self.buffer_size = buffer_size
        self.sample_rate = sample_rate
        self.running = True
        
        # Ring buffer for active system call frequencies/energies
        self.syscall_history = collections.deque(maxlen=128)
        self.current_audio_chunk = np.zeros(buffer_size, dtype=np.float32)
        self.lock = threading.Lock()
        
        # Audio feature state
        self.bass_energy = 0.0
        self.mid_energy = 0.0
        self.high_energy = 0.0
        self.syscall_density = 0.0

    def run(self):
        """Generates real-time synthetic audio-reactive syscall traces."""
        t = 0.0
        dt = 1.0 / self.sample_rate
        
        # Typical syscall categories mapped to audio frequencies (Hz)
        syscall_freqs = {
            'read': 120.0,    # Low frequency pulse
            'write': 240.0,   # Mid frequency pulse
            'mmap': 440.0,    # Resonant harmonic
            'execve': 880.0,  # High frequency transient burst
            'futex': 60.0     # Sub-bass rumble
        }
        
        while self.running:
            chunk = np.zeros(self.buffer_size, dtype=np.float32)
            
            # Simulate a burst of syscall activity
            active_calls = np.random.choice(
                list(syscall_freqs.keys()),
                size=np.random.randint(1, 4),
                p=[0.3, 0.3, 0.2, 0.05, 0.15]
            )
            
            for i in range(self.buffer_size):
                sample = 0.0
                for call in active_calls:
                    freq = syscall_freqs[call]
                    # Synthesize FM/AM modulated waves based on call trace execution
                    sample += 0.2 * math.sin(2 * math.pi * freq * t + 0.5 * math.sin(2 * math.pi * 3.0 * t))
                chunk[i] = sample
                t += dt

            # Compute FFT for audio-reactivity features
            fft_data = np.abs(np.fft.rfft(chunk))
            
            with self.lock:
                self.current_audio_chunk = chunk
                self.bass_energy = float(np.mean(fft_data[1:10]))
                self.mid_energy = float(np.mean(fft_data[10:50]))
                self.high_energy = float(np.mean(fft_data[50:150]))
                self.syscall_density = len(active_calls) / 4.0
                self.syscall_history.append(self.bass_energy + self.mid_energy)

            time.sleep(self.buffer_size / self.sample_rate)

    def stop(self):
        self.running = False


# ==============================================================================
# 2. GLSL Shaders (Mandala Synthesizer)
# ==============================================================================

VERTEX_SHADER = """
#version 330 core
layout(location = 0) in vec2 a_position;
out vec2 v_uv;

void main() {
    v_uv = a_position * 0.5 + 0.5;
    gl_Position = vec4(a_position, 0.0, 1.0);
}
"""

FRAGMENT_SHADER = """
#version 330 core
in vec2 v_uv;
out vec4 fragColor;

uniform vec2 u_resolution;
uniform float u_time;
uniform float u_bass;
uniform float u_mid;
uniform float u_high;
uniform float u_syscall_density;

#define PI 3.14159265359

// Palette generator by Inigo Quilez
vec3 palette( in float t, in vec3 a, in vec3 b, in vec3 c, in vec3 d ) {
    return a + b*cos( 6.28318*(c*t+d) );
}

void main() {
    // Normalize coordinates (-1 to 1, aspect ratio corrected)
    vec2 uv = (gl_FragCoord.xy * 2.0 - u_resolution.xy) / u_resolution.y;
    vec2 uv0 = uv;
    vec3 finalColor = vec3(0.0);
    
    // Polar conversion for radial symmetry (Mandala base)
    float r = length(uv);
    float a = atan(uv.y, uv.x);
    
    // Sycall-driven mandala symmetry count (ranges dynamically 4.0 - 12.0)
    float N = 4.0 + floor(u_syscall_density * 8.0);
    a = mod(a, 2.0 * PI / N) - PI / N;
    uv = vec2(cos(a), sin(a)) * r;

    // Iterative Raymarched Fractal Layers driven by Audio Frequencies
    for (float i = 0.0; i < 4.0; i++) {
        uv = fract(uv * (1.5 + u_mid * 0.2)) - 0.5;

        float d = length(uv) * exp(-length(uv0));

        // Color palette parameters dynamically altered by audio spectrum
        vec3 a_col = vec3(0.5, 0.5, 0.5);
        vec3 b_col = vec3(0.5, 0.5, 0.5);
        vec3 c_col = vec3(1.0, 1.0, 1.0);
        vec3 d_col = vec3(0.263 + u_high * 0.1, 0.416, 0.557 + u_bass * 0.2);

        vec3 col = palette(length(uv0) + i * 0.4 + u_time * 0.4, a_col, b_col, c_col, d_col);

        d = sin(d * 8.0 + u_time + u_bass * 3.0) / 8.0;
        d = abs(d);
        d = pow(0.01 / d, 1.2);

        finalColor += col * d;
    }

    // Dynamic glow vignette based on High frequencies
    finalColor *= (1.2 - r * 0.5) + u_high * 0.5;

    fragColor = vec4(finalColor, 1.0);
}
"""

# ==============================================================================
# 3. Main Synthesizer Engine & Renderer
# ==============================================================================

class VisualSynthesizer:
    def __init__(self, width=1280, height=720):
        self.width = width
        self.height = height
        
        pygame.init()
        pygame.display.gl_set_attribute(pygame.GL_CONTEXT_MAJOR_VERSION, 3)
        pygame.display.gl_set_attribute(pygame.GL_CONTEXT_MINOR_VERSION, 3)
        pygame.display.gl_set_attribute(pygame.GL_CONTEXT_PROFILE_MASK, pygame.GL_CONTEXT_PROFILE_CORE)
        
        self.screen = pygame.display.set_mode((self.width, self.height), DOUBLEBUF | OPENGL)
        pygame.display.set_caption("Syscall Generative Visual Synthesizer")

        self.init_gl()
        
        # Start syscall monitor and audio analysis thread
        self.monitor = SystemCallMonitor()
        self.monitor.start()

    def init_gl(self):
        """Compiles GLSL shaders and sets up vertex buffers for full-screen quad rendering."""
        self.shader = compileProgram(
            compileShader(VERTEX_SHADER, GL_VERTEX_SHADER),
            compileShader(FRAGMENT_SHADER, GL_FRAGMENT_SHADER)
        )
        glUseProgram(self.shader)

        # Full-screen quad (2 triangles)
        vertices = np.array([
            -1.0, -1.0,
             1.0, -1.0,
            -1.0,  1.0,
            -1.0,  1.0,
             1.0, -1.0,
             1.0,  1.0,
        ], dtype=np.float32)

        self.vao = glGenVertexArrays(1)
        glBindVertexArray(self.vao)

        vbo = glGenBuffers(1)
        glBindBuffer(GL_ARRAY_BUFFER, vbo)
        glBufferData(GL_ARRAY_BUFFER, vertices.nbytes, vertices, GL_STATIC_DRAW)

        position_loc = glGetAttribLocation(self.shader, "a_position")
        glEnableVertexAttribArray(position_loc)
        glVertexAttribPointer(position_loc, 2, GL_FLOAT, GL_FALSE, 0, None)

        # Uniform locations
        self.u_res_loc = glGetUniformLocation(self.shader, "u_resolution")
        self.u_time_loc = glGetUniformLocation(self.shader, "u_time")
        self.u_bass_loc = glGetUniformLocation(self.shader, "u_bass")
        self.u_mid_loc = glGetUniformLocation(self.shader, "u_mid")
        self.u_high_loc = glGetUniformLocation(self.shader, "u_high")
        self.u_syscall_density_loc = glGetUniformLocation(self.shader, "u_syscall_density")

        glUniform2f(self.u_res_loc, float(self.width), float(self.height))

    def run(self):
        """Main rendering loop."""
        clock = pygame.time.Clock()
        start_time = time.time()
        running = True

        while running:
            for event in pygame.event.get():
                if event.type == pygame.QUIT or (
                    event.type == pygame.KEYDOWN and event.key == pygame.K_ESCAPE
                ):
                    running = False

            current_time = time.time() - start_time

            # Safely query audio/syscall features
            with self.monitor.lock:
                bass = self.monitor.bass_energy
                mid = self.monitor.mid_energy
                high = self.monitor.high_energy
                density = self.monitor.syscall_density

            # Pass audio-reactive data to GLSL shader uniforms
            glUseProgram(self.shader)
            glUniform1f(self.u_time_loc, current_time)
            glUniform1f(self.u_bass_loc, bass)
            glUniform1f(self.u_mid_loc, mid)
            glUniform1f(self.u_high_loc, high)
            glUniform1f(self.u_syscall_density_loc, density)

            # Draw
            glClear(GL_COLOR_BUFFER_BIT)
            glBindVertexArray(self.vao)
            glDrawArrays(GL_TRIANGLES, 0, 6)

            pygame.display.flip()
            clock.tick(60)

        # Cleanup
        self.monitor.stop()
        pygame.quit()
        sys.exit()

if __name__ == "__main__":
    app = VisualSynthesizer()
    app.run()