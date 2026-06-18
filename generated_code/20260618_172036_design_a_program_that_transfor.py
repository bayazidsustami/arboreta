import sys, time, curses, random, re, math
try:
    import pygame.midi as midi
except ImportError:
    print("pygame.midi required")
    sys.exit(1)

# ---- Helper functions ----------------------------------------------------
def syllable_count(word):
    # naive vowel groups count as syllables
    return max(1, len(re.findall(r'[aeiouy]+', word.lower())))

def stress_pattern(word):
    # alternate stressed/unstressed based on syllable position
    cnt = syllable_count(word)
    return [1 if i % 2 == 0 else 0 for i in range(cnt)]

def word_to_note(word):
    # map average stress to a MIDI note (C4=60)
    stresses = stress_pattern(word)
    avg = sum(stresses) / len(stresses)
    return 60 + int(avg * 12)  # within one octave

def init_midi():
    midi.init()
    dev = midi.get_default_output_id()
    player = midi.Output(dev, 0)
    return player

def play_note(player, note, duration=0.1, velocity=100):
    player.note_on(note, velocity)
    time.sleep(duration)
    player.note_off(note, velocity)

# ---- Cellular automaton -------------------------------------------------
class Cell:
    def __init__(self, word):
        self.word = word
        self.alive = random.choice([0, 1])
        self.note = word_to_note(word)

def evolve(cells):
    new = []
    n = len(cells)
    for i, cell in enumerate(cells):
        left = cells[(i-1)%n].alive
        right = cells[(i+1)%n].alive
        total = left + cell.alive + right
        # simple rule: become alive if total is 2 (like Life)
        alive = 1 if total == 2 else 0
        new_cell = Cell(cell.word)
        new_cell.alive = alive
        new.append(new_cell)
    return new

# ---- Visualization -------------------------------------------------------
def draw(stdscr, cells, width):
    stdscr.clear()
    line = ''
    for cell in cells:
        if cell.alive:
            line += cell.word + ' '
        else:
            line += ' ' * (len(cell.word)+1)
        if len(line) > width:
            break
    stdscr.addstr(0,0,line[:width])
    stdscr.refresh()

# ---- Main ----------------------------------------------------------------
def main(paragraph):
    words = re.findall(r'\b\w+\b', paragraph)
    cells = [Cell(w) for w in words]

    player = init_midi()
    stdscr = curses.initscr()
    curses.noecho()
    curses.cbreak()
    stdscr.nodelay(True)

    try:
        while True:
            h, w = stdscr.getmaxyx()
            draw(stdscr, cells, w)
            # play notes of alive cells
            for cell in cells:
                if cell.alive:
                    play_note(player, cell.note, duration=0.05)
            cells = evolve(cells)
            time.sleep(0.2)
            if stdscr.getch() == ord('q'):
                break
    finally:
        curses.nocbreak()
        curses.echo()
        curses.endwin()
        player.close()
        midi.quit()

if __name__ == '__main__':
    if len(sys.argv) > 1:
        txt = ' '.join(sys.argv[1:])
    else:
        txt = ("The quick brown fox jumps over the lazy dog while "
               "the moonlight dances across the silent sea.")
    main(txt)