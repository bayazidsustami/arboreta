// STELLAR OBSERVATORY: Interactive ASCII Gravity, Light Raytracing & Algorithmic Soundscape
// Controls: W/A/S/D or Arrow Keys to position singularity, '+' / '-' to adjust Mass, 'Q' to Quit.

use std::io::{self, Read, Write};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::thread;
use std::time::{Duration, Instant};

// --- SIMULATION CONSTANTS ---
const WIDTH: usize = 70;
const HEIGHT: usize = 24;
const NUM_BODIES: usize = 3;
const NUM_RAYS: usize = 12;

// --- DATA STRUCTURES ---
#[derive(Clone, Copy)]
struct Vec2 {
    x: f64,
    y: f64,
}

impl Vec2 {
    fn new(x: f64, y: f64) -> Self {
        Self { x, y }
    }
    fn dist(&self, other: Vec2) -> f64 {
        ((self.x - other.x).powi(2) + (self.y - other.y).powi(2)).sqrt()
    }
}

struct CelestialBody {
    pos: Vec2,
    vel: Vec2,
    mass: f64,
    symbol: char,
    orbit_radius: f64,
    angle: f64,
    speed: f64,
}

struct GravitationalAnomaly {
    pos: Vec2,
    mass: f64,
}

// --- TERMINAL ANSI SETUP ---
struct RawTerminal;
impl RawTerminal {
    fn enable() -> Self {
        print!("\x1B[?25l\x1B[2J"); // Hide cursor, clear screen
        io::stdout().flush().ok();
        #[cfg(unix)]
        unsafe {
            let mut term: libc::termios = std::mem::zeroed();
            libc::tcgetattr(0, &mut term);
            term.c_lflag &= !(libc::ICANON | libc::ECHO);
            libc::tcsetattr(0, libc::TCSANOW, &term);
        }
        RawTerminal
    }
}

impl Drop for RawTerminal {
    fn drop(&mut self) {
        print!("\x1B[?25h\x1B[0m\x1B[2J\x1B[1;1H"); // Restore cursor & screen
        io::stdout().flush().ok();
    }
}

fn read_key_nonblocking() -> Option<u8> {
    let mut buffer = [0u8; 1];
    #[cfg(unix)]
    unsafe {
        let mut fcntl_flags = libc::fcntl(0, libc::F_GETFL);
        libc::fcntl(0, libc::F_SETFL, fcntl_flags | libc::O_NONBLOCK);
        let n = libc::read(0, buffer.as_mut_ptr() as *mut libc::c_void, 1);
        libc::fcntl(0, libc::F_SETFL, fcntl_flags);
        if n > 0 { return Some(buffer[0]); }
    }
    None
}

// --- ALGORITHMIC AUDIO GENERATOR ---
// Synthesizes dynamic multi-frequency waves into stderr (PCM 8kHz 8-bit mono)
fn start_audio_engine(running: Arc<AtomicBool>, resonance_state: Arc<std::sync::Mutex<(f64, f64, f64)>>) {
    thread::spawn(move || {
        let mut t: u64 = 0;
        let mut stderr = io::stderr();
        let mut buffer = [0u8; 256];

        while running.load(Ordering::Relaxed) {
            let (f1, f2, dilation) = *resonance_state.lock().unwrap();
            
            for byte in buffer.iter_mut() {
                t = t.wrapping_add(1);
                let time_sec = t as f64 / 8000.0;

                // Algorithmic synthesis driven by planetary harmonics and time dilation
                let base_wave = ((time_sec * f1 * 2.0 * std::f64::consts::PI).sin() * 40.0) as i16;
                let harmonic = ((time_sec * f2 * 2.0 * std::f64::consts::PI).sin() * 25.0) as i16;
                let sub_drone = ((time_sec * (f1 * 0.5) * std::f64::consts::PI).sin() * 30.0) as i16;
                
                // Frequency modulation from gravitational redshift
                let fm = ((t as f64 * 0.001 * dilation).sin() * 15.0) as i16;

                let val = 128 + (base_wave + harmonic + sub_drone + fm).clamp(-127, 127);
                *byte = val as u8;
            }

            if stderr.write_all(&buffer).is_err() {
                break; // Break if pipe is broken
            }
            thread::sleep(Duration::from_millis(15));
        }
    });
}

