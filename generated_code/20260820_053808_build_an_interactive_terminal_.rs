// Interactive Terminal Cellular Automaton with Micro-tonal ASCII Soundscapes & CPU Visual Poetry
// Runnable with standard rustc: rustc main.rs && ./main

use std::fs::File;
use std::io::{self, Read, Write};
use std::thread::sleep;
use std::time::Duration;

const WIDTH: usize = 50;
const HEIGHT: usize = 18;

// Micro-tonal scale representation using ASCII & Unicode soundwave symbols
const MICROTONAL_NOTES: &[char] = &['·', '~', '≈', '∽', '∿', '♭', '♮', '♯', '♪', '♫'];

// Poetry lexicons indexed by CPU load intensity (Calm -> Mid -> Overclocked)
const POETRY_CALM: &[&str] = &["silicon dream", "soft static", "dormant pulse", "ether drift", "zero state", "cold logic"];
const POETRY_MID: &[&str] = &["current hums", "weaving cycles", "flickering grid", "decaying echo", "latent resonance"];
const POETRY_HIGH: &[&str] = &["overclocked heart", "feverish surge", "silicon spark", "calcified fire", "cascade loop"];

struct CpuMonitor {
    prev_idle: u64,
    prev_total: u64,
}

impl CpuMonitor {
    fn new() -> Self {
        let (idle, total) = Self::read_proc_stat().unwrap_or((0, 1));
        Self { prev_idle: idle, prev_total: total }
    }

    // Reads /proc/stat on Linux systems; falls back smoothly if unavailable
    fn get_usage(&mut self) -> f32 {
        if let Some((idle, total)) = Self::read_proc_stat() {
            let total_diff = total.saturating_sub(self.prev_total);
            let idle_diff = idle.saturating_sub(self.prev_idle);
            self.prev_idle = idle;
            self.prev_total = total;
            if total_diff > 0 {
                return (1.0 - (idle_diff as f32 / total_diff as f32)).clamp(0.0, 1.0);
            }
        }
        0.30 // Fallback nominal load value
    }

    fn read_proc_stat() -> Option<(u64, u64)> {
        let mut file = File::open("/proc/stat").ok()?;
        let mut contents = String::new();
        file.read_to_string(&mut contents).ok()?;
        let line = contents.lines().next()?;
        let parts: Vec<u64> = line
            .split_whitespace()
            .skip(1)
            .filter_map(|s| s.parse().ok())
            .collect();
        if parts.len() >= 4 {
            let idle = parts[3];
            let total: u64 = parts.iter().sum();
            Some((idle, total))
        } else {
            None
        }
    }
}

struct Automaton {
    grid: [[bool; WIDTH]; HEIGHT],
    decay: [[f32; WIDTH]; HEIGHT],
    tones: [[usize; WIDTH]; HEIGHT],
    tick: usize,
}

impl Automaton {
    fn new() -> Self {
        let mut grid = [[false; WIDTH]; HEIGHT];
        // Seed initial Gliders and Oscillators
        let seeds = [
            (5, 5), (6, 6), (6, 7), (5, 7), (4, 7),
            (15, 10), (16, 10), (17, 10), (16, 9), (16, 11),
            (30, 8), (31, 8), (32, 8), (30, 12), (31, 12), (32, 12),
        ];
        for (x, y) in seeds {
            if x < WIDTH && y < HEIGHT {
                grid[y][x] = true;
            }
        }
        Self {
            grid,
            decay: [[0.0; WIDTH]; HEIGHT],
            tones: [[0; WIDTH]; HEIGHT],
            tick: 0,
        }
    }

    fn count_neighbors(&self, x: usize, y: usize) -> u8 {
        let mut count = 0;
        for dy in [-1, 0, 1] {
            for dx in [-1, 0, 1] {
                if dx == 0 && dy == 0 { continue; }
                let nx = (x as isize + dx).rem_euclid(WIDTH as isize) as usize;
                let ny = (y as isize + dy).rem_euclid(HEIGHT as isize) as usize;
                if self.grid[ny][nx] { count += 1; }
            }
        }
        count
    }

