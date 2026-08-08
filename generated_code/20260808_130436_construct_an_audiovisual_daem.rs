// Audio-Visual Network Daemon: Packet Loss Ink-Wash Terminal Simulation
// Compiles directly with `rustc` (no external crate dependencies required).
// Uses standard terminal ANSI sequences, fluid density advection, and real network probes.

use std::io::{self, Write};
use std::net::{ToSocketAddrs, UdpSocket};
use std::sync::atomic::{AtomicBool, AtomicUsize, Ordering};
use std::sync::Arc;
use std::thread;
use std::time::{Duration, Instant};

const WIDTH: usize = 80;
const HEIGHT: usize = 35;
const INK_SHADES: &[char] = &[' ', '░', '▒', '▓', '█'];

struct Particle {
    x: f32,
    y: f32,
    vx: f32,
    vy: f32,
    life: f32,
}

fn main() -> io::Result<()> {
    // Shared state between network thread and renderer thread
    let packet_loss_counter = Arc::new(AtomicUsize::new(0));
    let dns_success_flag = Arc::new(AtomicBool::new(false));

    // Spawn network monitor thread (Pings target to detect loss, sends DNS queries to detect success)
    let loss_clone = Arc::clone(&packet_loss_counter);
    let dns_clone = Arc::clone(&dns_success_flag);
    thread::spawn(move || network_monitor_daemon(loss_clone, dns_clone));

    // Terminal setup: Hide cursor and clear screen
    print!("\x1B[?25l\x1B[2J");
    io::stdout().flush()?;

    let mut grid = vec![0.0f32; WIDTH * HEIGHT];
    let mut particles: Vec<Particle> = Vec::new();
    let mut last_frame = Instant::now();

    loop {
        let dt = last_frame.elapsed().as_secs_f32();
        last_frame = Instant::now();

        // 1. Check DNS Query Trigger -> Erase screen with ripple sweep
        if dns_clone.swap(false, Ordering::Relaxed) {
            // Audio cue: DNS resolution flourish (Terminal Bell pitch pattern)
            print!("\x07");
            io::stdout().flush()?;

            // Dissolve/Erase ink grid slowly
            for val in grid.iter_mut() {
                *val *= 0.1;
            }
            particles.clear();
        }

        // 2. Check Packet Loss Trigger -> Inject fluid dynamics particle streams
        let loss_events = loss_clone.swap(0, Ordering::Relaxed);
        for _ in 0..loss_events {
            // Audio cue: Low pitch pulse for lost packet
            print!("\x07");
            
            // Spawn cluster of fluid ink particles
            let origin_x = (WIDTH / 2) as f32 + (rand_simple() * 10.0 - 5.0);
            let origin_y = 2.0;
            for _ in 0..15 {
                let angle = rand_simple() * std::f32::consts::TAU;
                let speed = 2.0 + rand_simple() * 4.0;
                particles.push(Particle {
                    x: origin_x,
                    y: origin_y,
                    vx: angle.cos() * speed,
                    vy: angle.sin() * speed + 1.5, // gentle downward gravity
                    life: 1.0,
                });
            }
        }

        // 3. Update Fluid Dynamics & Particle Physics
        let mut new_particles = Vec::new();
        for mut p in particles {
            p.x += p.vx * dt * 10.0;
            p.y += p.vy * dt * 10.0;
            p.vx += (rand_simple() - 0.5) * 0.5; // Brownian motion / fluid turbulence
            p.vy += 0.1; // Gravity
            p.life -= dt * 0.3;

            let ix = p.x as usize;
            let iy = p.y as usize;

            if ix < WIDTH && iy < HEIGHT && p.life > 0.0 {
                let idx = iy * WIDTH + ix;
                grid[idx] = (grid[idx] + 0.25).min(1.0); // Deposit ink on canvas
                new_particles.push(p);
            }
        }
        particles = new_particles;

        // 4. Fluid Diffusion Step (Simulate ink bleeding into surrounding paper)
        let mut next_grid = grid.clone();
        for y in 1..HEIGHT - 1 {
            for x in 1..WIDTH - 1 {
                let idx = y * WIDTH + x;
                let neighbors = grid[(y - 1) * WIDTH + x]
                    + grid[(y + 1) * WIDTH + x]
                    + grid[y * WIDTH + (x - 1)]
                    + grid[y * WIDTH + (x + 1)];
                next_grid[idx] = grid[idx] * 0.85 + (neighbors / 4.0) * 0.14;
            }
        }
        grid = next_grid;

        // 5. Render Generative Ink-Wash Painting to Terminal Canvas
        let mut buffer = String::with_capacity(WIDTH * HEIGHT * 8);
        buffer.push_str("\x1B[H"); // Move cursor to top-left

        for y in 0..HEIGHT {
            for x in 0..WIDTH {
                let val = grid[y * WIDTH + x];
                let shade_idx = ((val * (INK_SHADES.len() - 1) as f32).round() as usize)
                    .min(INK_SHADES.len() - 1);
                
                // Generative grayscale palette mapping using ANSI 256-color
                let color_code = 232 + (val * 23.0) as u8;
                buffer.push_str(&format!("\x1B[38;5;{}m{}", color_code, INK_SHADES[shade_idx]));
            }
            buffer.push('\n');
        }

        print!("{}", buffer);
        io::stdout().flush()?;

        thread::sleep(Duration::from_millis(33)); // ~30 FPS frame rate
    }
}

// Network monitoring daemon measuring packet loss and DNS resolutions
fn network_monitor_daemon(loss_counter: Arc<AtomicUsize>, dns_flag: Arc<AtomicBool>) {
    let mut probe_counter = 0;
    loop {
        probe_counter += 1;

        // Test 1: Active DNS resolution probe every 3 seconds
        if probe_counter % 6 == 0 {
            if ("one.one.one.one", 53).to_socket_addrs().is_ok() {
                dns_flag.store(true, Ordering::Relaxed);
            }
        }

        // Test 2: Network packet loss probe via UDP reachability test
        let socket = UdpSocket::bind("0.0.0.0:0");
        let reachable = if let Ok(s) = socket {
            s.set_read_timeout(Some(Duration::from_millis(400))).ok();
            s.connect("1.1.1.1:80").is_ok()
        } else {
            false
        };

        if !reachable {
            loss_counter.fetch_add(1, Ordering::Relaxed);
        }

        thread::sleep(Duration::from_millis(500));
    }
}

// Simple deterministic pseudo-random number generator for zero-dependency fluid chaos
fn rand_simple() -> f32 {
    use std::cell::Cell;
    thread_local! {
        static SEED: Cell<u32> = Cell::new(0xDEADBEEF);
    }
    SEED.with(|seed| {
        let mut x = seed.get();
        x ^= x << 13;
        x ^= x >> 17;
        x ^= x << 5;
        seed.set(x);
        (x as f32) / (u32::MAX as f32)
    })
}