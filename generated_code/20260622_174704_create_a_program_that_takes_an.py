import sys, math, random, itertools, tempfile, subprocess, os, json
from collections import defaultdict

# External dependencies: mido, music21, numpy
# Install with: pip install mido music21 numpy

try:
    import mido
    from music21 import converter, chord, instrument, analysis, stream
    import numpy as np
except ImportError as e:
    sys.stderr.write("Missing required module: %s\n" % e.name)
    sys.exit(1)

# ---------- Helper functions ----------
def midi_to_stream(mid_path):
    """Convert MIDI file to music21 stream."""
    return converter.parse(mid_path)

def extract_chords(s):
    """Return list of (offset, chord) tuples from stream."""
    chords = []
    for c in s.chordify().recurse().getElementsByClass('Chord'):
        chords.append((c.offset, c))
    return chords

def chord_to_rule(ch):
    """Map a chord to an L-system production rule."""
    root = ch.root().name  # e.g., 'C', 'D#'
    quality = ch.quality
    # Simple deterministic mapping: each pitch class gets a unique string
    pcs = ch.pitches
    rule_body = ""
    for p in pcs:
        # use + and - based on pitch class parity
        sign = '+' if p.midi % 2 == 0 else '-'
        rule_body += chr(65 + (p.midi % 26)) + sign
    return (root, rule_body)

def generate_lsystem(axiom, rules, depth):
    """Iteratively apply L-system rules."""
    cur = axiom
    for _ in range(depth):
        nxt = []
        for sym in cur:
            if sym in rules:
                nxt.append(rules[sym])
            else:
                nxt.append(sym)
        cur = ''.join(nxt)
    return cur

def turtle_path(lsys, angle=25, step=10):
    """Interpret L-system string as turtle graphics, return list of line segments."""
    x, y = 0.0, 0.0
    angle_rad = math.radians(angle)
    dir_angle = 0.0
    stack = []
    segments = []
    for cmd in lsys:
        if cmd.isalpha():
            nx = x + step * math.cos(dir_angle)
            ny = y + step * math.sin(dir_angle)
            segments.append(((x, y), (nx, ny), cmd))
            x, y = nx, ny
        elif cmd == '+':
            dir_angle += angle_rad
        elif cmd == '-':
            dir_angle -= angle_rad
        elif cmd == '[':
            stack.append((x, y, dir_angle))
        elif cmd == ']':
            x, y, dir_angle = stack.pop()
    return segments

def midi_tempo(mid):
    """Extract tempo (microseconds per beat) from MIDI meta messages."""
    for track in mid.tracks:
        for msg in track:
            if msg.type == 'set_tempo':
                return msg.tempo  # microseconds per beat
    return 500000  # default 120 BPM

def midi_key(mid):
    """Rough key detection using first key signature meta."""
    for track in mid.tracks:
        for msg in track:
            if msg.type == 'key_signature':
                return msg.key
    return 'C'

def velocity_color(vel):
    """Map MIDI velocity (0-127) to a hue."""
    hue = int(240 * (1 - vel / 127.0))  # blue (fast) to red (slow)
    return f"hsl({hue},80%,60%)"

def create_svg(frames, width=800, height=600, duration=10):
    """Assemble animated SVG from frame data."""
    svg_parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="-400 -300 800 600">']
    total_frames = len(frames)
    for i, segs in enumerate(frames):
        opacity = 0.8 * (i+1)/total_frames
        for ((x1, y1), (x2, y2), sym, col) in segs:
            svg_parts.append(
                f'<line x1="{x1:.2f}" y1="{y1:.2f}" x2="{x2:.2f}" y2="{y2:.2f}" '
                f'stroke="{col}" stroke-width="2" opacity="{opacity}">'
                f'<animate attributeName="opacity" from="0" to="{opacity}" dur="{duration}s" '
                f'begin="{i*duration/total_frames}s" fill="freeze" /></line>'
            )
    svg_parts.append('</svg>')
    return '\n'.join(svg_parts)

# ---------- Main processing ----------
def main():
    if len(sys.argv) < 2:
        sys.stderr.write("Usage: python script.py input.mid > out.svg\n")
        sys.exit(1)

    midi_path = sys.argv[1]
    mid = mido.MidiFile(midi_path)
    tempo_us = midi_tempo(mid)
    bpm = 60_000_000 / tempo_us
    key = midi_key(mid)

    # Parse with music21 for harmonic analysis
    s = midi_to_stream(midi_path)
    s.insert(0, instrument.Piano())
    chords = extract_chords(s)

    # Build L-system rules per chord root
    rule_map = {}
    for _, ch in chords:
        root, body = chord_to_rule(ch)
        if root not in rule_map:
            rule_map[root] = body

    # Use first chord as axiom
    if chords:
        axiom_root, _ = chord_to_rule(chords[0][1])
        axiom = axiom_root
    else:
        axiom = 'A'

    # Generate frames synchronized to chord changes
    frames = []
    depth = 3
    for idx, (offset, ch) in enumerate(chords):
        # Map chord to rule (override or add)
        root, rule_body = chord_to_rule(ch)
        rule_map[root] = rule_body

        # Build rule dict for L-system
        rules = {r: rule_map[r] for r in rule_map}
        lsys_str = generate_lsystem(axiom, rules, depth)

        # Turtle graphics
        segs = turtle_path(lsys_str, angle=25, step=8)

        # Color by average velocity (approximate using chord notes velocities)
        vel = np.mean([n.velocity for n in ch.notes]) if ch.notes else 64
        col = velocity_color(vel)

        # Attach color to segment info
        colored_segs = [(p1, p2, sym, col) for (p1, p2, sym) in segs]
        frames.append(colored_segs)

        # Update axiom to last root for continuity
        axiom = root

    # Build SVG animation
    svg = create_svg(frames, width=800, height=600, duration= max(1, len(frames) * 0.5))
    sys.stdout.write(svg)

if __name__ == '__main__':
    main()