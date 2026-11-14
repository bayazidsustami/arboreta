import os
import sys
import time
import random
import math
import socket

# ANSI Escape Sequences for terminal manipulation
CLEAR_SCREEN = "\033[2J"
HIDE_CURSOR = "\033[?25l"
SHOW_CURSOR = "\033[?25h"
MOVE_HOME = "\033[H"

def get_network_latency():
    """Measure real-time network latency to drive watercolor bleeding chaos."""
    start = time.time()
    try:
        conn = socket.create_connection(("8.8.8.8", 53), timeout=0.15)
        conn.close()
        latency = (time.time() - start) * 1000
    except (socket.timeout, socket.error):
        latency = 250.0  # Simulated high latency spike on packet drop/delay
    return max(5.0, min(latency, 600.0))

def generate_ghost_shape(width, height):
    """Generate a procedural silhouette mask for a friendly ghost."""
    grid = [[0.0 for _ in range(width)] for _ in range(height)]
    cx, cy = width // 2, height // 2 - 2
    for y in range(height):
        for x in range(width):
            dx = (x - cx) / (width / 3.5)
            dy = (y - cy) / (height / 2.8)
            
            # Rounded head and flowing body
            if dx*dx + dy*dy <= 1.0 and y <= cy + 2:
                grid[y][x] = 1.0
            elif abs(dx) <= 0.85 and cy + 2 < y < height - 2:
                # Create wavy bottom tails
                wave = math.sin(x * 0.9) * 0.25
                if y < height - 2 + wave * 3:
                    grid[y][x] = 0.85
    return grid

def main():
    width, height = 44, 22
    ghost_mask = generate_ghost_shape(width, height)
    
    # Initialize color grid with ethereal watercolor hues (RGB)
    colors = [[[random.randint(170, 210), random.randint(180, 230), random.randint(220, 255)] 
               for _ in range(width)] for _ in range(height)]
    
    chars = " .·:=*#%@$"
    
    print(HIDE_CURSOR, end="")
    print(CLEAR_SCREEN, end="")
    
    try:
        step = 0
        while True:
            latency = get_network_latency()
            spike_factor = latency / 200.0
            
            print(MOVE_HOME, end="")
            print(f"\033[1;35m ~ GHOSTLY WATERCOLOUR PORTRAIT ~ \033[0m")
            print(f"\033[90mNetwork Latency Spike: {latency:.1f}ms (Intensity: {spike_factor:.2f})\033[0m\n")
            
            # Water color diffusion simulation influenced by latency spikes
            new_colors = [row[:] for row in colors]
            for y in range(height):
                for x in range(width):
                    if ghost_mask[y][x] > 0:
                        r_sum, g_sum, b_sum = colors[y][x]
                        count = 1
                        for ny, nx in [(y-1,x), (y+1,x), (y,x-1), (y,x+1)]:
                            if 0 <= ny < height and 0 <= nx < width:
                                r_sum += colors[ny][nx][0]
                                g_sum += colors[ny][nx][1]
                                b_sum += colors[ny][nx][2]
                                count += 1
                        
                        avg_r = r_sum / count
                        avg_g = g_sum / count
                        avg_b = b_sum / count
                        
                        # Pigment bleeding caused by network jitter
                        bleed_r = (random.random() - 0.5) * 50 * spike_factor
                        bleed_g = (random.random() - 0.5) * 50 * spike_factor
                        bleed_b = (random.random() - 0.5) * 70 * spike_factor
                        
                        nr = max(40, min(255, int(avg_r * 0.75 + colors[y][x][0] * 0.25 + bleed_r)))
                        ng = max(40, min(255, int(avg_g * 0.75 + colors[y][x][1] * 0.25 + bleed_g)))
                        nb = max(100, min(255, int(avg_b * 0.75 + colors[y][x][2] * 0.25 + bleed_b)))
                        
                        new_colors[y][x] = [nr, ng, nb]
            
            colors = new_colors
            
            # Render frame using ANSI 24-bit truecolor
            for y in range(height):
                line = []
                for x in range(width):
                    mask = ghost_mask[y][x]
                    if mask > 0:
                        r, g, b = colors[y][x]
                        char_idx = int((mask + math.sin(step + x * 0.3) * 0.15) * (len(chars) - 1))
                        char_idx = max(0, min(char_idx, len(chars) - 1))
                        ch = chars[char_idx]
                        line.append(f"\033[38;2;{r};{g};{b}m{ch}\033[0m")
                    else:
                        line.append(" ")
                print("".join(line))
            
            step += 0.25
            time.sleep(0.12)
            
    except KeyboardInterrupt:
        pass
    finally:
        print(SHOW_CURSOR, end="")
        print("\n")

if __name__ == "__main__":
    main()