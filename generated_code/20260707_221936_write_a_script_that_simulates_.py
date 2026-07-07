import sys
import argparse
import time
import os

# ----------------------------------------------------------------------
# Simple 1‑dimensional cellular automaton visualizer (e.g., Rule 30, 90, 110)
# ----------------------------------------------------------------------
# Cells are binary (0/1). The automaton evolves according to a Wolfram rule.
# The current state is printed as a line of characters, live cells as '█',
# dead cells as a space. The terminal is cleared after each frame for animation.
# ----------------------------------------------------------------------


def rule_to_table(rule_num: int) -> dict:
    """Convert rule number (0‑255) to a lookup table mapping 3‑bit patterns to output bit."""
    if not (0 <= rule_num <= 255):
        raise ValueError("Rule must be between 0 and 255.")
    bits = f"{rule_num:08b}"                # 8‑bit binary string
    patterns = [(7 - i) for i in range(8)]  # 111,110,...,000 as integers
    return {p: int(b) for p, b in zip(patterns, bits)}


def step(state: list[int], table: dict[int, int]) -> list[int]:
    """One evolution step using periodic boundary conditions."""
    n = len(state)
    new = [0] * n
    for i in range(n):
        left = state[(i - 1) % n]
        center = state[i]
        right = state[(i + 1) % n]
        pattern = (left << 2) | (center << 1) | right
        new[i] = table[pattern]
    return new


def render(state: list[int]) -> str:
    """Return a printable string for a given state."""
    return "".join('█' if cell else ' ' for cell in state)


def animate(width: int, steps: int, rule: int, delay: float, seed: str | None):
    """Run the automaton and animate it in the terminal."""
    table = rule_to_table(rule)

    # initialise with a single live cell in the centre, or a custom seed
    if seed:
        state = [1 if ch == '1' else 0 for ch in seed[:width].ljust(width, '0')]
    else:
        state = [0] * width
        state[width // 2] = 1

    for _ in range(steps):
        # clear screen (works on most Unix terminals and Windows 10+)
        os.system('cls' if os.name == 'nt' else 'clear')
        print(render(state))
        state = step(state, table)
        time.sleep(delay)


def main():
    parser = argparse.ArgumentParser(description="Simple 1‑D cellular automaton.")
    parser.add_argument("-w", "--width", type=int, default=80,
                        help="Number of cells per line (default: 80)")
    parser.add_argument("-s", "--steps", type=int, default=200,
                        help="Number of generations to display (default: 200)")
    parser.add_argument("-r", "--rule", type=int, default=30,
                        help="Wolfram rule number (0‑255, default: 30)")
    parser.add_argument("-d", "--delay", type=float, default=0.05,
                        help="Seconds between frames (default: 0.05)")
    parser.add_argument("-e", "--seed", type=str, default=None,
                        help="Optional binary seed string (e.g., 10110)")
    args = parser.parse_args()

    try:
        animate(args.width, args.steps, args.rule, args.delay, args.seed)
    except KeyboardInterrupt:
        sys.exit("\nAnimation interrupted.")


if __name__ == "__main__":
    main()