    fn step(&mut self, cpu_usage: f32) {
        let mut next_grid = [[false; WIDTH]; HEIGHT];
        self.tick += 1;

        for y in 0..HEIGHT {
            for x in 0..WIDTH {
                let neighbors = self.count_neighbors(x, y);
                let alive = self.grid[y][x];

                if alive && (neighbors == 2 || neighbors == 3) {
                    next_grid[y][x] = true;
                } else if !alive && neighbors == 3 {
                    next_grid[y][x] = true;
                }

                // When a cell dies, deposit a micro-tonal soundscape remnant
                if alive && !next_grid[y][x] {
                    self.decay[y][x] = 1.0;
                    let micro_pitch = (x + y + (cpu_usage * 100.0) as usize) % MICROTONAL_NOTES.len();
                    self.tones[y][x] = micro_pitch;
                } else {
                    // Decay dead cell trails over time
                    self.decay[y][x] *= 0.85;
                }
            }
        }

        // Spontaneous regeneration rate influenced by CPU load intensity
        if self.tick % 4 == 0 {
            let rx = (self.tick * 17 + (cpu_usage * 73.0) as usize) % WIDTH;
            let ry = (self.tick * 31 + (cpu_usage * 41.0) as usize) % HEIGHT;
            next_grid[ry][rx] = true;
        }

        self.grid = next_grid;
    }

    fn generate_poetry(&self, cpu_usage: f32) -> String {
        let lexicon = if cpu_usage < 0.25 {
            POETRY_CALM
        } else if cpu_usage < 0.60 {
            POETRY_MID
        } else {
            POETRY_HIGH
        };

        let dead_trail_energy: usize = self.decay.iter()
            .flat_map(|row| row.iter())
            .filter(|&&d| d > 0.2)
            .count();

        let word1 = lexicon[(self.tick + dead_trail_energy) % lexicon.len()];
        let word2 = lexicon[(self.tick * 3 + dead_trail_energy * 7) % lexicon.len()];
        let glyph = MICROTONAL_NOTES[((cpu_usage * 9.0) as usize).min(MICROTONAL_NOTES.len() - 1)];

        format!(" [{}] ~ \"{} {}\" ~ [CPU Load: {:04.1}%]", glyph, word1, word2, cpu_usage * 100.0)
    }

    fn render(&self, cpu_usage: f32) {
        let mut out = String::with_capacity(WIDTH * HEIGHT * 12);
        out.push_str("\x1b[H"); // Reset cursor to top-left

        out.push_str("╭── Micro-tonal Soundscape & Visual Poetry Automaton ──╮\r\n");

        for y in 0..HEIGHT {
            out.push('│');
            for x in 0..WIDTH {
                if self.grid[y][x] {
                    // Live cells: Vivid cyan
                    out.push_str("\x1b[38;5;51m█\x1b[0m");
                } else if self.decay[y][x] > 0.08 {
                    // Decaying dead cell soundscape: Fade color based on resonance level
                    let note = MICROTONAL_NOTES[self.tones[y][x]];
                    let intensity = self.decay[y][x];
                    let color = if intensity > 0.7 {
                        "\x1b[38;5;198m" // Glowing magenta
                    } else if intensity > 0.35 {
                        "\x1b[38;5;141m" // Soft lavender
                    } else {
                        "\x1b[38;5;60m"  // Deep slate blue
                    };
                    out.push_str(color);
                    out.push(note);
                    out.push_str("\x1b[0m");
                } else {
                    out.push(' ');
                }
            }
            out.push_str("│\r\n");
        }

        out.push_str("╰──────────────────────────────────────────────────────╯\r\n");
        out.push_str(&self.generate_poetry(cpu_usage));
        out.push_str("\r\n\x1b[K");

        print!("{}", out);
        let _ = io::stdout().flush();
    }
}

fn main() {
    // Hide cursor & clear terminal screen
    print!("\x1b[?25l\x1b[2J");
    let _ = io::stdout().flush();

    let mut cpu_monitor = CpuMonitor::new();
    let mut automaton = Automaton::new();

    loop {
        let cpu_usage = cpu_monitor.get_usage();
        automaton.step(cpu_usage);
        automaton.render(cpu_usage);
        sleep(Duration::from_millis(90));
    }
}