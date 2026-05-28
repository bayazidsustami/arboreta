import os, sys, random, struct, math, matplotlib.pyplot as plt

# ==================== DNA MARKERS ====================
DNA_START = "#===DNA-START===\n"
DNA_END   = "#===DNA-END===\n"

# ==================== Helpers ====================

def read_own_source():
    with open(__file__, "r", encoding="utf-8") as f:
        return f.readlines()

def extract_dna(lines):
    try:
        s = lines.index(DNA_START) + 1
        e = lines.index(DNA_END)
        return [l.rstrip("\n") for l in lines[s:e]]
    except ValueError:
        return []  # no DNA yet

def dna_to_bits(dna):
    bits = []
    for line in dna:
        for ch in line:
            if ch == ' ':
                bits.append(0)
            elif ch == '\t':
                bits.append(1)
    return bits

def bits_to_notes(bits):
    # group into 7‑bit note values (0‑127), ignore incomplete group
    notes = []
    for i in range(0, len(bits)//7*7, 7):
        val = 0
        for b in bits[i:i+7]:
            val = (val << 1) | b
        notes.append(val)
    if not notes:  # ensure we have something
        notes = [60]  # middle C
    return notes

def write_midi(notes, filename="output.mid"):
    # Very tiny Type‑0 MIDI writer (single track)
    def varlen(n):
        out = b""
        while True:
            out = struct.pack("B", n & 0x7F) + out
            n >>= 7
            if n == 0:
                break
        return out[:-1] + struct.pack("B", out[-1] | 0x80)

    track = b""
    time = 0
    for n in notes:
        delta = varlen(time)
        track += delta + b'\x90' + struct.pack("BB", n % 128, 100)  # note on
        delta = varlen(240)  # duration
        track += delta + b'\x80' + struct.pack("BB", n % 128, 0)    # note off
        time = 0

    # end of track
    track += varlen(0) + b'\xFF\x2F\x00'

    # header chunk
    header = b'MThd' + struct.pack(">IHHH", 6, 1, 1, 480)
    # track chunk
    trk = b'MTrk' + struct.pack(">I", len(track)) + track
    with open(filename, "wb") as f:
        f.write(header + trk)

def draw_vortex(notes):
    plt.figure(figsize=(6,6))
    t = [i for i in range(len(notes))]
    r = [0.5 + 0.5*math.sin(n/12.0) for n in notes]
    x = [r[i]*math.cos(2*math.pi*i/len(notes)) for i in range(len(notes))]
    y = [r[i]*math.sin(2*math.pi*i/len(notes)) for i in range(len(notes))]
    sc = plt.scatter(x, y, c=notes, cmap="viridis", s=50, edgecolor="k")
    plt.axis('equal')
    plt.axis('off')
    plt.title("DNA Melody Vortex")
    plt.colorbar(sc, label="MIDI pitch")
    plt.savefig("vortex.png")
    plt.close()

def mutate_dna(dna, rate=0.02):
    new_dna = []
    for line in dna:
        chars = list(line)
        for i in range(len(chars)):
            if random.random() < rate:
                chars[i] = ' ' if chars[i] == '\t' else '\t'
        # possibly add/remove a whitespace char
        if random.random() < rate:
            if random.random() < 0.5 and chars:
                del chars[random.randrange(len(chars))]
            else:
                chars.insert(random.randrange(len(chars)+1), random.choice([' ', '\t']))
        new_dna.append(''.join(chars))
    # occasionally insert a new random line
    if random.random() < rate:
        new_line = ''.join(random.choice([' ', '\t']) for _ in range(random.randint(5,15)))
        new_dna.append(new_line)
    return new_dna

def rebuild_source(lines, new_dna):
    try:
        s = lines.index(DNA_START) + 1
        e = lines.index(DNA_END)
        before = lines[:s]
        after  = lines[e:]
        middle = [l+"\n" for l in new_dna]
        return before + middle + after
    except ValueError:
        # no markers – append at end
        return lines + [DNA_START] + [l+"\n" for l in new_dna] + [DNA_END]

# ==================== Main ====================

def main():
    lines = read_own_source()
    dna = extract_dna(lines)

    if not dna:  # first run – create random DNA
        dna = [''.join(random.choice([' ', '\t']) for _ in range(random.randint(8,20))) for _ in range(12)]

    bits = dna_to_bits(dna)
    notes = bits_to_notes(bits)

    write_midi(notes)
    draw_vortex(notes)

    mutated = mutate_dna(dna)
    new_source = rebuild_source(lines, mutated)

    # rewrite itself
    with open(__file__, "w", encoding="utf-8") as f:
        f.writelines(new_source)

if __name__ == "__main__":
    main()
#===DNA-START===
     
	     
	 	 
  	 	
 	   

#===DNA-END===