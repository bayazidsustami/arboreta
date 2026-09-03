// Terminal-based recursive ASCII quilt visualization driven by simulated multi-threaded CPU activity and memory states.
// Dependencies required: crossterm = "0.27", rand = "0.8"

use crossterm::{
    cursor::{Hide, MoveTo, Show},
    event::{self, Event, KeyCode},
    execute,
    style::{Color, Print, SetForegroundColor},
    terminal::{disable_raw_mode, enable_raw_mode, Clear, ClearType, Size},
};
use rand::Rng;
use std::{
    io::{stdout, Result},
    sync::{
        atomic::{AtomicBool, Ordering},
        Arc, Mutex,
    },
    thread,
    time::{Duration, Instant},
};

// Represents a thread's live metrics: activity level (CPU simulation) and memory allocation pattern.
#[derive(Clone, Copy, Debug)]
struct ThreadState {
    id: usize,
    activity: f32,    // 0.0 to 1.0 (CPU load simulation)
    memory_mb: usize, // Memory footprint controlling fractal recursion depth and weave
    x: f32,           // Position in quilt coordinate space
    y: f32,
    vx: f32, // Velocity vectors for position synthesis
    vy: f32,
}

// Global visualizer state shared across worker threads
struct SystemQuilt {
    threads: Vec<ThreadState>,
    mutation_energy: f32, // Accumulated energy from thread collisions
    palette_shift: usize,
}

const WEAVE_CHARS: &[char] = &['░', '▒', '▓', '█', '┼', '╳', '═', '║', '╬', '╪', '▲', '◆', '❖', '⚙'];
const COLOR_PALETTE: &[Color] = &[
    Color::Cyan,
    Color::Magenta,
    Color::Yellow,
    Color::Green,
    Color::Red,
    Color::Blue,
    Color::DarkCyan,
    Color::DarkMagenta,
    Color::AnsiValue(208), // Orange
    Color::AnsiValue(141), // Violet
    Color::AnsiValue(198), // Deep Pink
];

fn main() -> Result<()> {
    // Terminal UI Setup
    enable_raw_mode()?;
    let mut out = stdout();
    execute!(out, Hide, Clear(ClearType::All))?;

    let running = Arc::new(AtomicBool::new(true));
    let num_threads = num_cpus();
    let system_state = Arc::new(Mutex::new(SystemQuilt {
        threads: (0..num_threads)
            .map(|id| ThreadState {
                id,
                activity: 0.1,
                memory_mb: 64,
                x: rand::thread_rng().gen_range(0.1..0.9),
                y: rand::thread_rng().gen_range(0.1..0.9),
                vx: rand::thread_rng().gen_range(-0.02..0.02),
                vy: rand::thread_rng().gen_range(-0.02..0.02),
            })
            .collect(),
        mutation_energy: 0.0,
        palette_shift: 0,
    }));

    // Spawn CPU workload threads to simulate dynamic activity and real OS thread footprints
    let mut worker_handles = Vec::new();
    for t_id in 0..num_threads {
        let state_ref = Arc::clone(&system_state);
        let is_running = Arc::clone(&running);

        let handle = thread::spawn(move || {
            let mut rng = rand::thread_rng();
            let mut local_alloc: Vec<u8> = Vec::new();

            while is_running.load(Ordering::Relaxed) {
                let start = Instant::now();

                // Dynamic CPU Workload Simulation
                let work_cycles = rng.gen_range(50_000..2_000_000);
                let mut dummy = 0.0f64;
                for i in 0..work_cycles {
                    dummy += (i as f64).sin().sqrt();
                }

                // Simulate memory expansion and compaction based on thread compute intensity
                let memory_target = (work_cycles / 2000) + rng.gen_range(32..512);
                if local_alloc.len() < memory_target * 1024 {
                    local_alloc.resize(memory_target * 1024, dummy as u8);
                } else if local_alloc.len() > memory_target * 1024 {
                    local_alloc.truncate(memory_target * 1024);
                }

                let elapsed = start.elapsed().as_secs_f32();
                let computed_activity = (elapsed * 100.0).clamp(0.05, 1.0);

                // Update shared thread visual state
                if let Ok(mut state) = state_ref.lock() {
                    if let Some(t) = state.threads.get_mut(t_id) {
                        t.activity = computed_activity;
                        t.memory_mb = local_alloc.len() / 1024;
                        t.x = (t.x + t.vx + 1.0) % 1.0;
                        t.y = (t.y + t.vy + 1.0) % 1.0;
                    }
                }

                thread::sleep(Duration::from_millis(rng.gen_range(16..50)));
            }
        });
        worker_handles.push(handle);
    }

    // Main Renderer Loop
    let mut last_frame = Instant::now();
    while running.load(Ordering::Relaxed) {
        if event::poll(Duration::from_millis(16))? {
            if let Event::Key(key) = event::read()? {
                if key.code == KeyCode::Char('q') || key.code == KeyCode::Esc {
                    running.store(false, Ordering::Relaxed);
                    break;
                }
            }
        }

        // Process physics and collisions between threads
        {
            let mut state = system_state.lock().unwrap();
            let n = state.threads.len();
            for i in 0..n {
                for j in (i + 1)..n {
                    let dx = state.threads[i].x - state.threads[j].x;
                    let dy = state.threads[i].y - state.threads[j].y;
                    let dist = (dx * dx + dy * dy).sqrt();

                    // Collision triggered: mutate quilt colors and redirect vectors
                    if dist < 0.08 {
                        state.mutation_energy += 1.5;
                        state.palette_shift = (state.palette_shift + 1) % COLOR_PALETTE.len();
                        state.threads[i].vx = -state.threads[i].vx;
                        state.threads[j].vy = -state.threads[j].vy;
                    }
                }
            }
            state.mutation_energy = (state.mutation_energy * 0.95).max(0.0);
        }

        // Render recursive ASCII Quilt frame
        if last_frame.elapsed() >= Duration::from_millis(33) {
            render_quilt(&system_state)?;
            last_frame = Instant::now();
        }
    }

    // Cleanup and termination
    for handle in worker_handles {
        let _ = handle.join();
    }
    execute!(out, Show, MoveTo(0, 0), Clear(ClearType::All))?;
    disable_raw_mode()?;
    Ok(())
}

