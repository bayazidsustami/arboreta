import numpy as np
import matplotlib.pyplot as plt
from matplotlib.animation import FuncAnimation

# Lorenz system parameters
SIGMA = 10.0
RHO = 28.0
BETA = 8.0 / 3.0

# Simulation setup for the migrating flock
NUM_FLOCK = 45
DT = 0.015

# Initialize particle positions in 3D space near the attractor
positions = np.random.randn(NUM_FLOCK, 3) * 5.0 + np.array([0.0, 0.0, 25.0])

# Typographic glyph pool representing evolutionary/temperature mutation states
GLYPHS = ['λ', 'Ω', 'Ψ', 'Φ', 'Σ', '§', '¶', '‡', '†', '•', '°', '∗']

# Setup dark-themed canvas for glowing aesthetics
fig = plt.figure(figsize=(12, 10))
fig.patch.set_facecolor('#08080c')
ax = fig.add_subplot(111, projection='3d')
ax.set_facecolor('#08080c')
ax.axis('off')

# Initialize text artists for each migrating glyph in the flock
text_artists = []
for _ in range(NUM_FLOCK):
    t = ax.text(0, 0, 0, '', color='white', ha='center', va='center', fontweight='bold')
    text_artists.append(t)

def update(frame):
    global positions
    
    # Compute Lorenz attractor derivatives
    x, y, z = positions[:, 0], positions[:, 1], positions[:, 2]
    dx = SIGMA * (y - x)
    dy = x * (RHO - z) - y
    dz = x * y - BETA * z
    
    # Update positions using Euler integration
    positions[:, 0] += dx * DT
    positions[:, 1] += dy * DT
    positions[:, 2] += dz * DT
    
    # Add organic flocking jitter
    positions += np.random.normal(0, 0.15, positions.shape)
    
    # Calculate local temperature field based on vertical height and radius
    temperatures = np.clip((positions[:, 2] - 5.0) / 35.0, 0.0, 1.0)
    
    for i, t in enumerate(text_artists):
        px, py, pz = positions[i]
        temp = temperatures[i]
        
        # Mutate typographic glyph shape based on local temperature
        glyph_idx = int(temp * (len(GLYPHS) - 1))
        glyph = GLYPHS[glyph_idx]
        
        # Mutate typography size with temperature intensity
        fontsize = 8 + int(temp * 18)
        
        # Dynamic glowing color gradient (cyan to fiery orange-magenta)
        r = min(1.0, temp * 1.5)
        g = max(0.2, 1.0 - temp)
        b = 0.9
        color = (r, g, b)
        
        # Update artist properties
        t.set_position((px, py))
        t.set_3d_properties(pz, zdir='z')
        t.set_text(glyph)
        t.set_fontsize(fontsize)
        t.set_color(color)
        
    # Lock camera perspective on the attractor bounding box
    ax.set_xlim(-25, 25)
    ax.set_ylim(-30, 30)
    ax.set_zlim(0, 50)
    return text_artists

# Run the generative art animation
anim = FuncAnimation(fig, update, frames=400, interval=25, blit=False)
plt.show()