fn main() {
    let _raw_term = RawTerminal::enable();
    let running = Arc::new(AtomicBool::new(true));
    let resonance = Arc::new(std::sync::Mutex::new((220.0, 330.0, 1.0)));

    // Spawn audio synthesis thread
    start_audio_engine(Arc::clone(&running), Arc::clone(&resonance));

    // Initialize celestial bodies in orbital paths
    let mut bodies = vec![
        CelestialBody { pos: Vec2::new(35.0, 12.0), vel: Vec2::new(0.0, 0.0), mass: 50.0, symbol: 'Alpha', orbit_radius: 12.0, angle: 0.0, speed: 0.03 },
        CelestialBody { pos: Vec2::new(35.0, 12.0), vel: Vec2::new(0.0, 0.0), mass: 20.0, symbol: 'Beta', orbit_radius: 18.0, angle: 2.0, speed: 0.018 },
        CelestialBody { pos: Vec2::new(35.0, 12.0), vel: Vec2::new(0.0, 0.0), mass: 10.0, symbol: 'Gamma', orbit_radius: 6.0, angle: 4.1, speed: 0.05 },
    ];
    bodies[0].symbol = '◯';
    bodies[1].symbol = '✦';
    bodies[2].symbol = '•';

    let mut anomaly = GravitationalAnomaly {
        pos: Vec2::new(35.0, 12.0),
        mass: 120.0,
    };

    let start_time = Instant::now();

    while running.load(Ordering::Relaxed) {
        let frame_start = Instant::now();

        // 1. INPUT PROCESSING
        if let Some(key) = read_key_nonblocking() {
            match key {
                b'q' | b'Q' => running.store(false, Ordering::Relaxed),
                b'w' | b'W' => anomaly.pos.y = (anomaly.pos.y - 1.0).max(1.0),
                b's' | b'S' => anomaly.pos.y = (anomaly.pos.y + 1.0).min((HEIGHT - 2) as f64),
                b'a' | b'A' => anomaly.pos.x = (anomaly.pos.x - 1.0).max(1.0),
                b'd' | b'D' => anomaly.pos.x = (anomaly.pos.x + 1.0).min((WIDTH - 2) as f64),
                b'+' | b'=' => anomaly.mass = (anomaly.mass + 20.0).min(500.0),
                b'-' | b'_' => anomaly.mass = (anomaly.mass - 20.0).max(10.0),
                _ => {}
            }
        }

        // 2. ORBITAL MECHANICS & TIME DILATION SIMULATION
        let center = Vec2::new((WIDTH / 2) as f64, (HEIGHT / 2) as f64);
        for body in bodies.iter_mut() {
            body.angle += body.speed;
            
            // Perturb orbit based on distance to gravitational anomaly
            let dist_to_anomaly = body.pos.dist(anomaly.pos).max(1.0);
            let anomaly_pull = anomaly.mass / (dist_to_anomaly * dist_to_anomaly);
            
            let base_x = center.x + body.orbit_radius * body.angle.cos() * 1.8; // Aspect ratio adjustment
            let base_y = center.y + body.orbit_radius * body.angle.sin();
            
            let dir_x = (anomaly.pos.x - base_x) / dist_to_anomaly;
            let dir_y = (anomaly.pos.y - base_y) / dist_to_anomaly;

            body.pos.x = base_x + dir_x * anomaly_pull * 2.0;
            body.pos.y = base_y + dir_y * anomaly_pull * 2.0;
        }

        // Calculate Resonance Harmonics for Soundscape
        let d1 = bodies[0].pos.dist(bodies[1].pos);
        let d2 = bodies[1].pos.dist(bodies[2].pos);
        let freq1 = 110.0 + (d1 * 8.0);
        let freq2 = 220.0 + (d2 * 12.0);
        
        // Gravitational Time Dilation factor: T' = T * sqrt(1 - 2GM/rc^2)
        let observer_dist = anomaly.pos.dist(center).max(2.0);
        let time_dilation = (1.0 - (anomaly.mass / (observer_dist * 100.0))).max(0.1).sqrt();

        if let Ok(mut res) = resonance.lock() {
            *res = (freq1, freq2, time_dilation);
        }

        // 3. ASCII CANVAS RENDERING
        let mut canvas = vec![vec![' '; WIDTH]; HEIGHT];

        // Draw Boundary Box
        for x in 0..WIDTH {
            canvas[0][x] = '─';
            canvas[HEIGHT - 1][x] = '─';
        }
        for y in 0..HEIGHT {
            canvas[y][0] = '│';
            canvas[y][WIDTH - 1] = '│';
        }
        canvas[0][0] = '┌'; canvas[0][WIDTH - 1] = '┐';
        canvas[HEIGHT - 1][0] = '└'; canvas[HEIGHT - 1][WIDTH - 1] = '┘';

        // Gravitational Lensing (Raytracing Light Paths)
        for i in 0..NUM_RAYS {
            let angle = (i as f64 / NUM_RAYS as f64) * std::f64::consts::TAU;
            let mut ray = Vec2::new(center.x, center.y);
            let mut dir = Vec2::new(angle.cos() * 1.2, angle.sin() * 0.6);

            for _step in 0..40 {
                ray.x += dir.x;
                ray.y += dir.y;

                if ray.x <= 1.0 || ray.x >= (WIDTH - 2) as f64 || ray.y <= 1.0 || ray.y >= (HEIGHT - 2) as f64 {
                    break;
                }

                // Bend light ray toward singularity (Relativistic Deflection)
                let r_dist = ray.dist(anomaly.pos).max(1.5);
                let bend_force = (0.005 * anomaly.mass) / (r_dist * r_dist);
                dir.x += (anomaly.pos.x - ray.x) * bend_force;
                dir.y += (anomaly.pos.y - ray.y) * bend_force;

                let cx = ray.x.round() as usize;
                let cy = ray.y.round() as usize;

                if cx < WIDTH - 1 && cy < HEIGHT - 1 && canvas[cy][cx] == ' ' {
                    // Char intensity based on deflection speed/bending
                    canvas[cy][cx] = if bend_force > 0.08 { '*' } else if bend_force > 0.03 { '+' } else { '.' };
                }
            }
        }

        // Plot Celestial Bodies
        for body in &bodies {
            let bx = body.pos.x.round() as usize;
            let by = body.pos.y.round() as usize;
            if bx > 0 && bx < WIDTH - 1 && by > 0 && by < HEIGHT - 1 {
                canvas[by][bx] = body.symbol;
            }
        }

        // Plot Gravitational Anomaly Singularity
        let ax = anomaly.pos.x.round() as usize;
        let ay = anomaly.pos.y.round() as usize;
        if ax > 0 && ax < WIDTH - 1 && ay > 0 && ay < HEIGHT - 1 {
            canvas[ay][ax] = '█';
        }

        // 4. DISPLAY FRAME
        let mut frame_str = String::with_capacity(WIDTH * HEIGHT + 512);
        frame_str.push_str("\x1B[H"); // Cursor to home

        frame_str.push_str(&format!(
            "\x1B[1;36m=== STELLAR OBSERVATORY & GRAVITATIONAL LENS ===\x1B[0m\n"
        ));

        for y in 0..HEIGHT {
            for x in 0..WIDTH {
                let ch = canvas[y][x];
                match ch {
                    '█' => frame_str.push_str("\x1B[1;31m█\x1B[0m"), // Red Blackhole
                    '◯' | '✦' | '•' => frame_str.push_str(&format!("\x1B[1;33m{}\x1B[0m", ch)), // Gold Orbs
                    '*' | '+' | '.' => frame_str.push_str(&format!("\x1B[34m{}\x1B[0m", ch)), // Blue Light Path
                    '─' | '│' | '┌' | '┐' | '└' | '┘' => frame_str.push_str(&format!("\x1B[90m{}\x1B[0m", ch)),
                    _ => frame_str.push(ch),
                }
            }
            frame_str.push('\n');
        }

        let elapsed = start_time.elapsed().as_secs_f64();
        frame_str.push_str(&format!(
            "\x1B[1;32m[WASD]\x1B[0m Move Anomaly | \x1B[1;32m[+/-]\x1B[0m Mass: \x1B[1;35m{:.0}\x1B[0m | \x1B[1;32m[Q]\x1B[0m Quit\n",
            anomaly.mass
        ));
        frame_str.push_str(&format!(
            "Time-Dilation Factor: \x1B[1;33m{:.4}x\x1B[0m | Resonant Freq: \x1B[1;36m{:.1}Hz / {:.1}Hz\x1B[0m | Elapsed: {:.1}s\n",
            time_dilation, freq1, freq2, elapsed
        ));

        print!("{}", frame_str);
        io::stdout().flush().ok();

        // Target ~30 FPS
        let render_duration = frame_start.elapsed();
        if render_duration < Duration::from_millis(33) {
            thread::sleep(Duration::from_millis(33) - render_duration);
        }
    }
}

For visual inspiration on atmospheric terminal application design in Rust, check out this guide on [Rust retro chat App – A Custom TUI Chat with Client & Server](https://www.youtube.com/watch?v=653rafFNBmA).