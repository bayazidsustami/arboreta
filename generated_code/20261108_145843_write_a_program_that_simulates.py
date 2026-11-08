import random
import os
import time
import sys

# Terminal grid dimensions
WIDTH = 60
HEIGHT = 20

# Initialize cellular automata grid and cell age tracking
grid = [[random.choice([0, 0, 0, 1]) for _ in range(WIDTH)] for _ in range(HEIGHT)]
age = [[0 for _ in range(WIDTH)] for _ in range(HEIGHT)]

# Initial rule set: Conway's Game of Life (Birth on 3, Survive on 2 or 3)
birth_rule = {3}
survive_rule = {2, 3}

# ASCII characters representing glowing intensity based on cell age
CHARS = " .:-=+*#%@"

def get_neighbors(g, r, c):
    """Count living Moore neighbors around a cell."""
    count = 0
    for dr in [-1, 0, 1]:
        for dc in [-1, 0, 1]:
            if dr == 0 and dc == 0:
                continue
            nr, nc = r + dr, c + dc
            if 0 <= nr < HEIGHT and 0 <= nc < WIDTH:
                if g[nr][nc] > 0:
                    count += 1
    return count

def mutate_rule():
    """Mutate the cellular automata rule set when a cell hits the boundary."""
    global birth_rule, survive_rule
    b_size = random.randint(1, 3)
    s_size = random.randint(1, 4)
    birth_rule = set(random.sample(range(1, 9), b_size))
    survive_rule = set(random.sample(range(1, 9), s_size))

def main():
    global grid, age
    # Clear screen and hide cursor for smooth rendering
    sys.stdout.write("\033[2J\033[?25l")
    sys.stdout.flush()
    
    try:
        for step in range(500):
            new_grid = [[0 for _ in range(WIDTH)] for _ in range(HEIGHT)]
            new_age = [[0 for _ in range(WIDTH)] for _ in range(HEIGHT)]
            boundary_touched = False
            
            for r in range(HEIGHT):
                for c in range(WIDTH):
                    neighbors = get_neighbors(grid, r, c)
                    is_alive = grid[r][c] > 0
                    
                    # Apply cellular automata rules
                    if is_alive:
                        if neighbors in survive_rule:
                            new_grid[r][c] = 1
                            new_age[r][c] = age[r][c] + 1
                        else:
                            new_grid[r][c] = 0
                    else:
                        if neighbors in birth_rule:
                            new_grid[r][c] = 1
                            new_age[r][c] = 1
                            
                    # Check if a living cell touches any screen boundary
                    if new_grid[r][c] == 1 and (r == 0 or r == HEIGHT - 1 or c == 0 or c == WIDTH - 1):
                        boundary_touched = True
                        
            if boundary_touched:
                mutate_rule()
                
            grid = new_grid
            age = new_age
            
            # Render ANSI ASCII mosaic with glowing color shifts
            output = ["\033[H"]
            output.append(f"Step: {step:03d} | Birth: {sorted(list(birth_rule))} | Survive: {sorted(list(survive_rule))}\n")
            output.append("+" + "-" * WIDTH + "+\n")
            for r in range(HEIGHT):
                row_str = "|"
                for c in range(WIDTH):
                    if grid[r][c] == 1:
                        a = age[r][c]
                        char_idx = min(a, len(CHARS) - 1)
                        color_code = 31 + (a % 6)
                        row_str += f"\033[1;{color_code}m{CHARS[char_idx]}\033[0m"
                    else:
                        row_str += " "
                row_str += "|\n"
                output.append(row_str)
            output.append("+" + "-" * WIDTH + "+")
            
            sys.stdout.write("".join(output))
            sys.stdout.flush()
            time.sleep(0.08)
    except KeyboardInterrupt:
        pass
    finally:
        # Restore cursor
        sys.stdout.write("\033[?25h\n")
        sys.stdout.flush()

if __name__ == "__main__":
    main()