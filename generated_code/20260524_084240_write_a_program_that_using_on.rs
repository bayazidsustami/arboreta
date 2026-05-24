use std::io::{self, Write};
use std::thread;
use std::time::{Duration, Instant};

use rand::Rng;
use crossterm::{
    cursor::{Hide, MoveTo},
    execute,
    terminal::{Clear, ClearType, EnterAlternateScreen, LeaveAlternateScreen},
    ExecutableCommand,
};

/// Simple combinator that stacks a base rune with a random set of diacritics.
fn decorate(ch: char) -> String {
    // a few combining marks that look interesting in a terminal
    const DIACRITICS: &[char] = &[
        '\u{0300}', // grave
        '\u{0301}', // acute
        '\u{0302}', // circumflex
        '\u{0303}', // tilde
        '\u{0304}', // macron
        '\u{0305}', // overline
        '\u{0306}', // breve
        '\u{0307}', // dot above
        '\u{0308}', // diaeresis
        '\u{0309}', // hook above
        '\u{030A}', // ring above
        '\u{030B}', // double acute
        '\u{030C}', // caron
    ];
    let mut rng = rand::thread_rng();
    let count = rng.gen_range(1..=3);
    let mut s = String::new();
    s.push(ch);
    for _ in 0..count {
        let d = DIACRITICS[rng.gen_range(0..DIACRITICS.len())];
        s.push(d);
    }
    s
}

/// Produce a line whose visual length encodes a “syllable count”.
fn make_line(syllables: usize, width: u16, row: u16) -> String {
    let base = ['a', 'e', 'i', 'o', 'u', 'y'];
    let mut rng = rand::thread_rng();
    let mut line = String::new();
    for _ in 0..syllables {
        let ch = base[rng.gen_range(0..base.len())];
        line.push_str(&decorate(ch));
        line.push(' ');
    }
    // Pad or trim to fit the screen width, then move cursor to column that
    // represents the rhyme scheme (here, a simple modulo).
    let col = (syllables as u16 * 3) % width;
    format!("\x1B[{};{}H{}", row + 1, col + 1, line)
}

/// Main loop: pretend we read an audio spectrum and map its bins to
/// syllable counts, then render poetic lines with cursor control.
fn main() -> io::Result<()> {
    // Switch to alternate screen and hide cursor.
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen, Hide)?;

    // Terminal size (fallback to 80x24).
    let (width, height) = crossterm::terminal::size().unwrap_or((80, 24));

    // Simulated live stream for 30 seconds.
    let start = Instant::now();
    let duration = Duration::from_secs(30);
    let mut row = 0;

    while Instant::now() - start < duration {
        // Simulate a spectrum: 8 frequency bins → 8 syllable counts.
        let mut rng = rand::thread_rng();
        let mut line = String::new();

        for bin in 0..8 {
            let magnitude = rng.gen_range(0..=height);
            // Map magnitude to syllable count (1..=10).
            let syllables = ((magnitude as f32 / height as f32) * 9.0).ceil() as usize + 1;
            line.push_str(&make_line(syllables, width, (row + bin as u16) % height));
        }

        // Write all lines at once.
        stdout.execute(Clear(ClearType::All))?;
        stdout.write_all(line.as_bytes())?;
        stdout.flush()?;

        row = (row + 1) % height;
        thread::sleep(Duration::from_millis(200));
    }

    // Restore terminal.
    execute!(stdout, LeaveAlternateScreen)?;
    Ok(())
}