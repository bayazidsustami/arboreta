use std::collections::VecDeque;
use std::io::{self, BufRead, Read, Write};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::{Duration, Instant};

#[derive(Clone, Copy, Debug, PartialEq)]
enum Lane {
    A,
    S,
    K,
    L,
}

impl Lane {
    fn char(&self) -> char {
        match self {
            Lane::A => 'A',
            Lane::S => 'S',
            Lane::K => 'K',
            Lane::L => 'L',
        }
    }

    fn index(&self) -> usize {
        match self {
            Lane::A => 0,
            Lane::S => 1,
            Lane::K => 2,
            Lane::L => 3,
        }
    }

    fn from_char(c: char) -> Option<Self> {
        match c.to_ascii_uppercase() {
            'A' => Some(Lane::A),
            'S' => Some(Lane::S),
            'K' => Some(Lane::K),
            'L' => Some(Lane::L),
            _ => None,
        }
    }
}

struct Note {
    lane: Lane,
    y: f32, // Track position: 0.0 at top, 1.0 at hit line
}

struct GameState {
    notes: Vec<Note>,
    score: u32,
    combo: u32,
    tempo_multiplier: f32,
    latency_ms: u32,
    feedback: String,
    feedback_timer: u8,
}

const TRACK_HEIGHT: usize = 16;
const HIT_LINE: usize = 14;

fn parse_log_line(line: &str) -> (Lane, u32) {
    let hash: u32 = line.bytes().fold(0, |acc, b| acc.wrapping_add(b as u32));
    let lane = match hash % 4 {
        0 => Lane::A,
        1 => Lane::S,
        2 => Lane::K,
        _ => Lane::L,
    };

    let latency = if line.contains("404") || line.contains("500") || line.contains("timeout") || line.contains("ERROR") {
        250 + (hash % 300)
    } else if line.contains("ping") || line.contains("ms") || line.contains("latency") {
        let digits: String = line.chars().filter(|c| c.is_ascii_digit()).collect();
        digits.parse::<u32>().unwrap_or(40).min(600)
    } else {
        20 + (hash % 60)
    };

    (lane, latency)
}

fn set_raw_mode(enable: bool) {
    if enable {
        let _ = std::process::Command::new("stty").arg("raw").arg("-echo").status();
    } else {
        let _ = std::process::Command::new("stty").arg("-raw").arg("echo").status();
    }
}

