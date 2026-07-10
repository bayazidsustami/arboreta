#!/usr/bin/env python3
"""
Simple 1‑dimensional cellular automaton visualizer.
Uses elementary cellular automaton rules (0‑255). The default is Rule 30.
Run without arguments for an interactive demo, or pass a rule number
and number of generations, e.g.:

    python ca.py 110 50
"""

import sys
import argparse
from typing import List

def int_to_rule(rule_num: int) -> List[int]:
    """Convert a rule number (0‑255) to a list of 8 bits."""
    return [(rule_num >> i) & 1 for i in range(7, -1, -1)]

def evolve(state: List[int], rule: List[int]) -> List[int]:
    """Compute next generation of the automaton."""
    n = len(state)
    # periodic boundary conditions (wrap around)
    return [
        rule[(state[(i - 1) % n] << 2) |
              (state[i] << 1) |
              state[(i + 1) % n])]
        for i in range(n)
    ]

def render(state: List[int]) -> str:
    """Render a state as a string: live cells as █, dead as space."""
    return ''.join('█' if cell else ' ' for cell in state)

def main() -> None:
    parser = argparse.ArgumentParser(description="Elementary cellular automaton")
    parser.add_argument("rule", nargs='?', type=int, default=30,
                        help="Rule number (0‑255), default 30")
    parser.add_argument("steps", nargs='?', type=int, default=40,
                        help="Number of generations to display, default 40")
    parser.add_argument("-w", "--width", type=int, default=79,
                        help="Width of the universe, default 79")
    args = parser.parse_args()

    rule = int_to_rule(args.rule & 0xFF)
    # start with a single live cell in the middle
    state = [0] * args.width
    state[args.width // 2] = 1

    for _ in range(args.steps):
        print(render(state))
        state = evolve(state, rule)

if __name__ == "__main__":
    main()