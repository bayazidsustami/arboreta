package main

import (
	"fmt"
	"os"
	"strings"
)

func main() {
	// Python script that self‑modifies and animates a mandala.
	const py = `#!/usr/bin/env python3
import sys, os, time, random, re

# HAIKU: quiet moonlight drifts
# HAIKU: blossoms whisper in wind
# HAIKU: stars pulse like heartbeats

def read_self():
    """Return the full source of this file."""
    with open(__file__, 'r', encoding='utf-8') as f:
        return f.read()

def extract_haikus(src):
    """Find all lines that start with '# HAIKU:'."""
    return re.findall(r'(?m)^# HAIKU: (.*)$', src)

def meter_from_haiku(haiku):
    """Simple meter: count syllables approximated by vowels."""
    return sum(1 for c in haiku.lower() if c in 'aeiou')

def build_mandala(radius, chars):
    """Generate a list of strings forming a circular mandala."""
    out = []
    for y in range(-radius, radius+1):
        line = ''
        for x in range(-radius, radius+1):
            d = (x*x + y*y)**0.5
            if d > radius-0.5 and d < radius+0.5:
                line += random.choice(chars)
            else:
                line += ' '
        out.append(line)
    return out

def animate(meter):
    """Animate the mandala; meter influences size and speed."""
    radius = 3 + (meter % 5)          # radius 3‑7
    chars = ['*', '+', 'o', '@']
    delay = 0.3 - (meter % 3)*0.05    # 0.3‑0.2 sec
    while True:
        mandala = build_mandala(radius, chars)
        os.system('cls' if os.name=='nt' else 'clear')
        print('\n'.join(mandala))
        time.sleep(delay)

def rotate_haikus(haikus):
    """Move first haiku to the end to evolve the poem."""
    return haikus[1:] + haikus[:1]

def rewrite_self(new_haikus):
    """Rewrite this file with updated HAiku lines."""
    src = read_self()
    # replace existing HAiku block
    new_block = '\n'.join(f'# HAIKU: {h}' for h in new_haikus)
    src = re.sub(r'(?m)(^# HAIKU: .*$\n)+', new_block + '\n', src)
    with open(__file__, 'w', encoding='utf-8') as f:
        f.write(src)

def main():
    src = read_self()
    haikus = extract_haikus(src)
    if not haikus:
        haikus = ['empty silence']
    meter = sum(meter_from_haiku(h) for h in haikus) % 10
    # update poem for next run
    rewrite_self(rotate_haikus(haikus))
    # run animation
    animate(meter)

if __name__ == '__main__':
    main()
`
	// Write the Python script to a file.
	filename := "self_mod.py"
	if err := os.WriteFile(filename, []byte(strings.TrimSpace(py)), 0755); err != nil {
		fmt.Fprintln(os.Stderr, "write error:", err)
		os.Exit(1)
	}
	fmt.Println("Python self‑modifying mandala script written to", filename)
}