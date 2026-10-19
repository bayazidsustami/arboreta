import numpy as np
import matplotlib.pyplot as plt
import matplotlib.animation as animation

# Grid dimensions for the bioluminescent ecosystem
WIDTH, HEIGHT = 140, 140

# Initialize the grid with sparse random organic seed points
grid = np.random.rand(HEIGHT, WIDTH)
grid = np.where(grid > 0.82, 1.0, 0.0)

def update(frame, img, grid):
    """Computes the next generation of Conway's Game of Life fused with watercolor diffusion and drift."""
    # Count living neighbors using periodic boundary rolls
    neighbors = (
        np.roll(grid, 1, 0) + np.roll(grid, -1, 0) +
        np.roll(grid, 1, 1) + np.roll(grid, -1, 1) +
        np.roll(grid, (1, 1), (0, 1)) + np.roll(grid, (-1, -1), (0, 1)) +
        np.roll(grid, (1, -1), (0, 1)) + np.roll(grid, (-1, 1), (0, 1))
    )
    
    # Standard Game of Life life/death logic thresholds
    alive = grid > 0.4
    new_born = (neighbors >= 2.5) & (neighbors <= 3.5) & (~alive)
    surviving = (neighbors >= 1.5) & (neighbors <= 3.5) & alive
    
    next_state = np.zeros_like(grid)
    next_state[new_born | surviving] = 1.0
    
    # Watercolor bleed: spatial diffusion simulating ink bleeding through wet parchment
    bleed = (
        np.roll(grid, 1, 0) + np.roll(grid, -1, 0) +
        np.roll(grid, 1, 1) + np.roll(grid, -1, 1)
    ) / 4.0
    
    # Gentle directional current drift (flowing slowly down and right)
    drifted = np.roll(np.roll(grid, 1, axis=0), 1, axis=1)
    
    # Blend cellular logic with fading bioluminescent ink decay
    decay = 0.82
    grid[:] = np.clip(next_state * 0.9 + (bleed * 0.35 + drifted * 0.15) * decay, 0.0, 1.0)
    
    img.set_array(grid)
    return img,

# Setup the dark atmospheric visualization canvas
fig, ax = plt.subplots(figsize=(8, 8))
fig.patch.set_facecolor('#04060b')
ax.set_facecolor('#04060b')
ax.axis('off')

# Render with a glowing aquatic/bioluminescent colormap and smooth bicubic interpolation
img = ax.imshow(grid, cmap='ocean', interpolation='bicubic', vmin=0, vmax=1)

ani = animation.FuncAnimation(fig, update, fargs=(img, grid), interval=40, blit=True)
plt.show()