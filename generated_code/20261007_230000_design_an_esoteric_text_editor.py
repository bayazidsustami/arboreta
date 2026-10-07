import curses

def main(stdscr):
    # Initialize curses text editor interface
    curses.curs_set(1)
    buffer = []
    vowels = set("aeiouAEIOU")
    
    while True:
        stdscr.clear()
        stdscr.addstr(0, 0, "=== SUMERIAN MUTATOR TEXT EDITOR ===")
        stdscr.addstr(1, 0, "Backspace devours the oldest vowel in the scroll. ESC to exit.")
        stdscr.addstr(2, 0, "-" * 60)
        
        # Render the active document buffer onto the screen
        doc_text = "".join(buffer)
        try:
            stdscr.addstr(4, 0, doc_text)
        except curses.error:
            pass
        
        stdscr.refresh()
        
        ch = stdscr.getch()
        
        if ch == 27:  # ESC key to exit
            break
        elif ch in (curses.KEY_BACKSPACE, 127, 8):
            # Esoteric mechanic: backspace deletes the oldest vowel anywhere in the document
            for i, char in enumerate(buffer):
                if char in vowels:
                    buffer.pop(i)
                    break
        elif ch == 10 or ch == 13:  # Newline / Enter key
            buffer.append("\n")
        elif 32 <= ch <= 126:  # Standard printable characters
            buffer.append(chr(ch))

if __name__ == "__main__":
    curses.wrapper(main)