fn main() {
    let running = Arc::new(AtomicBool::new(true));
    let r = running.clone();
    ctrlc_handler(move || {
        r.store(false, Ordering::SeqCst);
    });

    let game_state = Arc::new(Mutex::new(GameState {
        notes: Vec::new(),
        score: 0,
        combo: 0,
        tempo_multiplier: 1.0,
        latency_ms: 20,
        feedback: String::from("READY"),
        feedback_timer: 0,
    }));

    let state_stdin = game_state.clone();
    let running_stdin = running.clone();

    // Stream reader thread (Log ingest pipeline)
    thread::spawn(move || {
        let stdin = io::stdin();
        let handle = stdin.lock();
        let mut lines = handle.lines();

        while running_stdin.load(Ordering::SeqCst) {
            if let Some(Ok(line)) = lines.next() {
                if line.trim().is_empty() {
                    continue;
                }
                let (lane, latency) = parse_log_line(&line);
                let mut state = state_stdin.lock().unwrap();
                state.latency_ms = latency;

                // Spike triggers speed shift & extra drop notes
                if latency > 150 {
                    state.tempo_multiplier = 2.2;
                    state.notes.push(Note { lane, y: 0.0 });
                    state.notes.push(Note {
                        lane: match lane {
                            Lane::A => Lane::K,
                            Lane::S => Lane::L,
                            Lane::K => Lane::A,
                            Lane::L => Lane::S,
                        },
                        y: -0.2,
                    });
                } else {
                    state.tempo_multiplier = 1.0;
                    state.notes.push(Note { lane, y: 0.0 });
                }
            } else {
                // Synthetic generator if stdin starves
                thread::sleep(Duration::from_millis(300));
                let mut state = state_stdin.lock().unwrap();
                let lane = match rand_simple() % 4 {
                    0 => Lane::A,
                    1 => Lane::S,
                    2 => Lane::K,
                    _ => Lane::L,
                };
                state.notes.push(Note { lane, y: 0.0 });
            }
        }
    });

    // Keyboard input thread
    let state_input = game_state.clone();
    let running_input = running.clone();
    set_raw_mode(true);

    thread::spawn(move || {
        let mut buffer = [0u8; 1];
        while running_input.load(Ordering::SeqCst) {
            if io::stdin().read_exact(&mut buffer).is_ok() {
                let ch = buffer[0] as char;
                if ch == '\u{3}' || ch == 'q' || ch == 'Q' {
                    running_input.store(false, Ordering::SeqCst);
                    break;
                }
                if let Some(pressed_lane) = Lane::from_char(ch) {
                    let mut state = state_input.lock().unwrap();
                    let hit_idx = state.notes.iter().position(|n| {
                        n.lane == pressed_lane && (n.y - (HIT_LINE as f32 / TRACK_HEIGHT as f32)).abs() < 0.15
                    });

                    if let Some(idx) = hit_idx {
                        state.notes.remove(idx);
                        state.combo += 1;
                        let pts = 100 * state.combo;
                        state.score += pts;
                        state.feedback = format!("PERFECT! +{}", pts);
                        state.feedback_timer = 10;
                    } else {
                        state.combo = 0;
                        state.feedback = String::from("MISS!");
                        state.feedback_timer = 8;
                    }
                }
            }
        }
    });

    // Render / Game Loop
    let mut stdout = io::stdout();
    print!("\x1B[2J\x1B[?25l"); // Clear screen, hide cursor

    let mut last_tick = Instant::now();
    while running.load(Ordering::SeqCst) {
        let dt = last_tick.elapsed().as_secs_f32();
        last_tick = Instant::now();

        {
            let mut state = game_state.lock().unwrap();

            // Advance notes
            let speed = 0.8 * state.tempo_multiplier;
            for note in state.notes.iter_mut() {
                note.y += dt * speed;
            }

            // Missed notes dropped off bottom
            let prev_len = state.notes.len();
            state.notes.retain(|n| n.y <= 1.05);
            if state.notes.len() < prev_len {
                state.combo = 0;
                state.feedback = String::from("DROPPED!");
                state.feedback_timer = 6;
            }

            if state.feedback_timer > 0 {
                state.feedback_timer -= 1;
            }

            // Render UI
            let mut grid = vec![vec![' '; 17]; TRACK_HEIGHT];
            for r in 0..TRACK_HEIGHT {
                grid[r][0] = '|';
                grid[r][4] = '|';
                grid[r][8] = '|';
                grid[r][12] = '|';
                grid[r][16] = '|';
            }

            // Draw Hit Line
            for c in 0..17 {
                if c % 4 == 0 {
                    grid[HIT_LINE][c] = '+';
                } else {
                    grid[HIT_LINE][c] = '=';
                }
            }

            // Draw Notes
            for note in &state.notes {
                let row = (note.y * TRACK_HEIGHT as f32) as usize;
                if row < TRACK_HEIGHT {
                    let col = note.lane.index() * 4 + 2;
                    grid[row][col] = note.lane.char();
                }
            }

            // Build Frame Buffer
            let mut frame = String::with_capacity(2048);
            frame.push_str("\x1B[H"); // Reset cursor to top-left
            frame.push_str("=== LOG RHYTHM PIPELINE ===\r\n");
            frame.push_str(&format!(
                "Latency: {:3} ms | Tempo: {:.1}x {}\r\n",
                state.latency_ms,
                state.tempo_multiplier,
                if state.tempo_multiplier > 1.5 { "⚡ [SPIKE!]" } else { "  " }
            ));
            frame.push_str("---------------------------\r\n");

            for row in grid {
                let line: String = row.into_iter().collect();
                frame.push_str(&line);
                frame.push_str("\r\n");
            }

            frame.push_str("---------------------------\r\n");
            frame.push_str(&format!("  A   S   K   L   (Controls)\r\n"));
            frame.push_str(&format!("SCORE: {:06} | COMBO: {:2}\r\n", state.score, state.combo));
            frame.push_str(&format!("STATUS: {:15}\r\n", if state.feedback_timer > 0 { &state.feedback } else { "" }));
            frame.push_str("Press 'Q' to Quit\r\n");

            let _ = stdout.write_all(frame.as_bytes());
            let _ = stdout.flush();
        }

        thread::sleep(Duration::from_millis(33)); // ~30 FPS
    }

    set_raw_mode(false);
    print!("\x1B[?25h\x1B[2J\x1B[HGame Over!\r\n");
    let _ = stdout.flush();
}

static mut SEED: u32 = 1337;
fn rand_simple() -> u32 {
    unsafe {
        SEED = SEED.wrapping_mul(1664525).wrapping_add(1013904223);
        SEED
    }
}

fn ctrlc_handler<F>(f: F)
where
    F: Fn() + Send + 'static,
{
    thread::spawn(move || {
        let _ = io::stdin().read_exact(&mut [0u8; 1]);
    });
}