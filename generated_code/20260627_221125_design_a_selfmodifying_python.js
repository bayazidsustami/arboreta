const fs = require('fs');
const path = 'selfmod.py';
const pythonCode = `# Self-modifying Python script that animates an 8‑bit grayscale image encoded in whitespace.
# The image is 16×16 pixels, each pixel stored as 8 whitespace characters (space=0, tab=1) between markers.
# On each run the script reads its own source, decodes the image, applies a simple cellular automaton,
# then rewrites itself with the new image encoded back into the whitespace region.

import os, sys, re

WIDTH, HEIGHT = 16, 16
MARKER_START = '# BEGIN IMAGE'
MARKER_END = '# END IMAGE'

def read_source():
    with open(__file__, 'r', encoding='utf-8') as f:
        return f.read()

def extract_whitespace(src):
    pattern = re.compile(rf'({MARKER_START}\\n)([ \\t\\n]*?)({MARKER_END})', re.MULTILINE)
    m = pattern.search(src)
    if not m:
        sys.exit('Image markers not found')
    return m.start(2), m.end(2), m.group(2)

def decode_image(ws):
    bits = [1 if c == '\\t' else 0 for c in ws if c in (' ', '\\t')]
    if len(bits) < WIDTH*HEIGHT*8:
        sys.exit('Not enough bits')
    bytes_ = [int(''.join(str(b) for b in bits[i:i+8]), 2) for i in range(0, WIDTH*HEIGHT*8, 8)]
    img = [bytes_[i*WIDTH:(i+1)*WIDTH] for i in range(HEIGHT)]
    return img

def encode_image(img):
    bits = []
    for row in img:
        for val in row:
            bits.extend([int(b) for b in f'{val:08b}'])
    ws = ''.join('\\t' if b else ' ' for b in bits)
    # split into lines of 128 chars for readability
    lines = [ws[i:i+128] for i in range(0, len(ws), 128)]
    return '\\n'.join(lines)

def cellular_step(img):
    new = [[0]*WIDTH for _ in range(HEIGHT)]
    for y in range(HEIGHT):
        for x in range(WIDTH):
            s = 0
            cnt = 0
            for dy in (-1,0,1):
                for dx in (-1,0,1):
                    if dy==0 and dx==0: continue
                    ny, nx = y+dy, x+dx
                    if 0<=ny<HEIGHT and 0<=nx<WIDTH:
                        s += img[ny][nx]
                        cnt += 1
            new[y][x] = s//cnt if cnt else img[y][x]
    return new

def main():
    src = read_source()
    start, end, ws = extract_whitespace(src)
    img = decode_image(ws)
    img = cellular_step(img)
    new_ws = encode_image(img)
    new_src = src[:start] + new_ws + src[end:]
    with open(__file__, 'w', encoding='utf-8') as f:
        f.write(new_src)

if __name__ == '__main__':
    main()
# BEGIN IMAGE
                                                                                                                                                                                                
# END IMAGE
`;

fs.writeFileSync(path, pythonCode, {encoding: 'utf8'});
console.log('Python self-modifying script written to', path);