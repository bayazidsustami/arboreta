import sys, os, re, time, math, random, threading

# ----- poem input (edit this block) -----
POEM = """\
the moon whispers soft
over the silent sea
waves kiss the night
and stars sigh in melody"""
# ----------------------------------------

# simple syllable estimator: count vowel groups
def syllable_count(line):
    return len(re.findall(r'[aeiouy]+', line.lower()))
    
# extract rhyme key (last 2 letters of last word)
def rhyme_key(line):
    words = re.findall(r"[a-zA-Z']+", line)
    if not words: return ''
    return words[-1].lower()[-2:]

# very naive sentiment polarity (+1 happy, -1 sad, 0 neutral)
POS_WORDS = {"soft","whispers","kiss","sigh","melody","star","moon","silently"}
NEG_WORDS = {"dark","lonely","cold","sad","pain"}
def sentiment(line):
    pos = sum(w in POS_WORDS for w in re.findall(r"\w+", line.lower()))
    neg = sum(w in NEG_WORDS for w in re.findall(r"\w+", line.lower()))
    return (pos - neg)

# compute poem metrics
lines = [l for l in POEM.splitlines() if l.strip()]
syllables = sum(syllable_count(l) for l in lines)
rhyme_scheme = [rhyme_key(l) for l in lines]
sentiment_score = sum(sentiment(l) for l in lines)

# initial offsets for each line (degrees)
# This list will be self‑modified by the running program
offsets = [0, 0, 0, 0]  # placeholder; will be replaced on first run

# ----- self‑modifying helper -----
def update_source(new_offsets):
    src_path = os.path.abspath(sys.argv[0])
    with open(src_path, 'r', encoding='utf-8') as f:
        src = f.read()
    # replace the offsets line
    new_line = f'offsets = {new_offsets}  # placeholder; will be replaced on first run'
    src = re.sub(r'offsets = \[.*?\]  # placeholder; will be replaced on first run',
                 new_line, src, flags=re.S)
    with open(src_path, 'w', encoding='utf-8') as f:
        f.write(src)

# ANSI color helper (HSV → RGB → 256‑color)
def hsv_to_ansi(h, s=1, v=1):
    h = h % 360
    c = v * s
    x = c * (1 - abs((h/60) % 2 - 1))
    m = v - c
    if h < 60: r,g,b = c,x,0
    elif h < 120: r,g,b = x,c,0
    elif h < 180: r,g,b = 0,c,x
    elif h < 240: r,g,b = 0,x,c
    elif h < 300: r,g,b = x,0,c
    else: r,g,b = c,0,x
    r,g,b = [int((v+m)*255) for v in (r,g,b)]
    # approximate to 256‑color
    return 16 + 36*round(r/255*5) + 6*round(g/255*5) + round(b/255*5)

def clear():
    sys.stdout.write('\033[2J\033[H')
    sys.stdout.flush()

def draw():
    clear()
    t = time.time()
    for i, line in enumerate(lines):
        # rotation speed driven by syllable count
        speed = 0.2 + 0.05 * (syllables % 5)
        phase = math.radians(offsets[i]) + t * speed
        # horizontal wobble
        dx = int(10 * math.sin(phase))
        # vertical placement
        y = i * 2 + 5
        # color shift driven by sentiment and rhyme similarity
        hue = (sentiment_score * 30 + i * 90 + (rhyme_scheme[i] and ord(rhyme_scheme[i][0])*2 or 0)) % 360
        hue = (hue + t*20) % 360
        color = hsv_to_ansi(hue)
        sys.stdout.write(f'\033[{y};{dx+10}H\033[38;5;{color}m{line}\033[0m')
    sys.stdout.flush()

def animate():
    while True:
        draw()
        # evolve offsets slightly each frame (mathematically driven)
        new_offsets = [(off + random.choice([-1,0,1]) + int(syllables*0.1)) % 360 for off in offsets]
        update_source(new_offsets)
        # load new offsets for next iteration
        globals()['offsets'][:] = new_offsets
        time.sleep(0.1)

if __name__ == '__main__':
    # if offsets placeholder untouched, initialise them
    if offsets == [0, 0, 0, 0]:
        offsets = [i*90 for i in range(len(lines))]
        update_source(offsets)
    try:
        animate()
    except KeyboardInterrupt:
        clear()
        sys.exit(0)