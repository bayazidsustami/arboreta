import cv2, numpy as np, sys, os, time, shutil, threading

# Settings
WIDTH, HEIGHT = 80, 45            # ASCII output size
GRID_W, GRID_H = 32, 24           # Game of Life grid size
ASCII_CHARS = " .:-=+*#%@"
FRAMELEN = 0.05                   # seconds between frames

# Shared state for self‑modifying source
frame_ascii = ""                  # will hold latest ASCII art
source_path = os.path.abspath(__file__)

def game_of_life_step(board):
    """One Conway step on a binary board."""
    neighbours = sum(np.roll(np.roll(board, i, 0), j, 1)
                     for i in (-1,0,1) for j in (-1,0,1)
                     if not (i==0 and j==0))
    survive = (board == 1) & ((neighbours == 2) | (neighbours == 3))
    born = (board == 0) & (neighbours == 3)
    return survive | born

def histogram_to_grid(gray):
    """Map grayscale histogram to a Game of Life board."""
    hist = cv2.calcHist([gray], [0], None, [GRID_W*GRID_H], [0,256]).flatten()
    board = (hist > np.mean(hist)).astype(np.uint8)
    return board.reshape((GRID_H, GRID_W))

def image_to_ascii(img):
    """Resize image and convert to ASCII characters."""
    small = cv2.resize(img, (WIDTH, HEIGHT), interpolation=cv2.INTER_AREA)
    norm = cv2.normalize(small, None, 0, len(ASCII_CHARS)-1, cv2.NORM_MINMAX).astype(int)
    rows = ["".join(ASCII_CHARS[p] for p in line) for line in norm]
    return "\n".join(rows)

def writer_thread():
    """Continuously rewrite this file with the latest ASCII frame."""
    while True:
        if frame_ascii:
            with open(source_path, "r", encoding="utf-8") as f:
                lines = f.readlines()
            # replace the block between markers
            start, end = None, None
            for i, l in enumerate(lines):
                if l.strip() == "# <<ASCII_START>>":
                    start = i
                if l.strip() == "# <<ASCII_END>>":
                    end = i
            if start is not None and end is not None and end > start:
                new_block = ["# <<ASCII_START>>\n",
                             "frame_ascii = '''\\\n",
                             frame_ascii.replace("'''", "\\'''") + "\\\n'''\\\n",
                             "# <<ASCII_END>>\n"]
                lines = lines[:start] + new_block + lines[end+1:]
                tmp = source_path + ".tmp"
                with open(tmp, "w", encoding="utf-8") as f:
                    f.writelines(lines)
                shutil.move(tmp, source_path)
        time.sleep(0.5)

def main():
    global frame_ascii
    cap = cv2.VideoCapture(0)
    if not cap.isOpened():
        print("Webcam not found.")
        return

    # initialise Game of Life board with zeros
    gol_board = np.zeros((GRID_H, GRID_W), dtype=np.uint8)

    threading.Thread(target=writer_thread, daemon=True).start()

    try:
        while True:
            ret, frame = cap.read()
            if not ret:
                break
            gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)

            # update Game of Life board from histogram
            gol_board = histogram_to_grid(gray)
            gol_board = game_of_life_step(gol_board)

            # use board to colour the ASCII output (simple on/off)
            ascii_art = image_to_ascii(gray)
            # inject colour codes based on Life cells
            lines = ascii_art.splitlines()
            colored = []
            for y, line in enumerate(lines):
                row = ""
                for x, ch in enumerate(line):
                    # map pixel to nearest Life cell
                    cell = gol_board[(y * GRID_H)//HEIGHT, (x * GRID_W)//WIDTH]
                    if cell:
                        row += f"\x1b[31m{ch}\x1b[0m"   # red for live cells
                    else:
                        row += ch
                colored.append(row)
            frame_ascii = "\n".join(colored)

            # display locally
            os.system('cls' if os.name == 'nt' else 'clear')
            print(frame_ascii)
            time.sleep(FRAMELEN)
    finally:
        cap.release()

if __name__ == "__main__":
    main()

# <<ASCII_START>>
frame_ascii = '''\
'''
# <<ASCII_END>>