fn num_cpus() -> usize {
    thread::available_parallelism()
        .map(|p| p.get())
        .unwrap_or(4)
}

// Generates the recursive, ever-evolving quilt visually representing execution states.
fn render_quilt(state_ref: &Arc<Mutex<SystemQuilt>>) -> Result<()> {
    let (cols, rows) = crossterm::terminal::size().unwrap_or((80, 24));
    let state = state_ref.lock().unwrap();
    let mut out = stdout();

    let mut frame_buffer = vec![vec![(' ', Color::Reset); cols as usize]; rows as usize];

    // Compute recursive weave for each cell on screen
    for r in 0..rows as usize {
        let y_norm = r as f32 / rows as f32;
        for c in 0..cols as usize {
            let x_norm = c as f32 / cols as f32;

            let mut char_val = 0.0f32;
            let mut color_idx = state.palette_shift;

            // Fractal/Recursive evaluation across threads
            for t in &state.threads {
                let dx = x_norm - t.x;
                let dy = y_norm - t.y;
                let dist_sq = dx * dx + dy * dy + 0.001;

                // Memory footprint determines recursive weave frequency
                let weave_freq = (t.memory_mb as f32 / 32.0).clamp(1.0, 16.0);
                let recursive_pattern = (dist_sq.sqrt() * weave_freq * std::f32::consts::PI).sin();

                char_val += (t.activity * recursive_pattern) / dist_sq.sqrt();
                if recursive_pattern > 0.5 {
                    color_idx = (color_idx + t.id) % COLOR_PALETTE.len();
                }
            }

            // Map continuous output to weave characters
            let idx = (char_val.abs() * 5.0 + state.mutation_energy) as usize % WEAVE_CHARS.len();
            let symbol = WEAVE_CHARS[idx];

            let final_color = if state.mutation_energy > 0.5 && (r + c) % 2 == 0 {
                Color::White // Flash on collision mutation
            } else {
                COLOR_PALETTE[color_idx % COLOR_PALETTE.len()]
            };

            frame_buffer[r][c] = (symbol, final_color);
        }
    }

    // Flush frame buffer to terminal stdout
    for (r, row) in frame_buffer.iter().enumerate() {
        execute!(out, MoveTo(0, r as u16))?;
        for (ch, color) in row {
            execute!(out, SetForegroundColor(*color), Print(ch))?;
        }
    }

    Ok(())
}