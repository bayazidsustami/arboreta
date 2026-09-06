use std::collections::VecDeque;
use std::io::{self, Write};
use std::thread;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

// Ephemeral ASCII flora generated deterministically from seconds
const FLORA_PETALS: &[&str] = &["*", "+", "o", "x", "v", "^", "~", "°", "•", "✿", "❀", "𓆏"];
const TOMBSTONES: &[&str] = &[
    "  ╭─────╮  ",
    "  │ R.I.P │  ",
    "  │  00   │  ",
    " ─┴───────┴─ ",
];

struct Leaf {
    symbol: &'static str,
    x: u16,
    y: u16,
    birth_sec: u64,
}

fn deterministic_rand(seed: u64, max: u64) -> u64 {
    // Simple LCG for deterministic generation without external crates
    seed.wrapping_mul(6364136223846793005).wrapping_add(1) % max
}

fn main() -> io::Result<()> {
    let mut stdout = io::stdout();
    let mut garden: Vec<Leaf> = Vec::new();
    let mut graveyards: VecDeque<String> = VecDeque::new();
    let mut last_processed_sec: u64 = 0;
    let mut last_processed_hour: u64 = 0;

    // Clear terminal screen and hide cursor
    print!("\x1B[2J\x1B[?25l");
    stdout.flush()?;

    loop {
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs();

        let sec = now % 60;
        let min = (now / 60) % 60;
        let hour = (now / 3600) % 24;

        // Terminal Buffer Setup (40x20 canvas)
        let width = 60;
        let height = 20;
        let mut canvas = vec![vec![' '; width]; height];

        // 1. Check for Hour Collapse (Transition to Visual Cemetery)
        if last_processed_hour != 0 && hour != last_processed_hour {
            garden.clear();
            let tomb_tag = format!("{:02}:00", hour);
            graveyards.push_back(tomb_tag);
            if graveyards.len() > 3 {
                graveyards.pop_front();
            }
        }
        last_processed_hour = hour;

        // 2. Spawn Ephemeral Flora on each new second
        if now != last_processed_sec {
            last_processed_sec = now;

            // Deterministic spawn placement based on timestamp
            let flower_idx = deterministic_rand(now, FLORA_PETALS.len() as u64) as usize;
            let x = (deterministic_rand(now + 1, (width - 4) as u64) + 2) as u16;
            let y = (deterministic_rand(now + 2, (height - 6) as u64) + 2) as u16;

            garden.push(Leaf {
                symbol: FLORA_PETALS[flower_idx],
                x,
                y,
                birth_sec: now,
            });
        }

        // 3. Wither Flora as Minutes Decay
        let max_lifespan = 60 - min + 10; // Flora decays faster late in the hour
        garden.retain(|leaf| (now - leaf.birth_sec) < max_lifespan);

        // Render Garden Canvas
        for leaf in &garden {
            let ch = leaf.symbol.chars().next().unwrap_or('.');
            if (leaf.y as usize) < height && (leaf.x as usize) < width {
                canvas[leaf.y as usize][leaf.x as usize] = ch;
            }
        }

        // 4. Render Cemetery (Tombs of collapsed hours at the bottom)
        let cemetery_y = height - 5;
        for (idx, tomb_time) in graveyards.iter().enumerate() {
            let offset_x = idx * 18 + 2;
            if offset_x + 12 < width {
                for (row, line) in TOMBSTONES.iter().enumerate() {
                    let rendered_line = if row == 2 {
                        line.replace("00", tomb_time)
                    } else {
                        line.to_string()
                    };
                    for (col, c) in rendered_line.chars().enumerate() {
                        if cemetery_y + row < height {
                            canvas[cemetery_y + row][offset_x + col] = c;
                        }
                    }
                }
            }
        }

        // Draw HUD / Digital Time Core
        let time_str = format!("── [ {:02}:{:02}:{:02} ] ──", hour, min, sec);
        let start_x = (width - time_str.len()) / 2;
        for (i, c) in time_str.chars().enumerate() {
            canvas[0][start_x + i] = c;
        }

        // Draw Frame Border & Output Buffer
        print!("\x1B[H"); // Reset cursor to top-left
        println!("┌{}┐", "─".repeat(width));
        for row in canvas {
            let line: String = row.into_iter().collect();
            println!("│{}│", line);
        }
        println!("└{}┘", "─".repeat(width));
        println!(" Ecosystem: {} Active Flora | Cemetery: {} Hours Collapsed", garden.len(), graveyards.len());

        stdout.flush()?;
        thread::sleep(Duration::from_millis(200));
    }
}