import time
import math
import sys

# Sunset ANSI color palette stages (RGB values)
SUNSET_STAGES = [
    (25, 25, 112),   # Midnight Blue
    (75, 0, 130),    # Indigo
    (255, 69, 0),    # Orange Red
    (255, 140, 0),   # Dark Orange
    (255, 215, 0),   # Gold
    (72, 61, 139)    # Dark Slate Blue
]

# Poetic fragments reflecting migratory journeys
POETRY_LINES = [
    "Wings beat against the fading violet tide,",
    "A fragile pulse echoing ancient skies.",
    "Gold threads of light dissolve in deepening dusk,",
    "We chart the wind where northern shadows sleep.",
    "A rhythmic spark across the freezing dark,",
    "The horizon bends beneath a fiery breath."
]

def interpolate_color(c1, c2, factor):
    """Linear interpolation between two RGB color tuples."""
    return tuple(int(c1[i] + (c2[i] - c1[i]) * factor) for i in range(3))

def rgb_to_ansi(rgb):
    """Convert RGB tuple to 24-bit ANSI terminal color escape code."""
    return f"\033[38;2;{rgb[0]};{rgb[1]};{rgb[2]}m"

def generate_heartbeat_wave(t, bpm=140):
    """Simulate a high-frequency migratory bird heartbeat rhythm."""
    beat_freq = bpm / 60.0
    phase = (t * beat_freq) % 1.0
    if phase < 0.15:
        return math.sin(phase * math.pi / 0.15) * 2.0
    elif phase < 0.3:
        return -math.sin((phase - 0.15) * math.pi / 0.15) * 0.5
    else:
        return math.sin(t * 3.0) * 0.2

def main():
    width = 60
    height = 10
    total_steps = 45
    
    # Hide terminal cursor for smooth rendering
    sys.stdout.write("\033[?25l")
    sys.stdout.flush()
    
    try:
        for step in range(total_steps):
            t = step * 0.25
            
            # Dynamically compute sunset transition color
            stage_idx = (step // 8) % len(SUNSET_STAGES)
            next_stage_idx = (stage_idx + 1) % len(SUNSET_STAGES)
            factor = (step % 8) / 8.0
            current_rgb = interpolate_color(SUNSET_STAGES[stage_idx], SUNSET_STAGES[next_stage_idx], factor)
            color_code = rgb_to_ansi(current_rgb)
            
            # Reset cursor to top-left of the frame
            sys.stdout.write("\033[H")
            
            sys.stdout.write(f"{color_code}=== MIGRATORY PULSE ENGINE | STAGE {step+1}/{total_steps} ===\033[0m\n\n")
            
            # Generate ASCII wave interference pattern modulated by heartbeat
            hb = generate_heartbeat_wave(t)
            for y in range(height):
                line = []
                for x in range(width):
                    v = math.sin(x * 0.2 + t) + math.cos(y * 0.3 - t * 0.5) + hb * 1.5
                    char_idx = int(abs(v * 3)) % len(" .:-=+*#%@")
                    line.append(" .:-=+*#%@"[char_idx])
                sys.stdout.write(f"{color_code}{''.join(line)}\033[0m\n")
            
            # Render corresponding generative poetry line
            poetry_line = POETRY_LINES[step % len(POETRY_LINES)]
            sys.stdout.write(f"\n  \033[3m\"{poetry_line}\"\033[0m\n")
            
            sys.stdout.flush()
            time.sleep(0.12)
            
    finally:
        # Restore terminal cursor and color state
        sys.stdout.write("\033[?25h")
        sys.stdout.write("\033[0m\nMigration complete.\n")
        sys.stdout.flush()

if __name__ == "__main__":
    main()